import hashlib
import importlib.util
import pathlib
import subprocess
import sys
import tempfile
import unittest


def load_module():
    script_path = (
        pathlib.Path(__file__).resolve().parents[1]
        / "pull_app_store_analytics.py"
    )
    spec = importlib.util.spec_from_file_location(
        "pull_app_store_analytics", script_path
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load pull_app_store_analytics module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def der_integer(value: int) -> bytes:
    raw = value.to_bytes(max(1, (value.bit_length() + 7) // 8), "big")
    if raw[0] & 0x80:
        raw = b"\0" + raw
    return b"\x02" + bytes([len(raw)]) + raw


class AppStoreAnalyticsPullTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_module()

    def test_der_signature_converts_to_fixed_width_jose(self):
        body = der_integer(1) + der_integer(2)
        der = b"\x30" + bytes([len(body)]) + body
        signature = self.module.der_ecdsa_to_jose(der)
        self.assertEqual(len(signature), 64)
        self.assertEqual(signature[:32], b"\0" * 31 + b"\x01")
        self.assertEqual(signature[32:], b"\0" * 31 + b"\x02")

    def test_create_jwt_uses_raw_signature_and_expected_claims(self):
        body = der_integer(3) + der_integer(4)
        completed = subprocess.CompletedProcess(
            args=[], returncode=0, stdout=b"\x30" + bytes([len(body)]) + body
        )

        def fake_run(*args, **kwargs):
            self.assertNotIn("secret-key", kwargs["input"].decode("ascii"))
            return completed

        token = self.module.create_jwt(
            key_id="KEY123",
            issuer_id="ISSUER123",
            key_path=pathlib.Path("secret-key.p8"),
            now=1_700_000_000,
            run=fake_run,
        )
        self.assertEqual(len(token.split(".")), 3)

    def test_select_active_request_skips_stopped_requests(self):
        requests = [
            {
                "id": "stopped",
                "attributes": {
                    "accessType": "ONGOING",
                    "stoppedDueToInactivity": True,
                },
            },
            {
                "id": "active",
                "attributes": {
                    "accessType": "ONGOING",
                    "stoppedDueToInactivity": False,
                },
            },
        ]
        selected = self.module.select_active_request(requests)
        self.assertEqual(selected["id"], "active")

    def test_file_matches_checks_size_and_checksum(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = pathlib.Path(temp_dir) / "segment.tsv.gz"
            path.write_bytes(b"segment-data")
            checksum = hashlib.md5(b"segment-data").hexdigest()
            self.assertTrue(
                self.module.file_matches(
                    path, checksum=checksum, size_in_bytes=len(b"segment-data")
                )
            )
            self.assertFalse(
                self.module.file_matches(
                    path, checksum=checksum, size_in_bytes=999
                )
            )

    def test_manifest_record_does_not_persist_signed_url(self):
        segment = {
            "id": "segment-id",
            "attributes": {
                "checksum": "abc123",
                "sizeInBytes": 42,
                "url": "https://signed.example/private-token",
            },
        }
        record = self.module.segment_record(
            report_key="engagement",
            report_name="App Store Discovery and Engagement Standard",
            processing_date="2026-08-27",
            segment=segment,
            relative_path=pathlib.Path("engagement/segment.tsv.gz"),
        )
        self.assertNotIn("url", record)
        self.assertNotIn("private-token", str(record))

    def test_all_reports_include_detailed_product_page_sources(self):
        self.assertEqual(
            self.module.REPORT_NAMES["engagement-detailed"],
            "App Store Discovery and Engagement Detailed",
        )
        self.assertEqual(
            self.module.REPORT_NAMES["downloads-detailed"],
            "App Downloads Detailed",
        )


if __name__ == "__main__":
    unittest.main()
