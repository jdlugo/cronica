import importlib.util
import json
import pathlib
import struct
import sys
import tempfile
import unittest


def load_module():
    path = pathlib.Path(__file__).resolve().parents[1] / "prepare_custom_product_pages.py"
    spec = importlib.util.spec_from_file_location("prepare_custom_product_pages", path)
    if spec is None or spec.loader is None:
        raise RuntimeError("Unable to load prepare_custom_product_pages")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def write_png_header(path: pathlib.Path, width: int, height: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n" + b"\0" * 8 + struct.pack(">II", width, height)
    )


class CustomProductPagePackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.module = load_module()

    def test_package_reorders_verified_assets(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = pathlib.Path(temp_dir)
            manifest = {
                "schema_version": 1,
                "app_id": "455556959",
                "pages": [
                    {
                        "reference_name": "Puzzle",
                        "slug": "puzzle",
                        "primary_locale": {
                            "locale": "en-US",
                            "promotional_text": "Daily movie puzzle",
                        },
                        "screen_order": [
                            "HomeScreen",
                            "DetailScreen",
                            "WatchlistScreen",
                        ],
                        "locales": {
                            "fr-FR": {
                                "promotional_text": "Puzzle cinéma quotidien",
                                "keywords": ["jeu"],
                            }
                        },
                    }
                ],
            }
            manifest_path = root / "manifest.json"
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")
            screenshots = root / "screenshots"
            for locale in ("en-US", "fr-FR"):
                for screen in manifest["pages"][0]["screen_order"]:
                    for device, size in self.module.DEVICE_SIZES.items():
                        write_png_header(
                            screenshots / locale / f"01-{screen}_{device}.png",
                            *size,
                        )
            output = root / "package"
            count = self.module.prepare_package(manifest_path, screenshots, output)
            self.assertEqual(count, 12)
            package = json.loads(
                (output / "package-manifest.json").read_text(encoding="utf-8")
            )
            self.assertEqual(
                {value["locale"] for value in package["localizations"]},
                {"en-US", "fr-FR"},
            )
            french = next(
                value for value in package["localizations"]
                if value["locale"] == "fr-FR"
            )
            self.assertTrue(
                french["assets"][0].startswith("puzzle/fr-FR/01-HomeScreen")
            )

    def test_keyword_overlap_is_rejected_per_locale(self):
        manifest = {
            "schema_version": 1,
            "pages": [
                {
                    "slug": "one",
                    "screen_order": ["a", "b", "c"],
                    "locales": {
                        "fr-FR": {
                            "promotional_text": "a",
                            "keywords": ["jeu"],
                        }
                    },
                },
                {
                    "slug": "two",
                    "screen_order": ["a", "b", "c"],
                    "locales": {
                        "fr-FR": {
                            "promotional_text": "b",
                            "keywords": ["JEU"],
                        }
                    },
                },
            ],
        }
        with self.assertRaisesRegex(ValueError, "overlap"):
            self.module.validate_manifest(manifest)


if __name__ == "__main__":
    unittest.main()
