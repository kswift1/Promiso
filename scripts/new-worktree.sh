#!/bin/bash
# 새 worktree 생성 및 초기 설정 자동화 스크립트

set -e  # 에러 발생 시 중단

# 색상 출력
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 Promiso 새 Worktree 생성${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# 1. 브랜치 타입 선택
echo "브랜치 타입을 선택하세요:"
echo "  1) feature/브랜치명"
echo "  2) fix/브랜치명"
echo "  3) refactor/브랜치명"
echo "  4) develop"
echo "  5) release/버전"
echo ""
read -p "선택 (1-5): " branch_type

case $branch_type in
  1) prefix="feature/" ;;
  2) prefix="fix/" ;;
  3) prefix="refactor/" ;;
  4) prefix="" ;;
  5) prefix="release/" ;;
  *) echo "잘못된 선택"; exit 1 ;;
esac

# 2. 브랜치명 입력
if [ "$prefix" != "" ]; then
  read -p "브랜치명 입력 (예: add-user-feature): " branch_name
  BRANCH="${prefix}${branch_name}"
else
  BRANCH="develop"
fi

# 3. Base 브랜치 선택
if [ "$BRANCH" != "develop" ]; then
  echo ""
  echo "Base 브랜치를 선택하세요:"
  echo "  1) develop (기본)"
  echo "  2) main"
  read -p "선택 (1-2, 기본 1): " base_choice
  
  case ${base_choice:-1} in
    1) BASE_BRANCH="develop" ;;
    2) BASE_BRANCH="main" ;;
    *) BASE_BRANCH="develop" ;;
  esac
else
  BASE_BRANCH="main"
fi

# 4. 경로 설정
MAIN_REPO="$HOME/Developer/Promiso"
WORKTREE_ROOT="$HOME/Developer/Promiso-worktrees"
WORKTREE_PATH="$WORKTREE_ROOT/$BRANCH"

echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}📋 설정 요약${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "브랜치: $BRANCH"
echo "Base: $BASE_BRANCH"
echo "경로: $WORKTREE_PATH"
echo ""
read -p "진행하시겠습니까? (y/N): " confirm

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo "취소되었습니다."
  exit 0
fi

# 5. Worktree 생성
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}1. Worktree 생성${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cd "$MAIN_REPO"
git worktree add -b "$BRANCH" "$WORKTREE_PATH" "$BASE_BRANCH"

echo -e "${GREEN}✅ Worktree 생성 완료${NC}"

# 6. Firebase 설정 (심볼릭 링크 생성)
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}2. Firebase 설정${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

cd "$WORKTREE_PATH"

# 중앙 저장소 확인
FIREBASE_CONFIG_DIR="$HOME/Developer/Promiso-Config"
if [ ! -f "$FIREBASE_CONFIG_DIR/GoogleService-Info-Dev.plist" ]; then
  echo -e "${YELLOW}⚠️  중앙 저장소에 Firebase Config 파일이 없습니다.${NC}"
  echo ""
  echo "다음 중 하나를 실행하세요:"
  echo "  1) make secrets-pull  (Notion에서 다운로드)"
  echo "  2) Firebase Console에서 수동 다운로드"
  echo ""
  echo "건너뛰고 계속합니다..."
else
  # 심볼릭 링크 생성
  for env in Dev Stage Prod; do
    LINK_PATH="$WORKTREE_PATH/Projects/App/Resources-$env/GoogleService-Info.plist"
    TARGET="$FIREBASE_CONFIG_DIR/GoogleService-Info-$env.plist"

    if [ -f "$TARGET" ]; then
      rm -f "$LINK_PATH"
      ln -s "$TARGET" "$LINK_PATH"
      echo -e "${GREEN}✅ $env: 심볼릭 링크 생성${NC}"
    fi
  done
fi

echo -e "${GREEN}✅ Firebase 설정 완료${NC}"

# 7. Tuist 의존성 설치 및 프로젝트 생성
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}3. Tuist 프로젝트 생성${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Tuist 의존성 설치
echo "📦 Tuist 의존성 설치 중..."
tuist install

# 프로젝트 생성
echo "🔨 Xcode 프로젝트 생성 중..."
tuist generate

echo -e "${GREEN}✅ Tuist 프로젝트 생성 완료${NC}"

# 8. 완료
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🎉 완료!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "다음 명령어로 Xcode를 열 수 있습니다:"
echo ""
echo "  cd $WORKTREE_PATH"
echo "  open Promiso-Workspace.xcworkspace"
echo ""
echo "또는:"
echo ""
echo "  make open"
echo ""
