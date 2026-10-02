#!/usr/bin/env python3
"""
Fetch localized movie/TV content from TMDB API for screenshot testing.

Reads Shared/Preview Data/content.json for item IDs and media types,
fetches localized text (title/name, overview, genres) for each non-English
locale, and saves as content_{locale}.json files.

Usage:
    python3 scripts/fetch_localized_content.py --api-key YOUR_TMDB_API_KEY
"""

import argparse
import json
import os
import sys
import time
import urllib.request
import urllib.error
import urllib.parse

LOCALES = [
    "de", "es", "es-MX", "fr", "it", "ja", "ko",
    "nl", "pl", "pt-BR", "sq", "tr", "zh", "ar",
]

TMDB_BASE = "https://api.themoviedb.org/3"
REQUEST_DELAY = 0.25  # 4 req/sec, well under TMDB's 40/10s limit
REGION_BY_LOCALE = {
    "es": "ES",
    "es-MX": "MX",
    "fr": "FR",
    "pt-BR": "BR",
}


def determine_media_type(item):
    """Movie items have a 'title' key; TV items have 'name'."""
    if "title" in item:
        return "movie"
    return "tv"


def build_tmdb_url(media_type, item_id, locale, api_key):
    """Build a localized, target-region-aware TMDB request URL."""
    params = {
        "api_key": api_key,
        "language": locale,
        "append_to_response": "credits",
    }
    if locale in REGION_BY_LOCALE:
        params["region"] = REGION_BY_LOCALE[locale]
    return f"{TMDB_BASE}/{media_type}/{item_id}?{urllib.parse.urlencode(params)}"


def fetch_tmdb(media_type, item_id, locale, api_key):
    """Fetch a single item from TMDB with the given locale and target region."""
    url = build_tmdb_url(media_type, item_id, locale, api_key)
    req = urllib.request.Request(url)
    req.add_header("Accept", "application/json")

    resp = urllib.request.urlopen(req)
    return json.loads(resp.read().decode("utf-8"))


def apply_localized_fields(item, fetched, media_type):
    """
    Replace only text fields in the item with localized values.
    Keeps images, credits, and all other fields from the English base.
    """
    localized = dict(item)  # shallow copy of the English item

    # Title / Name
    if media_type == "movie":
        if "title" in fetched and fetched["title"]:
            localized["title"] = fetched["title"]
    else:
        if "name" in fetched and fetched["name"]:
            localized["name"] = fetched["name"]

    # Overview
    if "overview" in fetched and fetched["overview"]:
        localized["overview"] = fetched["overview"]

    # Genres
    if "genres" in fetched and fetched["genres"]:
        localized["genres"] = fetched["genres"]

    return localized


def main():
    parser = argparse.ArgumentParser(
        description="Fetch localized TMDB content for screenshot testing."
    )
    parser.add_argument(
        "--api-key",
        required=True,
        help="TMDB API key (used as Bearer token)",
    )
    args = parser.parse_args()

    # Resolve paths relative to the script's parent directory (project root)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    preview_data_dir = os.path.join(project_root, "Shared", "Preview Data")
    content_path = os.path.join(preview_data_dir, "content.json")

    if not os.path.exists(content_path):
        print(f"Error: {content_path} not found.", file=sys.stderr)
        sys.exit(1)

    with open(content_path, "r", encoding="utf-8") as f:
        content = json.load(f)

    items = content["results"]
    print(f"Loaded {len(items)} items from content.json")

    # Determine media types upfront
    item_types = []
    for item in items:
        media_type = determine_media_type(item)
        item_id = item["id"]
        label = item.get("title") or item.get("name", f"ID {item_id}")
        item_types.append((item_id, media_type, label))

    print(f"Items: {sum(1 for _, t, _ in item_types if t == 'movie')} movies, "
          f"{sum(1 for _, t, _ in item_types if t == 'tv')} TV shows")
    print(f"Locales: {', '.join(LOCALES)}")
    print(f"Total requests: {len(items) * len(LOCALES)}")
    print()

    for locale in LOCALES:
        print(f"--- Locale: {locale} ---")
        localized_items = []

        for idx, item in enumerate(items):
            item_id, media_type, label = item_types[idx]
            print(f"  [{idx + 1}/{len(items)}] {media_type}/{item_id} ({label})...", end=" ")

            try:
                fetched = fetch_tmdb(media_type, item_id, locale, args.api_key)
                localized = apply_localized_fields(item, fetched, media_type)
                localized_items.append(localized)
                print("OK")
            except urllib.error.HTTPError as e:
                print(f"WARN: HTTP {e.code} - keeping English")
                localized_items.append(dict(item))
            except Exception as e:
                print(f"WARN: {e} - keeping English")
                localized_items.append(dict(item))

            time.sleep(REQUEST_DELAY)

        # Save the localized file
        output = {"results": localized_items}
        # Use locale as-is for filenames (e.g., content_pt-BR.json)
        output_path = os.path.join(preview_data_dir, f"content_{locale}.json")
        with open(output_path, "w", encoding="utf-8") as f:
            json.dump(output, f, ensure_ascii=False, indent=2)

        print(f"  Saved: {output_path}")
        print()

    print("Done! All localized content files generated.")


if __name__ == "__main__":
    main()
