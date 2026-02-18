#!/bin/bash

# xcconfig 파일 자동 생성 스크립트
# GitHub Actions에서 Secrets를 환경변수로 받아 xcconfig 파일 생성
# 로컬에서는 .env 파일 또는 환경변수에서 읽음

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$PROJECT_ROOT/Config"

echo "🔧 xcconfig 파일 생성 중..."

# Config 디렉토리 생성 (없을 경우)
mkdir -p "$CONFIG_DIR"

# 환경 변수 존재 여부 확인 함수
check_env_var() {
  local var_name="$1"
  if [ -z "${!var_name}" ]; then
    echo "❌ 환경변수 $var_name 가 설정되지 않았습니다."
    return 1
  fi
  return 0
}

# Dev.xcconfig 생성
generate_dev_config() {
  echo "📝 Dev.xcconfig 생성 중..."

  check_env_var "GOOGLE_CLIENT_ID_DEV" || return 1
  check_env_var "GOOGLE_REVERSED_CLIENT_ID_DEV" || return 1
  check_env_var "KAKAO_NATIVE_APP_KEY_DEV" || return 1

  cat > "$CONFIG_DIR/Dev.xcconfig" <<EOF
// Dev Environment Configuration
// 자동 생성됨 - 수동 편집 금지
// iOS 앱에 필요한 키만 포함 (KAKAO_REST_API_KEY, NOTION_API_KEY는 Firebase Functions 전용)

GOOGLE_CLIENT_ID = ${GOOGLE_CLIENT_ID_DEV}
GOOGLE_REVERSED_CLIENT_ID = ${GOOGLE_REVERSED_CLIENT_ID_DEV}
KAKAO_NATIVE_APP_KEY = ${KAKAO_NATIVE_APP_KEY_DEV}
DEEPLINK_SCHEME = ${DEEPLINK_SCHEME_DEV:-promiso-dev}
DEEPLINK_WEB_HOST = ${DEEPLINK_WEB_HOST_DEV:-dev.promiso.app}
CLARITY_PROJECT_ID = ${CLARITY_PROJECT_ID}

// Code Signing (Automatic - Fastlane Match 사용)
CODE_SIGN_STYLE = Automatic
EOF

  echo "✅ Dev.xcconfig 생성 완료"
}

# Stage.xcconfig 생성
generate_stage_config() {
  echo "📝 Stage.xcconfig 생성 중..."

  check_env_var "GOOGLE_CLIENT_ID_STAGE" || return 1
  check_env_var "GOOGLE_REVERSED_CLIENT_ID_STAGE" || return 1
  check_env_var "KAKAO_NATIVE_APP_KEY_STAGE" || return 1

  cat > "$CONFIG_DIR/Stage.xcconfig" <<EOF
// Stage Environment Configuration
// 자동 생성됨 - 수동 편집 금지
// iOS 앱에 필요한 키만 포함 (KAKAO_REST_API_KEY, NOTION_API_KEY는 Firebase Functions 전용)

GOOGLE_CLIENT_ID = ${GOOGLE_CLIENT_ID_STAGE}
GOOGLE_REVERSED_CLIENT_ID = ${GOOGLE_REVERSED_CLIENT_ID_STAGE}
KAKAO_NATIVE_APP_KEY = ${KAKAO_NATIVE_APP_KEY_STAGE}
DEEPLINK_SCHEME = ${DEEPLINK_SCHEME_STAGE:-promiso-stage}
DEEPLINK_WEB_HOST = ${DEEPLINK_WEB_HOST_STAGE:-stage.promiso.app}
CLARITY_PROJECT_ID = ${CLARITY_PROJECT_ID}

// Code Signing (Automatic - Fastlane Match 사용)
CODE_SIGN_STYLE = Automatic
EOF

  echo "✅ Stage.xcconfig 생성 완료"
}

# Prod.xcconfig 생성
generate_prod_config() {
  echo "📝 Prod.xcconfig 생성 중..."

  check_env_var "GOOGLE_CLIENT_ID_PROD" || return 1
  check_env_var "GOOGLE_REVERSED_CLIENT_ID_PROD" || return 1
  check_env_var "KAKAO_NATIVE_APP_KEY_PROD" || return 1

  cat > "$CONFIG_DIR/Prod.xcconfig" <<EOF
// Production Environment Configuration
// 자동 생성됨 - 수동 편집 금지
// iOS 앱에 필요한 키만 포함 (KAKAO_REST_API_KEY, NOTION_API_KEY는 Firebase Functions 전용)

GOOGLE_CLIENT_ID = ${GOOGLE_CLIENT_ID_PROD}
GOOGLE_REVERSED_CLIENT_ID = ${GOOGLE_REVERSED_CLIENT_ID_PROD}
KAKAO_NATIVE_APP_KEY = ${KAKAO_NATIVE_APP_KEY_PROD}
DEEPLINK_SCHEME = ${DEEPLINK_SCHEME_PROD:-promiso}
DEEPLINK_WEB_HOST = ${DEEPLINK_WEB_HOST_PROD:-promiso.app}
CLARITY_PROJECT_ID = ${CLARITY_PROJECT_ID}

// Code Signing (Automatic - Fastlane Match 사용)
CODE_SIGN_STYLE = Automatic
EOF

  echo "✅ Prod.xcconfig 생성 완료"
}

# .env 파일에서 환경변수 로드 (로컬 개발용)
load_env_file() {
  local env_file="$PROJECT_ROOT/.env"

  if [ -f "$env_file" ]; then
    echo "📂 .env 파일에서 환경변수 로드 중..."
    set -a
    source "$env_file"
    set +a
    echo "✅ .env 파일 로드 완료"
  else
    echo "ℹ️  .env 파일이 없습니다. 환경변수를 직접 사용합니다."
  fi
}

# 메인 실행
main() {
  # 로컬 환경이면 .env 파일 로드 시도
  if [ "${CI:-false}" != "true" ]; then
    load_env_file
  fi

  # TARGET_ENV 환경변수가 있으면 해당 환경만 생성
  if [ -n "${TARGET_ENV}" ]; then
    echo "🎯 타겟 환경: ${TARGET_ENV}"
    case "${TARGET_ENV}" in
      dev)
        generate_dev_config || exit 1
        echo "🎉 Dev.xcconfig 생성 완료!"
        ;;
      stage)
        generate_stage_config || exit 1
        echo "🎉 Stage.xcconfig 생성 완료!"
        ;;
      prod)
        generate_prod_config || exit 1
        echo "🎉 Prod.xcconfig 생성 완료!"
        ;;
      *)
        echo "❌ 알 수 없는 환경: ${TARGET_ENV}"
        echo "   사용 가능한 환경: dev, stage, prod"
        exit 1
        ;;
    esac
    return 0
  fi

  # TARGET_ENV가 없으면 모든 환경 생성 (로컬 개발용)
  echo "🎯 모든 환경의 xcconfig 생성 시도..."
  local has_error=false

  if ! generate_dev_config; then
    has_error=true
  fi

  if ! generate_stage_config; then
    has_error=true
  fi

  if ! generate_prod_config; then
    has_error=true
  fi

  if [ "$has_error" = true ]; then
    echo ""
    echo "❌ 일부 xcconfig 파일 생성에 실패했습니다."
    echo "   필요한 환경변수를 확인하세요."
    exit 1
  fi

  echo ""
  echo "🎉 모든 xcconfig 파일 생성 완료!"
  echo "   생성된 파일:"
  echo "   - $CONFIG_DIR/Dev.xcconfig"
  echo "   - $CONFIG_DIR/Stage.xcconfig"
  echo "   - $CONFIG_DIR/Prod.xcconfig"
}

main "$@"
