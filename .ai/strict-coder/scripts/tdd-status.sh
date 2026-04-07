#!/usr/bin/env bash
set -euo pipefail

# Layer 2: TDD 상태 확인
# 현재 .tdd-state 를 읽기 쉽게 출력한다.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/.tdd-state"

if [ ! -f "$STATE_FILE" ]; then
    echo "📋 TDD 상태: 없음 (사이클 시작 전)"
    exit 0
fi

PHASE=$(jq -r '.phase' "$STATE_FILE")
RED_COMPLETE=$(jq -r '.red_complete' "$STATE_FILE")
GREEN_COMPLETE=$(jq -r '.green_complete' "$STATE_FILE")
LAST_RED=$(jq -r '.last_red_at // "없음"' "$STATE_FILE")
LAST_GREEN=$(jq -r '.last_green_at // "없음"' "$STATE_FILE")
MANIFEST=$(jq -r '.manifest_path // "없음"' "$STATE_FILE")
TEST_ARGS=$(jq -r '.test_args // "없음"' "$STATE_FILE")
FAILED=$(jq -r '.failed_count // 0' "$STATE_FILE")

echo "📋 TDD 상태"
echo "  phase:          $PHASE"
echo "  red_complete:   $RED_COMPLETE"
echo "  green_complete: $GREEN_COMPLETE"
echo "  last_red_at:    $LAST_RED"
echo "  last_green_at:  $LAST_GREEN"
echo "  manifest_path:  $MANIFEST"
echo "  test_args:      $TEST_ARGS"
echo "  failed_count:   $FAILED"
