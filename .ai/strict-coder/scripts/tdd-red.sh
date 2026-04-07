#!/usr/bin/env bash
set -euo pipefail

# Layer 2: TDD Red Phase
# 테스트를 실행하고 실패를 확인한 뒤 .tdd-state에 기록한다.
# 사용법: ./tdd-red.sh [cargo test 인수...]
# 예시:   ./tdd-red.sh --test schedule_test
#         ./tdd-red.sh --test schedule_test -- --exact test_create_schedule

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/.tdd-state"
RUST_DIR="$PROJECT_ROOT/infra/rust-backend"

if [ ! -f "$RUST_DIR/Cargo.toml" ]; then
    echo "ERROR: $RUST_DIR/Cargo.toml 이 없습니다." >&2
    exit 1
fi

# 현재 상태 확인 — green 상태면 reset 먼저 필요
if [ -f "$STATE_FILE" ]; then
    CURRENT_PHASE=$(jq -r '.phase // "none"' "$STATE_FILE")
    if [ "$CURRENT_PHASE" = "green" ]; then
        echo "ERROR: 현재 green 상태입니다. 새 사이클을 시작하려면 먼저 tdd-reset.sh 를 실행하세요." >&2
        exit 1
    fi
fi

echo "🔴 Red Phase: 테스트 실행 중..."
echo "  명령: cargo test --manifest-path $RUST_DIR/Cargo.toml $*"
echo ""

# 테스트 실행 — 실패가 예상됨
TEST_OUTPUT=$(cargo test --manifest-path "$RUST_DIR/Cargo.toml" "$@" 2>&1) || true
FAILED_COUNT=$(echo "$TEST_OUTPUT" | grep -c "FAILED" || echo "0")

echo "$TEST_OUTPUT"
echo ""

if [ "$FAILED_COUNT" -eq "0" ]; then
    echo "ERROR: 실패한 테스트가 없습니다. 먼저 실패하는 테스트를 작성하세요." >&2
    exit 1
fi

# .tdd-state 기록
jq -n \
    --arg phase "red" \
    --arg red_complete "true" \
    --arg green_complete "false" \
    --arg last_red_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg manifest_path "$RUST_DIR/Cargo.toml" \
    --arg test_args "$*" \
    --argjson failed_count "$FAILED_COUNT" \
    '{
        phase: $phase,
        red_complete: ($red_complete == "true"),
        green_complete: ($green_complete == "true"),
        last_red_at: $last_red_at,
        last_green_at: null,
        manifest_path: $manifest_path,
        test_args: $test_args,
        failed_count: $failed_count
    }' > "$STATE_FILE"

echo "✅ Red 확인 완료: ${FAILED_COUNT}개 테스트 실패"
echo "  상태 기록: $STATE_FILE"
echo "  다음 단계: 구현 후 tdd-green.sh 실행"
