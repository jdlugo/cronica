#!/usr/bin/env python3
"""Synchronize screenshots and available keywords for custom product-page drafts."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import time
from pathlib import Path
from typing import Any, Iterable
from urllib.request import Request, urlopen

from sync_custom_product_pages import (
    API_BASE_URL,
    AppStoreConnectClient,
    draft_version_for_page,
    first_env,
    latest_version_for_page,
    load_local_env,
    load_manifest,
    localization_resources,
)


DEFAULT_OUTPUT = Path(".build/international-growth/custom-product-page-media-sync.json")
DEVICE_CONFIGS = (
    {
        "source_label": "iPhone 6.9-inch",
        "file_token": "iphone-67",
        "display_type": "APP_IPHONE_67",
    },
    {
        "source_label": "iPad Pro 13-inch",
        "file_token": "ipad-129",
        "display_type": "APP_IPAD_PRO_3GEN_129",
    },
)
COMPLETE_ASSET_STATES = {"COMPLETE"}
FAILED_ASSET_STATES = {"FAILED"}


def configured_client(base_url: str = API_BASE_URL) -> AppStoreConnectClient:
    load_local_env()
    key_id = first_env("ASC_KEY_ID", "APP_STORE_CONNECT_API_KEY_ID") or "439479CNWQ"
    issuer_id = (
        first_env("ASC_ISSUER_ID", "APP_STORE_CONNECT_API_ISSUER_ID")
        or "69a6de7b-b570-47e3-e053-5b8c7c11a4d1"
    )
    key_path = Path(
        first_env("ASC_KEY_PATH", "APP_STORE_CONNECT_API_KEY_PATH")
        or f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8"
    ).expanduser()
    return AppStoreConnectClient(
        key_id=key_id,
        issuer_id=issuer_id,
        private_key_path=key_path,
        base_url=base_url,
    )


def version_for_sync(
    client: AppStoreConnectClient, page_id: str, *, apply: bool
) -> dict[str, Any]:
    if apply:
        return draft_version_for_page(client, page_id)
    return latest_version_for_page(client, page_id)


def screenshot_paths(
    page: dict[str, Any], locale: str, root: Path, device: dict[str, str]
) -> list[Path]:
    locale_root = root / locale
    paths: list[Path] = []
    for screen in page["screen_order"]:
        matches = sorted(locale_root.glob(f"*-{screen}_{device['source_label']}.png"))
        if len(matches) != 1:
            raise ValueError(
                f"Expected one {screen} screenshot for {locale} {device['source_label']}; "
                f"found {len(matches)}"
            )
        paths.append(matches[0])
    return paths


def upload_file_name(
    page: dict[str, Any], locale: str, device: dict[str, str], position: int, path: Path
) -> str:
    digest = hashlib.sha256(path.read_bytes()).hexdigest()[:12]
    screen = path.name.split("_", 1)[0].split("-", 1)[-1]
    return (
        f"{position:02d}-{page['slug']}-{locale}-{device['file_token']}-"
        f"{screen}-{digest}.png"
    )


def screenshot_set_create_payload(
    localization_id: str, display_type: str
) -> dict[str, Any]:
    return {
        "data": {
            "type": "appScreenshotSets",
            "attributes": {"screenshotDisplayType": display_type},
            "relationships": {
                "appCustomProductPageLocalization": {
                    "data": {
                        "type": "appCustomProductPageLocalizations",
                        "id": localization_id,
                    }
                }
            },
        }
    }


def screenshot_create_payload(
    screenshot_set_id: str, path: Path, file_name: str
) -> dict[str, Any]:
    return {
        "data": {
            "type": "appScreenshots",
            "attributes": {"fileSize": path.stat().st_size, "fileName": file_name},
            "relationships": {
                "appScreenshotSet": {
                    "data": {"type": "appScreenshotSets", "id": screenshot_set_id}
                }
            },
        }
    }


def screenshot_finalize_payload(screenshot_id: str) -> dict[str, Any]:
    return {
        "data": {
            "type": "appScreenshots",
            "id": screenshot_id,
            "attributes": {"uploaded": True},
        }
    }


def screenshot_order_payload(screenshot_ids: Iterable[str]) -> dict[str, Any]:
    return {
        "data": [
            {"type": "appScreenshots", "id": screenshot_id}
            for screenshot_id in screenshot_ids
        ]
    }


def preserved_screenshot_ids(
    existing_screenshots: Iterable[dict[str, Any]], target_file_names: Iterable[str]
) -> list[str]:
    target_names = set(target_file_names)
    return [
        resource["id"]
        for resource in existing_screenshots
        if resource.get("attributes", {}).get("fileName") not in target_names
    ]


def replacement_screenshots(
    existing_screenshots: Iterable[dict[str, Any]], target_file_names: Iterable[str]
) -> list[dict[str, Any]]:
    target_names = set(target_file_names)
    return [
        resource
        for resource in existing_screenshots
        if resource.get("attributes", {}).get("fileName") not in target_names
    ]


def validate_screenshot_count(target_count: int, preserved_count: int) -> int:
    final_count = target_count + preserved_count
    if final_count > 10:
        raise ValueError(
            f"Screenshot set would contain {final_count} images; Apple allows at most 10. "
            "Use --replace-existing to replace the custom-page media."
        )
    return final_count


def keyword_linkage_payload(keyword_ids: Iterable[str]) -> dict[str, Any]:
    return {
        "data": [
            {"type": "appKeywords", "id": keyword_id} for keyword_id in keyword_ids
        ]
    }


def page_media_locales(page: dict[str, Any]) -> list[dict[str, Any]]:
    locales: list[dict[str, Any]] = []
    seen: set[str] = set()
    for locale in [page["primary_locale"], *page["locales"]]:
        if locale["locale"] not in seen:
            locales.append(locale)
            seen.add(locale["locale"])
    return locales


def upload_operations(path: Path, operations: Iterable[dict[str, Any]]) -> None:
    payload = path.read_bytes()
    for operation in operations:
        offset = operation["offset"]
        length = operation["length"]
        headers = {
            header["name"]: header["value"]
            for header in operation.get("requestHeaders", [])
        }
        request = Request(
            operation["url"],
            data=payload[offset : offset + length],
            method=operation["method"],
            headers=headers,
        )
        with urlopen(request, timeout=120) as response:
            response.read()


def asset_state(resource: dict[str, Any]) -> str | None:
    return resource.get("attributes", {}).get("assetDeliveryState", {}).get("state")


def wait_for_asset(
    client: AppStoreConnectClient, screenshot_id: str, timeout_seconds: int = 120
) -> dict[str, Any]:
    deadline = time.monotonic() + timeout_seconds
    while True:
        response = client.request(
            "GET",
            f"/v1/appScreenshots/{screenshot_id}",
            params={
                "fields[appScreenshots]": "fileName,fileSize,assetDeliveryState"
            },
        )
        resource = response["data"]
        state = asset_state(resource)
        if state in COMPLETE_ASSET_STATES:
            return resource
        if state in FAILED_ASSET_STATES:
            errors = resource.get("attributes", {}).get("assetDeliveryState", {}).get("errors", [])
            raise RuntimeError(f"Screenshot {screenshot_id} processing failed: {errors}")
        if time.monotonic() >= deadline:
            raise TimeoutError(f"Screenshot {screenshot_id} remained in state {state}")
        time.sleep(2)


def reserve_upload_finalize(
    client: AppStoreConnectClient,
    *,
    screenshot_set_id: str,
    path: Path,
    file_name: str,
) -> dict[str, Any]:
    response = client.request(
        "POST",
        "/v1/appScreenshots",
        body=screenshot_create_payload(screenshot_set_id, path, file_name),
    )
    screenshot = response["data"]
    operations = screenshot.get("attributes", {}).get("uploadOperations", [])
    if not operations:
        raise RuntimeError(f"Apple returned no upload operations for {file_name}")
    upload_operations(path, operations)
    client.request(
        "PATCH",
        f"/v1/appScreenshots/{screenshot['id']}",
        body=screenshot_finalize_payload(screenshot["id"]),
    )
    return wait_for_asset(client, screenshot["id"])


def screenshot_sets(
    client: AppStoreConnectClient, localization_id: str
) -> list[dict[str, Any]]:
    return client.get_all(
        f"/v1/appCustomProductPageLocalizations/{localization_id}/appScreenshotSets",
        params={
            "fields[appScreenshotSets]": "screenshotDisplayType,appScreenshots",
            "limit": 50,
        },
    )


def screenshots(
    client: AppStoreConnectClient, screenshot_set_id: str
) -> list[dict[str, Any]]:
    return client.get_all(
        f"/v1/appScreenshotSets/{screenshot_set_id}/appScreenshots",
        params={
            "fields[appScreenshots]": "fileName,fileSize,assetDeliveryState",
            "limit": 50,
        },
    )


def synchronize_keywords(
    client: AppStoreConnectClient,
    *,
    app_id: str,
    localization_id: str,
    locale: dict[str, Any],
    apply: bool,
) -> dict[str, Any]:
    if not locale["keywords"]:
        return {"desired": [], "assigned_now": [], "would_assign": [], "unavailable": []}
    available = client.get_all(
        f"/v1/apps/{app_id}/searchKeywords",
        params={
            "filter[locale]": locale["locale"],
            "filter[platform]": "IOS",
            "limit": 200,
        },
    )
    available_ids = {resource["id"] for resource in available}
    assigned = client.get_all(
        f"/v1/appCustomProductPageLocalizations/{localization_id}/searchKeywords",
        params={"limit": 50},
    )
    assigned_ids = {resource["id"] for resource in assigned}
    desired = locale["keywords"]
    assignable = [keyword for keyword in desired if keyword in available_ids]
    missing = [keyword for keyword in assignable if keyword not in assigned_ids]
    unavailable = [keyword for keyword in desired if keyword not in available_ids]
    if apply and missing:
        client.request(
            "POST",
            f"/v1/appCustomProductPageLocalizations/{localization_id}/relationships/searchKeywords",
            body=keyword_linkage_payload(missing),
        )
    return {
        "desired": desired,
        "assigned_now": missing if apply else [],
        "would_assign": missing if not apply else [],
        "unavailable": unavailable,
    }


def synchronize_screenshot_set(
    client: AppStoreConnectClient,
    *,
    page: dict[str, Any],
    locale: str,
    localization_id: str,
    device: dict[str, str],
    root: Path,
    existing_sets: list[dict[str, Any]],
    apply: bool,
    replace_existing: bool,
) -> dict[str, Any]:
    paths = screenshot_paths(page, locale, root, device)
    target_files = [
        upload_file_name(page, locale, device, position, path)
        for position, path in enumerate(paths, 1)
    ]
    screenshot_set = next(
        (
            resource
            for resource in existing_sets
            if resource.get("attributes", {}).get("screenshotDisplayType")
            == device["display_type"]
        ),
        None,
    )
    if screenshot_set is None and not apply:
        return {
            "display_type": device["display_type"],
            "action": "would_create_set",
            "would_upload": target_files,
        }
    if screenshot_set is None:
        response = client.request(
            "POST",
            "/v1/appScreenshotSets",
            body=screenshot_set_create_payload(localization_id, device["display_type"]),
        )
        screenshot_set = response["data"]

    existing_screenshots = screenshots(client, screenshot_set["id"])
    existing_by_name = {
        resource.get("attributes", {}).get("fileName"): resource
        for resource in existing_screenshots
    }
    replacements = replacement_screenshots(existing_screenshots, target_files)
    preserved_ids = (
        []
        if replace_existing
        else preserved_screenshot_ids(existing_screenshots, target_files)
    )
    final_count = validate_screenshot_count(len(target_files), len(preserved_ids))
    replacement_names = [
        resource.get("attributes", {}).get("fileName") or resource["id"]
        for resource in replacements
    ]
    if apply and replace_existing:
        for resource in replacements:
            client.request("DELETE", f"/v1/appScreenshots/{resource['id']}")

    ordered_ids: list[str] = []
    uploaded: list[str] = []
    skipped: list[str] = []
    for path, file_name in zip(paths, target_files):
        existing = existing_by_name.get(file_name)
        if existing is not None and asset_state(existing) == "COMPLETE":
            ordered_ids.append(existing["id"])
            skipped.append(file_name)
            continue
        if existing is not None and apply:
            client.request("DELETE", f"/v1/appScreenshots/{existing['id']}")
        if not apply:
            uploaded.append(file_name)
            continue
        print(f"uploading {page['slug']} {locale} {device['display_type']} {path.name}")
        created = reserve_upload_finalize(
            client,
            screenshot_set_id=screenshot_set["id"],
            path=path,
            file_name=file_name,
        )
        ordered_ids.append(created["id"])
        uploaded.append(file_name)

    if apply and ordered_ids:
        client.request(
            "PATCH",
            f"/v1/appScreenshotSets/{screenshot_set['id']}/relationships/appScreenshots",
            body=screenshot_order_payload([*ordered_ids, *preserved_ids]),
        )
    return {
        "display_type": device["display_type"],
        "set_id": screenshot_set["id"],
        "uploaded": uploaded,
        "skipped": skipped,
        "deleted": replacement_names if apply and replace_existing else [],
        "would_delete": replacement_names if not apply and replace_existing else [],
        "preserved_existing": len(preserved_ids),
        "final_count": final_count,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest", type=Path, default=Path("fastlane/custom_product_pages/manifest.json")
    )
    parser.add_argument("--screenshots-root", type=Path, default=Path("fastlane/screenshots"))
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--base-url", default=API_BASE_URL)
    parser.add_argument(
        "--replace-existing",
        action="store_true",
        help="Replace each custom-page screenshot set instead of preserving old media.",
    )
    parser.add_argument("--apply", action="store_true")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    manifest = load_manifest(args.manifest)
    client = configured_client(args.base_url)
    live_pages = client.get_all(
        f"/v1/apps/{manifest['app_id']}/appCustomProductPages",
        params={"fields[appCustomProductPages]": "name,url,visible", "limit": 200},
    )
    live_by_name = {
        resource.get("attributes", {}).get("name"): resource for resource in live_pages
    }
    report_pages: list[dict[str, Any]] = []
    for page in manifest["pages"]:
        live_page = live_by_name.get(page["reference_name"])
        if live_page is None:
            raise ValueError(f"Missing custom product page draft: {page['reference_name']}")
        version = version_for_sync(client, live_page["id"], apply=args.apply)
        live_locales = localization_resources(client, version["id"])
        locales_by_code = {
            resource.get("attributes", {}).get("locale"): resource
            for resource in live_locales
        }
        page_report = {"reference_name": page["reference_name"], "locales": []}
        for locale in page_media_locales(page):
            resource = locales_by_code.get(locale["locale"])
            if resource is None:
                raise ValueError(
                    f"Missing {locale['locale']} localization for {page['reference_name']}"
                )
            existing_sets = screenshot_sets(client, resource["id"])
            set_reports = [
                synchronize_screenshot_set(
                    client,
                    page=page,
                    locale=locale["locale"],
                    localization_id=resource["id"],
                    device=device,
                    root=args.screenshots_root,
                    existing_sets=existing_sets,
                    apply=args.apply,
                    replace_existing=args.replace_existing,
                )
                for device in DEVICE_CONFIGS
            ]
            page_report["locales"].append(
                {
                    "locale": locale["locale"],
                    "screenshots": set_reports,
                    "keywords": synchronize_keywords(
                        client,
                        app_id=manifest["app_id"],
                        localization_id=resource["id"],
                        locale=locale,
                        apply=args.apply,
                    ),
                }
            )
        report_pages.append(page_report)

    report = {"mode": "apply" if args.apply else "dry_run", "pages": report_pages}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    set_reports = [
        screenshot_set
        for page in report_pages
        for locale in page["locales"]
        for screenshot_set in locale["screenshots"]
    ]
    print(
        f"mode={report['mode']} replace_existing={args.replace_existing} "
        f"pages={len(report_pages)} sets={len(set_reports)}"
    )
    print(f"report={args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
