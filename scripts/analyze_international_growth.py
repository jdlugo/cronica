#!/usr/bin/env python3
"""Build Cronica's aggregate international acquisition-to-revenue report."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import decimal
import gzip
import json
import os
import pathlib
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any, Callable, Iterable


TARGET_ORDER = ("FR", "ES", "MX", "BR", "US", "CN")
COHORT_NAMES = {
    "FR": "France target",
    "ES": "Spain target",
    "MX": "Mexico target",
    "BR": "Brazil target",
    "US": "U.S. comparator",
    "CN": "China observation",
}
POSTHOG_DEFAULT_URL = "https://us.posthog.com"


@dataclass
class DailyMetrics:
    apple_impressions: int = 0
    apple_page_views: int = 0
    apple_taps: int = 0
    apple_get_taps: int = 0
    apple_first_downloads: int = 0
    apple_redownloads: int = 0
    apple_updates: int = 0
    apple_search_impressions: int = 0
    apple_browse_impressions: int = 0
    apple_search_downloads: int = 0
    apple_browse_downloads: int = 0
    posthog_active_users: int = 0
    posthog_launches: int = 0
    posthog_puzzle_opens: int = 0
    posthog_puzzle_guesses: int = 0
    posthog_puzzle_finishes: int = 0
    posthog_ad_impressions: int = 0
    admob_requests: int = 0
    admob_matched_requests: int = 0
    admob_impressions: int = 0
    admob_clicks: int = 0
    admob_earnings_usd: decimal.Decimal = decimal.Decimal("0")


@dataclass
class DailyProductPageMetrics:
    apple_impressions: int = 0
    apple_page_views: int = 0
    apple_get_taps: int = 0
    apple_first_downloads: int = 0
    apple_redownloads: int = 0


def parse_date(value: str) -> dt.date:
    return dt.date.fromisoformat(value)


def in_window(
    value: dt.date, start: dt.date | None, end: dt.date | None
) -> bool:
    return (start is None or value >= start) and (end is None or value <= end)


def integer(value: Any) -> int:
    if value in (None, ""):
        return 0
    return int(decimal.Decimal(str(value)))


def territory(value: Any) -> str:
    normalized = str(value or "").strip().upper()
    return normalized or "UNKNOWN"


def product_page_title(value: Any) -> str:
    normalized = str(value or "").strip()
    if normalized.casefold() in {"default page", "default product page"}:
        return "Default product page"
    return normalized or "Unavailable product page"


def update_range(
    ranges: dict[str, tuple[dt.date, dt.date]], source: str, value: dt.date
) -> None:
    current = ranges.get(source)
    if current is None:
        ranges[source] = (value, value)
    else:
        ranges[source] = (min(current[0], value), max(current[1], value))


def rows_for(
    rows: dict[tuple[dt.date, str], DailyMetrics],
    date: dt.date,
    country: str,
) -> DailyMetrics:
    return rows.setdefault((date, country), DailyMetrics())


def parse_app_store_reports(
    root: pathlib.Path,
    rows: dict[tuple[dt.date, str], DailyMetrics],
    ranges: dict[str, tuple[dt.date, dt.date]],
    *,
    start: dt.date | None = None,
    end: dt.date | None = None,
) -> int:
    parsed_rows = 0
    for path in sorted(root.rglob("*.tsv.gz")):
        if any(part.endswith("-detailed") for part in path.parts):
            continue
        with gzip.open(path, "rt", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle, delimiter="\t")
            if not reader.fieldnames:
                continue
            report_type = (
                "engagement"
                if "Event" in reader.fieldnames
                else "downloads"
                if "Download Type" in reader.fieldnames
                else None
            )
            if report_type is None:
                continue
            for raw in reader:
                event_date = parse_date(raw["Date"])
                if not in_window(event_date, start, end):
                    continue
                country = territory(raw.get("Territory"))
                metrics = rows_for(rows, event_date, country)
                count = integer(raw.get("Counts"))
                parsed_rows += 1
                update_range(ranges, f"apple_{report_type}", event_date)
                if report_type == "engagement":
                    event = str(raw.get("Event") or "").strip().lower()
                    source = str(raw.get("Source Type") or "").strip().lower()
                    engagement = str(raw.get("Engagement Type") or "").strip().lower()
                    if event == "impression":
                        metrics.apple_impressions += count
                        if source == "app store search":
                            metrics.apple_search_impressions += count
                        elif source == "app store browse":
                            metrics.apple_browse_impressions += count
                    elif event == "page view":
                        metrics.apple_page_views += count
                    elif event == "tap":
                        metrics.apple_taps += count
                    if engagement == "get":
                        metrics.apple_get_taps += count
                else:
                    download_type = str(raw.get("Download Type") or "").lower()
                    source = str(raw.get("Source Type") or "").strip().lower()
                    if "first" in download_type:
                        metrics.apple_first_downloads += count
                        if source == "app store search":
                            metrics.apple_search_downloads += count
                        elif source == "app store browse":
                            metrics.apple_browse_downloads += count
                    elif "redownload" in download_type:
                        metrics.apple_redownloads += count
                    elif "update" in download_type:
                        metrics.apple_updates += count
    return parsed_rows


def parse_product_page_reports(
    root: pathlib.Path,
    rows: dict[tuple[dt.date, str, str], DailyProductPageMetrics],
    ranges: dict[str, tuple[dt.date, dt.date]],
    *,
    start: dt.date | None = None,
    end: dt.date | None = None,
) -> int:
    parsed_rows = 0
    for path in sorted(root.rglob("*.tsv.gz")):
        if not any(part.endswith("-detailed") for part in path.parts):
            continue
        with gzip.open(path, "rt", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle, delimiter="\t")
            if not reader.fieldnames or "Page Title" not in reader.fieldnames:
                continue
            report_type = (
                "engagement"
                if "Event" in reader.fieldnames
                else "downloads"
                if "Download Type" in reader.fieldnames
                else None
            )
            if report_type is None:
                continue
            for raw in reader:
                if str(raw.get("Page Type") or "").strip().lower() != "product page":
                    continue
                event_date = parse_date(raw["Date"])
                if not in_window(event_date, start, end):
                    continue
                country = territory(raw.get("Territory"))
                page_title = product_page_title(raw.get("Page Title"))
                metrics = rows.setdefault(
                    (event_date, country, page_title), DailyProductPageMetrics()
                )
                count = integer(raw.get("Counts"))
                parsed_rows += 1
                update_range(ranges, f"apple_page_{report_type}", event_date)
                if report_type == "engagement":
                    event = str(raw.get("Event") or "").strip().lower()
                    engagement = str(raw.get("Engagement Type") or "").strip().lower()
                    if event == "impression":
                        metrics.apple_impressions += count
                    elif event == "page view":
                        metrics.apple_page_views += count
                    if engagement == "get":
                        metrics.apple_get_taps += count
                else:
                    download_type = str(raw.get("Download Type") or "").lower()
                    if "first" in download_type:
                        metrics.apple_first_downloads += count
                    elif "redownload" in download_type:
                        metrics.apple_redownloads += count
    return parsed_rows


def posthog_query(start: dt.date, end: dt.date) -> str:
    end_exclusive = end + dt.timedelta(days=1)
    return f"""
SELECT
  toDate(timestamp) AS event_date,
  coalesce(nullIf(toString(properties.$geoip_country_code), ''), 'UNKNOWN') AS country,
  uniq(distinct_id) AS active_users,
  countIf(event IN ('Application Opened', 'app_launched')) AS launches,
  countIf(event = 'daily_puzzle_opened') AS puzzle_opens,
  countIf(event = 'daily_puzzle_guess_submitted') AS puzzle_guesses,
  countIf(event IN ('daily_puzzle_solved', 'daily_puzzle_failed')) AS puzzle_finishes,
  countIf(event IN ('ad_interstitial_impression', 'ad_rewarded_impression', 'ad_app_open_impression', 'ad_banner_impression')) AS ad_impressions
FROM events
WHERE timestamp >= toDateTime('{start.isoformat()}')
  AND timestamp < toDateTime('{end_exclusive.isoformat()}')
GROUP BY event_date, country
ORDER BY event_date, country
""".strip()


def fetch_posthog(
    *,
    token: str,
    project_id: str,
    start: dt.date,
    end: dt.date,
    base_url: str = POSTHOG_DEFAULT_URL,
    opener: Callable[..., Any] = urllib.request.urlopen,
) -> list[dict[str, Any]]:
    payload = json.dumps(
        {"query": {"kind": "HogQLQuery", "query": posthog_query(start, end)}}
    ).encode("utf-8")
    request = urllib.request.Request(
        f"{base_url.rstrip('/')}/api/projects/{project_id}/query/",
        data=payload,
        method="POST",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with opener(request, timeout=90) as response:
            result = json.load(response)
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", errors="replace")[:2_000]
        raise RuntimeError(
            f"PostHog API returned HTTP {error.code}: {body}"
        ) from error
    if result.get("error"):
        raise RuntimeError(f"PostHog query failed: {result['error']}")
    columns = result.get("columns", [])
    return [dict(zip(columns, values)) for values in result.get("results", [])]


def add_posthog_rows(
    source_rows: Iterable[dict[str, Any]],
    rows: dict[tuple[dt.date, str], DailyMetrics],
    ranges: dict[str, tuple[dt.date, dt.date]],
) -> None:
    for raw in source_rows:
        event_date = parse_date(str(raw["event_date"])[:10])
        country = territory(raw.get("country"))
        metrics = rows_for(rows, event_date, country)
        metrics.posthog_active_users += integer(raw.get("active_users"))
        metrics.posthog_launches += integer(raw.get("launches"))
        metrics.posthog_puzzle_opens += integer(raw.get("puzzle_opens"))
        metrics.posthog_puzzle_guesses += integer(raw.get("puzzle_guesses"))
        metrics.posthog_puzzle_finishes += integer(raw.get("puzzle_finishes"))
        metrics.posthog_ad_impressions += integer(raw.get("ad_impressions"))
        update_range(ranges, "posthog", event_date)


def parse_admob(
    path: pathlib.Path,
    rows: dict[tuple[dt.date, str], DailyMetrics],
    ranges: dict[str, tuple[dt.date, dt.date]],
    *,
    start: dt.date | None = None,
    end: dt.date | None = None,
) -> int:
    if not path.is_file():
        return 0
    parsed_rows = 0
    with path.open(newline="", encoding="utf-8-sig") as handle:
        for raw in csv.DictReader(handle):
            raw_date = str(raw.get("dim_DATE") or "")
            if len(raw_date) != 8:
                continue
            event_date = dt.datetime.strptime(raw_date, "%Y%m%d").date()
            if not in_window(event_date, start, end):
                continue
            country = territory(raw.get("dim_COUNTRY"))
            metrics = rows_for(rows, event_date, country)
            metrics.admob_requests += integer(raw.get("met_AD_REQUESTS"))
            metrics.admob_matched_requests += integer(
                raw.get("met_MATCHED_REQUESTS")
            )
            metrics.admob_impressions += integer(raw.get("met_IMPRESSIONS"))
            metrics.admob_clicks += integer(raw.get("met_CLICKS"))
            earnings_micros = decimal.Decimal(
                str(raw.get("met_ESTIMATED_EARNINGS") or "0")
            )
            metrics.admob_earnings_usd += earnings_micros / decimal.Decimal(
                "1000000"
            )
            parsed_rows += 1
            update_range(ranges, "admob", event_date)
    return parsed_rows


def combine(metrics: Iterable[DailyMetrics]) -> DailyMetrics:
    total = DailyMetrics()
    for item in metrics:
        for field in DailyMetrics.__dataclass_fields__:
            setattr(total, field, getattr(total, field) + getattr(item, field))
    return total


def metrics_for_country(
    rows: dict[tuple[dt.date, str], DailyMetrics], country: str
) -> DailyMetrics:
    return combine(value for (_, code), value in rows.items() if code == country)


def ratio(numerator: int | decimal.Decimal, denominator: int) -> str:
    if denominator == 0:
        return "n/a"
    return f"{(decimal.Decimal(numerator) / decimal.Decimal(denominator)) * 100:.2f}%"


def money(value: decimal.Decimal) -> str:
    return f"${value.quantize(decimal.Decimal('0.0001'))}"


def decimal_ratio(
    numerator: decimal.Decimal, denominator: int, multiplier: int = 1
) -> str:
    if denominator == 0:
        return "n/a"
    value = numerator * multiplier / decimal.Decimal(denominator)
    return f"${value.quantize(decimal.Decimal('0.0001'))}"


def render_markdown(
    rows: dict[tuple[dt.date, str], DailyMetrics],
    ranges: dict[str, tuple[dt.date, dt.date]],
    *,
    page_rows: dict[
        tuple[dt.date, str, str], DailyProductPageMetrics
    ] | None = None,
    generated_at: dt.datetime | None = None,
) -> str:
    page_rows = page_rows or {}
    generated_at = generated_at or dt.datetime.now(dt.timezone.utc)
    lines = [
        "# International Growth Report",
        "",
        f"Generated: {generated_at.isoformat(timespec='seconds')}",
        "",
        "## Source completeness",
        "",
        "| Source | First event date | Last event date |",
        "|---|---|---|",
    ]
    for source in ("apple_engagement", "apple_downloads", "posthog", "admob"):
        value = ranges.get(source)
        first = value[0].isoformat() if value else "unavailable"
        last = value[1].isoformat() if value else "unavailable"
        lines.append(f"| {source} | {first} | {last} |")

    lines.extend(
        [
            "",
            "## Acquisition by market",
            "",
            "| Market | Impressions | Page views | Get taps | First downloads | Page-view rate | Count-based download yield |",
            "|---|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for country in TARGET_ORDER:
        item = metrics_for_country(rows, country)
        lines.append(
            f"| {COHORT_NAMES[country]} | {item.apple_impressions:,} | "
            f"{item.apple_page_views:,} | {item.apple_get_taps:,} | "
            f"{item.apple_first_downloads:,} | "
            f"{ratio(item.apple_page_views, item.apple_impressions)} | "
            f"{ratio(item.apple_first_downloads, item.apple_impressions)} |"
        )

    if page_rows:
        lines.extend(
            [
                "",
                "## Product-page acquisition by market",
                "",
                "| Product page | Market | Impressions | Page views | Get taps | First downloads | Count-based download yield |",
                "|---|---|---:|---:|---:|---:|---:|",
            ]
        )
        page_keys = sorted(
            {
                (country, page_title)
                for _, country, page_title in page_rows
                if country in TARGET_ORDER
            },
            key=lambda value: (TARGET_ORDER.index(value[0]), value[1]),
        )
        for country, page_title in page_keys:
            items = [
                item
                for (_, code, title), item in page_rows.items()
                if code == country and title == page_title
            ]
            total = DailyProductPageMetrics()
            for item in items:
                for field in DailyProductPageMetrics.__dataclass_fields__:
                    setattr(total, field, getattr(total, field) + getattr(item, field))
            lines.append(
                f"| {page_title} | {COHORT_NAMES[country]} | "
                f"{total.apple_impressions:,} | {total.apple_page_views:,} | "
                f"{total.apple_get_taps:,} | {total.apple_first_downloads:,} | "
                f"{ratio(total.apple_first_downloads, total.apple_impressions)} |"
            )

    lines.extend(
        [
            "",
            "## Product activation by market",
            "",
            "| Market | Active user-days | Launches | Puzzle opens | Guesses | Finishes | Open-to-guess |",
            "|---|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for country in TARGET_ORDER:
        item = metrics_for_country(rows, country)
        lines.append(
            f"| {COHORT_NAMES[country]} | {item.posthog_active_users:,} | "
            f"{item.posthog_launches:,} | {item.posthog_puzzle_opens:,} | "
            f"{item.posthog_puzzle_guesses:,} | "
            f"{item.posthog_puzzle_finishes:,} | "
            f"{ratio(item.posthog_puzzle_guesses, item.posthog_puzzle_opens)} |"
        )

    lines.extend(
        [
            "",
            "## Monetization by market",
            "",
            "| Market | Requests | Matched | Impressions | Earnings | Revenue/active user-day | Revenue/1K App Store impressions |",
            "|---|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for country in TARGET_ORDER:
        item = metrics_for_country(rows, country)
        lines.append(
            f"| {COHORT_NAMES[country]} | {item.admob_requests:,} | "
            f"{item.admob_matched_requests:,} | {item.admob_impressions:,} | "
            f"{money(item.admob_earnings_usd)} | "
            f"{decimal_ratio(item.admob_earnings_usd, item.posthog_active_users)} | "
            f"{decimal_ratio(item.admob_earnings_usd, item.apple_impressions, 1000)} |"
        )

    worldwide = combine(rows.values())
    lines.extend(
        [
            "",
            "## Acquisition source",
            "",
            "| Source | Impressions | First downloads |",
            "|---|---:|---:|",
            f"| App Store search | {worldwide.apple_search_impressions:,} | {worldwide.apple_search_downloads:,} |",
            f"| App Store browse | {worldwide.apple_browse_impressions:,} | {worldwide.apple_browse_downloads:,} |",
            "",
            "## Interpretation rules",
            "",
            "- Never interpret an incomplete source date as zero.",
            "- Apple, PostHog, and AdMob countries are aggregate dimensions, not a user-level join.",
            "- Count-based download yield is directional and is not Apple's unique-device conversion rate.",
            "- Report China separately from target-market and international aggregates.",
            "- Keep absolute counts beside every rate.",
            "",
        ]
    )
    return "\n".join(lines)


CSV_FIELDS = [
    "date",
    "territory",
    "cohort",
    *DailyMetrics.__dataclass_fields__.keys(),
]


def write_daily_csv(
    path: pathlib.Path, rows: dict[tuple[dt.date, str], DailyMetrics]
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=CSV_FIELDS)
        writer.writeheader()
        for (event_date, country), metrics in sorted(rows.items()):
            raw = {
                "date": event_date.isoformat(),
                "territory": country,
                "cohort": COHORT_NAMES.get(country, "Other"),
            }
            for field in DailyMetrics.__dataclass_fields__:
                value = getattr(metrics, field)
                raw[field] = str(value) if isinstance(value, decimal.Decimal) else value
            writer.writerow(raw)


PRODUCT_PAGE_CSV_FIELDS = [
    "date",
    "territory",
    "cohort",
    "product_page",
    *DailyProductPageMetrics.__dataclass_fields__.keys(),
]


def write_product_page_daily_csv(
    path: pathlib.Path,
    rows: dict[tuple[dt.date, str, str], DailyProductPageMetrics],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=PRODUCT_PAGE_CSV_FIELDS)
        writer.writeheader()
        for (event_date, country, page_title), metrics in sorted(rows.items()):
            raw = {
                "date": event_date.isoformat(),
                "territory": country,
                "cohort": COHORT_NAMES.get(country, "Other"),
                "product_page": page_title,
            }
            for field in DailyProductPageMetrics.__dataclass_fields__:
                raw[field] = getattr(metrics, field)
            writer.writerow(raw)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Join App Store, PostHog, and AdMob aggregate territory data."
    )
    parser.add_argument(
        "--app-store-dir",
        type=pathlib.Path,
        default=pathlib.Path(".build/international-growth/app-store-connect"),
    )
    parser.add_argument(
        "--admob-csv",
        type=pathlib.Path,
        default=pathlib.Path("docs/admob_history.csv"),
    )
    parser.add_argument("--start", type=parse_date)
    parser.add_argument("--end", type=parse_date)
    parser.add_argument(
        "--posthog-token",
        default=os.getenv("POSTHOG_API_TOKEN"),
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--posthog-project", default=os.getenv("POSTHOG_PROJECT_ID", "560852")
    )
    parser.add_argument(
        "--posthog-url",
        default=os.getenv("POSTHOG_HOST", POSTHOG_DEFAULT_URL),
    )
    parser.add_argument("--skip-posthog", action="store_true")
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=pathlib.Path("docs/international_growth_report.md"),
    )
    parser.add_argument(
        "--csv-output",
        type=pathlib.Path,
        default=pathlib.Path(".build/international-growth/territory_daily.csv"),
    )
    parser.add_argument(
        "--page-csv-output",
        type=pathlib.Path,
        default=pathlib.Path(".build/international-growth/product_page_daily.csv"),
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.app_store_dir.is_dir():
        print(
            f"App Store report directory not found: {args.app_store_dir}",
            file=sys.stderr,
        )
        return 2
    rows: dict[tuple[dt.date, str], DailyMetrics] = {}
    page_rows: dict[tuple[dt.date, str, str], DailyProductPageMetrics] = {}
    ranges: dict[str, tuple[dt.date, dt.date]] = {}
    try:
        parsed_apple = parse_app_store_reports(
            args.app_store_dir,
            rows,
            ranges,
            start=args.start,
            end=args.end,
        )
        parsed_pages = parse_product_page_reports(
            args.app_store_dir,
            page_rows,
            ranges,
            start=args.start,
            end=args.end,
        )
        parsed_admob = parse_admob(
            args.admob_csv,
            rows,
            ranges,
            start=args.start,
            end=args.end,
        )
        if not args.skip_posthog and args.posthog_token and rows:
            start = args.start or min(date for date, _ in rows)
            end = args.end or max(date for date, _ in rows)
            add_posthog_rows(
                fetch_posthog(
                    token=args.posthog_token,
                    project_id=args.posthog_project,
                    start=start,
                    end=end,
                    base_url=args.posthog_url,
                ),
                rows,
                ranges,
            )
        write_daily_csv(args.csv_output, rows)
        write_product_page_daily_csv(args.page_csv_output, page_rows)
        report = render_markdown(rows, ranges, page_rows=page_rows)
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(report, encoding="utf-8")
    except (OSError, ValueError, RuntimeError, decimal.InvalidOperation) as error:
        print(f"International growth analysis failed: {error}", file=sys.stderr)
        return 1
    print(
        f"International growth report ready: {parsed_apple} Apple rows, "
        f"{parsed_pages} product-page rows, {parsed_admob} AdMob rows."
    )
    if not args.skip_posthog and not args.posthog_token:
        print("PostHog skipped because POSTHOG_API_TOKEN is not set.")
    print(f"Report: {args.output}")
    print(f"Daily data: {args.csv_output}")
    print(f"Product-page data: {args.page_csv_output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
