import importlib.util
import io
import pathlib
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


def load_module():
    script_path = pathlib.Path(__file__).resolve().parents[1] / "record_preview_videos.py"
    spec = importlib.util.spec_from_file_location("record_preview_videos", script_path)
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load record_preview_videos module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class PreviewVideoRecorderTimingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_module()

    def make_scenario(self, *, duration: float, trim: float):
        return self.module.Scenario(
            id="test",
            output_file="test.mp4",
            duration_seconds=duration,
            trim_start_seconds=trim,
            scene_duration_seconds=2.3,
        )

    def test_recording_window_includes_trim_start(self):
        scenario = self.make_scenario(duration=8.0, trim=0.7)
        window = self.module.recording_window_seconds(scenario)
        self.assertEqual(window, 9.7)

    def test_recording_window_clamps_negative_trim_start(self):
        scenario = self.make_scenario(duration=8.0, trim=-2.0)
        window = self.module.recording_window_seconds(scenario)
        self.assertEqual(window, 9.0)

    def test_recording_window_honors_custom_startup_buffer(self):
        scenario = self.make_scenario(duration=8.0, trim=1.5)
        window = self.module.recording_window_seconds(scenario, startup_buffer_seconds=1.4)
        self.assertEqual(window, 10.9)


class PreviewVideoMotionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_module()
        if shutil.which("ffmpeg") is None:
            raise unittest.SkipTest("ffmpeg is required for motion validation tests")

        cls.temp_dir = tempfile.TemporaryDirectory()
        cls.static_video = pathlib.Path(cls.temp_dir.name) / "static.mp4"
        cls.motion_video = pathlib.Path(cls.temp_dir.name) / "motion.mp4"

        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-hide_banner",
                "-loglevel",
                "error",
                "-f",
                "lavfi",
                "-i",
                "color=c=black:s=320x240:d=2",
                "-pix_fmt",
                "yuv420p",
                str(cls.static_video),
            ],
            check=True,
        )
        subprocess.run(
            [
                "ffmpeg",
                "-y",
                "-hide_banner",
                "-loglevel",
                "error",
                "-f",
                "lavfi",
                "-i",
                "testsrc2=s=320x240:d=2",
                "-pix_fmt",
                "yuv420p",
                str(cls.motion_video),
            ],
            check=True,
        )

    @classmethod
    def tearDownClass(cls):
        cls.temp_dir.cleanup()

    def test_video_has_motion_detects_static_video(self):
        self.assertFalse(self.module.video_has_motion(self.static_video))

    def test_video_has_motion_detects_moving_video(self):
        self.assertTrue(self.module.video_has_motion(self.motion_video))


class PreviewVideoRunScenarioTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_module()

    def make_scenario(self, *, scenario_id: str = "home-discovery"):
        return self.module.Scenario(
            id=scenario_id,
            output_file="01-home-discovery.mp4",
            duration_seconds=12.0,
            trim_start_seconds=1.2,
            scene_duration_seconds=3.6,
        )

    def test_run_scenario_removes_stale_raw_before_recording(self):
        scenario = self.make_scenario()
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = pathlib.Path(temp_dir)
            raw_dir = output_dir / "raw"
            raw_dir.mkdir(parents=True, exist_ok=True)
            stale_raw = raw_dir / f"{scenario.id}.mov"
            stale_raw.write_bytes(b"stale-capture")

            class FakeProcess:
                def __init__(self):
                    self.returncode = 0
                    self.stderr = io.StringIO("")

                def poll(self):
                    return None

                def send_signal(self, _):
                    self.returncode = 0

                def wait(self, timeout=None):
                    return 0

            def fake_popen(cmd, stdout=None, stderr=None, text=None):
                self.assertFalse(
                    stale_raw.exists(),
                    "run_scenario must remove stale raw captures before starting a new recording",
                )
                stale_raw.write_bytes(b"fresh-capture")
                return FakeProcess()

            with (
                mock.patch.object(self.module, "launch_preview_scenario"),
                mock.patch.object(self.module, "run"),
                mock.patch.object(self.module, "encode_video"),
                mock.patch.object(self.module.time, "sleep"),
                mock.patch.object(self.module.subprocess, "Popen", side_effect=fake_popen),
            ):
                self.module.run_scenario(
                    scenario=scenario,
                    udid="UDID",
                    bundle_id="com.example.app",
                    output_dir=output_dir,
                    keep_raw=True,
                )

    def test_run_scenario_raises_when_recorder_exits_with_error(self):
        scenario = self.make_scenario()
        with tempfile.TemporaryDirectory() as temp_dir:
            output_dir = pathlib.Path(temp_dir)

            class FailedRecorderProcess:
                def __init__(self):
                    self.returncode = 1
                    self.stderr = io.StringIO("record failed")

                def poll(self):
                    return 1

                def send_signal(self, _):
                    self.returncode = 1

                def wait(self, timeout=None):
                    return 1

            with (
                mock.patch.object(self.module, "launch_preview_scenario"),
                mock.patch.object(self.module, "run"),
                mock.patch.object(self.module, "encode_video"),
                mock.patch.object(self.module.time, "sleep"),
                mock.patch.object(
                    self.module.subprocess,
                    "Popen",
                    return_value=FailedRecorderProcess(),
                ),
            ):
                with self.assertRaises(RuntimeError):
                    self.module.run_scenario(
                        scenario=scenario,
                        udid="UDID",
                        bundle_id="com.example.app",
                        output_dir=output_dir,
                        keep_raw=True,
                    )


if __name__ == "__main__":
    unittest.main()
