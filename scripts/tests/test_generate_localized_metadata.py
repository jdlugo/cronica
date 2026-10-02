import importlib.util
from pathlib import Path
from urllib.parse import parse_qs, urlparse


ROOT = Path(__file__).resolve().parents[2]
TARGET_LOCALES = {"fr-FR", "es-ES", "es-MX", "pt-BR"}


def load_module(name, relative_path):
    spec = importlib.util.spec_from_file_location(name, ROOT / relative_path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


metadata = load_module("generate_localized_metadata", "scripts/generate_localized_metadata.py")
content = load_module("fetch_localized_content", "scripts/fetch_localized_content.py")
exporter = load_module("export_screenshots", "scripts/export_screenshots_for_fastlane.py")


def test_target_metadata_stays_within_app_store_limits():
    assert metadata.validate_all() == []
    for locale in TARGET_LOCALES:
        assert len(metadata.NAME[locale]) <= metadata.LIMITS["name"]
        assert len(metadata.SUBTITLE[locale]) <= metadata.LIMITS["subtitle"]
        assert len(metadata.KEYWORDS[locale]) <= metadata.LIMITS["keywords"]
        assert len(metadata.PROMOTIONAL_TEXT[locale]) <= metadata.LIMITS["promotional_text"]
        assert len(metadata.DESCRIPTION[locale]) <= metadata.LIMITS["description"]


def test_target_metadata_leads_with_puzzle_and_retains_tracking_intent():
    for locale in TARGET_LOCALES:
        acquisition_copy = " ".join([
            metadata.NAME[locale],
            metadata.SUBTITLE[locale],
            metadata.PROMOTIONAL_TEXT[locale],
        ]).lower()
        assert "emoji" in acquisition_copy
        assert "watchlist" in metadata.KEYWORDS[locale].lower()
        assert metadata.DESCRIPTION[locale].startswith(metadata.PUZZLE_DESCRIPTION_INTRO[locale])


def test_spain_and_mexico_positioning_is_intentionally_distinct():
    assert metadata.NAME["es-ES"] != metadata.NAME["es-MX"]
    assert metadata.SUBTITLE["es-ES"] != metadata.SUBTITLE["es-MX"]
    assert metadata.PROMOTIONAL_TEXT["es-ES"] != metadata.PROMOTIONAL_TEXT["es-MX"]
    assert "cartelera" in metadata.KEYWORDS["es-ES"]
    assert "pelis" in metadata.KEYWORDS["es-MX"]


def test_target_tmdb_requests_include_storefront_region():
    expected = {"fr": "FR", "es": "ES", "es-MX": "MX", "pt-BR": "BR"}
    for locale, region in expected.items():
        url = content.build_tmdb_url("movie", 1, locale, "test-key")
        query = parse_qs(urlparse(url).query)
        assert query["language"] == [locale]
        assert query["region"] == [region]


def test_first_three_marketing_screens_match_acquisition_funnel():
    ordered = sorted(
        (order, screen)
        for screen, order in exporter.MARKETING_SCREEN_ORDER.items()
        if screen not in exporter.WATCH_SCREENS
    )
    assert [screen for _, screen in ordered[:3]] == [
        "HomeScreen",
        "DetailScreen",
        "WatchlistScreen",
    ]
