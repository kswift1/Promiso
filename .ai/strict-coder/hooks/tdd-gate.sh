#!/usr/bin/env bash
set -euo pipefail

# Layer 1: Claude Code PreToolUse Hook
# Edit/Write 도구가 infra/rust-backend/src/ 파일을 수정하려 할 때
# .tdd-state 를 확인하고 Red 완료 전이면 차단한다.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# MultiEdit 지원
if [ -z "$FILE_PATH" ]; then
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.edits[0].file_path // empty')
fi

# 경로가 없으면 통과
if [ -z "$FILE_PATH" ]; then
    exit 0
fi

# Rust 백엔드 src/ 경로가 아니면 통과
if [[ "$FILE_PATH" != *"infra/rust-backend/src/"* ]]; then
    exit 0
fi

# 테스트 파일은 통과 (Red phase에서 테스트 작성 허용)
if [[ "$FILE_PATH" == *"_test.rs" ]] || [[ "$FILE_PATH" == *"/tests/"* ]]; then
    exit 0
fi

# .tdd-state 확인
STATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.tdd-state"

# .tdd-state가 있고 red 완료면 통과
if [ -f "$STATE_FILE" ]; then
    RED_COMPLETE=$(jq -r '.red_complete // false' "$STATE_FILE")
    if [ "$RED_COMPLETE" = "true" ]; then
        exit 0
    fi
fi

# .tdd-state 없어도 통과 (pre-commit에서 cargo check로 최종 검증)

# Red 완료 상태면 통과
exit 0
