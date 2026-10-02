# iOS Preview Video Automation

This project now supports fully automated preview video generation using Swift XCTest scenarios plus Simulator recording.

## What runs

1. `PreviewVideoTests` renders deterministic SwiftUI scenario flows.
2. `scripts/record_preview_videos.py` boots the simulator, records each scenario with `simctl`, and exports optimized MP4s via `ffmpeg`.
3. Scenario metadata is centralized in:
   - `CronicaTests/Screenshots/preview_video_scenarios.json`

## Generate videos

Run all scenarios:

```bash
python3 scripts/record_preview_videos.py --output-dir fastlane/preview_videos
```

Run a single scenario:

```bash
python3 scripts/record_preview_videos.py \
  --scenario home-discovery \
  --output-dir fastlane/preview_videos
```

List available scenario IDs:

```bash
python3 scripts/record_preview_videos.py --list
```

Run via fastlane:

```bash
fastlane ios preview_videos
```

Optional fastlane flags:

```bash
fastlane ios preview_videos scenario:home-discovery
fastlane ios preview_videos udid:94D34470-35F8-474C-B62A-90D85254784D
fastlane ios preview_videos keep_raw:true
```

## Output

- Final videos: `fastlane/preview_videos/*.mp4`
- Raw captures (optional): `fastlane/preview_videos/raw/*.mov` when `--keep-raw` is used

## CI automation

- Workflow: `.github/workflows/preview-videos-ci.yml`
- Triggers:
  - Pushes that change preview automation files.
  - Manual `workflow_dispatch` runs (optional single scenario input).
  - Weekday scheduled run at `14:30 UTC`.
- Artifacts:
  - Generated videos are uploaded as `ios-preview-videos`.
