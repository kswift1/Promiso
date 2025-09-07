#!/bin/bash

# add_feature_dependency.sh
# 새로 생성된 피쳐를 AppFeatureDeps.swift에 자동으로 추가하는 스크립트

set -e

# 입력값 검증
if [ -z "$1" ]; then
    echo "❌ Error: 피쳐 이름이 필요합니다."
    echo "Usage: $0 <FEATURE_NAME>"
    exit 1
fi

FEATURE_NAME="$1"
DEPS_FILE="Tuist/ProjectDescriptionHelpers/AppFeatureDeps.swift"
FEATURE_FILE="Tuist/ProjectDescriptionHelpers/FeatureFactory/Features/Features+${FEATURE_NAME}.swift"

echo "  📝 피쳐 '$FEATURE_NAME'를 의존성에 추가 중..."

# 1. Feature 확장 파일이 생성되었는지 확인
if [ ! -f "$FEATURE_FILE" ]; then
    echo "  ❌ Error: $FEATURE_FILE 파일이 존재하지 않습니다."
    echo "  tuist scaffold이 제대로 실행되지 않았을 수 있습니다."
    exit 1
fi

# 2. AppFeatureDeps.swift 파일 백업
cp "$DEPS_FILE" "$DEPS_FILE.backup"

# 3. Feature를 camelCase로 변환 (첫 글자 소문자)
FEATURE_CAMEL=$(echo "${FEATURE_NAME:0:1}" | tr '[:upper:]' '[:lower:]')$(echo "${FEATURE_NAME:1}")

# 4. 이미 추가되어 있는지 확인
if grep -q "\.$FEATURE_CAMEL" "$DEPS_FILE"; then
    echo "  ℹ️  피쳐 '$FEATURE_NAME'는 이미 의존성에 추가되어 있습니다."
    rm "$DEPS_FILE.backup"
    exit 0
fi

# 5. 새로운 피쳐를 allFeatures 배열에 추가
# .schedule 다음에 추가하도록 패턴 매칭
if ! grep -q "\.schedule" "$DEPS_FILE"; then
    echo "  ❌ Error: .schedule 피쳐를 찾을 수 없습니다. AppFeatureDeps.swift 구조가 변경되었을 수 있습니다."
    rm "$DEPS_FILE.backup"
    exit 1
fi

# sed를 사용해서 .schedule 다음에 새 피쳐 추가 (쉼표 추가)
sed -i.temp "/\.schedule$/s/$/,/" "$DEPS_FILE"
sed -i.temp "/\.schedule,/a\\
      .$FEATURE_CAMEL" "$DEPS_FILE"

# 6. 임시 파일 정리
rm "$DEPS_FILE.temp"

echo "  ✅ 피쳐 '$FEATURE_NAME'가 AppFeatureDeps.swift에 추가되었습니다."
echo "  📍 추가된 내용: .$FEATURE_CAMEL"

# 7. 변경 사항 확인용 출력
echo "  📋 현재 등록된 피쳐들:"
grep -A 10 "let allFeatures:" "$DEPS_FILE" | grep "\." | sed 's/^[ ]*/    /'

rm "$DEPS_FILE.backup"