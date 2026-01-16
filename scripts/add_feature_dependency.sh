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
DEPS_FILE="Tuist/ProjectDescriptionHelpers/FeatureFactory/AppFeatureDeps.swift"
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

# 4. 이미 추가되어 있는지 확인 (배열 내부에서만 검색)
if awk '/let allFeatures.*\[/,/^\s*\]/ { if (/\.'$FEATURE_CAMEL'/) found=1 } END { exit !found }' "$DEPS_FILE"; then
    echo "  ℹ️  피쳐 '$FEATURE_NAME'는 이미 의존성에 추가되어 있습니다."
    rm "$DEPS_FILE.backup"
    exit 0
fi

# 5. Python 스크립트로 정확한 위치에 피쳐 추가 (인덴트/개행 유지)
python3 << EOF
import re, sys

DEPS_FILE = r'$DEPS_FILE'
FEATURE_CAMEL = r'$FEATURE_CAMEL'

with open(DEPS_FILE, 'r', encoding='utf-8') as f:
    content = f.read()

# 1) 'let allFeatures: [Feature] = [' 라인과 닫는 ']' 라인의 들여쓰기 캡쳐
#    - open_indent:  배열 여는 라인의 선행 공백
#    - items_block:  아이템들이 들어가는 블록(여는 '[' 다음 줄부터 닫는 ']' 직전까지)
#    - close_indent: 닫는 ']' 라인의 선행 공백
pattern = re.compile(
    r'^(?P<open_indent>\s*)let\s+allFeatures:\s*\[Feature\]\s*=\s*\[\s*\n'   # 여는 라인
    r'(?P<items_block>.*?)'                                                  # 아이템 영역(여러 줄)
    r'^(?P<close_indent>\s*)\]',                                             # 닫는 대괄호 라인
    re.MULTILINE | re.DOTALL
)

m = pattern.search(content)
if not m:
    print("  ❌ Error: allFeatures 배열을 찾을 수 없습니다.")
    sys.exit(1)

open_indent   = m.group('open_indent')
items_block   = m.group('items_block')
close_indent  = m.group('close_indent')

# 2) 아이템 라인의 기본 들여쓰기 계산
#    - 보통 open_indent + 2스페이스 정도가 배열 아이템 들여쓰기
item_indent = open_indent + "  "

# 3) 현재 배열 아이템 라인들을 정규화 (앞뒤 공백/빈 줄 정리)
lines = [ln for ln in items_block.splitlines()]

#   - 기존 아이템만 추출 ('.foo'로 시작하는 라인)
existing = [ln.strip() for ln in lines if ln.strip().startswith(".")]

#   - 주석/기타 라인은 따로 유지
others   = [ln for ln in lines if ln.strip() and not ln.strip().startswith(".")]

# 4) 중복 체크
needle = f".{FEATURE_CAMEL}"
if any(ln.startswith(needle) for ln in existing):
    print(f"  ℹ️  피쳐 '{FEATURE_CAMEL}'는 이미 의존성에 추가되어 있습니다.")
    sys.exit(0)

# 5) 새 배열 본문 구성
new_items = []

#    5-1) 기타 라인(주석 등) 먼저 보존
for ln in others:
    # 들여쓰기 정리: 주석 라인은 item_indent로 맞춰줌
    if ln.strip().startswith("//"):
        new_items.append(f"{item_indent}{ln.strip()}")
    else:
        # 혹시 다른 포맷이 있으면 원문을 보존하되 최소 들여쓰기만 보장
        new_items.append(f"{item_indent}{ln.strip()}")

#    5-2) 기존 아이템 보존
for ln in existing:
    # 끝에 콤마가 없다면 붙여줌 (스타일 일관성)
    if not ln.rstrip().endswith(","):
        ln = ln.rstrip() + ","
    new_items.append(f"{item_indent}{ln}")

#    5-3) 새 아이템 추가
new_items.append(f"{item_indent}.{FEATURE_CAMEL},")

#    5-4) 배열이 원래 완전히 비어 있었다면, 주석 헤더를 자동 추가
if not existing and not others:
    header = f"{item_indent}// 🤖 Auto-generated features"
    # 헤더를 첫 줄로, 그 다음 새 아이템 배치 (빈 줄 없이)
    new_items = [header, f"{item_indent}.{FEATURE_CAMEL},"]

# 6) 닫는 대괄호는 항상 개행 후 close_indent 맞춰 배치
new_block = (
    f"{open_indent}let allFeatures: [Feature] = [\n"
    + "\n".join(new_items) + "\n"
    + f"{close_indent}]"
)

# 7) 전체 내용 치환
new_content = (
    content[:m.start()] + new_block + content[m.end():]
)

with open(DEPS_FILE, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("  ✅ 성공적으로 추가되었습니다.")
EOF

if [ $? -eq 0 ]; then
    echo "  ✅ 피쳐 '$FEATURE_NAME'가 AppFeatureDeps.swift에 추가되었습니다."
    echo "  📍 추가된 내용: .$FEATURE_CAMEL"
    
    # 7. 변경 사항 확인용 출력
    echo "  📋 현재 등록된 피쳐들:"
    awk '/let allFeatures: \[Feature\] = \[/,/^    \]/ { if (/^      \.[a-zA-Z]/) print "    " $0 }' "$DEPS_FILE"
    
    rm "$DEPS_FILE.backup"
else
    echo "  ❌ 피쳐 추가에 실패했습니다. 백업에서 복구합니다."
    mv "$DEPS_FILE.backup" "$DEPS_FILE"
    exit 1
fi
