#!/usr/bin/env python3
"""Download App Store Connect Analytics report segments safely.

The script uses an existing ongoing Analytics Reports request. It never creates
or mutates App Store Connect resources, and it never persists signed segment
URLs or API credentials.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import pathlib
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Callable, Iterable


API_ROOT = "https://api.appstoreconnect.apple.com"
REPORT_NAMES = {
    "engagement": "App Store Discovery and Engagement Standard",
    "downloads": "App Downloads Standard",
    "engagement-detailed": "App Store Discovery and Engagement Detailed",
    "downloads-detailed": "App Downloads Detailed",
}


def base64url(value: bytes) -> str:
    return base64.urlsafe_b64encode(value).rstrip(b"=").decode("ascii")


def _read_der_length(value: bytes, index: int) -> tuple[int, int]:
    if index >= len(value):
        raise ValueError("Truncated DER length")
    first = value[index]
    index += 1
    if first < 0x80:
        return first, index
    byte_count = first & 0x7F
    if byte_count == 0 or byte_count > 4 or index + byte_count > len(value):
        raise ValueError("Invalid DER length")
    length = int.from_bytes(value[index : index + byte_count], "big")
    return length, index + byte_count


def _read_der_integer(value: bytes, index: int) -> tuple[bytes, int]:
    if index >= len(value) or value[index] != 0x02:
        raise ValueError("Expected DER integer")
    length, index = _read_der_length(value, index + 1)
    end = index + length
    if length == 0 or end > len(value):
        raise ValueError("Invalid DER integer")
    integer = value[index:end]
    while len(integer) > 1 and integer[0] == 0:
        integer = integer[1:]
    return integer, end


def der_ecdsa_to_jose(signature: bytes, component_size: int = 32) -> bytes:
    """Convert OpenSSL's ASN.1 ECDSA signature to JWT's raw R || S form."""

    if not signature or signature[0] != 0x30:
        raise ValueError("Expected DER sequence")
    sequence_length, index = _read_der_length(signature, 1)
    sequence_end = index + sequence_length
    if sequence_end != len(signature):
        raise ValueError("Invalid DER sequence length")
    r_value, index = _read_der_integer(signature, index)
    s_value, index = _read_der_integer(signature, index)
    if index != sequence_end:
        raise ValueError("Unexpected DER signature data")
    if len(r_value) > component_size or len(s_value) > component_size:
        raise ValueError("ECDSA component exceeds expected size")
    return r_value.rjust(component_size, b"\0") + s_value.rjust(
        component_size, b"\0"
    )


def create_jwt(
    *,
    key_id: str,
    issuer_id: str,
    key_path: pathlib.Path,
    now: int | None = None,
    run: Callable[..., subprocess.CompletedProcess[bytes]] = subprocess.run,
) -> str:
    issued_at = int(time.time()) if now is None else now
    header = {"alg": "ES256", "kid": key_id, "typ": "JWT"}
    payload = {
        "iss": issuer_id,
        "iat": issued_at,
        "exp": issued_at + 1_200,
        "aud": "appstoreconnect-v1",
    }
    encoded_header = base64url(
        json.dumps(header, separators=(",", ":")).encode("utf-8")
    )
    encoded_payload = base64url(
        json.dumps(payload, separators=(",", ":")).encode("utf-8")
    )
    signing_input = f"{encoded_header}.{encoded_payload}".encode("ascii")
    completed = run(
        [
            "openssl",
            "dgst",
            "-sha256",
            "-sign",
            str(key_path.expanduser()),
        ],
        input=signing_input,
        capture_output=True,
        check=True,
    )
    signature = der_ecdsa_to_jose(completed.stdout)
    return f"{encoded_header}.{encoded_payload}.{base64url(signature)}"


class AppStoreConnectClient:
    def __init__(
        self,
        token: str,
        *,
        opener: Callable[..., Any] = urllib.request.urlopen,
    ) -> None:
        self.token = token
        self.opener = opener

    def get_json(self, path_or_url: str) -> dict[str, Any]:
        url = (
            path_or_url
            if path_or_url.startswith("https://")
            else f"{API_ROOT}{path_or_url}"
        )
        request = urllib.request.Request(
            url,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Accept": "application/json",
            },
        )
        try:
            with self.opener(request, timeout=60) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            body = error.read().decode("utf-8", errors="replace")[:2_000]
            raise RuntimeError(
                f"App Store Connect API returned HTTP {error.code}: {body}"
            ) from error

    def paged(self, path: str) -> Iterable[dict[str, Any]]:
        next_url: str | None = path
        while next_url:
            payload = self.get_json(next_url)
            yield from payload.get("data", [])
            next_url = payload.get("links", {}).get("next")


def select_active_request(
    requests: Iterable[dict[str, Any]], request_id: str | None = None
) -> dict[str, Any]:
    candidates = []
    for request in requests:
        if request_id and request.get("id") != request_id:
            continue
        attributes = request.get("attributes", {})
        if attributes.get("stoppedDueToInactivity"):
            continue
        if attributes.get("accessType") == "ONGOING":
            candidates.append(request)
    if not candidates:
        requested = f" {request_id}" if request_id else ""
        raise RuntimeError(f"No active ongoing analytics report request{requested}")
    return candidates[0]


def checksum_for(path: pathlib.Path, expected_checksum: str) -> str:
    algorithm = "md5" if len(expected_checksum) == 32 else "sha256"
    digest = hashlib.new(algorithm)
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def file_matches(
    path: pathlib.Path, *, checksum: str, size_in_bytes: int | None
) -> bool:
    if not path.is_file():
        return False
    if size_in_bytes is not None and path.stat().st_size != size_in_bytes:
        return False
    return checksum_for(path, checksum).lower() == checksum.lower()


def download_segment(
    url: str,
    destination: pathlib.Path,
    *,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    request = urllib.request.Request(url, headers={"User-Agent": "CronicaAnalytics/1"})
    try:
        with opener(request, timeout=120) as response, temporary.open("wb") as output:
            while True:
                chunk = response.read(1024 * 1024)
                if not chunk:
                    break
                output.write(chunk)
        temporary.replace(destination)
    except urllib.error.HTTPError as error:
        temporary.unlink(missing_ok=True)
        raise RuntimeError(
            f"Analytics segment download returned HTTP {error.code}"
        ) from error
    except Exception:
        temporary.unlink(missing_ok=True)
        raise


def load_manifest(path: pathlib.Path) -> dict[str, Any]:
    if not path.exists():
        return {"schema_version": 1, "segments": {}}
    payload = json.loads(path.read_text(encoding="utf-8"))
    if payload.get("schema_version") != 1:
        raise RuntimeError("Unsupported analytics manifest schema")
    payload.setdefault("segments", {})
    return payload


def write_manifest(path: pathlib.Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(".tmp")
    temporary.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    temporary.replace(path)


def segment_record(
    *,
    report_key: str,
    report_name: str,
    processing_date: str,
    segment: dict[str, Any],
    relative_path: pathlib.Path,
) -> dict[str, Any]:
    attributes = segment.get("attributes", {})
    return {
        "report_key": report_key,
        "report_name": report_name,
        "processing_date": processing_date,
        "checksum": attributes.get("checksum"),
        "size_in_bytes": attributes.get("sizeInBytes"),
        "path": relative_path.as_posix(),
    }


def pull_reports(
    *,
    client: AppStoreConnectClient,
    app_id: str,
    output_dir: pathlib.Path,
    report_keys: Iterable[str],
    request_id: str | None = None,
    segment_opener: Callable[..., Any] = urllib.request.urlopen,
) -> tuple[int, int]:
    request_path = f"/v1/apps/{urllib.parse.quote(app_id)}/analyticsReportRequests?limit=200"
    active_request = select_active_request(
        client.paged(request_path), request_id=request_id
    )
    selected_request_id = active_request["id"]
    reports_path = (
        f"/v1/analyticsReportRequests/{selected_request_id}/reports?limit=200"
    )
    reports_by_name = {
        report.get("attributes", {}).get("name"): report
        for report in client.paged(reports_path)
    }

    output_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = output_dir / "manifest.json"
    manifest = load_manifest(manifest_path)
    manifest.update(
        {
            "app_id": app_id,
            "request_id": selected_request_id,
            "updated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        }
    )

    downloaded = 0
    reused = 0
    for report_key in report_keys:
        report_name = REPORT_NAMES[report_key]
        report = reports_by_name.get(report_name)
        if not report:
            raise RuntimeError(f"Analytics report is unavailable: {report_name}")
        query = urllib.parse.urlencode(
            {"filter[granularity]": "DAILY", "limit": "200"}
        )
        instances_path = (
            f"/v1/analyticsReports/{report['id']}/instances?{query}"
        )
        instances = sorted(
            client.paged(instances_path),
            key=lambda item: item.get("attributes", {}).get("processingDate", ""),
        )
        for instance in instances:
            processing_date = instance.get("attributes", {}).get(
                "processingDate", "unknown-date"
            )
            segments_path = (
                f"/v1/analyticsReportInstances/{instance['id']}/segments?limit=200"
            )
            for segment in client.paged(segments_path):
                segment_id = segment["id"]
                attributes = segment.get("attributes", {})
                checksum = attributes.get("checksum")
                if not checksum:
                    raise RuntimeError(f"Segment {segment_id} has no checksum")
                relative_path = pathlib.Path(report_key) / processing_date / (
                    f"{segment_id}.tsv.gz"
                )
                destination = output_dir / relative_path
                size = attributes.get("sizeInBytes")
                if file_matches(
                    destination, checksum=checksum, size_in_bytes=size
                ):
                    reused += 1
                else:
                    signed_url = attributes.get("url")
                    if not signed_url:
                        raise RuntimeError(
                            f"Segment {segment_id} has no download URL"
                        )
                    download_segment(
                        signed_url, destination, opener=segment_opener
                    )
                    if not file_matches(
                        destination, checksum=checksum, size_in_bytes=size
                    ):
                        destination.unlink(missing_ok=True)
                        raise RuntimeError(
                            f"Checksum or size verification failed for segment {segment_id}"
                        )
                    downloaded += 1
                manifest["segments"][segment_id] = segment_record(
                    report_key=report_key,
                    report_name=report_name,
                    processing_date=processing_date,
                    segment=segment,
                    relative_path=relative_path,
                )
                write_manifest(manifest_path, manifest)
    return downloaded, reused


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Download existing App Store Connect Analytics reports."
    )
    parser.add_argument(
        "--app-id", default=os.getenv("ASC_APP_ID", "455556959")
    )
    parser.add_argument("--request-id", default=os.getenv("ASC_REPORT_REQUEST_ID"))
    parser.add_argument(
        "--key-id",
        default=os.getenv("ASC_KEY_ID")
        or os.getenv("APP_STORE_CONNECT_API_KEY_KEY_ID"),
    )
    parser.add_argument(
        "--issuer-id",
        default=os.getenv("ASC_ISSUER_ID")
        or os.getenv("APP_STORE_CONNECT_API_KEY_ISSUER_ID"),
    )
    parser.add_argument(
        "--key-path",
        default=os.getenv("ASC_KEY_PATH")
        or os.getenv("APP_STORE_CONNECT_API_KEY_KEY_FILEPATH"),
    )
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        default=pathlib.Path(".build/international-growth/app-store-connect"),
    )
    parser.add_argument(
        "--report",
        choices=["all", *REPORT_NAMES],
        default="all",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.key_id or not args.issuer_id or not args.key_path:
        print(
            "Set ASC_KEY_ID, ASC_ISSUER_ID, and ASC_KEY_PATH before pulling reports.",
            file=sys.stderr,
        )
        return 2
    key_path = pathlib.Path(args.key_path).expanduser()
    if not key_path.is_file():
        print("ASC_KEY_PATH does not point to a readable file.", file=sys.stderr)
        return 2
    report_keys = list(REPORT_NAMES) if args.report == "all" else [args.report]
    try:
        token = create_jwt(
            key_id=args.key_id,
            issuer_id=args.issuer_id,
            key_path=key_path,
        )
        downloaded, reused = pull_reports(
            client=AppStoreConnectClient(token),
            app_id=args.app_id,
            output_dir=args.output_dir,
            report_keys=report_keys,
            request_id=args.request_id,
        )
    except (RuntimeError, ValueError, subprocess.CalledProcessError) as error:
        print(f"App Store analytics pull failed: {error}", file=sys.stderr)
        return 1
    print(
        f"App Store analytics ready: {downloaded} downloaded, "
        f"{reused} verified and reused."
    )
    print(f"Manifest: {args.output_dir / 'manifest.json'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
