#!/bin/bash
# Convention Check Hook for Promiso Project
# 이 스크립트는 Claude Code에서 코드 작성 후 자동으로 실행됩니다.

set -e

CHANGED_FILE="$1"

echo "🔍 컨벤션 체크 중: $CHANGED_FILE"

# Swift 파일만 체크
if [[ ! "$CHANGED_FILE" =~ \.swift$ ]]; then
  echo "✅ Swift 파일이 아님, 스킵"
  exit 0
fi

ERRORS=0
WARNINGS=0

# 1. TCA Deprecated API 체크 (Critical)
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "1. TCA Deprecated API 체크"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if grep -n "@BindingState\|\.task\s*{\|\.fireAndForget" "$CHANGED_FILE" 2>/dev/null; then
  echo "❌ Critical: TCA Deprecated API 사용됨"
  echo "   - @BindingState → @ObservableState"
  echo "   - .task { } → Effect.run { }"
  echo "   - .fireAndForget { } → Effect.run { }"
  ERRORS=$((ERRORS + 1))
else
  echo "✅ 통과"
fi

# 2. 강제 언래핑 체크 (Critical)
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "2. 강제 언래핑 체크"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if grep -n "!" "$CHANGED_FILE" 2>/dev/null | grep -v "// swiftlint:disable\|!=" | head -5; then
  echo "🟡 Warning: 강제 언래핑 발견 (guard let 또는 if let 권장)"
  WARNINGS=$((WARNINGS + 1))
else
  echo "✅ 통과"
fi

# 3. 하드코딩 색상 체크 (Warning)
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "3. 하드코딩 색상 체크"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if grep -n "Color(red:\|Color(UIColor\|\.init(red:" "$CHANGED_FILE" 2>/dev/null; then
  echo "🟡 Warning: 하드코딩 색상 발견 (Theme.swift 사용 권장)"
  WARNINGS=$((WARNINGS + 1))
else
  echo "✅ 통과"
fi

# 4. 축약 네이밍 체크 (Warning)
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "4. 축약 네이밍 체크"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if grep -n "\(btn\|lbl\|txt\|img\)" "$CHANGED_FILE" 2>/dev/null; then
  echo "🟡 Warning: 축약 네이밍 발견 (전체 단어 사용 권장)"
  WARNINGS=$((WARNINGS + 1))
else
  echo "✅ 통과"
fi

# 5. View 파일 특수 체크
if [[ "$CHANGED_FILE" =~ View\.swift$ ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "5. View 파일 체크"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Aurora Background 체크
  if ! grep -q "\.auroraBackground()" "$CHANGED_FILE" 2>/dev/null; then
    echo "🟡 Warning: Aurora Background 미적용 (주요 화면에 권장)"
    WARNINGS=$((WARNINGS + 1))
  fi

  # Glass Effect Fallback 체크
  if grep -q "\.glassEffect" "$CHANGED_FILE" 2>/dev/null; then
    if ! grep -q "#available(iOS 26" "$CHANGED_FILE" 2>/dev/null; then
      echo "❌ Critical: Glass Effect Fallback 누락"
      echo "   iOS 26 미만 분기 처리 필요"
      ERRORS=$((ERRORS + 1))
    else
      echo "✅ Glass Effect + Fallback 적용됨"
    fi
  fi
fi

# 결과 요약
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "컨벤션 체크 결과"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "파일: $CHANGED_FILE"
echo "❌ Critical: $ERRORS건"
echo "🟡 Warning: $WARNINGS건"

if [ $ERRORS -gt 0 ]; then
  echo ""
  echo "❌ Critical 에러가 있어 작업을 중단합니다."
  echo "   위의 문제를 수정한 후 다시 시도하세요."
  exit 2  # Hook 실패 (작업 중단)
fi

if [ $WARNINGS -gt 0 ]; then
  echo ""
  echo "🟡 Warning이 있지만 작업을 계속합니다."
  echo "   가능하면 수정을 권장합니다."
fi

echo ""
echo "✅ 컨벤션 체크 완료"
exit 0
