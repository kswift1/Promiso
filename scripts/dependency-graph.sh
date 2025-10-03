#!/bin/bash

# 의존성 그래프 시각화 스크립트
# 실행: ./scripts/dependency-graph.sh

set -e

echo "🔍 Promiso 프로젝트 의존성 그래프"
echo "================================"
echo ""

# 색상 정의
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# 레이어별 모듈 표시
echo "📦 레이어별 모듈 구조"
echo ""

echo -e "${GREEN}[Presentation Layer]${NC}"
echo "  └── Features/"
for feature_dir in Projects/Features/*/; do
  if [ -d "$feature_dir" ]; then
    feature_name=$(basename "$feature_dir")
    echo "      ├── $feature_name"
  fi
done
echo ""

echo -e "${BLUE}[Adapter Layer]${NC}"
echo "  └── Clients/"
for client_dir in Projects/Clients/Sources/*/; do
  if [ -d "$client_dir" ]; then
    client_name=$(basename "$client_dir")
    echo "      ├── $client_name"
  fi
done
echo ""

echo -e "${YELLOW}[Domain Layer]${NC}"
echo "  └── Domain/"
echo "      ├── Repositories/ (Protocols)"
echo "      └── Models/"
echo ""

echo -e "${RED}[Infrastructure Layer]${NC}"
echo "  └── Core/"
echo "      ├── CoreInfrastructure/ (Firebase)"
echo "      └── CoreNetworking/"
echo ""

# 의존성 화살표 표시
echo "📊 의존성 흐름"
echo ""
echo "  Feature (Presentation)"
echo "    ↓ @Dependency(\.client)"
echo "  Clients (Adapter)"
echo "    ↓ uses Protocol"
echo "  Domain (Business Logic)"
echo "    ↑ implements"
echo "  Core (Infrastructure)"
echo ""

# 각 Feature의 의존성 분석
echo "🔗 Feature별 의존성 분석"
echo ""

for project_file in Projects/Features/*/Project.swift; do
  if [ -f "$project_file" ]; then
    feature_name=$(basename $(dirname "$project_file"))
    echo -e "${GREEN}$feature_name${NC}"

    # Project.swift에서 dependencies 추출
    dependencies=$(grep -A 20 "dependencies:" "$project_file" | grep "target:" | sed 's/.*target: "\(.*\)".*/\1/' | sed 's/^/    → /')

    if [ -n "$dependencies" ]; then
      echo "$dependencies"
    else
      echo "    → (no dependencies)"
    fi
    echo ""
  fi
done

# 의존성 규칙 체크
echo "✅ 의존성 규칙 검증"
echo ""

# Domain이 다른 모듈을 import하는지 체크
echo "🔍 Domain Layer 순수성 체크..."
domain_violations=$(grep -r "import.*Feature\|import.*Client\|import.*Core\|import.*Firebase" Projects/Domain/Sources/ 2>/dev/null || true)

if [ -z "$domain_violations" ]; then
  echo -e "  ${GREEN}✓${NC} Domain은 외부 프레임워크에 의존하지 않습니다"
else
  echo -e "  ${RED}✗${NC} Domain에서 다음 의존성 발견:"
  echo "$domain_violations" | sed 's/^/    /'
fi
echo ""

# Clients가 Core를 직접 import하는지 체크
echo "🔍 Clients → Core 직접 의존 체크..."
client_violations=$(grep -r "import CoreInfrastructure" Projects/Clients/Sources/ 2>/dev/null || true)

if [ -z "$client_violations" ]; then
  echo -e "  ${GREEN}✓${NC} Clients는 Domain Protocol만 사용합니다"
else
  echo -e "  ${RED}✗${NC} Clients에서 다음 의존성 발견:"
  echo "$client_violations" | sed 's/^/    /'
fi
echo ""

# 요약
echo "📈 의존성 통계"
echo ""
total_features=$(find Projects/Features -maxdepth 1 -type d | tail -n +2 | wc -l | tr -d ' ')
total_clients=$(find Projects/Clients/Sources -maxdepth 1 -type d 2>/dev/null | tail -n +2 | wc -l | tr -d ' ')
total_repos=$(find Projects/Domain/Sources/Repositories -name "*Protocol.swift" 2>/dev/null | wc -l | tr -d ' ')

echo "  Features:          $total_features"
echo "  Clients:           $total_clients"
echo "  Domain Protocols:  $total_repos"
echo ""

echo "✨ 의존성 그래프 분석 완료!"
echo ""
echo "💡 자세한 내용은 다음을 참고하세요:"
echo "  - docs/architecture/001-dependency-architecture.md"
echo "  - Projects/Clients/README.md"
echo "  - Projects/Domain/README.md"
