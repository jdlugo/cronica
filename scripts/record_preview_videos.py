#!/usr/bin/env python3
"""
Record iOS preview videos by launching in-app preview scenarios on the simulator.

This script:
1) boots a target simulator,
2) builds + installs the app for simulator (unless skipped),
3) launches one preview scenario at a time via app launch arguments,
4) records the simulator while each scenario plays,
5) exports finalized MP4 files for fastlane/App Store use.
"""

from __future__ import annotations

import argparse
import json
import os
import shlex
import signal
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class Scenario:
    id: str
    output_file: str
    duration_seconds: float
    trim_start_seconds: float
    scene_duration_seconds: float


def run(
    cmd: list[str],
    check: bool = True,
    env: dict[str, str] | None = None,
    quiet: bool = False,
) -> subprocess.CompletedProcess:
    print(f"+ {shlex.join(cmd)}")
    kwargs: dict[str, object] = {}
    if quiet:
        kwargs["stdout"] = subprocess.DEVNULL
        kwargs["stderr"] = subprocess.DEVNULL
    return subprocess.run(cmd, check=check, env=env, **kwargs)


def load_scenarios(manifest_path: Path) -> list[Scenario]:
    with manifest_path.open("r", encoding="utf-8") as handle:
        raw = json.load(handle)

    scenarios: list[Scenario] = []
    for entry in raw:
        scenarios.append(
            Scenario(
                id=entry["id"],
                output_file=entry["outputFile"],
                duration_seconds=float(entry["durationSeconds"]),
                trim_start_seconds=float(entry.get("trimStartSeconds", 0.0)),
                scene_duration_seconds=float(entry.get("sceneDurationSeconds", 2.3)),
            )
        )
    return scenarios


def discover_simulator_udid(preferred_name: str, runtime_hint: str) -> str:
    result = subprocess.run(
        ["xcrun", "simctl", "list", "devices", "available", "--json"],
        check=True,
        capture_output=True,
        text=True,
    )
    payload = json.loads(result.stdout)
    devices_by_runtime = payload.get("devices", {})

    # Prefer exact runtime + name match first.
    for runtime, devices in devices_by_runtime.items():
        if runtime_hint in runtime:
            for device in devices:
                if device.get("isAvailable") and device.get("name") == preferred_name:
                    return device["udid"]

    # Then any booted iPhone.
    for devices in devices_by_runtime.values():
        for device in devices:
            if (
                device.get("isAvailable")
                and device.get("state") == "Booted"
                and "iPhone" in device.get("name", "")
            ):
                return device["udid"]

    # Then first available preferred-name device.
    for devices in devices_by_runtime.values():
        for device in devices:
            if device.get("isAvailable") and device.get("name") == preferred_name:
                return device["udid"]

    # Finally first available iPhone.
    for devices in devices_by_runtime.values():
        for device in devices:
            if device.get("isAvailable") and "iPhone" in device.get("name", ""):
                return device["udid"]

    raise RuntimeError("No available iPhone simulator found.")


def ensure_simulator_ready(udid: str) -> None:
    run(["xcrun", "simctl", "boot", udid], check=False, quiet=True)
    run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True)
    run(["xcrun", "simctl", "ui", udid, "appearance", "dark"], check=False, quiet=True)
    run(
        [
            "xcrun",
            "simctl",
            "status_bar",
            udid,
            "override",
            "--time",
            "9:41",
            "--dataNetwork",
            "wifi",
            "--wifiBars",
            "3",
            "--cellularMode",
            "active",
            "--cellularBars",
            "4",
            "--batteryState",
            "charged",
            "--batteryLevel",
            "100",
        ],
        check=False,
        quiet=True,
    )


def clear_status_bar_override(udid: str) -> None:
    run(["xcrun", "simctl", "status_bar", udid, "clear"], check=False, quiet=True)


def build_app_for_simulator(
    *,
    project: Path,
    scheme: str,
    udid: str,
    derived_data_path: Path,
) -> Path:
    run(
        [
            "xcodebuild",
            "build",
            "-project",
            str(project),
            "-scheme",
            scheme,
            "-destination",
            f"platform=iOS Simulator,id={udid}",
            "-derivedDataPath",
            str(derived_data_path),
        ]
    )

    app_path = derived_data_path / "Build" / "Products" / "Debug-iphonesimulator" / "StreamingNow.app"
    if not app_path.exists():
        raise RuntimeError(f"Built app not found at '{app_path}'.")
    return app_path


def install_app(*, udid: str, app_path: Path) -> None:
    run(["xcrun", "simctl", "install", udid, str(app_path)])


def launch_preview_scenario(*, udid: str, bundle_id: str, scenario: Scenario) -> None:
    run(["xcrun", "simctl", "terminate", udid, bundle_id], check=False, quiet=True)
    run(
        [
            "xcrun",
            "simctl",
            "launch",
            "--terminate-running-process",
            udid,
            bundle_id,
            "--preview-video-scenario",
            scenario.id,
            "--preview-video-scene-duration",
            f"{scenario.scene_duration_seconds:.2f}",
            "--preview-video-disable-monetization",
        ]
    )


def stop_recorder(process: subprocess.Popen[bytes], timeout_seconds: float = 20.0) -> None:
    if process.poll() is not None:
        return
    process.send_signal(signal.SIGINT)
    try:
        process.wait(timeout=timeout_seconds)
    except subprocess.TimeoutExpired:
        process.terminate()
        try:
            process.wait(timeout=5.0)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5.0)


def recording_window_seconds(
    scenario: Scenario,
    startup_buffer_seconds: float = 1.0,
) -> float:
    safe_trim = max(0.0, scenario.trim_start_seconds)
    safe_buffer = max(0.0, startup_buffer_seconds)
    return scenario.duration_seconds + safe_trim + safe_buffer


def probe_video(path: Path) -> tuple[float | None, int | None]:
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration,size",
            "-of",
            "json",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    payload = json.loads(result.stdout or "{}")
    fmt = payload.get("format", {})
    duration = fmt.get("duration")
    size = fmt.get("size")
    return (
        float(duration) if duration is not None else None,
        int(size) if size is not None else None,
    )


def _sampled_frame_hashes(
    path: Path,
    sample_fps: float = 3.0,
    sample_width: int = 240,
) -> list[str]:
    safe_fps = max(0.5, sample_fps)
    safe_width = max(32, sample_width)
    filter_expression = f"fps={safe_fps:.2f},scale={safe_width}:-2"
    result = subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(path),
            "-vf",
            filter_expression,
            "-f",
            "framemd5",
            "-",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    hashes: list[str] = []
    for line in result.stdout.splitlines():
        if not line or line.startswith("#"):
            continue
        parts = [part.strip() for part in line.split(",")]
        if len(parts) < 6:
            continue
        hashes.append(parts[-1])
    return hashes


def video_has_motion(
    path: Path,
    sample_fps: float = 3.0,
    min_unique_frames: int = 3,
    min_sampled_frames: int = 4,
) -> bool:
    hashes = _sampled_frame_hashes(path, sample_fps=sample_fps)
    if len(hashes) < min_sampled_frames:
        return False
    return len(set(hashes)) >= min_unique_frames


def encode_video(raw_video: Path, final_video: Path, scenario: Scenario) -> None:
    final_video.parent.mkdir(parents=True, exist_ok=True)
    run(
        [
            "ffmpeg",
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(raw_video),
            "-ss",
            f"{scenario.trim_start_seconds:.2f}",
            "-t",
            f"{scenario.duration_seconds:.2f}",
            "-vf",
            "setpts=PTS-STARTPTS,fps=30,format=yuv420p",
            "-an",
            "-c:v",
            "libx264",
            "-preset",
            "medium",
            "-crf",
            "20",
            "-movflags",
            "+faststart",
            str(final_video),
        ]
    )

    encoded_duration, encoded_size = probe_video(final_video)
    minimum_duration = max(1.0, scenario.duration_seconds * 0.8)
    minimum_size = 2_048
    if (
        encoded_duration is None
        or encoded_size is None
        or encoded_duration < minimum_duration
        or encoded_size < minimum_size
    ):
        raise RuntimeError(
            "Encoded video failed validation for "
            f"'{scenario.id}' (duration={encoded_duration}, size={encoded_size})."
        )

    if not video_has_motion(final_video):
        raise RuntimeError(
            "Encoded video failed motion validation for "
            f"'{scenario.id}' (appears visually static)."
        )


def run_scenario(
    *,
    scenario: Scenario,
    udid: str,
    bundle_id: str,
    output_dir: Path,
    keep_raw: bool,
) -> Path:
    raw_dir = output_dir / "raw"
    raw_dir.mkdir(parents=True, exist_ok=True)
    raw_video = raw_dir / f"{scenario.id}.mov"
    final_video = output_dir / scenario.output_file

    print(f"\n=== Recording scenario: {scenario.id} ===")
    print(f"Output: {final_video}")

    # Ensure stale captures from previous runs cannot be re-encoded as fresh output.
    if raw_video.exists():
        raw_video.unlink()

    launch_preview_scenario(udid=udid, bundle_id=bundle_id, scenario=scenario)
    # Let the first scene fully render before capture starts.
    time.sleep(1.2)

    record_cmd = ["xcrun", "simctl", "io", udid, "recordVideo", "--codec=h264", str(raw_video)]
    capture_started_at = time.time()
    record_proc = subprocess.Popen(
        record_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )

    # Give recorder enough time to initialize before relying on captured frames.
    time.sleep(0.4)
    time.sleep(recording_window_seconds(scenario))
    stop_recorder(record_proc)
    run(["xcrun", "simctl", "terminate", udid, bundle_id], check=False, quiet=True)

    recorder_exit_code = record_proc.poll()
    recorder_stderr = ""
    if record_proc.stderr is not None:
        recorder_stderr = record_proc.stderr.read().strip()
    if recorder_exit_code not in (0, None):
        details = f"simctl recordVideo exited with code {recorder_exit_code}"
        if recorder_stderr:
            details = f"{details}: {recorder_stderr}"
        raise RuntimeError(details)

    if not raw_video.exists() or raw_video.stat().st_size == 0:
        raise RuntimeError(
            "simctl recordVideo did not produce a usable capture file."
        )
    if raw_video.stat().st_mtime < capture_started_at - 0.5:
        raise RuntimeError(
            "simctl recordVideo capture appears stale (file was not freshly written)."
        )

    encode_video(raw_video, final_video, scenario)

    if not keep_raw and raw_video.exists():
        raw_video.unlink()

    return final_video


def parse_args(project_root: Path) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fully automated iOS preview video generation.")
    parser.add_argument(
        "--project",
        default=str(project_root / "Story.xcodeproj"),
        help="Path to the Xcode project.",
    )
    parser.add_argument(
        "--scheme",
        default="Story (iOS)",
        help="Xcode scheme to test.",
    )
    parser.add_argument(
        "--bundle-id",
        default="com.dlugokecki.qscanlite",
        help="Bundle identifier to launch on simulator.",
    )
    parser.add_argument(
        "--manifest",
        default=str(project_root / "CronicaTests" / "Screenshots" / "preview_video_scenarios.json"),
        help="Path to preview scenario manifest JSON.",
    )
    parser.add_argument(
        "--derived-data-path",
        default=str(project_root / ".build" / "preview_videos"),
        help="DerivedData path used for building the app.",
    )
    parser.add_argument(
        "--skip-build",
        action="store_true",
        help="Skip xcodebuild and use the app currently installed on simulator.",
    )
    parser.add_argument(
        "--output-dir",
        default=str(project_root / "fastlane" / "preview_videos"),
        help="Output directory for finalized videos.",
    )
    parser.add_argument(
        "--udid",
        default=None,
        help="Simulator UDID. If omitted, auto-discovers iPhone 17 Pro on iOS-26-1, then falls back.",
    )
    parser.add_argument(
        "--device-name",
        default="iPhone 17 Pro",
        help="Preferred simulator name when auto-discovering UDID.",
    )
    parser.add_argument(
        "--runtime-hint",
        default="iOS-26-1",
        help="Preferred runtime key suffix when auto-discovering UDID (e.g. iOS-26-1).",
    )
    parser.add_argument(
        "--scenario",
        action="append",
        default=[],
        help="Scenario id to run. Repeat for multiple. Default runs all scenarios.",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List available scenarios and exit.",
    )
    parser.add_argument(
        "--keep-raw",
        action="store_true",
        help="Keep raw simulator captures in output-dir/raw.",
    )
    return parser.parse_args()


def main() -> int:
    project_root = Path(__file__).resolve().parent.parent
    args = parse_args(project_root)

    project = Path(args.project).resolve()
    manifest_path = Path(args.manifest).resolve()
    output_dir = Path(args.output_dir).resolve()
    derived_data_path = Path(args.derived_data_path).resolve()

    scenarios = load_scenarios(manifest_path)
    scenarios_by_id = {scenario.id: scenario for scenario in scenarios}

    if args.list:
        for scenario in scenarios:
            print(f"{scenario.id:20} -> {scenario.output_file}")
        return 0

    selected_ids = args.scenario or [scenario.id for scenario in scenarios]
    missing = [scenario_id for scenario_id in selected_ids if scenario_id not in scenarios_by_id]
    if missing:
        print(f"Unknown scenario id(s): {', '.join(missing)}", file=sys.stderr)
        return 2

    selected_scenarios = [scenarios_by_id[scenario_id] for scenario_id in selected_ids]
    udid = args.udid or discover_simulator_udid(args.device_name, args.runtime_hint)

    print(f"Using simulator UDID: {udid}")
    print(f"Scenario count: {len(selected_scenarios)}")
    output_dir.mkdir(parents=True, exist_ok=True)

    generated: list[Path] = []
    try:
        ensure_simulator_ready(udid)
        if not args.skip_build:
            app_path = build_app_for_simulator(
                project=project,
                scheme=args.scheme,
                udid=udid,
                derived_data_path=derived_data_path,
            )
            install_app(udid=udid, app_path=app_path)

        for scenario in selected_scenarios:
            generated.append(
                run_scenario(
                    scenario=scenario,
                    udid=udid,
                    bundle_id=args.bundle_id,
                    output_dir=output_dir,
                    keep_raw=args.keep_raw,
                )
            )
    finally:
        clear_status_bar_override(udid)

    print("\nGenerated preview videos:")
    for path in generated:
        print(f"- {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
