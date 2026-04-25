#!/usr/bin/env bash
set -euo pipefail

# Layer 2: TDD 사이클 초기화
# .tdd-state 를 삭제하고 새 사이클을 시작할 수 있게 한다.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
STATE_FILE="$PROJECT_ROOT/.tdd-state"

if [ ! -f "$STATE_FILE" ]; then
    echo "📋 TDD 상태: 이미 초기화됨 (파일 없음)"
    exit 0
fi

PHASE=$(jq -r '.phase' "$STATE_FILE")
GREEN_COMPLETE=$(jq -r '.green_complete' "$STATE_FILE")

# green 완료 전 초기화 시 경고
if [ "$PHASE" = "red" ] && [ "$GREEN_COMPLETE" != "true" ]; then
    echo "⚠️  경고: Red 상태에서 초기화합니다. Green을 완료하지 않은 사이클이 버려집니다."
    echo "  계속하려면 Enter, 취소하려면 Ctrl+C"
    read -r
fi

rm "$STATE_FILE"
echo "✅ TDD 상태 초기화 완료. 새 사이클을 시작할 수 있습니다."
echo "  다음 단계: tdd-red.sh 실행"
