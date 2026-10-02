#!/usr/bin/env python3
"""Prepare or submit configured custom product pages for App Review."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from sync_custom_product_pages import (
    API_BASE_URL,
    AppStoreConnectClient,
    AppStoreConnectError,
    first_env,
    load_local_env,
    load_manifest,
    version_key,
)


DEFAULT_OUTPUT = Path(".build/international-growth/custom-product-page-submission.json")
ACTIVE_SUBMISSION_STATES = {
    "READY_FOR_REVIEW",
    "WAITING_FOR_REVIEW",
    "IN_REVIEW",
    "UNRESOLVED_ISSUES",
    "CANCELING",
    "COMPLETING",
}
EDITABLE_PAGE_STATES = {"PREPARE_FOR_SUBMISSION", "READY_FOR_REVIEW"}
SUBMITTED_PAGE_STATES = {"WAITING_FOR_REVIEW", "IN_REVIEW", "ACCEPTED", "APPROVED"}


def configured_client(base_url: str) -> AppStoreConnectClient:
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
    if not key_path.exists():
        raise ValueError(f"App Store Connect private key not found: {key_path}")
    return AppStoreConnectClient(
        key_id=key_id,
        issuer_id=issuer_id,
        private_key_path=key_path,
        base_url=base_url,
    )


def review_submission_create_payload(app_id: str) -> dict[str, Any]:
    return {
        "data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}}
            },
        }
    }


def review_item_create_payload(
    submission_id: str, page_version_id: str
) -> dict[str, Any]:
    return {
        "data": {
            "type": "reviewSubmissionItems",
            "relationships": {
                "reviewSubmission": {
                    "data": {"type": "reviewSubmissions", "id": submission_id}
                },
                "appCustomProductPageVersion": {
                    "data": {
                        "type": "appCustomProductPageVersions",
                        "id": page_version_id,
                    }
                },
            },
        }
    }


def review_submission_submit_payload(submission_id: str) -> dict[str, Any]:
    return {
        "data": {
            "type": "reviewSubmissions",
            "id": submission_id,
            "attributes": {"submitted": True},
        }
    }


def related_id(resource: dict[str, Any], relationship: str) -> str | None:
    data = resource.get("relationships", {}).get(relationship, {}).get("data")
    return data.get("id") if data else None


def review_items(
    client: AppStoreConnectClient, submission_id: str
) -> list[dict[str, Any]]:
    return client.get_all(
        f"/v1/reviewSubmissions/{submission_id}/items",
        params={
            "fields[reviewSubmissionItems]": (
                "appStoreVersion,appCustomProductPageVersion"
            ),
            "include": "appStoreVersion,appCustomProductPageVersion",
            "limit": 50,
        },
    )


def active_submissions(
    client: AppStoreConnectClient, app_id: str
) -> list[dict[str, Any]]:
    return [
        resource
        for resource in client.get_all(
            f"/v1/apps/{app_id}/reviewSubmissions",
            params={
                "fields[reviewSubmissions]": "platform,state,submittedDate",
                "limit": 50,
            },
        )
        if resource.get("attributes", {}).get("state") in ACTIVE_SUBMISSION_STATES
    ]


def target_page_versions(
    client: AppStoreConnectClient, manifest: dict[str, Any]
) -> list[dict[str, str]]:
    pages = client.get_all(
        f"/v1/apps/{manifest['app_id']}/appCustomProductPages",
        params={"fields[appCustomProductPages]": "name", "limit": 200},
    )
    pages_by_name = {
        page.get("attributes", {}).get("name"): page for page in pages
    }
    targets: list[dict[str, str]] = []
    for configured_page in manifest["pages"]:
        name = configured_page["reference_name"]
        page = pages_by_name.get(name)
        if page is None:
            raise ValueError(f"Missing custom product page: {name}")
        versions = client.get_all(
            f"/v1/appCustomProductPages/{page['id']}/appCustomProductPageVersions",
            params={
                "fields[appCustomProductPageVersions]": "version,state",
                "limit": 200,
            },
        )
        if not versions:
            raise ValueError(f"Custom product page has no version: {name}")
        version = max(
            versions,
            key=lambda item: version_key(
                item.get("attributes", {}).get("version", "0")
            ),
        )
        targets.append(
            {
                "reference_name": name,
                "page_id": page["id"],
                "version_id": version["id"],
                "version": version.get("attributes", {}).get("version", ""),
                "state": version.get("attributes", {}).get("state", ""),
            }
        )
    return targets


def item_only_ready_submissions(
    submissions: list[dict[str, Any]],
    items_by_submission: dict[str, list[dict[str, Any]]],
) -> list[dict[str, Any]]:
    return [
        submission
        for submission in submissions
        if submission.get("attributes", {}).get("state") == "READY_FOR_REVIEW"
        and not any(
            related_id(item, "appStoreVersion")
            for item in items_by_submission.get(submission["id"], [])
        )
    ]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("fastlane/custom_product_pages/manifest-v2.json"),
    )
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--base-url", default=API_BASE_URL)
    parser.add_argument(
        "--prepare",
        action="store_true",
        help="Create or reuse an item-only review submission and attach the pages.",
    )
    parser.add_argument(
        "--submit",
        action="store_true",
        help="Prepare the submission and send it to App Review.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    apply = args.prepare or args.submit
    manifest = load_manifest(args.manifest)
    client = configured_client(args.base_url)
    targets = target_page_versions(client, manifest)
    target_ids = {target["version_id"] for target in targets}

    submissions = active_submissions(client, manifest["app_id"])
    items_by_submission = {
        submission["id"]: review_items(client, submission["id"])
        for submission in submissions
    }
    linked_submission_ids = {
        submission_id
        for submission_id, items in items_by_submission.items()
        if any(related_id(item, "appCustomProductPageVersion") in target_ids for item in items)
    }
    if len(linked_submission_ids) > 1:
        raise ValueError("Target custom pages are split across multiple active submissions")

    submission = None
    if linked_submission_ids:
        submission_id = next(iter(linked_submission_ids))
        submission = next(item for item in submissions if item["id"] == submission_id)
    else:
        candidates = item_only_ready_submissions(submissions, items_by_submission)
        if len(candidates) > 1:
            raise ValueError("Multiple item-only draft submissions are available")
        submission = candidates[0] if candidates else None

    submission_action = "reused" if submission else "would_create"
    if submission is None and apply:
        response = client.request(
            "POST",
            "/v1/reviewSubmissions",
            body=review_submission_create_payload(manifest["app_id"]),
        )
        submission = response["data"]
        submissions.append(submission)
        items_by_submission[submission["id"]] = []
        submission_action = "created"

    submission_id = submission["id"] if submission else None
    submission_state = (
        submission.get("attributes", {}).get("state") if submission else None
    )
    if submission_state and submission_state != "READY_FOR_REVIEW":
        linked_ids = {
            related_id(item, "appCustomProductPageVersion")
            for item in items_by_submission.get(submission_id, [])
        }
        if not target_ids.issubset(linked_ids):
            raise ValueError(
                f"Submission {submission_id} is {submission_state} and cannot accept missing pages"
            )

    existing_ids = {
        related_id(item, "appCustomProductPageVersion")
        for item in items_by_submission.get(submission_id, [])
    }
    item_results: list[dict[str, str]] = []
    for target in targets:
        version_id = target["version_id"]
        if version_id in existing_ids or target["state"] in SUBMITTED_PAGE_STATES:
            item_results.append(
                {"reference_name": target["reference_name"], "action": "already_attached"}
            )
            continue
        if target["state"] not in EDITABLE_PAGE_STATES:
            raise ValueError(
                f"{target['reference_name']} is not reviewable from state {target['state']}"
            )
        if not apply:
            item_results.append(
                {"reference_name": target["reference_name"], "action": "would_attach"}
            )
            continue
        client.request(
            "POST",
            "/v1/reviewSubmissionItems",
            body=review_item_create_payload(submission_id, version_id),
        )
        existing_ids.add(version_id)
        item_results.append(
            {"reference_name": target["reference_name"], "action": "attached"}
        )

    submitted = False
    would_submit = args.submit and not apply
    if args.submit:
        if submission_state not in {None, "READY_FOR_REVIEW"}:
            submitted = submission_state in {"WAITING_FOR_REVIEW", "IN_REVIEW"}
        elif target_ids.issubset(existing_ids):
            client.request(
                "PATCH",
                f"/v1/reviewSubmissions/{submission_id}",
                body=review_submission_submit_payload(submission_id),
            )
            submitted = True
        else:
            raise ValueError("Not all custom pages are attached to the review submission")

    report = {
        "mode": "submit" if args.submit else "prepare" if args.prepare else "dry_run",
        "app_id": manifest["app_id"],
        "targets": targets,
        "submission": {
            "id": submission_id,
            "state": submission_state,
            "action": submission_action,
            "would_submit": would_submit,
            "submitted": submitted,
        },
        "items": item_results,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        f"mode={report['mode']} submission={submission_action} "
        f"attach={sum(item['action'] in {'attached', 'would_attach'} for item in item_results)} "
        f"submitted={submitted}"
    )
    print(f"report={args.output}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (AppStoreConnectError, OSError, ValueError, KeyError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
