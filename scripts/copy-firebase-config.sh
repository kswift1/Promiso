#!/bin/bash

# GoogleService-Info.plist 파일을 Config 폴더에서 Resources 폴더로 복사
# Config 폴더를 Google Drive에서 다운받은 후 실행

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$PROJECT_ROOT/Config"
APP_DIR="$PROJECT_ROOT/Projects/App"

echo "🔧 GoogleService-Info.plist 파일 복사 중..."

# 파일 존재 확인 함수
check_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "❌ 파일을 찾을 수 없습니다: $file"
    return 1
  fi
  return 0
}

# Dev 환경
echo "📝 Dev 환경 설정 중..."
if check_file "$CONFIG_DIR/GoogleService-Info-Dev.plist"; then
  cp "$CONFIG_DIR/GoogleService-Info-Dev.plist" \
     "$APP_DIR/Resources-Dev/GoogleService-Info.plist"
  echo "✅ Dev GoogleService-Info.plist 복사 완료"
else
  echo "⚠️  Dev plist 파일을 건너뜁니다"
fi

# Stage 환경
echo "📝 Stage 환경 설정 중..."
if check_file "$CONFIG_DIR/GoogleService-Info-Stage.plist"; then
  cp "$CONFIG_DIR/GoogleService-Info-Stage.plist" \
     "$APP_DIR/Resources-Stage/GoogleService-Info.plist"
  echo "✅ Stage GoogleService-Info.plist 복사 완료"
else
  echo "⚠️  Stage plist 파일을 건너뜁니다"
fi

# Prod 환경
echo "📝 Prod 환경 설정 중..."
if check_file "$CONFIG_DIR/GoogleService-Info-Prod.plist"; then
  cp "$CONFIG_DIR/GoogleService-Info-Prod.plist" \
     "$APP_DIR/Resources-Prod/GoogleService-Info.plist"
  echo "✅ Prod GoogleService-Info.plist 복사 완료"
else
  echo "⚠️  Prod plist 파일을 건너뜁니다"
fi

echo ""
echo "🎉 Firebase 설정 파일 복사 완료!"
echo ""
echo "다음 단계:"
echo "  1. tuist generate"
echo "  2. tuist build PromisoDev"
