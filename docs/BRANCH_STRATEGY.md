# Promiso Git 브랜치 전략

Promiso 프로젝트의 Git 브랜치 전략 및 릴리즈 흐름입니다.

## 문서 메타

- 목적: 브랜치 역할과 병합/릴리즈 흐름 기준 정의
- 대상 독자: 모든 기여자, 릴리즈 담당자
- 최종 수정일: 2026-02-06
- 관련 문서: [README.md](README.md) · [CI_CD.md](CI_CD.md) · [DEPLOYMENT.md](DEPLOYMENT.md)

## 범위 안내

- 이 문서: 브랜치 정책과 병합 흐름
- 워크플로우 job/secret 상세: [CI_CD.md](CI_CD.md)
- 실제 배포 실행 절차: [DEPLOYMENT.md](DEPLOYMENT.md)

## 📋 목차

1. [브랜치 구조](#브랜치-구조)
2. [브랜치별 역할](#브랜치별-역할)
3. [워크플로우](#워크플로우)
4. [배포 프로세스](#배포-프로세스)
5. [브랜치 생성 및 관리](#브랜치-생성-및-관리)

---

## 브랜치 구조

```
main (production)
 ↑
 │ PR + 테스트 + 승인
 │
staging (stage 환경)
 ↑
 │ PR + 테스트 + 승인
 │
develop (개발 환경)
 ↑
 │ PR + 테스트
 │
feature/* (기능 개발)
```

### 브랜치 종류

| 브랜치 | 보호 | 용도 | 목적 |
|--------|------|------|------|
| `main` | ✅ | 프로덕션 릴리즈 기준선 | 프로덕션 릴리스 |
| `staging` | ✅ | 출시 전 검증 기준선 | 최종 QA/검증 |
| `develop` | ✅ | 기능 통합 기준선 | 개발 통합 |
| `feature/*` | ❌ | - | 기능 개발 |
| `hotfix/*` | ❌ | - | 긴급 수정 |

---

## 브랜치별 역할

### 🔴 `main` (프로덕션)

**용도**: App Store에 배포되는 안정적인 프로덕션 코드

**특징**:
- 항상 배포 가능한 상태 유지
- 직접 커밋 금지
- `staging` 브랜치에서만 PR 허용
- Tag를 통한 버전 관리 (`v1.0.0`, `v1.1.0` 등)

**Firebase 프로젝트**: `promiso-prod`

**빌드 타겟**: `Promiso`
- Bundle ID: `com.promiso`
- Firebase: `promiso-prod`
- App Icon: 오리지널 (뱃지 없음)

---

### 🟡 `staging` (스테이징)

**용도**: 출시 전 최종 QA 및 검증

**특징**:
- 프로덕션과 동일한 환경
- `develop` 브랜치에서만 PR 허용
- 프로덕션 배포 전 필수 경유

**Firebase 프로젝트**: `promiso-stage`

**빌드 타겟**: `PromisoStage`
- Bundle ID: `com.promiso.stage`
- Firebase: `promiso-stage`
- App Icon: 노란색 "STG" 뱃지

---

### 🟢 `develop` (개발)

**용도**: 개발 중인 기능들의 통합 브랜치

**특징**:
- 모든 `feature/*` 브랜치가 병합되는 곳
- Firebase Dev 프로젝트 사용

**Firebase 프로젝트**: `promiso-dev`

**빌드 타겟**: `PromisoDev`
- Bundle ID: `com.promiso.dev`
- Firebase: `promiso-dev`
- App Icon: 파란색 "DEV" 뱃지

---

### 🔵 `feature/*` (기능 브랜치)

**용도**: 새 기능 개발

**네이밍 규칙**:
```bash
feature/기능명-간단설명
```

**예시**:
```bash
feature/home-promise-list       # 홈 화면 약속 목록
feature/auth-kakao-login        # 카카오 로그인
feature/group-settings          # 그룹 설정
```

**생명 주기**:
1. `develop`에서 분기
2. 기능 개발
3. PR → `develop`
4. 병합 후 삭제

---

### 🔥 `hotfix/*` (긴급 수정)

**용도**: 프로덕션 긴급 버그 수정

**네이밍 규칙**:
```bash
hotfix/버전-이슈번호-간단설명
```

**예시**:
```bash
hotfix/v1.2.1-123-login-crash   # v1.2.1 로그인 크래시 수정
```

**생명 주기**:
1. `main`에서 분기
2. 버그 수정
3. PR → `main` (동시에 `develop`, `staging`에도 병합)
4. 즉시 배포

---

## 워크플로우

### 1️⃣ 일반 기능 개발

```bash
# 1. develop에서 feature 브랜치 생성
git checkout develop
git pull origin develop
git checkout -b feature/home-promise-list

# 2. 기능 개발 및 커밋
git add .
git commit -m "feat: 홈 화면 약속 목록 추가"

# 3. develop으로 PR 생성
git push origin feature/home-promise-list
# GitHub에서 PR 생성: feature/home-promise-list → develop

# 4. 검증 실행
# - 로컬 테스트 또는 필요한 워크플로우 수동 실행
# - 리뷰 후 승인

# 5. develop에 병합
# - 배포 동작은 docs/CI_CD.md 기준 확인

# 6. 브랜치 삭제
git branch -d feature/home-promise-list
```

### 2️⃣ 스테이징 배포

```bash
# 1. develop → staging PR
git checkout staging
git pull origin staging
git checkout -b release/v1.2.0  # 선택적

# GitHub에서 PR 생성: develop → staging

# 2. 검증 실행
# - 로컬 테스트 또는 필요한 워크플로우 수동 실행
# - 리뷰 및 QA

# 3. staging에 병합
# - 배포 동작은 docs/CI_CD.md 기준 확인

# 4. QA 진행
# - TestFlight Stage Track에서 최종 검증
```

### 3️⃣ 프로덕션 배포

```bash
# 1. staging → main PR
# GitHub에서 PR 생성: staging → main

# 2. 검증 실행
# - 로컬 테스트 또는 필요한 워크플로우 수동 실행
# - 최종 승인

# 3. main에 병합
# - 배포 동작은 docs/CI_CD.md 기준 확인

# 4. 버전 태그 생성
git checkout main
git pull origin main
git tag v1.2.0
git push origin v1.2.0

# 5. App Store 제출
# - TestFlight에서 최종 확인
# - App Store Connect에서 수동 제출
```

### 4️⃣ 긴급 수정 (Hotfix)

```bash
# 1. main에서 hotfix 브랜치 생성
git checkout main
git pull origin main
git checkout -b hotfix/v1.2.1-123-login-crash

# 2. 버그 수정
git add .
git commit -m "fix: 로그인 크래시 수정"

# 3. main으로 PR (최우선)
git push origin hotfix/v1.2.1-123-login-crash
# GitHub에서 PR 생성: hotfix/* → main

# 4. main에 병합 후 즉시 배포

# 5. develop과 staging에도 반영
git checkout develop
git merge hotfix/v1.2.1-123-login-crash
git push origin develop

git checkout staging
git merge hotfix/v1.2.1-123-login-crash
git push origin staging

# 6. 브랜치 삭제
git branch -d hotfix/v1.2.1-123-login-crash
```

---

## 배포 프로세스

### 환경별 배포 타겟

| 브랜치 | 빌드 타겟 | Firebase | TestFlight Track | 자동/수동 |
|--------|-----------|----------|------------------|-----------|
| `develop` | PromisoDev | promiso-dev | Dev Track | CI/CD 설정 기준 |
| `staging` | PromisoStage | promiso-stage | Stage Track | CI/CD 설정 기준 |
| `main` | Promiso | promiso-prod | Prod Track → App Store | CI/CD 설정 기준 |

### 운영 기준

- 브랜치 정책/병합 순서: 이 문서 기준
- 워크플로우 트리거/잡/시크릿: [CI_CD.md](CI_CD.md)
- 실제 배포 실행 절차: [DEPLOYMENT.md](DEPLOYMENT.md)
- 참고: 현재 자동 트리거는 `PR → develop/staging/main`(PR Check)과 `release/** + infra/firebase/**`(Firebase Stage Auto)입니다.

---

## 브랜치 생성 및 관리

### 초기 브랜치 생성

```bash
# 1. develop 브랜치 생성 (main에서 분기)
git checkout main
git pull origin main
git checkout -b develop
git push origin develop

# 2. staging 브랜치 생성 (main에서 분기)
git checkout main
git checkout -b staging
git push origin staging

# 3. GitHub에서 브랜치 보호 설정
# Settings → Branches → Add rule
# - main: Require pull request reviews, Require status checks
# - staging: Require pull request reviews
# - develop: Require status checks
```

### 브랜치 보호 규칙

**main (최고 수준)**:
- ✅ Require pull request before merging
- ✅ Require approvals: 1
- ✅ Require status checks to pass
  - ✅ 저장소에서 지정한 필수 체크
- ✅ Require conversation resolution
- ✅ Do not allow bypassing the above settings

**staging**:
- ✅ Require pull request before merging
- ✅ Require approvals: 1
- ✅ Require status checks to pass
  - ✅ 저장소에서 지정한 필수 체크

**develop**:
- ✅ Require pull request before merging
- ✅ Require status checks to pass
  - ✅ 저장소에서 지정한 필수 체크
- ⬜ Require approvals (선택)

---

## 버전 관리

### 버전 번호 규칙

**Semantic Versioning (v{MAJOR}.{MINOR}.{PATCH})**:
```
v1.0.0    # 최초 릴리스
v1.1.0    # 새 기능 추가
v1.1.1    # 버그 수정
v2.0.0    # 주요 변경 (Breaking Changes)
```

### Tag 생성

```bash
# main 브랜치에서만 태그 생성
git checkout main
git pull origin main

# 태그 생성 (버전 + 릴리스 노트)
git tag -a v1.2.0 -m "Release v1.2.0

- 새 기능: 그룹 설정
- 개선: 홈 화면 성능
- 버그 수정: 로그인 크래시
"

# 태그 푸시
git push origin v1.2.0
```

---

## CI/CD 파이프라인 요약

이 문서는 브랜치 정책만 다루며, CI/CD 동작 상세는 아래 문서를 기준으로 관리합니다.

- 워크플로우 트리거/단계: [CI_CD.md](CI_CD.md)
- 배포 실행 체크리스트: [DEPLOYMENT.md](DEPLOYMENT.md)

---

## 문제 해결

### Q: develop 브랜치가 없는데?

**A**: 아래 명령어로 생성하세요.

```bash
git checkout main
git pull origin main
git checkout -b develop
git push origin develop

# staging도 동일하게 생성
git checkout main
git checkout -b staging
git push origin staging
```

### Q: 브랜치 보호 규칙은 어떻게 설정하나요?

**A**: GitHub 레포지토리 → Settings → Branches

1. "Add rule" 클릭
2. Branch name pattern: `main`
3. 체크박스 설정:
   - ✅ Require a pull request before merging
   - ✅ Require approvals (1)
   - ✅ Require status checks to pass before merging
     - 저장소에 지정된 필수 체크 선택
4. "Create" 클릭
5. `staging`, `develop`도 동일하게 반복

### Q: feature 브랜치를 잘못된 브랜치에서 만들었어요

**A**: rebase로 베이스 변경

```bash
# feature/my-feature를 main → develop으로 변경
git checkout feature/my-feature
git rebase --onto develop main feature/my-feature
git push origin feature/my-feature --force-with-lease
```

### Q: hotfix를 develop/staging에도 반영하려면?

**A**: cherry-pick 또는 merge

```bash
# 방법 1: merge (권장)
git checkout develop
git merge hotfix/v1.2.1-123-bug
git push origin develop

# 방법 2: cherry-pick
git checkout develop
git cherry-pick <hotfix-commit-hash>
git push origin develop
```

---

## 참고 문서

- [Git Flow](https://nvie.com/posts/a-successful-git-branching-model/)
- [Semantic Versioning](https://semver.org/)
- [GitHub Branch Protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches)
- [docs/CI_CD.md](CI_CD.md) - GitHub Actions 워크플로우
- [docs/SETUP_GUIDE.md](SETUP_GUIDE.md) - 프로젝트 초기 설정

---

## 요약 체크리스트

### 개발자
- [ ] feature 브랜치는 `develop`에서 분기
- [ ] 커밋 메시지는 컨벤션 준수 (`feat:`, `fix:` 등)
- [ ] PR 생성 시 템플릿 작성
- [ ] CI 체크 통과 확인

### 릴리스 매니저
- [ ] develop → staging PR 생성
- [ ] TestFlight Stage Track QA 완료
- [ ] staging → main PR 생성 (최종 승인)
- [ ] main 병합 후 버전 태그 생성
- [ ] App Store Connect 제출

### 긴급 상황
- [ ] hotfix 브랜치는 `main`에서 분기
- [ ] main 병합 후 즉시 배포
- [ ] develop, staging에도 반영 필수
