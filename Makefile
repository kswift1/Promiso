# Promiso Project Makefile
# Usage: make feature FEATURE_NAME=YourFeature

.PHONY: feature help

# 기본값 설정
FEATURE_NAME ?=

# 피쳐 생성 + 의존성 자동 추가 + 프로젝트 생성
feature:
	@if [ -z "$(FEATURE_NAME)" ]; then \
		echo "❌ Error: 피쳐 이름이 필요합니다."; \
		echo "Usage: make feature FEATURE_NAME=YourFeature"; \
		exit 1; \
	fi
	@echo "🚀 피쳐 '$(FEATURE_NAME)' 생성 중..."
	@echo "1/4 피쳐 스캐폴드 생성..."
	tuist scaffold feature --name $(FEATURE_NAME)
	@echo "2/4 의존성 자동 추가..."
	@./scripts/add_feature_dependency.sh $(FEATURE_NAME)
	@echo "3/4 프로젝트 생성..."
	tuist generate
	@echo "4/4 완료! ✅"
	@echo ""
	@echo "🎉 피쳐 '$(FEATURE_NAME)'가 성공적으로 생성되고 앱에 통합되었습니다!"
	@echo "📂 위치: Projects/Features/$(FEATURE_NAME)Feature/"
	@echo "🔧 다음 단계: Xcode에서 $(FEATURE_NAME)Feature를 열고 개발을 시작하세요."

# 도움말
help:
	@echo "Promiso Project Commands:"
	@echo ""
	@echo "  make feature FEATURE_NAME=YourFeature  - 새 피쳐 생성 + 자동 통합"
	@echo "  make help                             - 이 도움말 표시"
	@echo ""
	@echo "예시:"
	@echo "  make feature FEATURE_NAME=Login       - Login 피쳐 생성"
	@echo "  make feature FEATURE_NAME=Profile     - Profile 피쳐 생성"