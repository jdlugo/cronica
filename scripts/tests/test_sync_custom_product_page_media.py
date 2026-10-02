import importlib.util
import sys
from pathlib import Path


SCRIPT_PATH = Path(__file__).parents[1] / "sync_custom_product_page_media.py"
sys.path.insert(0, str(SCRIPT_PATH.parent))
SPEC = importlib.util.spec_from_file_location("sync_custom_product_page_media", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def test_screenshot_paths_follow_page_screen_order(tmp_path):
    locale_root = tmp_path / "fr-FR"
    locale_root.mkdir()
    home = locale_root / "01-HomeScreen_iPhone 6.9-inch.png"
    detail = locale_root / "02-DetailScreen_iPhone 6.9-inch.png"
    watchlist = locale_root / "03-WatchlistScreen_iPhone 6.9-inch.png"
    for path in (home, detail, watchlist):
        path.write_bytes(b"png")
    page = {"screen_order": ["WatchlistScreen", "DetailScreen", "HomeScreen"]}

    assert MODULE.screenshot_paths(page, "fr-FR", tmp_path, MODULE.DEVICE_CONFIGS[0]) == [
        watchlist,
        detail,
        home,
    ]


def test_upload_file_name_changes_with_content(tmp_path):
    path = tmp_path / "01-HomeScreen_iPhone 6.9-inch.png"
    path.write_bytes(b"first")
    page = {"slug": "daily-puzzle"}
    first = MODULE.upload_file_name(page, "fr-FR", MODULE.DEVICE_CONFIGS[0], 1, path)
    path.write_bytes(b"second")
    second = MODULE.upload_file_name(page, "fr-FR", MODULE.DEVICE_CONFIGS[0], 1, path)

    assert first != second
    assert first.startswith("01-daily-puzzle-fr-FR-iphone-67-HomeScreen-")


def test_screenshot_payloads_match_apple_contract(tmp_path):
    path = tmp_path / "shot.png"
    path.write_bytes(b"1234")

    assert MODULE.screenshot_set_create_payload("locale-id", "APP_IPHONE_67") == {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": "APP_IPHONE_67"},
            "relationships": {
                "appCustomProductPageLocalization": {
                    "data": {
                        "type": "appCustomProductPageLocalizations",
                        "id": "locale-id",
                    }
                }
            },
        }
    }
    assert MODULE.screenshot_create_payload("set-id", path, "shot.png")["data"][
        "attributes"
    ] == {"fileSize": 4, "fileName": "shot.png"}
    assert MODULE.screenshot_finalize_payload("shot-id")["data"]["attributes"] == {
        "uploaded": True
    }
    assert MODULE.screenshot_order_payload(["one", "two"])["data"] == [
        {"type": "appScreenshots", "id": "one"},
        {"type": "appScreenshots", "id": "two"},
    ]


def test_keyword_linkage_payload_uses_app_keyword_ids():
    assert MODULE.keyword_linkage_payload(["films", "streaming"]) == {
        "data": [
            {"type": "appKeywords", "id": "films"},
            {"type": "appKeywords", "id": "streaming"},
        ]
    }


def test_page_media_locales_includes_primary_once():
    page = {
        "primary_locale": {"locale": "en-US", "keywords": []},
        "locales": [
            {"locale": "fr-FR", "keywords": ["films"]},
            {"locale": "en-US", "keywords": []},
        ],
    }

    assert [locale["locale"] for locale in MODULE.page_media_locales(page)] == [
        "en-US",
        "fr-FR",
    ]


def test_preserved_screenshot_ids_excludes_managed_files():
    resources = [
        {"id": "managed", "attributes": {"fileName": "managed.png"}},
        {"id": "inherited", "attributes": {"fileName": "default.png"}},
    ]

    assert MODULE.preserved_screenshot_ids(resources, ["managed.png"]) == ["inherited"]


def test_replacement_screenshots_selects_only_non_target_files():
    resources = [
        {"id": "current", "attributes": {"fileName": "current.png"}},
        {"id": "stale", "attributes": {"fileName": "stale.png"}},
    ]

    assert MODULE.replacement_screenshots(resources, ["current.png"]) == [resources[1]]


def test_screenshot_count_guard_requires_replacement_above_ten():
    assert MODULE.validate_screenshot_count(3, 7) == 10

    try:
        MODULE.validate_screenshot_count(3, 8)
    except ValueError as error:
        assert "--replace-existing" in str(error)
    else:
        raise AssertionError("Expected screenshot count validation to fail")


def test_version_for_sync_reads_submitted_page_in_dry_run():
    class Client:
        def get_all(self, path, *, params):
            return [
                {
                    "id": "submitted-id",
                    "attributes": {"version": "1", "state": "WAITING_FOR_REVIEW"},
                }
            ]

        def request(self, method, path, *, body):
            raise AssertionError("Media dry run must not create a draft")

    version = MODULE.version_for_sync(Client(), "page-id", apply=False)

    assert version["id"] == "submitted-id"
