import unittest
from pathlib import Path


class PostHogAuditContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.script = (
            Path(__file__).resolve().parents[1] / "posthog_audit.sh"
        ).read_text(encoding="utf-8")

    def test_international_queries_are_part_of_release_audit(self):
        for label in (
            "International telemetry property coverage by build",
            "Target-territory activation and monetization signals",
            "Target-territory locale and content-region alignment",
            "Daily Puzzle localization coverage by build",
        ):
            self.assertIn(label, self.script)

    def test_international_join_dimensions_are_queried(self):
        for property_name in (
            "app_locale",
            "device_region",
            "content_region",
            "puzzle_locale",
            "puzzle_localization_source",
        ):
            self.assertIn(f"properties.{property_name}", self.script)


if __name__ == "__main__":
    unittest.main()
