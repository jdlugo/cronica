#!/usr/bin/env bash
set -euo pipefail

: "${POSTHOG_API_TOKEN:?Set POSTHOG_API_TOKEN (use the project personal token starting with phx_).}"
: "${POSTHOG_PROJECT_REF:=@current}"
POSTHOG_BASE_URL="${POSTHOG_BASE_URL:-https://us.posthog.com}"
DAYS=${POSTHOG_DAYS_BACK:-30}
TOP_LIMIT=${TOP_LIMIT:-25}

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

api_call() {
  curl --silent --show-error --fail \
    --retry 4 \
    --retry-all-errors \
    --retry-delay 1 \
    -H "Authorization: Bearer ${POSTHOG_API_TOKEN}" \
    -H 'Content-Type: application/json' \
    "$@"
}

run_query_json() {
  local query="$1"
  local payload
  payload=$(jq -cn --arg q "$query" '{query:{kind:"HogQLQuery",query:$q}}')
  api_call -X POST "${POSTHOG_BASE_URL}/api/projects/${POSTHOG_PROJECT_REF}/query/" --data "$payload"
}

run_query() {
  local label="$1"
  local query="$2"
  printf '\n== %s ==\n' "$label"
  run_query_json "$query"
}

run_query_pretty() {
  local label="$1"
  local query="$2"
  printf '\n== %s ==\n' "$label"
  run_query_json "$query" | jq '.'
}

get_count() {
  local query="$1"
  local result
  result=$(run_query_json "$query")
  echo "$result" | jq -r '(.results // [])[0][0] // 0'
}

get_count_by_event() {
  local event="$1"
  get_count "SELECT count() AS total FROM events WHERE timestamp >= now() - INTERVAL ${DAYS} DAY AND event = '${event}'"
}

PROJECT_JSON=$(api_call "${POSTHOG_BASE_URL}/api/projects/${POSTHOG_PROJECT_REF}/")
PROJECT_ID=$(echo "$PROJECT_JSON" | jq -r '.id // "unknown"')
PROJECT_NAME=$(echo "$PROJECT_JSON" | jq -r '.name // "unknown"')

cat <<INFO
Project: ${PROJECT_NAME} (id=${PROJECT_ID})

== Health Checks ==
GET /api/projects/${POSTHOG_PROJECT_REF}/
$(echo "$PROJECT_JSON" | jq '{id,name,uuid,timezone}')
INFO

TOTAL_30D=$(get_count "SELECT count() AS total FROM events WHERE timestamp >= now() - INTERVAL ${DAYS} DAY")
TOP_EVENTS=$(run_query_json "SELECT event, count() AS total FROM events WHERE timestamp >= now() - INTERVAL ${DAYS} DAY GROUP BY event ORDER BY total DESC LIMIT ${TOP_LIMIT}")
GUESSING_EVENTS=$(run_query_json "SELECT event, count() AS total FROM events WHERE (event ILIKE '%guess%' OR event ILIKE '%puzzle%' OR event ILIKE '%ad%') AND timestamp >= now() - INTERVAL ${DAYS} DAY GROUP BY event ORDER BY total DESC LIMIT ${TOP_LIMIT}")

printf '\n== Totals ==\nAll events in last %s days: %s\n' "$DAYS" "$TOTAL_30D"
printf '\n== Top Events ==\n'
echo "$TOP_EVENTS" | jq '.'
printf '\n== Guessing/Ads related ==\n'
echo "$GUESSING_EVENTS" | jq '.'

printf '\n== Daily puzzle + ad event primitive counts ==\n'
for required in \
  daily_puzzle_guess_submitted \
  daily_puzzle_hint_unlocked \
  daily_puzzle_solved \
  daily_puzzle_failed \
  daily_puzzle_ad_opportunity \
  daily_puzzle_prompt_shown \
  daily_puzzle_prompt_response \
  daily_puzzle_opened \
  daily_puzzle_share_tapped \
  daily_puzzle_next_tapped \
  daily_puzzle_next_loaded \
  daily_puzzle_reminders_toggle_changed \
  daily_puzzle_open_requested \
  daily_puzzle_session_started \
  daily_puzzle_session_ended \
  daily_puzzle_run_started \
  daily_puzzle_run_completed \
  daily_puzzle_run_shared \
  daily_puzzle_run_continue_tapped \
  daily_puzzle_weekly_goal_updated \
  daily_puzzle_hint_offer_shown \
  daily_puzzle_hint_offer_tapped \
  daily_puzzle_hint_reward_granted \
  ad_interstitial_load \
  ad_interstitial_engagement \
  ad_interstitial_present \
  ad_interstitial_dismiss \
  ad_interstitial_impression \
  ad_interstitial_click \
  ad_rewarded_load \
  ad_rewarded_present \
  ad_rewarded_dismiss \
  ad_rewarded_impression \
  ad_rewarded_click \
  ad_hint_present \
  ad_hint_dismiss \
  ad_hint_waiting_for_inventory \
  ad_hint_interstitial_presented \
  ad_hint_rewarded_presented \
  ad_app_open_load \
  ad_app_open_present \
  ad_app_open_dismiss \
  ad_app_open_impression \
  ad_app_open_click; do
  c=$(get_count_by_event "$required")
  printf '%-35s %s\n' "$required:" "$c"
done

run_query_pretty "Daily puzzle entry volume by source and build (last ${DAYS} days)" "
SELECT
  properties.app_version AS app_version,
  properties.build_number AS build_number,
  event,
  properties.source AS source,
  count() AS total_events,
  uniq(distinct_id) AS unique_users
FROM events
WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
  AND event IN ('daily_puzzle_open_requested', 'daily_puzzle_opened')
GROUP BY app_version, build_number, event, source
ORDER BY app_version DESC, build_number DESC, total_events DESC"

run_query_pretty "Daily puzzle strict session funnel by build (last ${DAYS} days)" "
SELECT
  app_version,
  build_number,
  countIf(has_opened) AS opened_sessions,
  countIf(has_opened AND has_started) AS started_sessions,
  countIf(has_opened AND has_started AND has_guess) AS guessing_sessions,
  countIf(has_opened AND has_started AND has_guess AND has_terminal) AS terminal_sessions,
  if(opened_sessions = 0, 0.0, started_sessions / opened_sessions * 100) AS open_to_start_pct,
  if(started_sessions = 0, 0.0, guessing_sessions / started_sessions * 100) AS start_to_guess_pct,
  if(guessing_sessions = 0, 0.0, terminal_sessions / guessing_sessions * 100) AS guess_to_terminal_pct
FROM (
  SELECT
    properties.app_version AS app_version,
    properties.build_number AS build_number,
    toString(properties.runtime_session_id) AS runtime_session_id,
    countIf(event = 'daily_puzzle_opened') > 0 AS has_opened,
    countIf(event = 'daily_puzzle_session_started') > 0 AS has_started,
    countIf(event = 'daily_puzzle_guess_submitted') > 0 AS has_guess,
    countIf(event IN ('daily_puzzle_solved', 'daily_puzzle_failed')) > 0 AS has_terminal
  FROM events
  WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
    AND properties.runtime_session_id IS NOT NULL
    AND toString(properties.runtime_session_id) != ''
  GROUP BY app_version, build_number, runtime_session_id
)
GROUP BY app_version, build_number
ORDER BY app_version DESC, build_number DESC"

run_query_pretty "Three-round Daily Run funnel by build (last ${DAYS} days)" "
SELECT
  app_version,
  build_number,
  countIf(has_started) AS runs_started,
  countIf(has_started AND has_completed) AS runs_completed,
  countIf(has_started AND has_completed AND has_shared) AS completed_runs_shared,
  countIf(has_started AND has_completed AND has_continued) AS completed_runs_continued,
  if(runs_started = 0, 0.0, runs_completed / runs_started * 100) AS run_completion_pct,
  if(runs_completed = 0, 0.0, completed_runs_shared / runs_completed * 100) AS run_share_pct,
  if(runs_completed = 0, 0.0, completed_runs_continued / runs_completed * 100) AS run_continue_pct
FROM (
  SELECT
    properties.app_version AS app_version,
    properties.build_number AS build_number,
    distinct_id,
    toString(properties.run_sequence) AS run_sequence,
    countIf(event = 'daily_puzzle_run_started') > 0 AS has_started,
    countIf(event = 'daily_puzzle_run_completed') > 0 AS has_completed,
    countIf(event = 'daily_puzzle_run_shared') > 0 AS has_shared,
    countIf(event = 'daily_puzzle_run_continue_tapped') > 0 AS has_continued
  FROM events
  WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
    AND event IN (
      'daily_puzzle_run_started',
      'daily_puzzle_run_completed',
      'daily_puzzle_run_shared',
      'daily_puzzle_run_continue_tapped'
    )
    AND properties.run_sequence IS NOT NULL
  GROUP BY app_version, build_number, distinct_id, run_sequence
)
GROUP BY app_version, build_number
ORDER BY app_version DESC, build_number DESC"

run_query_pretty "Weekly Movie Goal outcomes by build (last ${DAYS} days)" "
SELECT
  properties.app_version AS app_version,
  properties.build_number AS build_number,
  properties.outcome AS outcome,
  count() AS updates,
  uniq(distinct_id) AS unique_users
FROM events
WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
  AND event = 'daily_puzzle_weekly_goal_updated'
GROUP BY app_version, build_number, outcome
ORDER BY app_version DESC, build_number DESC, updates DESC"

run_query_pretty "Contextual rewarded-hint funnel by build (last ${DAYS} days)" "
SELECT
  app_version,
  build_number,
  countIf(has_offer) AS offered_puzzles,
  countIf(has_offer AND has_tap) AS tapped_puzzles,
  countIf(has_offer AND has_tap AND has_reward) AS rewarded_puzzles,
  countIf(has_offer AND has_tap AND has_reward AND has_solve) AS rewarded_solved_puzzles,
  if(offered_puzzles = 0, 0.0, tapped_puzzles / offered_puzzles * 100) AS offer_tap_pct,
  if(tapped_puzzles = 0, 0.0, rewarded_puzzles / tapped_puzzles * 100) AS reward_delivery_pct,
  if(rewarded_puzzles = 0, 0.0, rewarded_solved_puzzles / rewarded_puzzles * 100) AS reward_assisted_solve_pct
FROM (
  SELECT
    properties.app_version AS app_version,
    properties.build_number AS build_number,
    distinct_id,
    toString(properties.puzzle_id) AS puzzle_id,
    countIf(event = 'daily_puzzle_hint_offer_shown') > 0 AS has_offer,
    countIf(event = 'daily_puzzle_hint_offer_tapped') > 0 AS has_tap,
    countIf(event = 'daily_puzzle_hint_reward_granted') > 0 AS has_reward,
    countIf(event = 'daily_puzzle_solved') > 0 AS has_solve
  FROM events
  WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
    AND event IN (
      'daily_puzzle_hint_offer_shown',
      'daily_puzzle_hint_offer_tapped',
      'daily_puzzle_hint_reward_granted',
      'daily_puzzle_solved'
    )
    AND properties.puzzle_id IS NOT NULL
  GROUP BY app_version, build_number, distinct_id, puzzle_id
)
GROUP BY app_version, build_number
ORDER BY app_version DESC, build_number DESC"

run_query_pretty "Prompt engagement funnel (last ${DAYS} days)" "
SELECT
  opened,
  prompt_shown,
  prompt_response,
  if(opened = 0, 0.0, prompt_shown / opened * 100) AS prompt_show_rate_pct,
  if(prompt_shown = 0, 0.0, prompt_response / prompt_shown * 100) AS prompt_response_rate_pct
FROM (
  SELECT
    countIf(event = 'daily_puzzle_opened') AS opened,
    countIf(event = 'daily_puzzle_prompt_shown') AS prompt_shown,
    countIf(event = 'daily_puzzle_prompt_response') AS prompt_response
  FROM events
  WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
)"

run_query_pretty "Interstitial ad conversion health (last ${DAYS} days)" "
SELECT
  interstitial_load_requested,
  interstitial_load_loaded,
  interstitial_present_attempted,
  interstitial_present_presented,
  interstitial_impression,
  interstitial_click,
  if(interstitial_load_requested = 0, 0.0, interstitial_load_loaded / interstitial_load_requested * 100) AS fill_rate_pct,
  if(interstitial_load_loaded = 0, 0.0, interstitial_present_attempted / interstitial_load_loaded * 100) AS present_attempt_per_load_pct,
  if(interstitial_present_presented = 0, 0.0, interstitial_impression / interstitial_present_presented * 100) AS impression_per_present_pct,
  if(interstitial_impression = 0, 0.0, interstitial_click / interstitial_impression * 100) AS click_per_impression_pct
FROM (
  SELECT
    countIf(event = 'ad_interstitial_load' AND properties.outcome = 'requested') AS interstitial_load_requested,
    countIf(event = 'ad_interstitial_load' AND properties.outcome = 'loaded') AS interstitial_load_loaded,
    countIf(event = 'ad_interstitial_present' AND properties.outcome = 'attempted') AS interstitial_present_attempted,
    countIf(event = 'ad_interstitial_present' AND properties.outcome = 'presented') AS interstitial_present_presented,
    countIf(event = 'ad_interstitial_impression' AND properties.outcome = 'recorded') AS interstitial_impression,
    countIf(event = 'ad_interstitial_click' AND properties.outcome = 'recorded') AS interstitial_click
  FROM events
  WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
)"

run_query_pretty "Rewarded ad conversion health (last ${DAYS} days)" "
SELECT
  rewarded_load_requested,
  rewarded_load_loaded,
  rewarded_present_attempted,
  rewarded_present_presented,
  rewarded_impression,
  rewarded_click,
  rewarded_dismiss,
  if(rewarded_load_requested = 0, 0.0, rewarded_load_loaded / rewarded_load_requested * 100) AS fill_rate_pct,
  if(rewarded_load_loaded = 0, 0.0, rewarded_present_attempted / rewarded_load_loaded * 100) AS present_attempt_per_load_pct,
  if(rewarded_present_presented = 0, 0.0, rewarded_impression / rewarded_present_presented * 100) AS impression_per_present_pct,
  if(rewarded_impression = 0, 0.0, rewarded_click / rewarded_impression * 100) AS click_per_impression_pct
FROM (
  SELECT
    countIf(event = 'ad_rewarded_load' AND properties.outcome = 'requested') AS rewarded_load_requested,
    countIf(event = 'ad_rewarded_load' AND properties.outcome = 'loaded') AS rewarded_load_loaded,
    countIf(event = 'ad_rewarded_present' AND properties.outcome = 'attempted') AS rewarded_present_attempted,
    countIf(event = 'ad_rewarded_present' AND properties.outcome = 'presented') AS rewarded_present_presented,
    countIf(event = 'ad_rewarded_impression' AND properties.outcome = 'recorded') AS rewarded_impression,
    countIf(event = 'ad_rewarded_click' AND properties.outcome = 'recorded') AS rewarded_click,
    countIf(event = 'ad_rewarded_dismiss' AND properties.outcome = 'dismissed') AS rewarded_dismiss
  FROM events
  WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
)"

run_query_pretty "Hint flow telemetry split (last ${DAYS} days)" "
SELECT
  hint_present_attempted,
  hint_present_rewarded,
  hint_present_interstitial,
  hint_waiting_for_inventory,
  hint_dismiss_interstitial,
  hint_interstitial_presented,
  hint_rewarded_presented,
  hint_dismiss_total
FROM (
  SELECT
    countIf(event = 'ad_hint_present' AND properties.outcome = 'attempted') AS hint_present_attempted,
    countIf(event = 'ad_hint_present' AND properties.outcome = 'rewarded_presented') AS hint_present_rewarded,
    countIf(event = 'ad_hint_present' AND properties.outcome = 'interstitial_presented') AS hint_present_interstitial,
    countIf(event = 'ad_hint_waiting_for_inventory' AND properties.outcome = 'waiting_for_inventory') AS hint_waiting_for_inventory,
    countIf(event = 'ad_hint_dismiss' AND properties.outcome = 'interstitial_dismissed') AS hint_dismiss_interstitial,
    countIf(event = 'ad_hint_interstitial_presented' AND properties.outcome = 'interstitial_presented') AS hint_interstitial_presented,
    countIf(event = 'ad_hint_rewarded_presented' AND properties.outcome = 'rewarded_presented') AS hint_rewarded_presented,
    countIf(event = 'ad_hint_dismiss' AND properties.outcome = 'interstitial_dismissed') AS hint_dismiss_total
  FROM events
  WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
)"

run_query_pretty "App-open presentation efficiency (last ${DAYS} days)" "
SELECT
  present_attempted,
  present_presented,
  blocked_cooldown,
  blocked_session_limit,
  no_inventory,
  impressions,
  clicks,
  if(present_attempted = 0, 0.0, impressions / present_attempted * 100) AS impression_per_attempt_pct,
  if(impressions = 0, 0.0, clicks / impressions * 100) AS click_per_impression_pct
FROM (
  SELECT
    countIf(event = 'ad_app_open_present' AND properties.outcome = 'attempted') AS present_attempted,
    countIf(event = 'ad_app_open_present' AND properties.outcome = 'presented') AS present_presented,
    countIf(event = 'ad_app_open_present' AND properties.outcome = 'cooldown') AS blocked_cooldown,
    countIf(event = 'ad_app_open_present' AND properties.outcome = 'session_limit_reached') AS blocked_session_limit,
    countIf(event = 'ad_app_open_present' AND properties.outcome = 'no_inventory') AS no_inventory,
    countIf(event = 'ad_app_open_impression' AND properties.outcome = 'recorded') AS impressions,
    countIf(event = 'ad_app_open_click' AND properties.outcome = 'recorded') AS clicks
  FROM events
  WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
)"

run_query_pretty "App-open outcomes by source and block reason (last ${DAYS} days)" "
SELECT
  properties.source AS source,
  properties.outcome AS outcome,
  properties.block_reason AS block_reason,
  count() AS total
FROM events
WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
  AND event = 'ad_app_open_present'
GROUP BY source, outcome, block_reason
ORDER BY total DESC"

run_query_pretty "Interstitial outcomes by placement context (last ${DAYS} days)" "
SELECT
  properties.source AS source,
  properties.trigger AS trigger,
  properties.flow AS flow,
  properties.outcome AS outcome,
  properties.block_reason AS block_reason,
  count() AS total
FROM events
WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
  AND event = 'ad_interstitial_present'
GROUP BY source, trigger, flow, outcome, block_reason
ORDER BY total DESC"

run_query_pretty "Release health by app version and build (last ${DAYS} days)" "
SELECT
  properties.app_version AS app_version,
  properties.build_number AS build_number,
  uniq(distinct_id) AS unique_users,
  countIf(event IN ('Application Opened', 'app_launched')) AS launches,
  countIf(event = 'daily_puzzle_opened') AS puzzle_opens,
  countIf(event = 'daily_puzzle_solved') AS puzzle_solves,
  countIf(event IN ('ad_interstitial_impression', 'ad_rewarded_impression', 'ad_app_open_impression')) AS ad_impressions
FROM events
WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
GROUP BY app_version, build_number
ORDER BY app_version DESC, build_number DESC"

run_query_pretty "Consent eligibility by build (last ${DAYS} days)" "
SELECT
  properties.app_version AS app_version,
  properties.build_number AS build_number,
  properties.outcome AS outcome,
  count() AS total,
  uniq(distinct_id) AS unique_users
FROM events
WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
  AND event = 'ad_startup_eligibility_evaluated'
GROUP BY app_version, build_number, outcome
ORDER BY app_version DESC, build_number DESC, total DESC"

run_query_pretty "Puzzle depth and monetization by build (last ${DAYS} days)" "
SELECT
  app_version,
  build_number,
  unique_users,
  puzzle_sessions,
  completed_rounds,
  next_taps,
  next_loads,
  native_opportunities,
  puzzle_interstitial_opportunities,
  puzzle_interstitial_impressions,
  if(puzzle_sessions = 0, 0.0, completed_rounds / puzzle_sessions) AS rounds_per_session,
  if(completed_rounds = 0, 0.0, next_taps / completed_rounds * 100) AS continuation_rate_pct,
  if(next_taps = 0, 0.0, next_loads / next_taps * 100) AS continuation_load_rate_pct,
  if(puzzle_sessions = 0, 0.0, puzzle_interstitial_impressions / puzzle_sessions) AS interstitial_impressions_per_puzzle_session
FROM (
  SELECT
    properties.app_version AS app_version,
    properties.build_number AS build_number,
    uniq(distinct_id) AS unique_users,
    uniqIf(properties.runtime_session_id, event = 'daily_puzzle_session_started') AS puzzle_sessions,
    countIf(event IN ('daily_puzzle_solved', 'daily_puzzle_failed')) AS completed_rounds,
    countIf(event = 'daily_puzzle_next_tapped') AS next_taps,
    countIf(event = 'daily_puzzle_next_loaded') AS next_loads,
    countIf(event = 'daily_puzzle_ad_opportunity' AND properties.placement = 'native_puzzle') AS native_opportunities,
    countIf(event = 'ad_interstitial_engagement' AND properties.trigger = 'puzzle_completed' AND properties.outcome = 'presenting') AS puzzle_interstitial_opportunities,
    countIf(event = 'ad_interstitial_impression' AND properties.trigger = 'puzzle_completed') AS puzzle_interstitial_impressions
  FROM events
  WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
  GROUP BY app_version, build_number
)
ORDER BY app_version DESC, build_number DESC"

run_query_pretty "Puzzle interstitial decisions by build (last ${DAYS} days)" "
SELECT
  properties.app_version AS app_version,
  properties.build_number AS build_number,
  event,
  properties.outcome AS outcome,
  properties.block_reason AS block_reason,
  count() AS total,
  uniq(distinct_id) AS unique_users
FROM events
WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
  AND properties.trigger = 'puzzle_completed'
  AND event IN ('ad_interstitial_engagement', 'ad_interstitial_present', 'ad_interstitial_impression', 'ad_interstitial_dismiss')
GROUP BY app_version, build_number, event, outcome, block_reason
ORDER BY app_version DESC, build_number DESC, total DESC"

run_query_pretty "International telemetry property coverage by build (last ${DAYS} days)" "
SELECT
  app_version,
  build_number,
  total_events,
  app_locale_events,
  device_region_events,
  content_region_events,
  if(total_events = 0, 0.0, app_locale_events / total_events * 100) AS app_locale_coverage_pct,
  if(total_events = 0, 0.0, device_region_events / total_events * 100) AS device_region_coverage_pct,
  if(total_events = 0, 0.0, content_region_events / total_events * 100) AS content_region_coverage_pct
FROM (
  SELECT
    properties.app_version AS app_version,
    properties.build_number AS build_number,
    count() AS total_events,
    countIf(properties.app_locale IS NOT NULL AND toString(properties.app_locale) != '') AS app_locale_events,
    countIf(properties.device_region IS NOT NULL AND toString(properties.device_region) != '') AS device_region_events,
    countIf(properties.content_region IS NOT NULL AND toString(properties.content_region) != '') AS content_region_events
  FROM events
  WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
    AND properties.app_version IS NOT NULL
  GROUP BY app_version, build_number
)
ORDER BY app_version DESC, build_number DESC"

run_query_pretty "Target-territory activation and monetization signals (last ${DAYS} days)" "
SELECT
  territory,
  app_version,
  build_number,
  uniq(distinct_id) AS unique_users,
  uniqIf(distinct_id, event IN ('Application Opened', 'app_launched')) AS launched_users,
  uniqIf(distinct_id, event = 'daily_puzzle_opened') AS puzzle_opened_users,
  uniqIf(distinct_id, event = 'daily_puzzle_guess_submitted') AS puzzle_activated_users,
  uniqIf(distinct_id, event = 'daily_puzzle_solved') AS puzzle_solved_users,
  countIf(event IN ('ad_interstitial_impression', 'ad_rewarded_impression', 'ad_app_open_impression')) AS ad_impressions,
  if(launched_users = 0, 0.0, puzzle_opened_users / launched_users * 100) AS launch_to_puzzle_open_pct,
  if(puzzle_opened_users = 0, 0.0, puzzle_activated_users / puzzle_opened_users * 100) AS puzzle_activation_pct,
  if(puzzle_activated_users = 0, 0.0, puzzle_solved_users / puzzle_activated_users * 100) AS activated_to_solved_pct,
  if(unique_users = 0, 0.0, ad_impressions / unique_users) AS ad_impressions_per_user
FROM (
  SELECT
    upper(coalesce(
      nullIf(toString(properties.device_region), ''),
      nullIf(toString(properties.\$geoip_country_code), ''),
      'UNKNOWN'
    )) AS territory,
    properties.app_version AS app_version,
    properties.build_number AS build_number,
    distinct_id,
    event
  FROM events
  WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
)
WHERE territory IN ('FR', 'ES', 'MX', 'BR', 'US', 'CN')
GROUP BY territory, app_version, build_number
ORDER BY territory, app_version DESC, build_number DESC"

run_query_pretty "Target-territory locale and content-region alignment (last ${DAYS} days)" "
SELECT
  upper(toString(properties.device_region)) AS device_region,
  toString(properties.app_locale) AS app_locale,
  upper(toString(properties.content_region)) AS content_region,
  count() AS total_events,
  uniq(distinct_id) AS unique_users
FROM events
WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
  AND upper(toString(properties.device_region)) IN ('FR', 'ES', 'MX', 'BR', 'US', 'CN')
  AND properties.app_locale IS NOT NULL
  AND properties.content_region IS NOT NULL
GROUP BY device_region, app_locale, content_region
ORDER BY device_region, unique_users DESC, total_events DESC"

run_query_pretty "Daily Puzzle localization coverage by build (last ${DAYS} days)" "
SELECT
  properties.app_version AS app_version,
  properties.build_number AS build_number,
  properties.puzzle_locale AS puzzle_locale,
  properties.puzzle_localization_source AS puzzle_localization_source,
  count() AS total_events,
  uniq(distinct_id) AS unique_users
FROM events
WHERE timestamp >= now() - INTERVAL ${DAYS} DAY
  AND event LIKE 'daily_puzzle_%'
GROUP BY app_version, build_number, puzzle_locale, puzzle_localization_source
ORDER BY app_version DESC, build_number DESC, total_events DESC"
