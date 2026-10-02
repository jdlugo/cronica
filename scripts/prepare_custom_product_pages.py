#!/usr/bin/env python3
"""Validate and stage Cronica custom product-page assets."""

from __future__ import annotations

import argparse
import json
import pathlib
import shutil
import struct
import sys
from typing import Any


DEVICE_SIZES = {
    "iPhone 6.9-inch": (1320, 2868),
    "iPad Pro 13-inch": (2064, 2752),
}


def png_size(path: pathlib.Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError(f"Not a PNG: {path}")
    return struct.unpack(">II", header[16:24])


def load_manifest(path: pathlib.Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if value.get("schema_version") != 1 or not value.get("pages"):
        raise ValueError("Custom product-page manifest is missing schema_version 1 or pages")
    return value


def page_localizations(page: dict[str, Any]) -> list[tuple[str, dict[str, Any]]]:
    values: dict[str, dict[str, Any]] = {}
    primary = page.get("primary_locale")
    if primary:
        locale = str(primary.get("locale") or "").strip()
        if not locale:
            raise ValueError(f"{page.get('slug', 'page')} primary locale is missing")
        values[locale] = primary
    for locale, localization in page.get("locales", {}).items():
        if locale in values:
            raise ValueError(f"Duplicate localization for {page.get('slug', 'page')}/{locale}")
        values[locale] = localization
    return list(values.items())


def validate_manifest(manifest: dict[str, Any]) -> None:
    keywords_by_locale: dict[str, set[str]] = {}
    slugs: set[str] = set()
    for page in manifest["pages"]:
        slug = str(page.get("slug") or "").strip()
        if not slug or slug in slugs:
            raise ValueError(f"Missing or duplicate page slug: {slug!r}")
        slugs.add(slug)
        if len(page.get("screen_order", [])) != 3:
            raise ValueError(f"{slug} must define exactly three acquisition screens")
        for locale, localization in page_localizations(page):
            promotional_text = str(localization.get("promotional_text") or "")
            if not promotional_text or len(promotional_text) > 170:
                raise ValueError(
                    f"{slug}/{locale} promotional text is {len(promotional_text)} characters"
                )
            keywords = {
                str(value).strip().casefold()
                for value in localization.get("keywords", [])
            }
            overlap = keywords_by_locale.setdefault(locale, set()) & keywords
            if overlap:
                raise ValueError(
                    f"{locale} keywords overlap across pages: {', '.join(sorted(overlap))}"
                )
            keywords_by_locale[locale].update(keywords)


def find_source(
    screenshots_dir: pathlib.Path, locale: str, screen: str, device: str
) -> pathlib.Path:
    matches = sorted((screenshots_dir / locale).glob(f"*-{screen}_{device}.png"))
    if len(matches) != 1:
        raise ValueError(
            f"Expected one {locale}/{screen}/{device} source, found {len(matches)}"
        )
    return matches[0]


def prepare_package(
    manifest_path: pathlib.Path,
    screenshots_dir: pathlib.Path,
    output_dir: pathlib.Path,
    *,
    validate_only: bool = False,
) -> int:
    manifest = load_manifest(manifest_path)
    validate_manifest(manifest)
    staged: list[dict[str, Any]] = []
    asset_count = 0
    for page in manifest["pages"]:
        for locale, localization in page_localizations(page):
            assets = []
            for position, screen in enumerate(page["screen_order"], start=1):
                for device, expected_size in DEVICE_SIZES.items():
                    source = find_source(screenshots_dir, locale, screen, device)
                    actual_size = png_size(source)
                    if actual_size != expected_size:
                        raise ValueError(
                            f"{source} is {actual_size[0]}x{actual_size[1]}, expected "
                            f"{expected_size[0]}x{expected_size[1]}"
                        )
                    destination = (
                        output_dir
                        / page["slug"]
                        / locale
                        / f"{position:02d}-{screen}_{device}.png"
                    )
                    if not validate_only:
                        destination.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(source, destination)
                    assets.append(destination.relative_to(output_dir).as_posix())
                    asset_count += 1
            staged.append(
                {
                    "reference_name": page["reference_name"],
                    "slug": page["slug"],
                    "locale": locale,
                    "promotional_text": localization["promotional_text"],
                    "keywords": localization.get("keywords", []),
                    "assets": assets,
                }
            )
    if not validate_only:
        output_dir.mkdir(parents=True, exist_ok=True)
        (output_dir / "package-manifest.json").write_text(
            json.dumps(
                {"app_id": manifest["app_id"], "localizations": staged},
                indent=2,
                ensure_ascii=False,
            )
            + "\n",
            encoding="utf-8",
        )
    return asset_count


def parse_args() -> argparse.Namespace:
    root = pathlib.Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=pathlib.Path,
        default=root / "fastlane/custom_product_pages/manifest.json",
    )
    parser.add_argument(
        "--screenshots-dir",
        type=pathlib.Path,
        default=root / "fastlane/screenshots",
    )
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        default=root / ".build/international-growth/custom-product-pages",
    )
    parser.add_argument("--validate-only", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        count = prepare_package(
            args.manifest,
            args.screenshots_dir,
            args.output_dir,
            validate_only=args.validate_only,
        )
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"Custom product-page package failed: {error}", file=sys.stderr)
        return 1
    action = "Validated" if args.validate_only else "Staged"
    print(f"{action} {count} custom product-page assets.")
    if not args.validate_only:
        print(f"Package: {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
