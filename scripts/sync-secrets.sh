#!/bin/bash

# Notion Secrets Sync Script
# Notion에서 시크릿을 읽어와 xcconfig 파일 생성 및 GitHub Secrets 업데이트

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NOTION_API_KEY="${NOTION_API_KEY:-}"
SECRETS_DB_ID="5e30fc69caf4432da2bc1183c10960dd"
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_DIR="${PROJECT_ROOT}/Config"

# GitHub repo (for secrets update)
GITHUB_REPO="kswift1/Promiso"

print_usage() {
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  pull      Notion에서 시크릿 읽어와 xcconfig 생성"
  echo "  push-gh   GitHub Secrets 업데이트"
  echo "  list      현재 시크릿 목록 표시"
  echo "  add       새 시크릿 추가 (Notion에)"
  echo ""
  echo "Environment:"
  echo "  NOTION_API_KEY  Notion Integration API Key (required)"
}

check_notion_api_key() {
  if [ -z "$NOTION_API_KEY" ]; then
    echo -e "${RED}Error: NOTION_API_KEY 환경변수가 설정되지 않았습니다.${NC}"
    echo ""
    echo "설정 방법:"
    echo "  export NOTION_API_KEY='YOUR_NOTION_API_KEY'"
    echo ""
    echo "또는 ~/.zshrc에 추가:"
    echo "  echo 'export NOTION_API_KEY=\"YOUR_NOTION_API_KEY\"' >> ~/.zshrc"
    exit 1
  fi
}

# Notion에서 시크릿 목록 조회
fetch_secrets() {
  curl -s -X POST "https://api.notion.com/v1/databases/${SECRETS_DB_ID}/query" \
    -H "Authorization: Bearer ${NOTION_API_KEY}" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d '{}'
}

# 시크릿 목록 표시
cmd_list() {
  check_notion_api_key
  echo -e "${YELLOW}📋 Notion Secrets 목록${NC}"
  echo ""

  response=$(fetch_secrets)

  if echo "$response" | jq -e '.object == "error"' > /dev/null 2>&1; then
    echo -e "${RED}Error: $(echo "$response" | jq -r '.message')${NC}"
    exit 1
  fi

  echo "$response" | jq -r '.results[] |
    "┌─ \(.properties.Key.title[0].plain_text // "N/A")
│  Dev:   \(.properties.Dev.rich_text[0].plain_text // "-" | if length > 20 then .[0:20] + "..." else . end)
│  Stage: \(.properties.Stage.rich_text[0].plain_text // "-" | if length > 20 then .[0:20] + "..." else . end)
│  Prod:  \(.properties.Prod.rich_text[0].plain_text // "-" | if length > 20 then .[0:20] + "..." else . end)
└─"'
}

# xcconfig 파일 생성
cmd_pull() {
  check_notion_api_key
  echo -e "${YELLOW}🔄 Notion에서 시크릿 동기화 중...${NC}"

  response=$(fetch_secrets)

  if echo "$response" | jq -e '.object == "error"' > /dev/null 2>&1; then
    echo -e "${RED}Error: $(echo "$response" | jq -r '.message')${NC}"
    exit 1
  fi

  # 환경별 xcconfig 생성
  for env in Dev Stage Prod; do
    config_file="${CONFIG_DIR}/${env}.xcconfig"
    env_lower=$(echo "$env" | tr '[:upper:]' '[:lower:]')

    echo "// ${env} Environment Configuration" > "$config_file"
    echo "// 자동 생성됨 - 수동 편집 금지" >> "$config_file"
    echo "// Generated at: $(date '+%Y-%m-%d %H:%M:%S')" >> "$config_file"
    echo "" >> "$config_file"

    # iOS 앱에서 실제 사용하는 시크릿만 추출
    # KAKAO_REST_API_KEY, NOTION_API_KEY는 Firebase Functions에서만 사용
    echo "$response" | jq -r --arg env "$env" '.results[] |
      select(.properties[$env].rich_text[0].plain_text != null) |
      select(.properties.Key.title[0].plain_text | test("^(GOOGLE_CLIENT_ID|GOOGLE_REVERSED_CLIENT_ID|KAKAO_NATIVE_APP_KEY)$")) |
      "\(.properties.Key.title[0].plain_text | gsub("[\\n\\r]"; "")) = \(.properties[$env].rich_text[0].plain_text | gsub("[\\n\\r]"; " "))"' >> "$config_file"

    # Code Signing 설정 추가
    echo "" >> "$config_file"
    if [ "$env" == "Dev" ]; then
      echo "// Code Signing - Automatic (개발 환경)" >> "$config_file"
    elif [ "$env" == "Prod" ]; then
      echo "// Code Signing (Manual for Release builds)" >> "$config_file"
      echo "CODE_SIGN_STYLE = Manual" >> "$config_file"
      echo "CODE_SIGN_IDENTITY = iPhone Distribution" >> "$config_file"
      echo 'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*] = match AppStore $(PRODUCT_BUNDLE_IDENTIFIER)' >> "$config_file"
    else
      echo "// Code Signing (Manual for Release builds)" >> "$config_file"
      echo "CODE_SIGN_STYLE = Manual" >> "$config_file"
      echo "CODE_SIGN_IDENTITY[config=Release] = Apple Distribution" >> "$config_file"
      echo "CODE_SIGN_IDENTITY[config=Debug] = Apple Development" >> "$config_file"
      echo 'PROVISIONING_PROFILE_SPECIFIER[sdk=iphoneos*] = match AppStore $(PRODUCT_BUNDLE_IDENTIFIER)' >> "$config_file"
    fi

    echo "" >> "$config_file"

    echo -e "${GREEN}✅ ${config_file} 생성됨${NC}"
  done

  echo ""

  # Firebase Config 파일 다운로드
  FIREBASE_CONFIG_DIR="$HOME/Developer/Promiso-Config"
  mkdir -p "$FIREBASE_CONFIG_DIR"

  echo -e "${YELLOW}🔥 Firebase Config 다운로드 중...${NC}"

  for env in Dev Stage Prod; do
    env_upper=$(echo "$env" | tr '[:lower:]' '[:upper:]')

    # FIREBASE_CONFIG_{ENV} 키 찾기
    base64_value=$(echo "$response" | jq -r --arg key "FIREBASE_CONFIG_${env_upper}" --arg env "$env" '
      .results[] |
      select(.properties.Key.title[0].plain_text == $key) |
      .properties[$env].rich_text[0].plain_text // empty
    ')

    if [ -n "$base64_value" ]; then
      plist_file="$FIREBASE_CONFIG_DIR/GoogleService-Info-$env.plist"
      echo "$base64_value" | base64 -d > "$plist_file"
      echo -e "${GREEN}✅ $env: GoogleService-Info-$env.plist 다운로드됨${NC}"
    else
      echo -e "${YELLOW}⚠️  $env: FIREBASE_CONFIG_${env_upper} 없음 (건너뜀)${NC}"
    fi
  done

  echo ""

  # 현재 worktree에 심볼릭 링크 생성
  echo -e "${YELLOW}🔗 Firebase Config 심볼릭 링크 생성 중...${NC}"

  for env in Dev Stage Prod; do
    LINK_PATH="$PROJECT_ROOT/Projects/App/Resources-$env/GoogleService-Info.plist"
    TARGET="$FIREBASE_CONFIG_DIR/GoogleService-Info-$env.plist"

    # 타겟 파일이 존재하는 경우만 링크 생성
    if [ -f "$TARGET" ]; then
      # 기존 파일 제거
      rm -f "$LINK_PATH"

      # 심볼릭 링크 생성
      ln -s "$TARGET" "$LINK_PATH"
      echo -e "${GREEN}✅ $env: 심볼릭 링크 생성 완료${NC}"
    else
      echo -e "${YELLOW}⚠️  $env: 파일 없음 (링크 생성 건너뜀)${NC}"
    fi
  done

  echo ""
  echo -e "${GREEN}🎉 동기화 완료!${NC}"
  echo ""
  echo "✅ xcconfig 파일 생성"
  echo "✅ Firebase Config 다운로드"
  echo "✅ 심볼릭 링크 생성"
}

# GitHub Secrets 업데이트
cmd_push_gh() {
  check_notion_api_key

  # gh CLI 확인
  if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: gh CLI가 설치되지 않았습니다.${NC}"
    echo "설치: brew install gh"
    exit 1
  fi

  # gh 로그인 확인
  if ! gh auth status &> /dev/null; then
    echo -e "${RED}Error: gh에 로그인되지 않았습니다.${NC}"
    echo "로그인: gh auth login"
    exit 1
  fi

  echo -e "${YELLOW}🔄 GitHub Secrets 업데이트 중...${NC}"

  response=$(fetch_secrets)

  if echo "$response" | jq -e '.object == "error"' > /dev/null 2>&1; then
    echo -e "${RED}Error: $(echo "$response" | jq -r '.message')${NC}"
    exit 1
  fi

  # 각 시크릿을 GitHub에 업데이트
  echo "$response" | jq -c '.results[]' | while read -r row; do
    key=$(echo "$row" | jq -r '.properties.Key.title[0].plain_text // empty')

    if [ -z "$key" ]; then
      continue
    fi

    for env in Dev Stage Prod; do
      value=$(echo "$row" | jq -r --arg env "$env" '.properties[$env].rich_text[0].plain_text // empty')

      if [ -n "$value" ]; then
        secret_name="${key}_${env^^}"
        echo "  📤 ${secret_name}"
        echo "$value" | gh secret set "$secret_name" --repo "$GITHUB_REPO" 2>/dev/null || \
          echo -e "    ${YELLOW}⚠️  업데이트 실패 (권한 확인 필요)${NC}"
      fi
    done
  done

  echo ""
  echo -e "${GREEN}🎉 GitHub Secrets 업데이트 완료!${NC}"
}

# 새 시크릿 추가
cmd_add() {
  check_notion_api_key

  echo -e "${YELLOW}➕ 새 시크릿 추가${NC}"
  echo ""

  read -p "Key 이름: " key_name
  read -p "Dev 값: " dev_value
  read -p "Stage 값: " stage_value
  read -p "Prod 값: " prod_value
  read -p "설명 (선택): " description

  # Notion에 추가
  payload=$(jq -n \
    --arg db "$SECRETS_DB_ID" \
    --arg key "$key_name" \
    --arg dev "$dev_value" \
    --arg stage "$stage_value" \
    --arg prod "$prod_value" \
    --arg desc "$description" \
    '{
      parent: { database_id: $db },
      properties: {
        Key: { title: [{ text: { content: $key } }] },
        Dev: { rich_text: [{ text: { content: $dev } }] },
        Stage: { rich_text: [{ text: { content: $stage } }] },
        Prod: { rich_text: [{ text: { content: $prod } }] },
        Description: { rich_text: [{ text: { content: $desc } }] }
      }
    }')

  response=$(curl -s -X POST "https://api.notion.com/v1/pages" \
    -H "Authorization: Bearer ${NOTION_API_KEY}" \
    -H "Notion-Version: 2022-06-28" \
    -H "Content-Type: application/json" \
    -d "$payload")

  if echo "$response" | jq -e '.object == "error"' > /dev/null 2>&1; then
    echo -e "${RED}Error: $(echo "$response" | jq -r '.message')${NC}"
    exit 1
  fi

  echo ""
  echo -e "${GREEN}✅ '${key_name}' 추가됨${NC}"
  echo ""

  read -p "xcconfig 파일도 업데이트할까요? (y/n): " update_config
  if [ "$update_config" == "y" ]; then
    cmd_pull
  fi
}

# Main
case "${1:-}" in
  pull)
    cmd_pull
    ;;
  push-gh)
    cmd_push_gh
    ;;
  list)
    cmd_list
    ;;
  add)
    cmd_add
    ;;
  *)
    print_usage
    ;;
esac
