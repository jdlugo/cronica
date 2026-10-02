#!/usr/bin/env python3
"""Pull AdMob network report data and write CSV.

Auth model (per AdMob API docs): OAuth2 user credentials.
Use a refresh token from an OAuth client (desktop/web).
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from typing import Any, Dict, Iterable, List

TOKEN_URL = "https://oauth2.googleapis.com/token"
API_BASE = "https://admob.googleapis.com/v1"


def parse_date(value: str) -> dt.date:
    try:
        return dt.date.fromisoformat(value)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(f"Invalid date '{value}'. Use YYYY-MM-DD.") from exc


def date_dict(d: dt.date) -> Dict[str, int]:
    return {"year": d.year, "month": d.month, "day": d.day}


def fetch_access_token(client_id: str, client_secret: str, refresh_token: str) -> str:
    payload = urllib.parse.urlencode(
        {
            "client_id": client_id,
            "client_secret": client_secret,
            "refresh_token": refresh_token,
            "grant_type": "refresh_token",
        }
    ).encode("utf-8")

    req = urllib.request.Request(TOKEN_URL, data=payload, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")

    try:
        with urllib.request.urlopen(req, timeout=30) as res:
            body = json.loads(res.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        msg = exc.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"Token request failed ({exc.code}): {msg}") from exc

    token = body.get("access_token")
    if not token:
        raise RuntimeError(f"Token response missing access_token: {body}")
    return token


def build_report_spec(args: argparse.Namespace) -> Dict[str, Any]:
    dimensions = [d.strip() for d in args.dimensions.split(",") if d.strip()]
    metrics = [m.strip() for m in args.metrics.split(",") if m.strip()]

    spec: Dict[str, Any] = {
        "dateRange": {
            "startDate": date_dict(args.start_date),
            "endDate": date_dict(args.end_date),
        },
        "dimensions": dimensions,
        "metrics": metrics,
        "localizationSettings": {
            "currencyCode": args.currency,
            "languageCode": args.language,
        },
        "sortConditions": [{"dimension": "DATE", "order": "ASCENDING"}],
    }

    filters: List[Dict[str, Any]] = []
    if args.country:
        values = [x.strip().upper() for x in args.country.split(",") if x.strip()]
        if values:
            filters.append({"dimension": "COUNTRY", "matchesAny": {"values": values}})

    if args.app:
        values = [x.strip() for x in args.app.split(",") if x.strip()]
        if values:
            filters.append({"dimension": "APP", "matchesAny": {"values": values}})

    if filters:
        spec["dimensionFilters"] = filters

    if args.max_rows:
        spec["maxReportRows"] = args.max_rows

    return spec


def parse_streaming_json(body: bytes) -> List[Dict[str, Any]]:
    text = body.decode("utf-8").strip()
    if not text:
        return []

    # Some endpoints return NDJSON streaming chunks; some clients surface arrays.
    if text.startswith("["):
        payload = json.loads(text)
        if not isinstance(payload, list):
            raise RuntimeError("Unexpected JSON payload shape from AdMob API.")
        return [p for p in payload if isinstance(p, dict)]

    rows: List[Dict[str, Any]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        rows.append(json.loads(line))
    return rows


def generate_network_report(access_token: str, publisher_id: str, report_spec: Dict[str, Any]) -> List[Dict[str, Any]]:
    parent = f"accounts/{publisher_id}"
    url = f"{API_BASE}/{parent}/networkReport:generate"
    payload = json.dumps({"reportSpec": report_spec}).encode("utf-8")

    req = urllib.request.Request(url, data=payload, method="POST")
    req.add_header("Authorization", f"Bearer {access_token}")
    req.add_header("Content-Type", "application/json")

    try:
        with urllib.request.urlopen(req, timeout=90) as res:
            body = res.read()
    except urllib.error.HTTPError as exc:
        msg = exc.read().decode("utf-8", errors="ignore")
        raise RuntimeError(f"Report request failed ({exc.code}): {msg}") from exc

    return parse_streaming_json(body)


def report_rows_only(records: Iterable[Dict[str, Any]]) -> List[Dict[str, Any]]:
    return [r for r in records if "row" in r]


def flatten_row(row_wrapper: Dict[str, Any]) -> Dict[str, str]:
    row = row_wrapper.get("row", {})
    out: Dict[str, str] = {}

    for k, v in (row.get("dimensionValues") or {}).items():
        out[f"dim_{k}"] = v.get("value", "")

    for k, v in (row.get("metricValues") or {}).items():
        # metric value can be integerValue/microsValue/doubleValue
        if "integerValue" in v:
            out[f"met_{k}"] = str(v["integerValue"])
        elif "microsValue" in v:
            out[f"met_{k}"] = str(v["microsValue"])
        elif "doubleValue" in v:
            out[f"met_{k}"] = str(v["doubleValue"])
        else:
            out[f"met_{k}"] = ""

    return out


def write_csv(path: str, rows: List[Dict[str, str]]) -> None:
    if not rows:
        with open(path, "w", newline="", encoding="utf-8") as f:
            f.write("")
        return

    fieldnames = sorted({k for row in rows for k in row.keys()})
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Pull AdMob network report to CSV.")
    p.add_argument("--publisher-id", required=True, help="AdMob publisher id like pub-1234567890123456")
    p.add_argument("--start-date", type=parse_date, required=True, help="YYYY-MM-DD")
    p.add_argument("--end-date", type=parse_date, required=True, help="YYYY-MM-DD")
    p.add_argument("--output", default="admob_report.csv", help="Output CSV path")

    p.add_argument(
        "--dimensions",
        default="DATE,APP,COUNTRY,PLATFORM,AD_UNIT",
        help="Comma-separated AdMob dimensions",
    )
    p.add_argument(
        "--metrics",
        default="AD_REQUESTS,MATCHED_REQUESTS,IMPRESSIONS,CLICKS,ESTIMATED_EARNINGS",
        help="Comma-separated AdMob metrics",
    )
    p.add_argument("--country", default="", help="Optional ISO country filters, comma-separated (e.g. US,CA)")
    p.add_argument("--app", default="", help="Optional app id filters, comma-separated (e.g. ca-app-pub-...~...)")
    p.add_argument("--currency", default="USD", help="Localization currency code")
    p.add_argument("--language", default="en-US", help="Localization language code")
    p.add_argument("--max-rows", type=int, default=0, help="Optional max rows")

    p.add_argument("--client-id", default=os.getenv("ADMOB_CLIENT_ID", ""))
    p.add_argument("--client-secret", default=os.getenv("ADMOB_CLIENT_SECRET", ""))
    p.add_argument("--refresh-token", default=os.getenv("ADMOB_REFRESH_TOKEN", ""))

    args = p.parse_args()

    missing = [
        name
        for name, value in [
            ("client-id", args.client_id),
            ("client-secret", args.client_secret),
            ("refresh-token", args.refresh_token),
        ]
        if not value
    ]
    if missing:
        p.error("Missing OAuth credentials: " + ", ".join(missing) + ". Set args or ADMOB_* env vars.")

    if args.end_date < args.start_date:
        p.error("end-date must be on or after start-date")

    return args


def main() -> int:
    args = parse_args()

    token = fetch_access_token(args.client_id, args.client_secret, args.refresh_token)
    spec = build_report_spec(args)
    records = generate_network_report(token, args.publisher_id, spec)
    row_records = report_rows_only(records)
    flat_rows = [flatten_row(r) for r in row_records]
    write_csv(args.output, flat_rows)

    print(f"Fetched {len(flat_rows)} rows to {args.output}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:  # pragma: no cover
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
