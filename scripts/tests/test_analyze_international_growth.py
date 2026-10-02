import csv
import datetime as dt
import gzip
import importlib.util
import pathlib
import sys
import tempfile
import unittest


def load_module():
    script_path = (
        pathlib.Path(__file__).resolve().parents[1]
        / "analyze_international_growth.py"
    )
    spec = importlib.util.spec_from_file_location(
        "analyze_international_growth", script_path
    )
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load analyze_international_growth module")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


class InternationalGrowthAnalysisTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_module()
        cls.fixture_dir = pathlib.Path(__file__).resolve().parent / "fixtures"

    def install_fixture(self, name: str, destination: pathlib.Path) -> None:
        source = self.fixture_dir / name
        with source.open("rb") as input_file, gzip.open(
            destination, "wb"
        ) as output_file:
            output_file.write(input_file.read())

    def test_app_store_parser_aggregates_target_market_funnel(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = pathlib.Path(temp_dir)
            self.install_fixture(
                "app_store_engagement.tsv", root / "engagement.tsv.gz"
            )
            self.install_fixture(
                "app_store_downloads.tsv", root / "downloads.tsv.gz"
            )
            rows = {}
            ranges = {}
            parsed = self.module.parse_app_store_reports(root, rows, ranges)
            france = self.module.metrics_for_country(rows, "FR")
            self.assertEqual(parsed, 13)
            self.assertEqual(france.apple_impressions, 100)
            self.assertEqual(france.apple_page_views, 10)
            self.assertEqual(france.apple_get_taps, 5)
            self.assertEqual(france.apple_first_downloads, 4)
            self.assertEqual(
                ranges["apple_engagement"],
                (dt.date(2026, 8, 20), dt.date(2026, 8, 20)),
            )

    def test_admob_parser_converts_micros_and_aggregates_units(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            path = pathlib.Path(temp_dir) / "admob.csv"
            with path.open("w", newline="", encoding="utf-8") as handle:
                writer = csv.DictWriter(
                    handle,
                    fieldnames=[
                        "dim_COUNTRY",
                        "dim_DATE",
                        "met_AD_REQUESTS",
                        "met_CLICKS",
                        "met_ESTIMATED_EARNINGS",
                        "met_IMPRESSIONS",
                        "met_MATCHED_REQUESTS",
                    ],
                )
                writer.writeheader()
                writer.writerow(
                    {
                        "dim_COUNTRY": "FR",
                        "dim_DATE": "20260820",
                        "met_AD_REQUESTS": "10",
                        "met_CLICKS": "1",
                        "met_ESTIMATED_EARNINGS": "250000",
                        "met_IMPRESSIONS": "5",
                        "met_MATCHED_REQUESTS": "8",
                    }
                )
                writer.writerow(
                    {
                        "dim_COUNTRY": "FR",
                        "dim_DATE": "20260820",
                        "met_AD_REQUESTS": "4",
                        "met_CLICKS": "0",
                        "met_ESTIMATED_EARNINGS": "50000",
                        "met_IMPRESSIONS": "2",
                        "met_MATCHED_REQUESTS": "4",
                    }
                )
            rows = {}
            ranges = {}
            self.module.parse_admob(path, rows, ranges)
            france = self.module.metrics_for_country(rows, "FR")
            self.assertEqual(france.admob_requests, 14)
            self.assertEqual(france.admob_impressions, 7)
            self.assertEqual(france.admob_earnings_usd, self.module.decimal.Decimal("0.30"))

    def test_posthog_rows_add_behavior_without_user_level_join(self):
        rows = {}
        ranges = {}
        self.module.add_posthog_rows(
            [
                {
                    "event_date": "2026-08-20",
                    "country": "MX",
                    "active_users": 7,
                    "launches": 4,
                    "puzzle_opens": 3,
                    "puzzle_guesses": 2,
                    "puzzle_finishes": 1,
                    "ad_impressions": 2,
                }
            ],
            rows,
            ranges,
        )
        mexico = self.module.metrics_for_country(rows, "MX")
        self.assertEqual(mexico.posthog_active_users, 7)
        self.assertEqual(mexico.posthog_puzzle_guesses, 2)

    def test_default_product_page_labels_are_canonicalized(self):
        self.assertEqual(
            self.module.product_page_title("Default page"),
            "Default product page",
        )
        self.assertEqual(
            self.module.product_page_title("Default product page"),
            "Default product page",
        )

    def test_report_labels_directional_conversion_and_missing_sources(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = pathlib.Path(temp_dir)
            self.install_fixture(
                "app_store_engagement.tsv", root / "engagement.tsv.gz"
            )
            self.install_fixture(
                "app_store_downloads.tsv", root / "downloads.tsv.gz"
            )
            rows = {}
            ranges = {}
            self.module.parse_app_store_reports(root, rows, ranges)
            report = self.module.render_markdown(
                rows,
                ranges,
                generated_at=dt.datetime(
                    2026, 8, 27, tzinfo=dt.timezone.utc
                ),
            )
            self.assertIn("France target | 100 | 10 | 5 | 4", report)
            self.assertIn("Count-based download yield", report)
            self.assertIn("| posthog | unavailable | unavailable |", report)
            self.assertNotIn("Bearer", report)

    def test_detailed_reports_attribute_custom_product_pages(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = pathlib.Path(temp_dir)
            detailed = root / "engagement-detailed" / "page.tsv.gz"
            detailed.parent.mkdir(parents=True)
            with gzip.open(detailed, "wt", encoding="utf-8", newline="") as handle:
                writer = csv.DictWriter(
                    handle,
                    delimiter="\t",
                    fieldnames=[
                        "Date",
                        "Event",
                        "Page Type",
                        "Page Title",
                        "Engagement Type",
                        "Territory",
                        "Counts",
                    ],
                )
                writer.writeheader()
                writer.writerow(
                    {
                        "Date": "2026-08-20",
                        "Event": "Page view",
                        "Page Type": "Product page",
                        "Page Title": "Daily Puzzle - International",
                        "Engagement Type": "",
                        "Territory": "ES",
                        "Counts": "9",
                    }
                )
            rows = {}
            ranges = {}
            parsed = self.module.parse_product_page_reports(root, rows, ranges)
            self.assertEqual(parsed, 1)
            item = rows[(dt.date(2026, 8, 20), "ES", "Daily Puzzle - International")]
            self.assertEqual(item.apple_page_views, 9)
            report = self.module.render_markdown({}, ranges, page_rows=rows)
            self.assertIn("Daily Puzzle - International | Spain target", report)


if __name__ == "__main__":
    unittest.main()
