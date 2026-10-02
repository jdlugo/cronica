#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="${ROOT_DIR}/Shared/Configuration/AdConfiguration.swift"

if [[ ! -f "${CONFIG_FILE}" ]]; then
  printf "❌ Ad configuration file not found: %s\n" "${CONFIG_FILE}" >&2
  exit 1
fi

extract_ad_unit_id() {
  local key="$1"
  local line

  line="$(rg "static let ${key}[[:space:]]*=[[:space:]]*\"" "${CONFIG_FILE}" | head -n1 || true)"
  if [[ -z "${line}" ]]; then
    return 1
  fi

  sed -E 's/.*"([^"]+)".*/\1/' <<<"${line}"
}

is_google_test_id() {
  local id="$1"
  case "${id}" in
    "ca-app-pub-3940256099942544/2934735716"|\
    "ca-app-pub-3940256099942544/4411468910"|\
    "ca-app-pub-3940256099942544/1712485313"|\
    "ca-app-pub-3940256099942544/3986624511"|\
    "ca-app-pub-3940256099942544/6300978111")
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

required_keys=(native interstitial rewarded appOpen)
failed=0
parsed_ids=()
parsed_keys=()

printf "Checking AdMob unit IDs in %s\n" "${CONFIG_FILE}"
for key in "${required_keys[@]}"; do
  if ! ad_unit_id="$(extract_ad_unit_id "${key}")"; then
    printf "❌ Could not parse ad unit ID for '%s'\n" "${key}" >&2
    failed=1
    continue
  fi

  if [[ -z "${ad_unit_id}" ]]; then
    printf "❌ Ad unit ID for '%s' is empty\n" "${key}" >&2
    failed=1
    continue
  fi

  if is_google_test_id "${ad_unit_id}"; then
    printf "❌ '%s' uses Google TEST ad unit ID: %s\n" "${key}" "${ad_unit_id}" >&2
    failed=1
    continue
  fi

  duplicate_key=""
  for i in "${!parsed_ids[@]}"; do
    if [[ "${parsed_ids[$i]}" == "${ad_unit_id}" ]]; then
      duplicate_key="${parsed_keys[$i]}"
      break
    fi
  done
  if [[ -n "${duplicate_key}" ]]; then
    printf "❌ '%s' reuses ad unit ID already assigned to '%s': %s\n" "${key}" "${duplicate_key}" "${ad_unit_id}" >&2
    failed=1
    continue
  fi
  parsed_ids+=("${ad_unit_id}")
  parsed_keys+=("${key}")

  printf "✅ %s: %s\n" "${key}" "${ad_unit_id}"
done

if [[ "${failed}" -ne 0 ]]; then
  cat <<'EOF' >&2

Release gate failed: one or more ad units are missing or still in test mode.
Update Shared/Configuration/AdConfiguration.swift with production IDs before shipping.
EOF
  exit 1
fi

printf "\n✅ Release ad-unit gate passed.\n"
