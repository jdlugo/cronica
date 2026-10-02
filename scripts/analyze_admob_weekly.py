#!/usr/bin/env python3
"""Analyze AdMob CSV history with weekly WoW deltas.

Input: CSV from pull_admob_report.py
Output: markdown report + optional stdout summary
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Iterable, List, Tuple


@dataclass
class Totals:
    revenue: float = 0.0  # USD
    requests: float = 0.0
    matched: float = 0.0
    impressions: float = 0.0
    clicks: float = 0.0

    def add(self, revenue: float, requests: float, matched: float, impressions: float, clicks: float) -> None:
        self.revenue += revenue
        self.requests += requests
        self.matched += matched
        self.impressions += impressions
        self.clicks += clicks

    def per_day(self, days: int) -> "Totals":
        if days <= 0:
            return Totals()
        return Totals(
            revenue=self.revenue / days,
            requests=self.requests / days,
            matched=self.matched / days,
            impressions=self.impressions / days,
            clicks=self.clicks / days,
        )

    @property
    def match_rate(self) -> float:
        return (self.matched / self.requests) if self.requests else 0.0

    @property
    def show_rate(self) -> float:
        return (self.impressions / self.matched) if self.matched else 0.0

    @property
    def ctr(self) -> float:
        return (self.clicks / self.impressions) if self.impressions else 0.0

    @property
    def ecpm(self) -> float:
        return (self.revenue / self.impressions * 1000.0) if self.impressions else 0.0


@dataclass
class Row:
    date: dt.date
    app: str
    ad_unit: str
    country: str
    revenue: float
    requests: float
    matched: float
    impressions: float
    clicks: float


def pct(new: float, old: float) -> float:
    return ((new - old) / old * 100.0) if old else 0.0


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(description="Weekly AdMob analysis with WoW deltas")
    p.add_argument("--input", required=True, help="AdMob history CSV path")
    p.add_argument("--report-date", default="", help="Anchor date YYYY-MM-DD (default: latest date in file)")
    p.add_argument("--days", type=int, default=7, help="Window size in days (default 7)")
    p.add_argument("--top-n", type=int, default=10, help="Top movers by ad unit/country")
    p.add_argument("--output", default="", help="Optional markdown report output path")
    return p.parse_args()


def parse_csv(path: Path) -> List[Row]:
    rows: List[Row] = []
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for r in reader:
            d = r.get("dim_DATE", "").strip()
            if not d:
                continue
            try:
                day = dt.date.fromisoformat(d)
            except ValueError:
                continue
            rows.append(
                Row(
                    date=day,
                    app=r.get("dim_APP", ""),
                    ad_unit=r.get("dim_AD_UNIT", ""),
                    country=r.get("dim_COUNTRY", ""),
                    revenue=float(r.get("met_ESTIMATED_EARNINGS", "0") or 0) / 1_000_000.0,
                    requests=float(r.get("met_AD_REQUESTS", "0") or 0),
                    matched=float(r.get("met_MATCHED_REQUESTS", "0") or 0),
                    impressions=float(r.get("met_IMPRESSIONS", "0") or 0),
                    clicks=float(r.get("met_CLICKS", "0") or 0),
                )
            )
    return rows


def aggregate(rows: Iterable[Row]) -> Totals:
    t = Totals()
    for r in rows:
        t.add(r.revenue, r.requests, r.matched, r.impressions, r.clicks)
    return t


def aggregate_by(rows: Iterable[Row], key_fn) -> Dict[str, Totals]:
    out: Dict[str, Totals] = defaultdict(Totals)
    for r in rows:
        out[key_fn(r)].add(r.revenue, r.requests, r.matched, r.impressions, r.clicks)
    return out


def build_report(rows: List[Row], report_date: dt.date, days: int, top_n: int) -> str:
    cur_start = report_date - dt.timedelta(days=days - 1)
    cur_end = report_date
    prev_end = cur_start - dt.timedelta(days=1)
    prev_start = prev_end - dt.timedelta(days=days - 1)

    cur_rows = [r for r in rows if cur_start <= r.date <= cur_end]
    prev_rows = [r for r in rows if prev_start <= r.date <= prev_end]

    cur = aggregate(cur_rows).per_day(days)
    prev = aggregate(prev_rows).per_day(days)

    lines: List[str] = []
    lines.append(f"# AdMob Weekly Report ({cur_start} to {cur_end})")
    lines.append("")
    lines.append(f"Compared to: {prev_start} to {prev_end}")
    lines.append("")
    lines.append("## Overall (per day)")
    lines.append("")
    lines.append("| Metric | Previous | Current | WoW % |")
    lines.append("|---|---:|---:|---:|")
    lines.append(f"| Revenue (USD) | {prev.revenue:.4f} | {cur.revenue:.4f} | {pct(cur.revenue, prev.revenue):.2f}% |")
    lines.append(f"| Ad Requests | {prev.requests:.2f} | {cur.requests:.2f} | {pct(cur.requests, prev.requests):.2f}% |")
    lines.append(f"| Matched Requests | {prev.matched:.2f} | {cur.matched:.2f} | {pct(cur.matched, prev.matched):.2f}% |")
    lines.append(f"| Impressions | {prev.impressions:.2f} | {cur.impressions:.2f} | {pct(cur.impressions, prev.impressions):.2f}% |")
    lines.append(f"| Match Rate | {prev.match_rate:.4f} | {cur.match_rate:.4f} | {pct(cur.match_rate, prev.match_rate):.2f}% |")
    lines.append(f"| Show Rate | {prev.show_rate:.4f} | {cur.show_rate:.4f} | {pct(cur.show_rate, prev.show_rate):.2f}% |")
    lines.append(f"| eCPM | {prev.ecpm:.4f} | {cur.ecpm:.4f} | {pct(cur.ecpm, prev.ecpm):.2f}% |")
    lines.append(f"| CTR | {prev.ctr:.4f} | {cur.ctr:.4f} | {pct(cur.ctr, prev.ctr):.2f}% |")

    prev_by_ad = aggregate_by(prev_rows, lambda r: r.ad_unit)
    cur_by_ad = aggregate_by(cur_rows, lambda r: r.ad_unit)
    ad_deltas: List[Tuple[float, str, float, float]] = []
    for ad in set(prev_by_ad) | set(cur_by_ad):
        p = prev_by_ad.get(ad, Totals()).revenue / days
        c = cur_by_ad.get(ad, Totals()).revenue / days
        ad_deltas.append((c - p, ad, p, c))

    lines.append("")
    lines.append("## Ad Unit Movers (Revenue/day)")
    lines.append("")
    lines.append("| Ad Unit | Prev | Current | Delta |")
    lines.append("|---|---:|---:|---:|")
    for delta, ad, p, c in sorted(ad_deltas, key=lambda x: x[0])[:top_n]:
        lines.append(f"| {ad or '(unknown)'} | {p:.4f} | {c:.4f} | {delta:.4f} |")
    for delta, ad, p, c in sorted(ad_deltas, key=lambda x: x[0], reverse=True)[:top_n]:
        lines.append(f"| {ad or '(unknown)'} | {p:.4f} | {c:.4f} | +{delta:.4f} |")

    prev_by_country = aggregate_by(prev_rows, lambda r: r.country)
    cur_by_country = aggregate_by(cur_rows, lambda r: r.country)
    country_deltas: List[Tuple[float, str, float, float]] = []
    for ctry in set(prev_by_country) | set(cur_by_country):
        p = prev_by_country.get(ctry, Totals()).revenue / days
        c = cur_by_country.get(ctry, Totals()).revenue / days
        country_deltas.append((c - p, ctry, p, c))

    lines.append("")
    lines.append("## Country Movers (Revenue/day)")
    lines.append("")
    lines.append("| Country | Prev | Current | Delta |")
    lines.append("|---|---:|---:|---:|")
    for delta, ctry, p, c in sorted(country_deltas, key=lambda x: x[0])[:top_n]:
        lines.append(f"| {ctry or '(unknown)'} | {p:.4f} | {c:.4f} | {delta:.4f} |")
    for delta, ctry, p, c in sorted(country_deltas, key=lambda x: x[0], reverse=True)[:top_n]:
        lines.append(f"| {ctry or '(unknown)'} | {p:.4f} | {c:.4f} | +{delta:.4f} |")

    return "\n".join(lines) + "\n"


def main() -> int:
    args = parse_args()
    input_path = Path(args.input)
    rows = parse_csv(input_path)
    if not rows:
        raise SystemExit("No valid rows found in input CSV")

    max_date = max(r.date for r in rows)
    report_date = dt.date.fromisoformat(args.report_date) if args.report_date else max_date

    report = build_report(rows, report_date=report_date, days=args.days, top_n=args.top_n)
    print(report)

    if args.output:
        out = Path(args.output)
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_text(report, encoding="utf-8")
        print(f"Saved report: {out}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
