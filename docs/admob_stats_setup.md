# AdMob Stats: Repeatable Local Setup

This repo already contains:
- `scripts/pull_admob_report.py` (raw AdMob network report pull)
- `scripts/analyze_admob_weekly.py` (weekly WoW analysis)
- `scripts/run_admob_latest.sh` (wrapper added for one-command execution)

## One-time setup

1. Copy env template:
   - `cp .env.admob.local.example .env.admob.local`
2. Edit `.env.admob.local` and fill:
   - `ADMOB_CLIENT_ID`
   - `ADMOB_CLIENT_SECRET`
   - `ADMOB_REFRESH_TOKEN`

Notes:
- `.env.admob.local` is ignored by git via `.env.*`.
- Non-secret defaults (publisher/app/ad-unit IDs) are pre-filled from this repo.

## Run latest report

```bash
scripts/run_admob_latest.sh
```

Outputs:
- `docs/admob_history.csv`
- `docs/admob_weekly_report.md`

## Optional overrides

- Use custom env file:
  - `ADMOB_ENV_FILE=/path/to/.env.admob.local scripts/run_admob_latest.sh`
- Change lookback window:
  - set `ADMOB_REPORT_DAYS=30` in `.env.admob.local`
