import importlib.util
import json
from pathlib import Path

import pytest


SCRIPT_PATH = Path(__file__).parents[1] / "sync_custom_product_pages.py"
SPEC = importlib.util.spec_from_file_location("sync_custom_product_pages", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def sample_page():
    return {
        "reference_name": "Daily Puzzle - International",
        "slug": "daily-puzzle",
        "primary_locale": {
            "locale": "en-US",
            "promotional_text": "Solve today's emoji movie puzzle.",
            "keywords": [],
        },
        "screen_order": ["HomeScreen", "DetailScreen", "WatchlistScreen"],
        "locales": [
            {
                "locale": "fr-FR",
                "promotional_text": "Résolvez le puzzle film du jour.",
                "keywords": ["quiz film", "emoji film"],
            },
            {
                "locale": "es-MX",
                "promotional_text": "Resuelve el reto de películas de hoy.",
                "keywords": ["juego películas"],
            },
        ],
    }


def test_load_manifest_accepts_repository_contract(tmp_path):
    path = tmp_path / "manifest.json"
    path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "app_id": "123456789",
                "pages": [
                    {
                        "reference_name": "Daily Puzzle - International",
                        "slug": "daily-puzzle",
                        "primary_locale": {
                            "locale": "en-US",
                            "promotional_text": "Solve today's emoji movie puzzle.",
                        },
                        "screen_order": ["HomeScreen", "DetailScreen"],
                        "locales": {
                            "fr-FR": {
                                "promotional_text": "Résolvez le puzzle du jour.",
                                "keywords": "quiz film, emoji film",
                            }
                        },
                    }
                ],
            }
        ),
        encoding="utf-8",
    )

    manifest = MODULE.load_manifest(path)

    assert manifest["app_id"] == "123456789"
    assert manifest["pages"][0]["locales"] == [
        {
            "locale": "fr-FR",
            "promotional_text": "Résolvez le puzzle du jour.",
            "keywords": ["quiz film", "emoji film"],
        }
    ]


def test_build_create_payload_seeds_primary_locale_inline():
    payload = MODULE.build_create_payload(
        app_id="123456789",
        template_version_id="template-id",
        page=sample_page(),
    )

    assert payload["data"]["type"] == "appCustomProductPages"
    assert payload["data"]["attributes"]["name"] == "Daily Puzzle - International"
    relationships = payload["data"]["relationships"]
    assert relationships["app"]["data"]["id"] == "123456789"
    assert relationships["appStoreVersionTemplate"]["data"]["id"] == "template-id"
    assert relationships["appCustomProductPageVersions"]["data"][0]["id"] == (
        "${new-appCustomProductPageVersion-id}"
    )
    assert payload["included"][0]["relationships"][
        "appCustomProductPageLocalizations"
    ]["data"][0]["id"] == "${new-appCustomProductPageLocalization-id}"
    assert payload["included"][1]["attributes"] == {
        "locale": "en-US",
        "promotionalText": "Solve today's emoji movie puzzle.",
    }


def test_build_version_create_payload_links_real_page_id():
    assert MODULE.build_version_create_payload("page-id") == {
        "data": {
            "type": "appCustomProductPageVersions",
            "relationships": {
                "appCustomProductPage": {
                    "data": {"type": "appCustomProductPages", "id": "page-id"}
                }
            },
        }
    }


def test_build_localization_create_payload_links_draft_version():
    payload = MODULE.build_localization_create_payload(
        version_id="version-id", locale=sample_page()["locales"][1]
    )

    assert payload == {
        "data": {
            "type": "appCustomProductPageLocalizations",
            "attributes": {
                "locale": "es-MX",
                "promotionalText": "Resuelve el reto de películas de hoy.",
            },
            "relationships": {
                "appCustomProductPageVersion": {
                    "data": {
                        "type": "appCustomProductPageVersions",
                        "id": "version-id",
                    }
                }
            },
        }
    }


def test_localization_update_payload_targets_existing_resource():
    assert MODULE.build_localization_update_payload("localization-id", "New copy") == {
        "data": {
            "type": "appCustomProductPageLocalizations",
            "id": "localization-id",
            "attributes": {"promotionalText": "New copy"},
        }
    }


def test_page_locales_includes_primary_once():
    page = sample_page()
    page["locales"].append(page["primary_locale"])

    assert [locale["locale"] for locale in MODULE.page_locales(page)] == [
        "en-US",
        "fr-FR",
        "es-MX",
    ]


def test_create_missing_localizations_only_posts_absent_locales():
    class Client:
        def __init__(self):
            self.requests = []

        def request(self, method, path, *, body):
            self.requests.append((method, path, body))
            return {"data": {"id": "created"}}

    client = Client()
    created = MODULE.create_missing_localizations(
        client,
        version_id="version-id",
        configured_locales=sample_page()["locales"],
        existing_locales=[{"attributes": {"locale": "fr-FR"}}],
    )

    assert created == ["es-MX"]
    assert len(client.requests) == 1
    assert client.requests[0][2]["data"]["attributes"]["locale"] == "es-MX"


def test_synchronize_localizations_reports_dry_run_changes():
    class Client:
        def request(self, method, path, *, body):
            raise AssertionError("Dry run must not mutate App Store Connect")

    changes = MODULE.synchronize_localizations(
        Client(),
        version_id="version-id",
        configured_locales=MODULE.page_locales(sample_page()),
        existing_locales=[
            {
                "id": "en-id",
                "attributes": {"locale": "en-US", "promotionalText": "Old copy"},
            },
            {
                "id": "fr-id",
                "attributes": {
                    "locale": "fr-FR",
                    "promotionalText": "Résolvez le puzzle film du jour.",
                },
            },
        ],
        apply=False,
    )

    assert changes == {
        "created": [],
        "updated": [],
        "would_create": ["es-MX"],
        "would_update": ["en-US"],
        "unchanged": ["fr-FR"],
    }


def test_select_template_version_prefers_requested_ready_version():
    versions = [
        {
            "id": "old",
            "attributes": {"versionString": "4.25.39", "appStoreState": "READY_FOR_SALE"},
        },
        {
            "id": "review",
            "attributes": {"versionString": "4.25.40", "appStoreState": "WAITING_FOR_REVIEW"},
        },
    ]

    assert MODULE.select_template_version(versions, "4.25.39")["id"] == "old"
    assert MODULE.select_template_version(versions, None)["id"] == "old"
    with pytest.raises(ValueError, match="not available"):
        MODULE.select_template_version(versions, "4.25.40")


def test_plan_actions_is_idempotent_by_reference_name():
    pages = [sample_page(), {**sample_page(), "reference_name": "Movie Tracker - International"}]
    existing = [
        {
            "type": "appCustomProductPages",
            "id": "existing-id",
            "attributes": {"name": "Daily Puzzle - International"},
        }
    ]

    actions = MODULE.plan_actions(pages, existing)

    assert [action["action"] for action in actions] == ["skip", "create"]
    assert actions[0]["existing"]["id"] == "existing-id"


def test_version_for_sync_reads_latest_submitted_version_without_creating_draft():
    class Client:
        def get_all(self, path, *, params):
            assert path == "/v1/appCustomProductPages/page-id/appCustomProductPageVersions"
            return [
                {
                    "id": "submitted-id",
                    "attributes": {"version": "2", "state": "WAITING_FOR_REVIEW"},
                },
                {
                    "id": "approved-id",
                    "attributes": {"version": "1", "state": "APPROVED"},
                },
            ]

        def request(self, method, path, *, body):
            raise AssertionError("Read-only reconciliation must not create a draft")

    version = MODULE.version_for_sync(Client(), "page-id", apply=False)

    assert version["id"] == "submitted-id"
