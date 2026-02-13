#!/bin/bash

# ============================================================================
# 변경 모듈 감지 → 빌드/테스트 실행 스크립트
# ============================================================================
#
# 사용법:
#   ./scripts/run-changed-tests.sh [--build-only | --build-and-test]
#
# 환경변수:
#   PROMISO_CHECK_MODE=build       빌드만 (기본값)
#   PROMISO_CHECK_MODE=test        빌드 + 테스트
#   PROMISO_BASE_BRANCH=main       비교 기준 브랜치 (기본: origin/main)
#
# 종료 코드:
#   0  성공 (또는 변경 모듈 없음)
#   1  빌드/테스트 실패
#
# ============================================================================

set -euo pipefail

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 설정
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# CLI 인자 처리
CHECK_MODE="${PROMISO_CHECK_MODE:-build}"
BASE_BRANCH="${PROMISO_BASE_BRANCH:-origin/main}"

for arg in "$@"; do
  case "$arg" in
    --build-only)    CHECK_MODE="build" ;;
    --build-and-test) CHECK_MODE="test" ;;
    --base=*)        BASE_BRANCH="${arg#--base=}" ;;
    *)               echo "⚠️  Unknown option: $arg"; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# 시뮬레이터 destination
DESTINATION="platform=iOS Simulator,name=iPhone 16,OS=18.3.1"

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 모듈 매핑 함수
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

# 파일 경로 → 모듈 이름 매핑
path_to_module() {
  local file="$1"

  case "$file" in
    Projects/Shared/Sources/*|Projects/Shared/Resources/*)
      echo "PromisoShared"
      ;;
    Projects/Clients/Sources/*|Projects/Clients/Resources/*)
      echo "Clients"
      ;;
    Projects/Features/*/Sources/*|Projects/Features/*/Resources/*)
      # Projects/Features/HomeFeature/Sources/... → HomeFeature
      local feature_dir
      feature_dir=$(echo "$file" | sed -n 's|Projects/Features/\([^/]*\)/.*|\1|p')
      echo "$feature_dir"
      ;;
    *)
      # 테스트 파일 자체의 변경은 해당 모듈로 매핑
      case "$file" in
        Projects/Shared/Tests/*)
          echo "PromisoShared"
          ;;
        Projects/Clients/Tests/*)
          echo "Clients"
          ;;
        Projects/Features/*/Tests/*)
          local feature_dir
          feature_dir=$(echo "$file" | sed -n 's|Projects/Features/\([^/]*\)/.*|\1|p')
          echo "$feature_dir"
          ;;
        *)
          # 매핑 불가 (App, ResourceKit, Tuist 설정 등)
          echo ""
          ;;
      esac
      ;;
  esac
}

# 모듈 이름 → 테스트 타겟 이름 매핑
module_to_test_target() {
  local module="$1"
  echo "$module"
}

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 변경 파일 감지
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "🔍 변경된 Swift 파일 감지 중..."
echo "   기준: $BASE_BRANCH"
echo ""

# staged + unstaged + untracked 중 .swift 파일만
CHANGED_FILES=$(git diff --name-only "$BASE_BRANCH"..HEAD -- '*.swift' 2>/dev/null || true)

# 커밋되지 않은 변경도 포함
UNCOMMITTED=$(git diff --name-only -- '*.swift' 2>/dev/null || true)
STAGED=$(git diff --cached --name-only -- '*.swift' 2>/dev/null || true)

ALL_CHANGED=$(echo -e "$CHANGED_FILES\n$UNCOMMITTED\n$STAGED" | sort -u | grep -v '^$' || true)

if [ -z "$ALL_CHANGED" ]; then
  echo "✅ 변경된 Swift 파일이 없습니다."
  exit 0
fi

echo "📝 변경된 파일 ($(echo "$ALL_CHANGED" | wc -l | tr -d ' ')개):"
echo "$ALL_CHANGED" | sed 's/^/   /'
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 모듈 추출 + 의존성 전파
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

MODULES=""

while IFS= read -r file; do
  module=$(path_to_module "$file")
  if [ -n "$module" ]; then
    # 중복 방지: 이미 포함되어 있지 않으면 추가
    if ! echo "$MODULES" | grep -qx "$module"; then
      MODULES="${MODULES}${MODULES:+$'\n'}${module}"
    fi
  fi
done <<< "$ALL_CHANGED"

# 의존성 전파: Shared 변경 → Clients도 체크
if echo "$MODULES" | grep -qx "PromisoShared"; then
  echo "📦 PromisoShared 변경 감지 → Clients도 체크 대상에 추가"
  if ! echo "$MODULES" | grep -qx "Clients"; then
    MODULES="${MODULES}${MODULES:+$'\n'}Clients"
  fi
fi

if [ -z "$MODULES" ]; then
  echo "✅ 빌드/테스트 대상 모듈이 없습니다. (App/설정 파일만 변경)"
  exit 0
fi

SORTED_MODULES=($(echo "$MODULES" | sort))

echo "🎯 대상 모듈 (${#SORTED_MODULES[@]}개):"
for m in "${SORTED_MODULES[@]}"; do
  echo "   - $m"
done
echo ""
echo "📋 모드: $CHECK_MODE"
echo ""

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 빌드 / 테스트 실행
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

FAILED=()

for module in "${SORTED_MODULES[@]}"; do
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "🔨 빌드: $module"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if ! xcodebuild build-for-testing \
    -scheme "$module" \
    -workspace Promiso.xcworkspace \
    -destination "$DESTINATION" \
    -skipPackagePluginValidation 2>&1; then
    echo "❌ 빌드 실패: $module"
    FAILED+=("$module (빌드)")
    continue
  fi

  echo "✅ 빌드 성공: $module"

  if [ "$CHECK_MODE" = "test" ]; then
    echo ""
    echo "🧪 테스트: $module"

    if ! xcodebuild test \
      -scheme "$module" \
      -workspace Promiso.xcworkspace \
      -destination "$DESTINATION" \
      -skipPackagePluginValidation 2>&1; then
      echo "❌ 테스트 실패: $module"
      FAILED+=("$module (테스트)")
      continue
    fi

    echo "✅ 테스트 성공: $module"
  fi

  echo ""
done

# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
# 결과 요약
# ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ ${#FAILED[@]} -gt 0 ]; then
  echo "❌ 실패한 모듈:"
  for f in "${FAILED[@]}"; do
    echo "   - $f"
  done
  echo ""
  echo "💡 push를 강제하려면: git push --no-verify"
  exit 1
else
  echo "✅ 모든 모듈 검증 통과! (${#SORTED_MODULES[@]}개 모듈)"
fi
