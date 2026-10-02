import importlib.util
from pathlib import Path
import tempfile

from PIL import Image


SCRIPT_PATH = Path(__file__).resolve().parents[1] / "export_screenshots_for_fastlane.py"
SPEC = importlib.util.spec_from_file_location("export_screenshots_for_fastlane", SCRIPT_PATH)
exporter = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(exporter)


def test_app_store_device_dimensions_are_explicit():
    assert exporter.DEVICE_MAP["iPhone_6-9in_1320x2868"][1:] == (1320, 2868)
    assert exporter.DEVICE_MAP["iPad_13in_2064x2752"][1:] == (2064, 2752)


def test_prepare_png_resizes_and_removes_alpha():
    with tempfile.TemporaryDirectory() as temp_dir:
        path = Path(temp_dir) / "screenshot.png"
        Image.new("RGBA", (10, 20), (255, 0, 0, 64)).save(path)
        exporter.prepare_png(str(path), 20, 40)
        with Image.open(path) as prepared:
            assert prepared.size == (20, 40)
            assert prepared.mode == "RGB"
