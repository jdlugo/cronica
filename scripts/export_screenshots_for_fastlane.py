#!/usr/bin/env python3
"""
Export App Store screenshots into fastlane's expected folder structure.

Copies reference PNGs from swift-snapshot-testing's __Snapshots__ directories
into fastlane/screenshots/{locale}/{ordering_prefix}-{screen}_{device}.png,
ready for `fastlane deliver`.

iPad and Watch screenshots are resized to match App Store Connect's required
pixel dimensions using macOS `sips`.

Usage:
    python3 scripts/export_screenshots_for_fastlane.py
    python3 scripts/export_screenshots_for_fastlane.py --output-dir ~/Desktop/fastlane_screenshots
    python3 scripts/export_screenshots_for_fastlane.py --ios-only
    python3 scripts/export_screenshots_for_fastlane.py --watch-only
    python3 scripts/export_screenshots_for_fastlane.py --marketing --ios-only --clean
"""

import argparse
import os
import shutil
import subprocess

# ---------------------------------------------------------------------------
# Mapping: our locale codes -> App Store Connect locale codes
# ---------------------------------------------------------------------------
LOCALE_MAP = {
    # English (from ScreenshotTests)
    "en-US": "en-US",
    # Localized (from LocalizedScreenshotTests)
    "ar":    "ar-SA",
    "de":    "de-DE",
    "es":    "es-ES",
    "es-MX": "es-MX",
    "fr":    "fr-FR",
    "it":    "it",
    "ja":    "ja",
    "ko":    "ko",
    "nl":    "nl-NL",
    "pl":    "pl",
    "pt-BR": "pt-BR",
    "tr":    "tr",
    "zh":    "zh-Hans",
}

# ---------------------------------------------------------------------------
# Screen ordering — determines sort order in App Store listing.
# fastlane sorts screenshots alphabetically within each device, so the
# numeric prefix controls the display order.
# ---------------------------------------------------------------------------
SCREEN_ORDER = {
    "HomeScreen":              "01",
    "ExploreScreen":           "02",
    "DetailScreen":            "03",
    "DetailCastScreen":        "04",
    "DetailTrailersScreen":    "05",
    "SearchScreen":            "06",
    "WatchlistScreen":         "07",
    # Watch
    "WatchDetailScreen":       "01",
    "WatchTrendingScreen":     "02",
    "WatchWatchlistScreen":    "03",
}

# Marketing funnel ordering: Puzzle → Regional providers → Watchlist → supporting features
MARKETING_SCREEN_ORDER = {
    "HomeScreen":              "01",  # Daily Emoji Movie Puzzle
    "DetailScreen":            "02",  # Regional streaming-provider proof
    "WatchlistScreen":         "03",  # Personal watchlist value
    "ExploreScreen":           "04",  # Discover — browse catalog
    "SearchScreen":            "05",  # Find — search capability
    "DetailTrailersScreen":    "06",  # Preview — trailers & cast
    "DetailCastScreen":        "07",  # Connect — cast & recommendations
    # Watch (same order as raw mode)
    "WatchDetailScreen":       "01",
    "WatchTrendingScreen":     "02",
    "WatchWatchlistScreen":    "03",
}

# ---------------------------------------------------------------------------
# Device filename mapping and App Store Connect required pixel dimensions.
# swift-snapshot-testing can render at non-standard sizes and with alpha, so
# every exported asset is resized and flattened before App Store upload.
#
# Format: device_key -> (display_name, target_width, target_height)
#   target dimensions are None for devices that already match ASC specs.
# ---------------------------------------------------------------------------
DEVICE_MAP = {
    # iPhones — only 6.9" needed; both 6.5" and 6.9" map to the same ASC
    # device type (APP_IPHONE_67), so uploading both would exceed the 10-per-device limit.
    "iPhone_6-9in_1320x2868": ("iPhone 6.9-inch", 1320, 2868),
    # "iPhone_6-5in_1290x2796" intentionally omitted — same ASC slot as 6.9"
    # iPads — rendered at 1.5x, resize to ASC specs
    "iPad_13in_2064x2752":    ("iPad Pro 13-inch", 2064, 2752),
    "iPad_11in_1668x2420":    ("iPad Pro 11-inch", 1488, 2266),
    # Watch — rendered at 1.5x, resize to ASC specs
    "Watch_45mm_396x484":     ("Apple Watch Series 10", 396, 484),
    "Watch_Ultra_410x502":    ("Apple Watch Ultra 2", 410, 502),
}


def prepare_png(path, width=None, height=None):
    """Resize a PNG and remove its alpha channel for App Store Connect."""
    try:
        from PIL import Image
    except ImportError as error:
        raise RuntimeError("Pillow is required to prepare App Store screenshots") from error

    temporary = f"{path}.opaque.png"
    with Image.open(path) as source:
        image = source.convert("RGB")
        if width and height and image.size != (width, height):
            image = image.resize((width, height), Image.Resampling.LANCZOS)
        image.save(temporary, format="PNG", optimize=True)
    os.replace(temporary, path)


def parse_english_filename(filename):
    """Parse ScreenshotTests filename: testHomeScreen.en-US_iPhone_6-9in_1320x2868.png"""
    base = filename.replace(".png", "")
    # Split on first dot: "testHomeScreen" . "en-US_iPhone_6-9in_1320x2868"
    parts = base.split(".", 1)
    if len(parts) != 2:
        return None

    screen_raw = parts[0]  # "testHomeScreen"
    rest = parts[1]        # "en-US_iPhone_6-9in_1320x2868"

    # Strip "test" prefix
    screen = screen_raw
    if screen.startswith("test"):
        screen = screen[4:]

    # Split locale from device
    locale = "en-US"
    device_part = rest.replace("en-US_", "", 1)

    return {
        "screen": screen,
        "locale": locale,
        "device": device_part,
    }


def parse_localized_filename(filename, locale):
    """Parse LocalizedScreenshotTests filename: HomeScreen.de_iPhone_6-9in_1320x2868.png"""
    base = filename.replace(".png", "")
    # Split on first dot: "HomeScreen" . "de_iPhone_6-9in_1320x2868"
    parts = base.split(".", 1)
    if len(parts) != 2:
        return None

    screen = parts[0]  # "HomeScreen"
    rest = parts[1]    # "de_iPhone_6-9in_1320x2868"

    # Strip locale prefix from device part
    device_part = rest.replace(f"{locale}_", "", 1)

    return {
        "screen": screen,
        "locale": locale,
        "device": device_part,
    }


WATCH_SCREENS = {"WatchDetailScreen", "WatchTrendingScreen", "WatchWatchlistScreen"}


def is_watch_screen(screen_name):
    return screen_name in WATCH_SCREENS


def export_screenshot(src_path, parsed, output_dir, dry_run=False, marketing=False):
    """Copy a single screenshot into the fastlane folder structure, resizing if needed."""
    locale = parsed["locale"]
    screen = parsed["screen"]
    device_key = parsed["device"]

    # Map locale
    asc_locale = LOCALE_MAP.get(locale)
    if asc_locale is None:
        return None  # Skip unmapped locales

    # Map device
    device_info = DEVICE_MAP.get(device_key)
    if device_info is None:
        return None  # Unknown device
    device_name, target_w, target_h = device_info

    # Get ordering prefix — marketing uses conversion funnel order
    screen_order = MARKETING_SCREEN_ORDER if marketing else SCREEN_ORDER
    order = screen_order.get(screen, "99")

    # Build output filename: "01-HomeScreen_iPhone 6.9-inch.png"
    out_filename = f"{order}-{screen}_{device_name}.png"

    # Build output path
    out_dir = os.path.join(output_dir, asc_locale)
    out_path = os.path.join(out_dir, out_filename)

    if dry_run:
        suffix = f" (resize to {target_w}x{target_h})" if target_w else ""
        return out_path, suffix

    os.makedirs(out_dir, exist_ok=True)
    shutil.copy2(src_path, out_path)

    prepare_png(out_path, target_w, target_h)

    return out_path, ""


def main():
    parser = argparse.ArgumentParser(
        description="Export screenshots into fastlane folder structure."
    )
    parser.add_argument(
        "--output-dir",
        default=None,
        help="Output directory (default: fastlane/screenshots in project root)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print what would be copied without actually copying",
    )
    parser.add_argument(
        "--ios-only",
        action="store_true",
        help="Export only iOS (iPhone + iPad) screenshots",
    )
    parser.add_argument(
        "--watch-only",
        action="store_true",
        help="Export only Apple Watch screenshots",
    )
    parser.add_argument(
        "--clean",
        action="store_true",
        help="Remove output directory before exporting",
    )
    parser.add_argument(
        "--marketing",
        action="store_true",
        help="Export marketing screenshots (with gradient + headline) instead of raw screenshots",
    )
    parser.add_argument(
        "--locales",
        default=None,
        help="Comma-separated snapshot or App Store locale codes to export",
    )
    parser.add_argument(
        "--screens",
        default=None,
        help="Comma-separated screen names to export",
    )
    parser.add_argument(
        "--devices",
        default=None,
        help="Comma-separated snapshot device keys to export",
    )
    args = parser.parse_args()

    # Resolve paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)

    output_dir = args.output_dir or os.path.join(project_root, "fastlane", "screenshots")

    snapshots_base = os.path.join(
        project_root, "CronicaTests", "Screenshots", "__Snapshots__"
    )

    if args.marketing:
        # Marketing screenshots: all locales (including en-US) live under
        # MarketingScreenshotTests/{locale}/ with the same filename format
        # as LocalizedScreenshotTests.
        marketing_base = os.path.join(snapshots_base, "MarketingScreenshotTests")
        english_dir = None
        localized_base = marketing_base
        # Watch screenshots come from the raw snapshot sources (marketing
        # excludes Watch — text would be illegible at watch sizes).
        watch_english_dir = os.path.join(snapshots_base, "ScreenshotTests")
        watch_localized_base = os.path.join(snapshots_base, "LocalizedScreenshotTests")
    else:
        english_dir = os.path.join(snapshots_base, "ScreenshotTests")
        localized_base = os.path.join(snapshots_base, "LocalizedScreenshotTests")
        watch_english_dir = None
        watch_localized_base = None

    if args.clean and os.path.exists(output_dir):
        shutil.rmtree(output_dir)
        print(f"Cleaned: {output_dir}")

    # Collect all screenshots
    exported = 0
    resized = 0
    skipped = 0
    requested_locales = set(args.locales.split(",")) if args.locales else None
    requested_screens = set(args.screens.split(",")) if args.screens else None
    requested_devices = set(args.devices.split(",")) if args.devices else None

    def process_file(src, parsed):
        nonlocal exported, resized, skipped
        asc_locale = LOCALE_MAP.get(parsed["locale"])
        if requested_locales and not ({parsed["locale"], asc_locale} & requested_locales):
            return
        if requested_screens and parsed["screen"] not in requested_screens:
            return
        if requested_devices and parsed["device"] not in requested_devices:
            return

        # Filter by device type
        watch = is_watch_screen(parsed["screen"])
        if args.ios_only and watch:
            return
        if args.watch_only and not watch:
            return

        result = export_screenshot(src, parsed, output_dir, dry_run=args.dry_run, marketing=args.marketing)
        if result:
            out_path, suffix = result
            exported += 1
            if suffix:
                resized += 1
            if args.dry_run:
                rel = os.path.relpath(out_path, output_dir)
                print(f"  {os.path.basename(src)} -> {rel}{suffix}")
        else:
            skipped += 1

    # --- English screenshots (raw mode only) ---
    if english_dir and os.path.isdir(english_dir):
        for filename in sorted(os.listdir(english_dir)):
            if not filename.endswith(".png"):
                continue
            parsed = parse_english_filename(filename)
            if parsed is None:
                skipped += 1
                continue
            process_file(os.path.join(english_dir, filename), parsed)

    # --- Localized screenshots (includes en-US in marketing mode) ---
    if os.path.isdir(localized_base):
        for locale_folder in sorted(os.listdir(localized_base)):
            locale_dir = os.path.join(localized_base, locale_folder)
            if not os.path.isdir(locale_dir):
                continue
            for filename in sorted(os.listdir(locale_dir)):
                if not filename.endswith(".png"):
                    continue
                parsed = parse_localized_filename(filename, locale_folder)
                if parsed is None:
                    skipped += 1
                    continue
                process_file(os.path.join(locale_dir, filename), parsed)

    # --- Watch screenshots from raw sources (marketing mode only) ---
    # Marketing screenshots exclude Watch (text illegible at watch sizes),
    # so we pull Watch screenshots from the original raw snapshot directories.
    if watch_english_dir and os.path.isdir(watch_english_dir):
        for filename in sorted(os.listdir(watch_english_dir)):
            if not filename.endswith(".png"):
                continue
            parsed = parse_english_filename(filename)
            if parsed is None:
                continue
            if not is_watch_screen(parsed["screen"]):
                continue
            process_file(os.path.join(watch_english_dir, filename), parsed)

    if watch_localized_base and os.path.isdir(watch_localized_base):
        for locale_folder in sorted(os.listdir(watch_localized_base)):
            locale_dir = os.path.join(watch_localized_base, locale_folder)
            if not os.path.isdir(locale_dir):
                continue
            for filename in sorted(os.listdir(locale_dir)):
                if not filename.endswith(".png"):
                    continue
                parsed = parse_localized_filename(filename, locale_folder)
                if parsed is None:
                    continue
                if not is_watch_screen(parsed["screen"]):
                    continue
                process_file(os.path.join(locale_dir, filename), parsed)

    # Summary
    action = "Would export" if args.dry_run else "Exported"
    print(f"\n{action} {exported} screenshots to {output_dir}")
    if resized:
        resize_label = "would resize" if args.dry_run else "resized"
        print(f"  ({resized} iPad/Watch screenshots {resize_label} to App Store dimensions)")
    if skipped:
        print(f"Skipped {skipped} files (unmapped locale or unparseable filename)")

    # List locale breakdown
    if not args.dry_run and exported > 0:
        print("\nPer locale:")
        for locale_dir_name in sorted(os.listdir(output_dir)):
            full = os.path.join(output_dir, locale_dir_name)
            if os.path.isdir(full):
                count = len([f for f in os.listdir(full) if f.endswith(".png")])
                print(f"  {locale_dir_name}: {count} screenshots")


if __name__ == "__main__":
    main()
