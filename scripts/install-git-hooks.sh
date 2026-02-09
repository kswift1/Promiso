#!/bin/bash

# Git Hooks 설치 스크립트
# pre-commit hook을 .git/hooks/에 복사합니다.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# worktree 환경에서도 올바른 hooks 경로를 찾기 위해 git rev-parse 사용
GIT_DIR="$(cd "$PROJECT_ROOT" && git rev-parse --git-common-dir 2>/dev/null)"
HOOKS_DIR="$GIT_DIR/hooks"

echo "📦 Installing Git Hooks..."
echo ""

# hooks 디렉토리 확인
if [ ! -d "$HOOKS_DIR" ]; then
  echo "❌ Error: Git hooks directory not found: $HOOKS_DIR"
  echo "Make sure you're in a Git repository."
  exit 1
fi

# pre-commit hook 복사
cp "$SCRIPT_DIR/hooks/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"

echo "✅ pre-commit hook installed"
echo ""
echo "🎉 Git Hooks installation complete!"
echo ""
echo "이제 커밋 시 자동으로 민감한 파일을 체크합니다:"
echo "  - .xcconfig 파일"
echo "  - GoogleService-Info.plist"
echo "  - .env 파일"
echo "  - API Keys in code"
echo "  - Derived 폴더"
echo ""
echo "📝 Hook 위치: $HOOKS_DIR/pre-commit"
echo ""
