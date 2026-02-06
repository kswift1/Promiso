#!/bin/bash
# Firebase Config 파일을 base64로 인코딩 (Notion 업로드용)

set -e

CENTRAL_DIR="$HOME/Developer/Promiso-Config"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 Firebase Config Base64 인코딩"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for env in Dev Stage Prod; do
  plist_file="$CENTRAL_DIR/GoogleService-Info-$env.plist"

  if [ ! -f "$plist_file" ]; then
    echo "⚠️  $env: 파일 없음 ($plist_file)"
    continue
  fi

  env_upper=$(echo "$env" | tr '[:lower:]' '[:upper:]')

  echo "📦 $env 환경:"
  echo ""
  echo "Key: FIREBASE_CONFIG_${env_upper}"
  echo "Value (복사해서 Notion에 붙여넣기):"
  echo ""
  base64 -i "$plist_file"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
done

echo "✅ 완료!"
echo ""
echo "다음 단계:"
echo "1. Notion Secrets DB에 접속"
echo "2. 3개의 행 추가:"
echo "   - Key: FIREBASE_CONFIG_DEV,   Dev: (위의 DEV base64)"
echo "   - Key: FIREBASE_CONFIG_STAGE, Stage: (위의 STAGE base64)"
echo "   - Key: FIREBASE_CONFIG_PROD,  Prod: (위의 PROD base64)"
echo "3. make secrets-pull 실행"
echo ""
