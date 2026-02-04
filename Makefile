# ============================================================================
# Promiso Project Makefile
# ============================================================================
#
# 사용법: make <command> [OPTIONS]
# 도움말: make help
#
# ============================================================================

.PHONY: feature remove-feature deps color \
        emulator-start functions-build functions-api-preview \
        secrets-pull secrets-push secrets-list secrets-add \
        help

# 기본값 설정
FEATURE_NAME ?=
FORCE ?=

# ============================================================================
# 🏗️  Feature 관리
# ============================================================================

# 피쳐 생성 + 의존성 자동 추가 + 프로젝트 생성
feature:
	@if [ -z "$(FEATURE_NAME)" ]; then \
		echo "❌ Error: 피쳐 이름이 필요합니다."; \
		echo "Usage: make feature FEATURE_NAME=YourFeature"; \
		exit 1; \
	fi
	@echo "🚀 피쳐 '$(FEATURE_NAME)' 생성 중..."
	@echo "1/4 피쳐 스캐폴드 생성..."
	@tuist scaffold feature --name $(FEATURE_NAME)
	@echo "2/4 AppFeatureDeps.swift에 의존성 추가..."
	@./scripts/add_feature_dependency.sh $(FEATURE_NAME)
	@echo "3/4 프로젝트 생성..."
	@tuist install && tuist generate
	@echo "4/4 완료! ✅"
	@echo ""
	@echo "🎉 피쳐 '$(FEATURE_NAME)'가 성공적으로 생성되었습니다!"
	@echo "📂 위치: Projects/Features/$(FEATURE_NAME)Feature/"

# 피쳐 삭제 + 프로젝트 재생성
remove-feature:
	@if [ -z "$(FEATURE_NAME)" ]; then \
		echo "❌ Error: 피쳐 이름이 필요합니다."; \
		echo "Usage: make remove-feature FEATURE_NAME=YourFeature"; \
		exit 1; \
	fi
	@echo "🗑️  피쳐 '$(FEATURE_NAME)' 삭제 중..."
	@echo ""
	@echo "⚠️  주의: 다음 작업이 수행됩니다:"
	@echo "   - Projects/Features/$(FEATURE_NAME)Feature/ 폴더 완전 삭제"
	@echo "   - Tuist/ProjectDescriptionHelpers/FeatureFactory/Features/Features+$(FEATURE_NAME).swift 삭제"
	@echo "   - AppFeatureDeps.swift에서 의존성 제거"
	@echo "   - 프로젝트 재생성"
	@echo ""
	@if [ -z "$(FORCE)" ]; then \
		read -p "정말로 계속하시겠습니까? (y/N): " confirm; \
		if [ "$$confirm" != "y" ] && [ "$$confirm" != "Y" ]; then \
			echo "❌ 작업이 취소되었습니다."; \
			exit 1; \
		fi; \
	else \
		echo "⚡ FORCE 모드: 확인 없이 진행합니다."; \
	fi
	@echo ""
	@echo "1/4 피쳐 폴더 삭제..."
	@if [ -d "Projects/Features/$(FEATURE_NAME)Feature" ]; then \
		rm -rf "Projects/Features/$(FEATURE_NAME)Feature"; \
		echo "  ✅ Projects/Features/$(FEATURE_NAME)Feature/ 삭제 완료"; \
	else \
		echo "  ℹ️  Projects/Features/$(FEATURE_NAME)Feature/ 폴더가 존재하지 않습니다."; \
	fi
	@echo "2/4 Feature 확장 파일 삭제..."
	@if [ -f "Tuist/ProjectDescriptionHelpers/FeatureFactory/Features/Features+$(FEATURE_NAME).swift" ]; then \
		rm -f "Tuist/ProjectDescriptionHelpers/FeatureFactory/Features/Features+$(FEATURE_NAME).swift"; \
		echo "  ✅ Features+$(FEATURE_NAME).swift 삭제 완료"; \
	else \
		echo "  ℹ️  Features+$(FEATURE_NAME).swift 파일이 존재하지 않습니다."; \
	fi
	@echo "3/4 AppFeatureDeps.swift에서 의존성 제거..."
	@./scripts/remove_feature_dependency.sh $(FEATURE_NAME)
	@echo "4/4 프로젝트 재생성..."
	@if tuist install && tuist generate; then \
		echo "  ✅ 프로젝트 재생성 완료"; \
	else \
		echo "  ⚠️  프로젝트 재생성에 실패했습니다. 수동으로 'tuist generate'를 실행해주세요."; \
	fi
	@echo ""
	@echo "🎉 피쳐 '$(FEATURE_NAME)'가 성공적으로 삭제되었습니다!"

# ============================================================================
# 🎨 리소스 관리
# ============================================================================

# 의존성 그래프 시각화
deps:
	@echo "📊 의존성 그래프 분석 중..."
	@./scripts/dependency-graph.sh

# 컬러 에셋 자동 생성
color:
	@echo "🎨 컬러 에셋 및 Swift Extension 생성 중..."
	@./scripts/generate_colors.sh
	@echo "✅ 완료!"

# ============================================================================
# 🔥 Firebase
# ============================================================================

# Firebase Emulator 전체 실행
emulator-start:
	@echo "🧪 Firebase 에뮬레이터 실행 중..."
	@cd infra/firebase/functions && firebase emulators:start --only functions,firestore,auth,storage

# Firebase Functions 빌드
functions-build:
	@echo "🔧 Firebase Functions 빌드 중..."
	@cd infra/firebase/functions && npm run build

# Firebase Functions OpenAPI 미리보기
functions-api-preview:
	@echo "📖 OpenAPI 미리보기 실행 중..."
	@cd infra/firebase/functions && ( \
		npm run api:preview & \
		pid=$$!; \
		if command -v nc >/dev/null 2>&1; then \
			until nc -z localhost 8080; do sleep 0.2; done; \
		else \
			until lsof -iTCP:8080 -sTCP:LISTEN >/dev/null 2>&1; do sleep 0.2; done; \
		fi; \
		echo "🌐 OpenAPI Preview: http://localhost:8080"; \
		open http://localhost:8080 || true; \
		wait $$pid; \
	)

# ============================================================================
# 🔐 Secrets 관리 (Notion 기반)
# ============================================================================

# Notion → 로컬 xcconfig 동기화
secrets-pull:
	@./scripts/sync-secrets.sh pull

# Notion → GitHub Secrets 동기화
secrets-push:
	@./scripts/sync-secrets.sh push-gh

# 시크릿 목록 표시
secrets-list:
	@./scripts/sync-secrets.sh list

# 새 시크릿 추가 (대화형)
secrets-add:
	@./scripts/sync-secrets.sh add

# ============================================================================
# 📖 도움말
# ============================================================================

help:
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo "  Promiso Makefile Commands"
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
	@echo "  🏗️  Feature 관리"
	@echo "  ─────────────────────────────────────────────────────────────────"
	@echo "  make feature FEATURE_NAME=<Name>        새 피쳐 생성"
	@echo "  make remove-feature FEATURE_NAME=<Name> 피쳐 삭제"
	@echo "  make remove-feature ... FORCE=1         확인 없이 삭제"
	@echo ""
	@echo "  🎨 리소스 관리"
	@echo "  ─────────────────────────────────────────────────────────────────"
	@echo "  make deps                               의존성 그래프 시각화"
	@echo "  make color                              컬러 에셋 재생성"
	@echo ""
	@echo "  🔥 Firebase"
	@echo "  ─────────────────────────────────────────────────────────────────"
	@echo "  make emulator-start                     에뮬레이터 실행"
	@echo "  make functions-build                    Functions 빌드"
	@echo "  make functions-api-preview              OpenAPI 미리보기"
	@echo ""
	@echo "  🔐 Secrets 관리"
	@echo "  ─────────────────────────────────────────────────────────────────"
	@echo "  make secrets-list                       시크릿 목록 표시"
	@echo "  make secrets-pull                       Notion → xcconfig 동기화"
	@echo "  make secrets-push                       Notion → GitHub Secrets"
	@echo "  make secrets-add                        새 시크릿 추가"
	@echo ""
	@echo "  📖 기타"
	@echo "  ─────────────────────────────────────────────────────────────────"
	@echo "  make help                               이 도움말 표시"
	@echo ""
	@echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
	@echo ""
