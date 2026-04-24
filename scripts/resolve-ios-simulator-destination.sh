#!/bin/bash

set -euo pipefail

SIMCTL_OUTPUT="$(xcrun simctl list devices available)"

pick_device_udid() {
  local device_name="$1"

  printf '%s\n' "$SIMCTL_OUTPUT" |
    awk -v device_name="$device_name" 'index($0, device_name " (") { print }' |
    grep -Eo '[0-9A-F-]{36}' |
    tail -n 1
}

PREFERRED_DEVICES=(
  "iPhone 16"
  "iPhone 16 Pro"
  "iPhone 16 Plus"
  "iPhone 16 Pro Max"
  "iPhone 16e"
  "iPhone 17"
  "iPhone 17 Pro"
  "iPhone 17 Pro Max"
  "iPhone 17e"
  "iPhone Air"
)

for device in "${PREFERRED_DEVICES[@]}"; do
  udid="$(pick_device_udid "$device")"
  if [ -n "$udid" ]; then
    echo "platform=iOS Simulator,id=$udid"
    exit 0
  fi
done

fallback_udid="$(
  printf '%s\n' "$SIMCTL_OUTPUT" | awk '
    /iPhone .* \(/ { print }
  ' | grep -Eo '[0-9A-F-]{36}' | tail -n 1
)"

if [ -n "$fallback_udid" ]; then
  echo "platform=iOS Simulator,id=$fallback_udid"
  exit 0
fi

echo "No available iOS Simulator devices found." >&2
exit 1
