#!/bin/bash

# Git Hooks 설치 스크립트
# pre-commit hook을 .git/hooks/에 복사합니다.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"

echo "📦 Installing Git Hooks..."
echo ""

# .git/hooks 디렉토리 확인
if [ ! -d "$HOOKS_DIR" ]; then
  echo "❌ Error: .git/hooks directory not found"
  echo "Make sure you're in a Git repository."
  exit 1
fi

# pre-commit hook 복사
cp "$SCRIPT_DIR/hooks/pre-commit" "$HOOKS_DIR/pre-commit"
chmod +x "$HOOKS_DIR/pre-commit"
echo "✅ pre-commit hook installed"

# pre-push hook 복사
cp "$SCRIPT_DIR/hooks/pre-push" "$HOOKS_DIR/pre-push"
chmod +x "$HOOKS_DIR/pre-push"
echo "✅ pre-push hook installed"

echo ""
echo "🎉 Git Hooks installation complete!"
echo ""
echo "📌 pre-commit: 커밋 시 민감한 파일 체크"
echo "  - .xcconfig, GoogleService-Info.plist, .env, API Keys, Derived 폴더"
echo ""
echo "📌 pre-push: push 시 변경 모듈 빌드 검증"
echo "  - 기본: 빌드만 (PROMISO_CHECK_MODE=build)"
echo "  - 테스트 포함: PROMISO_CHECK_MODE=test git push"
echo "  - 우회: git push --no-verify"
echo ""
echo "📝 Hook 위치: .git/hooks/pre-commit, .git/hooks/pre-push"
echo ""
