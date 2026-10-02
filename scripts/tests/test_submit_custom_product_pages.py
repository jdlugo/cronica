import importlib.util
import sys
from pathlib import Path


SCRIPT_PATH = Path(__file__).parents[1] / "submit_custom_product_pages.py"
sys.path.insert(0, str(SCRIPT_PATH.parent))
SPEC = importlib.util.spec_from_file_location("submit_custom_product_pages", SCRIPT_PATH)
MODULE = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(MODULE)


def test_review_submission_create_payload_links_app():
    assert MODULE.review_submission_create_payload("app-id") == {
        "data": {
            "type": "reviewSubmissions",
            "attributes": {"platform": "IOS"},
            "relationships": {
                "app": {"data": {"type": "apps", "id": "app-id"}}
            },
        }
    }


def test_review_item_payload_links_submission_and_custom_page_version():
    payload = MODULE.review_item_create_payload("submission-id", "page-version-id")

    assert payload["data"]["type"] == "reviewSubmissionItems"
    assert payload["data"]["relationships"]["reviewSubmission"]["data"] == {
        "type": "reviewSubmissions",
        "id": "submission-id",
    }
    assert payload["data"]["relationships"]["appCustomProductPageVersion"][
        "data"
    ] == {"type": "appCustomProductPageVersions", "id": "page-version-id"}


def test_review_submission_submit_payload_sets_submitted():
    assert MODULE.review_submission_submit_payload("submission-id") == {
        "data": {
            "type": "reviewSubmissions",
            "id": "submission-id",
            "attributes": {"submitted": True},
        }
    }


def test_related_id_handles_present_and_null_relationships():
    resource = {
        "relationships": {
            "appCustomProductPageVersion": {
                "data": {"type": "appCustomProductPageVersions", "id": "version-id"}
            },
            "appStoreVersion": {"data": None},
        }
    }

    assert MODULE.related_id(resource, "appCustomProductPageVersion") == "version-id"
    assert MODULE.related_id(resource, "appStoreVersion") is None


def test_item_only_ready_submissions_excludes_app_version_submission():
    submissions = [
        {"id": "app", "attributes": {"state": "READY_FOR_REVIEW"}},
        {"id": "items", "attributes": {"state": "READY_FOR_REVIEW"}},
        {"id": "waiting", "attributes": {"state": "WAITING_FOR_REVIEW"}},
    ]
    items = {
        "app": [
            {
                "relationships": {
                    "appStoreVersion": {
                        "data": {"type": "appStoreVersions", "id": "version-id"}
                    }
                }
            }
        ],
        "items": [],
        "waiting": [],
    }

    assert MODULE.item_only_ready_submissions(submissions, items) == [submissions[1]]
