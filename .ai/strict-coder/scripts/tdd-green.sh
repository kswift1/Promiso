#!/usr/bin/env bash
set -euo pipefail

# Layer 2: TDD Green Phase
# Red 상태를 확인한 뒤 테스트를 실행하고 통과를 확인한다.
# 사용법: ./tdd-green.sh
# .tdd-state의 manifest_path와 test_args를 사용해 cargo test를 직접 실행한다.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/.tdd-state"

# .tdd-state 존재 확인
if [ ! -f "$STATE_FILE" ]; then
    echo "ERROR: .tdd-state 파일이 없습니다. 먼저 tdd-red.sh 를 실행하세요." >&2
    exit 1
fi

PHASE=$(jq -r '.phase' "$STATE_FILE")
RED_COMPLETE=$(jq -r '.red_complete' "$STATE_FILE")
MANIFEST_PATH=$(jq -r '.manifest_path' "$STATE_FILE")
TEST_ARGS=$(jq -r '.test_args' "$STATE_FILE")

# Red 상태 확인
if [ "$PHASE" != "red" ]; then
    echo "ERROR: 현재 phase=$PHASE. Red 상태에서만 Green으로 진행할 수 있습니다." >&2
    exit 1
fi

if [ "$RED_COMPLETE" != "true" ]; then
    echo "ERROR: Red가 완료되지 않았습니다. tdd-red.sh 를 먼저 실행하세요." >&2
    exit 1
fi

echo "🟢 Green Phase: 테스트 실행 중..."
echo "  명령: cargo test --manifest-path $MANIFEST_PATH $TEST_ARGS"
echo ""

# eval 없이 직접 실행 — 셸 인젝션 방지
# shellcheck disable=SC2086
TEST_OUTPUT=$(cargo test --manifest-path "$MANIFEST_PATH" $TEST_ARGS 2>&1) || true
FAILED_COUNT=$(echo "$TEST_OUTPUT" | grep -c "FAILED" || echo "0")

echo "$TEST_OUTPUT"
echo ""

if [ "$FAILED_COUNT" -gt "0" ]; then
    echo "ERROR: ${FAILED_COUNT}개 테스트가 여전히 실패합니다. 구현을 완성하세요." >&2
    exit 1
fi

# .tdd-state 갱신
UPDATED=$(jq \
    --arg phase "green" \
    --arg green_complete "true" \
    --arg last_green_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '. + {
        phase: $phase,
        green_complete: ($green_complete == "true"),
        last_green_at: $last_green_at
    }' "$STATE_FILE")

echo "$UPDATED" > "$STATE_FILE"

echo "✅ Green 확인 완료: 모든 테스트 통과"
echo "  상태 기록: $STATE_FILE"
echo "  다음 단계: 커밋 가능"
