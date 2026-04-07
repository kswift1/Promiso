#!/usr/bin/env bash
set -euo pipefail

# strict-coder 설치 스크립트
# 사용법: curl -sSL https://raw.githubusercontent.com/{user}/strict-coder/main/install.sh | bash
#    또는: ./.ai/strict-coder/install.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "📦 strict-coder 설치 중..."
echo "  프로젝트: $PROJECT_ROOT"
echo ""

# 1. git hooks 경로 설정
echo "1/4 — git hooks 경로 설정"
cd "$PROJECT_ROOT"
git config core.hooksPath .ai/strict-coder/hooks/
echo "  ✅ core.hooksPath → .ai/strict-coder/hooks/"

# 2. Claude Code settings.json 에 PreToolUse 훅 추가
echo "2/4 — Claude Code 훅 등록"
SETTINGS_FILE="$PROJECT_ROOT/.claude/settings.json"

if [ -f "$SETTINGS_FILE" ]; then
    # hooks 키가 이미 있는지 확인
    HAS_HOOKS=$(jq 'has("hooks")' "$SETTINGS_FILE")
    if [ "$HAS_HOOKS" = "true" ]; then
        echo "  ⏭️  .claude/settings.json 에 hooks 이미 존재 (스킵)"
    else
        # hooks 추가
        UPDATED=$(jq '. + {
            "hooks": {
                "PreToolUse": [
                    {
                        "matcher": "Edit|Write|MultiEdit",
                        "hooks": [
                            {
                                "type": "command",
                                "command": "bash \"$CLAUDE_PROJECT_DIR/.ai/strict-coder/hooks/tdd-gate.sh\"",
                                "timeout": 10
                            }
                        ]
                    }
                ]
            }
        }' "$SETTINGS_FILE")
        echo "$UPDATED" > "$SETTINGS_FILE"
        echo "  ✅ PreToolUse 훅 등록 완료"
    fi
else
    mkdir -p "$PROJECT_ROOT/.claude"
    cat > "$SETTINGS_FILE" << 'SETTINGS_EOF'
{
    "hooks": {
        "PreToolUse": [
            {
                "matcher": "Edit|Write|MultiEdit",
                "hooks": [
                    {
                        "type": "command",
                        "command": "bash \"$CLAUDE_PROJECT_DIR/.ai/strict-coder/hooks/tdd-gate.sh\"",
                        "timeout": 10
                    }
                ]
            }
        ]
    }
}
SETTINGS_EOF
    echo "  ✅ .claude/settings.json 생성 + 훅 등록 완료"
fi

# 3. .gitignore 에 .tdd-state 추가
echo "3/4 — .gitignore 설정"
GITIGNORE="$PROJECT_ROOT/.gitignore"

if [ -f "$GITIGNORE" ]; then
    if grep -q ".tdd-state" "$GITIGNORE"; then
        echo "  ⏭️  .tdd-state 이미 등록됨 (스킵)"
    else
        echo "" >> "$GITIGNORE"
        echo "# TDD State (strict-coder)" >> "$GITIGNORE"
        echo ".tdd-state" >> "$GITIGNORE"
        echo "  ✅ .tdd-state 추가"
    fi
else
    echo ".tdd-state" > "$GITIGNORE"
    echo "  ✅ .gitignore 생성 + .tdd-state 추가"
fi

# 4. 스크립트 실행 권한
echo "4/4 — 실행 권한 설정"
chmod +x "$SCRIPT_DIR/scripts/"*.sh 2>/dev/null || true
chmod +x "$SCRIPT_DIR/hooks/"* 2>/dev/null || true
echo "  ✅ 실행 권한 부여 완료"

echo ""
echo "✅ strict-coder 설치 완료"
echo ""
echo "사용법:"
echo "  TDD Red:    .ai/strict-coder/scripts/tdd-red.sh --test {test_file}"
echo "  TDD Green:  .ai/strict-coder/scripts/tdd-green.sh"
echo "  TDD Status: .ai/strict-coder/scripts/tdd-status.sh"
echo "  TDD Reset:  .ai/strict-coder/scripts/tdd-reset.sh"
