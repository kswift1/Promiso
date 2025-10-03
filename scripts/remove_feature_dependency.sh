#!/bin/bash

# remove_feature_dependency.sh
# 피쳐를 AppFeatureDeps.swift에서 제거하는 스크립트

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

echo "  📝 피쳐 '$FEATURE_NAME'를 의존성에서 제거 중..."

# 1. AppFeatureDeps.swift 파일 백업
if [ ! -f "$DEPS_FILE" ]; then
    echo "  ❌ Error: $DEPS_FILE 파일이 존재하지 않습니다."
    exit 1
fi

cp "$DEPS_FILE" "$DEPS_FILE.backup"

# 2. Feature를 camelCase로 변환 (첫 글자 소문자)
FEATURE_CAMEL=$(echo "${FEATURE_NAME:0:1}" | tr '[:upper:]' '[:lower:]')$(echo "${FEATURE_NAME:1}")

# 3. 피쳐가 의존성에 있는지 확인
if ! awk '/let allFeatures.*\[/,/\]$$$$/ { if (/\.'$FEATURE_CAMEL'/) found=1 } END { exit !found }' "$DEPS_FILE"; then
    echo "  ℹ️  피쳐 '$FEATURE_NAME'는 의존성에 없습니다."
    rm "$DEPS_FILE.backup"
    exit 0
fi

# 4. Python 스크립트로 피쳐 제거
python3 << EOF
import re, sys

DEPS_FILE = r'$DEPS_FILE'
FEATURE_CAMEL = r'$FEATURE_CAMEL'

with open(DEPS_FILE, 'r', encoding='utf-8') as f:
    content = f.read()

# allFeatures 배열 찾기
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

# 아이템 라인의 기본 들여쓰기 계산
item_indent = open_indent + "  "

# 현재 배열 아이템 라인들을 분석
lines = [ln for ln in items_block.splitlines()]

# 기존 아이템과 주석/기타 라인 분리
existing = []
others   = []

for ln in lines:
    stripped = ln.strip()
    if stripped.startswith("."):
        existing.append(stripped)
    elif stripped:  # 빈 줄이 아닌 경우
        others.append(ln)

# 제거할 피쳐 찾기 및 제거
needle = f".{FEATURE_CAMEL}"
filtered_existing = []
removed = False

for ln in existing:
    # 정확한 매칭: .featureName, 또는 .featureName, 형태
    clean_ln = ln.rstrip(',').strip()
    if clean_ln == needle:
        removed = True
        continue
    filtered_existing.append(ln)

if not removed:
    print(f"  ℹ️  피쳐 '{FEATURE_CAMEL}'를 찾을 수 없습니다.")
    sys.exit(0)

# 새 배열 본문 구성
new_items = []

# 주석/기타 라인 보존
for ln in others:
    if ln.strip().startswith("//"):
        new_items.append(f"{item_indent}{ln.strip()}")
    else:
        new_items.append(f"{item_indent}{ln.strip()}")

# 남은 아이템들 추가
for ln in filtered_existing:
    if not ln.rstrip().endswith(","):
        ln = ln.rstrip() + ","
    new_items.append(f"{item_indent}{ln}")

# 배열이 완전히 비어있다면 주석만 남김
if not filtered_existing and not others:
    new_items = [f"{item_indent}// 🤖 Auto-generated features"]

# 새 블록 생성
new_block = (
    f"{open_indent}let allFeatures: [Feature] = [\n"
    + "\n".join(new_items) + "\n"
    + f"{close_indent}]"
)

# 전체 내용 치환
new_content = (
    content[:m.start()] + new_block + content[m.end():]
)

with open(DEPS_FILE, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("  ✅ 성공적으로 제거되었습니다.")
EOF

if [ $? -eq 0 ]; then
    echo "  ✅ 피쳐 '$FEATURE_NAME'가 AppFeatureDeps.swift에서 제거되었습니다."
    
    # 변경 사항 확인용 출력
    echo "  📋 현재 등록된 피쳐들:"
    if awk '/let allFeatures: \[Feature\] = \[/,/^    \]/ { if (/^      \.[a-zA-Z]/) print "    " $0 }' "$DEPS_FILE" | grep -q "."; then
        awk '/let allFeatures: \[Feature\] = \[/,/^    \]/ { if (/^      \.[a-zA-Z]/) print "    " $0 }' "$DEPS_FILE"
    else
        echo "    (등록된 피쳐가 없습니다)"
    fi
    
    rm "$DEPS_FILE.backup"
else
    echo "  ❌ 피쳐 제거에 실패했습니다. 백업에서 복구합니다."
    mv "$DEPS_FILE.backup" "$DEPS_FILE"
    exit 1
fi