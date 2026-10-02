#!/usr/bin/env python3
"""Create configured App Store custom product pages as unsubmitted drafts."""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
from pathlib import Path
from typing import Any, Iterable
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

import jwt


API_BASE_URL = "https://api.appstoreconnect.apple.com"
DEFAULT_MANIFEST = Path("fastlane/custom_product_pages/manifest.json")
DEFAULT_OUTPUT = Path(".build/international-growth/custom-product-pages-sync.json")
READY_TEMPLATE_STATES = {"READY_FOR_SALE"}


class AppStoreConnectError(RuntimeError):
    pass


def load_local_env(path: Path = Path(".env")) -> None:
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("\"").strip("'")
        if key:
            os.environ.setdefault(key, value)


def first_env(*names: str) -> str | None:
    for name in names:
        value = os.environ.get(name)
        if value:
            return value
    return None


class AppStoreConnectClient:
    def __init__(
        self,
        *,
        key_id: str,
        issuer_id: str,
        private_key_path: Path,
        base_url: str = API_BASE_URL,
    ) -> None:
        self.key_id = key_id
        self.issuer_id = issuer_id
        self.private_key = private_key_path.expanduser().read_text(encoding="utf-8")
        self.base_url = base_url.rstrip("/")

    def token(self) -> str:
        now = int(time.time())
        return jwt.encode(
            {
                "iss": self.issuer_id,
                "iat": now,
                "exp": now + 1_200,
                "aud": "appstoreconnect-v1",
            },
            self.private_key,
            algorithm="ES256",
            headers={"kid": self.key_id, "typ": "JWT"},
        )

    def request(
        self,
        method: str,
        path_or_url: str,
        *,
        params: dict[str, Any] | None = None,
        body: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        url = path_or_url if path_or_url.startswith("http") else f"{self.base_url}{path_or_url}"
        if params:
            url = f"{url}?{urlencode(params, doseq=True)}"
        encoded_body = None if body is None else json.dumps(body).encode("utf-8")
        request = Request(
            url,
            data=encoded_body,
            method=method,
            headers={
                "Authorization": f"Bearer {self.token()}",
                "Accept": "application/json",
                "Content-Type": "application/json",
            },
        )
        try:
            with urlopen(request, timeout=60) as response:
                payload = response.read()
        except HTTPError as error:
            detail = error.read().decode("utf-8", errors="replace")
            raise AppStoreConnectError(
                f"App Store Connect returned HTTP {error.code}: {detail}"
            ) from error
        except URLError as error:
            raise AppStoreConnectError(f"App Store Connect request failed: {error.reason}") from error
        return json.loads(payload) if payload else {}

    def get_all(
        self,
        path: str,
        *,
        params: dict[str, Any] | None = None,
    ) -> list[dict[str, Any]]:
        resources: list[dict[str, Any]] = []
        next_url: str | None = path
        next_params = params
        while next_url:
            response = self.request("GET", next_url, params=next_params)
            resources.extend(response.get("data", []))
            next_url = response.get("links", {}).get("next")
            next_params = None
        return resources


def normalize_locales(raw_locales: Any) -> list[dict[str, Any]]:
    if isinstance(raw_locales, dict):
        entries = [dict(value, locale=key) for key, value in raw_locales.items()]
    elif isinstance(raw_locales, list):
        entries = [dict(value) for value in raw_locales]
    else:
        raise ValueError("Each custom product page requires a locales object or array")

    locales: list[dict[str, Any]] = []
    for entry in entries:
        locale = entry.get("locale")
        promotional_text = entry.get("promotional_text", entry.get("promotionalText", ""))
        if not locale or not promotional_text:
            raise ValueError("Each locale requires locale and promotional_text")
        keywords = entry.get("keywords", [])
        if isinstance(keywords, str):
            keywords = [part.strip() for part in keywords.split(",") if part.strip()]
        locales.append(
            {
                "locale": str(locale),
                "promotional_text": str(promotional_text),
                "keywords": list(keywords),
            }
        )
    return locales


def load_manifest(path: Path) -> dict[str, Any]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    app_id = str(raw.get("app_id", "")).strip()
    if not app_id:
        raise ValueError("Manifest requires app_id")

    pages: list[dict[str, Any]] = []
    names: set[str] = set()
    for raw_page in raw.get("pages", []):
        reference_name = raw_page.get("reference_name", raw_page.get("name"))
        if not reference_name:
            raise ValueError("Each page requires reference_name")
        if reference_name in names:
            raise ValueError(f"Duplicate page reference_name: {reference_name}")
        names.add(reference_name)
        pages.append(
            {
                "reference_name": str(reference_name),
                "slug": str(raw_page.get("slug", "")),
                "primary_locale": normalize_locales([raw_page.get("primary_locale")])[0],
                "screen_order": list(
                    raw_page.get("screen_order", raw_page.get("screenshot_order", []))
                ),
                "locales": normalize_locales(
                    raw_page.get("locales", raw_page.get("localizations"))
                ),
            }
        )
    if not pages:
        raise ValueError("Manifest requires at least one custom product page")
    return {"app_id": app_id, "pages": pages}


def version_key(version: str) -> tuple[tuple[int, Any], ...]:
    parts: list[tuple[int, Any]] = []
    for part in version.replace("-", ".").split("."):
        parts.append((0, int(part)) if part.isdigit() else (1, part.lower()))
    return tuple(parts)


def select_template_version(
    resources: Iterable[dict[str, Any]], requested_version: str | None
) -> dict[str, str]:
    candidates: list[dict[str, str]] = []
    for resource in resources:
        attributes = resource.get("attributes", {})
        version = attributes.get("versionString")
        state = attributes.get("appStoreState")
        if version and state in READY_TEMPLATE_STATES:
            candidates.append({"id": resource["id"], "version": version, "state": state})

    if requested_version:
        for candidate in candidates:
            if candidate["version"] == requested_version:
                return candidate
        raise ValueError(
            f"App Store version {requested_version} is not available in READY_FOR_SALE state"
        )
    if not candidates:
        raise ValueError("No READY_FOR_SALE App Store version is available as a template")
    return max(candidates, key=lambda candidate: version_key(candidate["version"]))


def build_create_payload(
    *,
    app_id: str,
    template_version_id: str,
    page: dict[str, Any],
) -> dict[str, Any]:
    version_id = "${new-appCustomProductPageVersion-id}"
    localization_id = "${new-appCustomProductPageLocalization-id}"
    primary_locale = page["primary_locale"]
    return {
        "data": {
            "type": "appCustomProductPages",
            "attributes": {"name": page["reference_name"]},
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
                "appStoreVersionTemplate": {
                    "data": {"type": "appStoreVersions", "id": template_version_id}
                },
                "appCustomProductPageVersions": {
                    "data": [
                        {"type": "appCustomProductPageVersions", "id": version_id}
                    ]
                },
            },
        },
        "included": [
            {
                "type": "appCustomProductPageVersions",
                "id": version_id,
                "relationships": {
                    "appCustomProductPage": {},
                    "appCustomProductPageLocalizations": {
                        "data": [
                            {
                                "type": "appCustomProductPageLocalizations",
                                "id": localization_id,
                            }
                        ]
                    },
                },
            },
            {
                "type": "appCustomProductPageLocalizations",
                "id": localization_id,
                "attributes": {
                    "locale": primary_locale["locale"],
                    "promotionalText": primary_locale["promotional_text"],
                },
            },
        ],
    }


def build_version_create_payload(page_id: str) -> dict[str, Any]:
    return {
        "data": {
            "type": "appCustomProductPageVersions",
            "relationships": {
                "appCustomProductPage": {
                    "data": {"type": "appCustomProductPages", "id": page_id}
                }
            },
        }
    }


def build_localization_create_payload(
    *, version_id: str, locale: dict[str, Any]
) -> dict[str, Any]:
    return {
        "data": {
            "type": "appCustomProductPageLocalizations",
            "attributes": {
                "locale": locale["locale"],
                "promotionalText": locale["promotional_text"],
            },
            "relationships": {
                "appCustomProductPageVersion": {
                    "data": {
                        "type": "appCustomProductPageVersions",
                        "id": version_id,
                    }
                }
            },
        }
    }


def build_localization_update_payload(
    localization_id: str, promotional_text: str
) -> dict[str, Any]:
    return {
        "data": {
            "type": "appCustomProductPageLocalizations",
            "id": localization_id,
            "attributes": {"promotionalText": promotional_text},
        }
    }


def page_locales(page: dict[str, Any]) -> list[dict[str, Any]]:
    locales: list[dict[str, Any]] = []
    seen: set[str] = set()
    for locale in [page["primary_locale"], *page["locales"]]:
        if locale["locale"] in seen:
            continue
        seen.add(locale["locale"])
        locales.append(locale)
    return locales


def plan_actions(
    pages: Iterable[dict[str, Any]], existing_pages: Iterable[dict[str, Any]]
) -> list[dict[str, Any]]:
    existing_by_name = {
        page.get("attributes", {}).get("name"): page
        for page in existing_pages
        if page.get("attributes", {}).get("name")
    }
    return [
        {
            "action": "skip" if page["reference_name"] in existing_by_name else "create",
            "page": page,
            "existing": existing_by_name.get(page["reference_name"]),
        }
        for page in pages
    ]


def draft_version_for_page(
    client: AppStoreConnectClient, page_id: str
) -> dict[str, Any]:
    versions = client.get_all(
        f"/v1/appCustomProductPages/{page_id}/appCustomProductPageVersions",
        params={
            "fields[appCustomProductPageVersions]": "version,state",
            "limit": 200,
        },
    )
    drafts = [
        version
        for version in versions
        if version.get("attributes", {}).get("state") == "PREPARE_FOR_SUBMISSION"
    ]
    if not drafts:
        raise ValueError(f"Custom product page {page_id} has no editable draft version")
    return max(
        drafts,
        key=lambda version: version_key(version.get("attributes", {}).get("version", "0")),
    )


def latest_version_for_page(
    client: AppStoreConnectClient, page_id: str
) -> dict[str, Any]:
    versions = client.get_all(
        f"/v1/appCustomProductPages/{page_id}/appCustomProductPageVersions",
        params={
            "fields[appCustomProductPageVersions]": "version,state",
            "limit": 200,
        },
    )
    if not versions:
        raise ValueError(f"Custom product page {page_id} has no version")
    return max(
        versions,
        key=lambda version: version_key(version.get("attributes", {}).get("version", "0")),
    )


def ensure_draft_version(
    client: AppStoreConnectClient, page_id: str
) -> dict[str, Any]:
    try:
        return draft_version_for_page(client, page_id)
    except ValueError:
        response = client.request(
            "POST",
            "/v1/appCustomProductPageVersions",
            body=build_version_create_payload(page_id),
        )
        return response["data"]


def version_for_sync(
    client: AppStoreConnectClient, page_id: str, *, apply: bool
) -> dict[str, Any]:
    if apply:
        return ensure_draft_version(client, page_id)
    return latest_version_for_page(client, page_id)


def localization_resources(
    client: AppStoreConnectClient, version_id: str
) -> list[dict[str, Any]]:
    return client.get_all(
        f"/v1/appCustomProductPageVersions/{version_id}/appCustomProductPageLocalizations",
        params={
            "fields[appCustomProductPageLocalizations]": "locale,promotionalText",
            "limit": 50,
        },
    )


def create_missing_localizations(
    client: AppStoreConnectClient,
    *,
    version_id: str,
    configured_locales: list[dict[str, Any]],
    existing_locales: Iterable[dict[str, Any]],
) -> list[str]:
    existing_codes = {
        resource.get("attributes", {}).get("locale") for resource in existing_locales
    }
    created: list[str] = []
    for locale in configured_locales:
        if locale["locale"] in existing_codes:
            continue
        client.request(
            "POST",
            "/v1/appCustomProductPageLocalizations",
            body=build_localization_create_payload(version_id=version_id, locale=locale),
        )
        created.append(locale["locale"])
    return created


def synchronize_localizations(
    client: AppStoreConnectClient,
    *,
    version_id: str,
    configured_locales: list[dict[str, Any]],
    existing_locales: Iterable[dict[str, Any]],
    apply: bool,
) -> dict[str, list[str]]:
    existing_by_code = {
        resource.get("attributes", {}).get("locale"): resource
        for resource in existing_locales
    }
    result: dict[str, list[str]] = {
        "created": [],
        "updated": [],
        "would_create": [],
        "would_update": [],
        "unchanged": [],
    }
    for locale in configured_locales:
        code = locale["locale"]
        resource = existing_by_code.get(code)
        if resource is None:
            if apply:
                client.request(
                    "POST",
                    "/v1/appCustomProductPageLocalizations",
                    body=build_localization_create_payload(
                        version_id=version_id, locale=locale
                    ),
                )
                result["created"].append(code)
            else:
                result["would_create"].append(code)
            continue

        current_text = resource.get("attributes", {}).get("promotionalText", "")
        if current_text == locale["promotional_text"]:
            result["unchanged"].append(code)
            continue
        if apply:
            client.request(
                "PATCH",
                f"/v1/appCustomProductPageLocalizations/{resource['id']}",
                body=build_localization_update_payload(
                    resource["id"], locale["promotional_text"]
                ),
            )
            result["updated"].append(code)
        else:
            result["would_update"].append(code)
    return result


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--template-version")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--base-url", default=API_BASE_URL)
    parser.add_argument(
        "--apply-drafts",
        action="store_true",
        help="Create missing draft pages. Never submits them for review.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    load_local_env()
    manifest = load_manifest(args.manifest)

    key_id = first_env("ASC_KEY_ID", "APP_STORE_CONNECT_API_KEY_ID") or "439479CNWQ"
    issuer_id = (
        first_env("ASC_ISSUER_ID", "APP_STORE_CONNECT_API_ISSUER_ID")
        or "69a6de7b-b570-47e3-e053-5b8c7c11a4d1"
    )
    key_path = Path(
        first_env("ASC_KEY_PATH", "APP_STORE_CONNECT_API_KEY_PATH")
        or f"~/.appstoreconnect/private_keys/AuthKey_{key_id}.p8"
    ).expanduser()
    if not key_path.exists():
        raise ValueError(f"App Store Connect private key not found: {key_path}")

    client = AppStoreConnectClient(
        key_id=key_id,
        issuer_id=issuer_id,
        private_key_path=key_path,
        base_url=args.base_url,
    )
    versions = client.get_all(
        f"/v1/apps/{manifest['app_id']}/appStoreVersions",
        params={
            "filter[platform]": "IOS",
            "fields[appStoreVersions]": "versionString,appStoreState",
            "limit": 200,
        },
    )
    template = select_template_version(versions, args.template_version)
    existing_pages = client.get_all(
        f"/v1/apps/{manifest['app_id']}/appCustomProductPages",
        params={
            "fields[appCustomProductPages]": "name,url,visible",
            "limit": 200,
        },
    )
    actions = plan_actions(manifest["pages"], existing_pages)

    results: list[dict[str, Any]] = []
    for item in actions:
        page = item["page"]
        if item["action"] == "skip":
            existing = item["existing"]
            version = version_for_sync(
                client, existing["id"], apply=args.apply_drafts
            )
            localization_changes = synchronize_localizations(
                client,
                version_id=version["id"],
                configured_locales=page_locales(page),
                existing_locales=localization_resources(client, version["id"]),
                apply=args.apply_drafts,
            )
            if args.apply_drafts:
                action = (
                    "updated_existing_draft"
                    if localization_changes["created"] or localization_changes["updated"]
                    else "skipped_existing"
                )
            else:
                action = (
                    "would_update_existing_draft"
                    if localization_changes["would_create"]
                    or localization_changes["would_update"]
                    else "skipped_existing"
                )
            results.append(
                {
                    "reference_name": page["reference_name"],
                    "action": action,
                    "id": existing.get("id"),
                    "url": existing.get("attributes", {}).get("url"),
                    "created_locales": localization_changes["created"],
                    "updated_locales": localization_changes["updated"],
                    "would_create_locales": localization_changes["would_create"],
                    "would_update_locales": localization_changes["would_update"],
                    "unchanged_locales": localization_changes["unchanged"],
                }
            )
            continue

        if not args.apply_drafts:
            results.append(
                {
                    "reference_name": page["reference_name"],
                    "action": "would_create_draft",
                    "locale_count": len(page["locales"]),
                    "screen_order": page["screen_order"],
                }
            )
            continue

        response = client.request(
            "POST",
            "/v1/appCustomProductPages",
            body=build_create_payload(
                app_id=manifest["app_id"],
                template_version_id=template["id"],
                page=page,
            ),
        )
        resource = response["data"]
        version = ensure_draft_version(client, resource["id"])
        existing_locales = localization_resources(client, version["id"])
        localization_changes = synchronize_localizations(
            client,
            version_id=version["id"],
            configured_locales=page_locales(page),
            existing_locales=existing_locales,
            apply=True,
        )
        results.append(
            {
                "reference_name": page["reference_name"],
                "action": "created_draft",
                "id": resource["id"],
                "url": resource.get("attributes", {}).get("url"),
                "created_locales": localization_changes["created"],
                "updated_locales": localization_changes["updated"],
            }
        )

    report = {
        "mode": "apply_drafts" if args.apply_drafts else "dry_run",
        "app_id": manifest["app_id"],
        "template_version": template,
        "results": results,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        f"mode={report['mode']} template={template['version']} "
        f"create={sum(result['action'] in {'created_draft', 'would_create_draft'} for result in results)} "
        f"update={sum(result['action'] in {'updated_existing_draft', 'would_update_existing_draft'} for result in results)} "
        f"skip={sum(result['action'] == 'skipped_existing' for result in results)}"
    )
    print(f"report={args.output}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AppStoreConnectError, OSError, ValueError, KeyError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
