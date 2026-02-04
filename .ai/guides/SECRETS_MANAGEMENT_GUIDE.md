# Secrets 관리 가이드

## 개요

Promiso 프로젝트의 시크릿은 **용도별로 다르게 관리**합니다:

### iOS 앱 빌드용 시크릿
**Notion**을 Single Source of Truth로 사용:
- 한 곳에서 모든 환경(Dev/Stage/Prod)의 시크릿 관리
- 팀원 누구나 쉽게 접근/수정 가능
- 로컬 xcconfig 자동 생성
- GitHub Secrets 자동 동기화

### Firebase Functions 전용 시크릿
**Google Cloud Secret Manager**로 관리:
- `KAKAO_REST_API_KEY` (장소 검색 API)
- `NOTION_FAQ_API_KEY` (FAQ 데이터베이스)
- `GEMINI_API_KEY`, `APNS_*`, `WIDGET_JWT_SECRET` 등

> 본 문서는 **iOS 앱 빌드용 시크릿 관리**에 대해 다룹니다.

## 아키텍처 (iOS 앱 빌드용)

```
┌─────────────────────────────────────────────────────────────┐
│              Notion Database (iOS 앱 빌드용)                 │
│            (Single Source of Truth for iOS)                 │
│                                                             │
│  ┌──────────────────────┬─────────┬─────────┬─────────┐    │
│  │ Key                  │ Dev     │ Stage   │ Prod    │    │
│  ├──────────────────────┼─────────┼─────────┼─────────┤    │
│  │ GOOGLE_CLIENT_ID     │ xxx     │ yyy     │ zzz     │    │
│  │ GOOGLE_REVERSED_...  │ xxx     │ yyy     │ zzz     │    │
│  │ KAKAO_NATIVE_APP_KEY │ xxx     │ yyy     │ zzz     │    │
│  └──────────────────────┴─────────┴─────────┴─────────┘    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                   ┌──────────────────────┐
                   │  sync-secrets.sh     │
                   │  (make secrets-*)    │
                   └──────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
┌──────────────────────────┐    ┌──────────────────────────┐
│    Local xcconfig        │    │    GitHub Secrets        │
│                          │    │                          │
│  Config/Dev.xcconfig     │    │  GOOGLE_CLIENT_ID_DEV    │
│  Config/Stage.xcconfig   │    │  GOOGLE_CLIENT_ID_STAGE  │
│  Config/Prod.xcconfig    │    │  GOOGLE_CLIENT_ID_PROD   │
│                          │    │  ...                     │
│  (.gitignore에 포함)      │    │                          │
└──────────────────────────┘    └──────────────────────────┘
              │                               │
              ▼                               ▼
       ┌────────────┐                ┌────────────────┐
       │ 로컬 빌드   │                │  CI/CD 빌드    │
       └────────────┘                └────────────────┘

※ Firebase Functions 시크릿은 별도로 Google Cloud Secret Manager에서 관리
```

## Notion Database 구조

### Database ID
```
5e30fc69caf4432da2bc1183c10960dd
```

### 속성 (Properties)

| 속성명 | 타입 | 설명 | 필수 |
|--------|------|------|------|
| `Key` | Title | 시크릿 이름 (예: GOOGLE_CLIENT_ID) | ✅ |
| `Dev` | Text | Development 환경 값 | ✅ |
| `Stage` | Text | Staging 환경 값 | ✅ |
| `Prod` | Text | Production 환경 값 | ✅ |
| `Description` | Text | 설명 (용도, 발급처 등) | ❌ |

### 현재 관리 중인 시크릿 (iOS 앱 빌드용)

| Key | 설명 | 발급처 | 사용처 |
|-----|------|--------|--------|
| `GOOGLE_CLIENT_ID` | Google OAuth Client ID | [Google Cloud Console](https://console.cloud.google.com) | iOS 앱 |
| `GOOGLE_REVERSED_CLIENT_ID` | Google OAuth URL Scheme | Google Cloud Console | iOS 앱 |
| `KAKAO_NATIVE_APP_KEY` | Kakao SDK Native App Key | [Kakao Developers](https://developers.kakao.com) | iOS 앱 |

> **Note:** `KAKAO_REST_API_KEY`, `NOTION_FAQ_API_KEY` 등 Firebase Functions 전용 시크릿은 **Google Cloud Secret Manager**에서 관리합니다.

## 초기 설정

### 1. NOTION_API_KEY 환경변수 설정 (로컬 개발용)

> **Note:** 이 키는 로컬에서 `make secrets-pull` 스크립트를 실행할 때만 필요합니다. iOS 앱 빌드나 실행에는 영향을 주지 않습니다.

```bash
# ~/.zshrc 또는 ~/.bashrc에 추가
export NOTION_API_KEY="ntn_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# 적용
source ~/.zshrc
```

### 2. Notion Integration 연결 확인

Secrets 데이터베이스에 Integration이 연결되어 있어야 합니다:

1. [Notion Secrets Database](https://notion.so/5e30fc69caf4432da2bc1183c10960dd) 열기
2. 우측 상단 `...` → `Connections`
3. 사용 중인 Integration 연결 확인

### 3. gh CLI 설치 (GitHub Secrets 동기화용)

```bash
brew install gh
gh auth login
```

## 사용법

### 시크릿 목록 확인

```bash
make secrets-list
```

출력 예시:
```
📋 Notion Secrets 목록

┌─ GOOGLE_CLIENT_ID
│  Dev:   809932911903-ugv4efp...
│  Stage: 511041416523-bek4g2m...
│  Prod:  367716701610-efrvms6...
└─
┌─ KAKAO_NATIVE_APP_KEY
│  Dev:   9351400ec18c40be1006...
│  Stage: df74fcf566003af1f800...
│  Prod:  85c9fc88501e426b8482...
└─
...
```

### 로컬 xcconfig 동기화

```bash
make secrets-pull
```

이 명령은:
1. Notion에서 모든 시크릿 조회
2. `Config/Dev.xcconfig`, `Config/Stage.xcconfig`, `Config/Prod.xcconfig` 생성
3. Code Signing 설정 자동 추가

### 새 시크릿 추가

#### 방법 1: CLI 사용

```bash
make secrets-add
```

대화형으로 입력:
```
➕ 새 시크릿 추가

Key 이름: NEW_API_KEY
Dev 값: dev_xxx
Stage 값: stage_xxx
Prod 값: prod_xxx
설명 (선택): 새로운 API 키

✅ 'NEW_API_KEY' 추가됨

xcconfig 파일도 업데이트할까요? (y/n): y
```

#### 방법 2: Notion에서 직접 추가

1. [Secrets Database](https://notion.so/5e30fc69caf4432da2bc1183c10960dd) 열기
2. 새 행 추가
3. 각 환경별 값 입력
4. `make secrets-pull` 실행

### GitHub Secrets 업데이트

```bash
make secrets-push
```

이 명령은:
1. Notion에서 모든 시크릿 조회
2. 각 시크릿을 `{KEY}_{ENV}` 형식으로 GitHub Secrets에 업데이트
   - 예: `GOOGLE_CLIENT_ID_DEV`, `GOOGLE_CLIENT_ID_STAGE`, `GOOGLE_CLIENT_ID_PROD`

## CI/CD 연동

### GitHub Actions에서 사용

```yaml
# .github/workflows/build.yml
jobs:
  build:
    steps:
      - name: Generate xcconfig
        run: |
          echo "GOOGLE_CLIENT_ID = ${{ secrets.GOOGLE_CLIENT_ID_PROD }}" >> Config/Prod.xcconfig
          echo "KAKAO_NATIVE_APP_KEY = ${{ secrets.KAKAO_NATIVE_APP_KEY_PROD }}" >> Config/Prod.xcconfig
          # ...
```

또는 동기화 스크립트 사용:

```yaml
      - name: Sync secrets from Notion
        env:
          NOTION_API_KEY: ${{ secrets.NOTION_API_KEY }}
        run: make secrets-pull
```

## 새 환경/팀원 온보딩

### 새 팀원이 해야 할 일

1. **NOTION_API_KEY 받기**
   - 기존 팀원에게 API Key 공유 받기
   - 또는 새 Integration 생성 후 Database에 연결

2. **환경변수 설정**
   ```bash
   echo 'export NOTION_API_KEY="ntn_xxx"' >> ~/.zshrc
   source ~/.zshrc
   ```

3. **시크릿 동기화**
   ```bash
   make secrets-pull
   ```

4. **빌드 확인**
   ```bash
   tuist generate
   # Xcode에서 빌드
   ```

## 보안 고려사항

### 주의사항

1. **NOTION_API_KEY는 절대 커밋하지 않기**
   - 환경변수로만 관리
   - CI에서는 GitHub Secrets 사용

2. **xcconfig 파일은 .gitignore에 포함**
   ```gitignore
   # Config/*.xcconfig는 .gitignore에 이미 포함
   Config/*.xcconfig
   ```

3. **Notion Database 접근 권한 관리**
   - 필요한 팀원만 Integration 접근 권한 부여
   - 퇴사자 발생 시 Integration API Key 재발급

### 시크릿 로테이션

시크릿 변경이 필요한 경우:

1. Notion에서 해당 시크릿 값 업데이트
2. `make secrets-pull` (로컬)
3. `make secrets-push` (GitHub)
4. CI/CD 재실행으로 새 값 적용

## 문제 해결

### "Database not found" 에러

```
Error: Could not find database with ID: xxx
```

**해결:**
- Notion에서 Secrets Database에 Integration이 연결되어 있는지 확인
- Database URL에서 올바른 ID를 사용하는지 확인

### "NOTION_API_KEY 환경변수가 설정되지 않았습니다" 에러

**해결:**
```bash
export NOTION_API_KEY="ntn_xxx"
# 또는 영구 설정
echo 'export NOTION_API_KEY="ntn_xxx"' >> ~/.zshrc
```

### GitHub Secrets 업데이트 실패

```
⚠️ 업데이트 실패 (권한 확인 필요)
```

**해결:**
```bash
# gh CLI 로그인 확인
gh auth status

# 재로그인
gh auth login

# 레포지토리 권한 확인
gh repo view kswift1/Promiso
```

### xcconfig 파일이 비어있음

**해결:**
- Notion Database에 데이터가 있는지 확인
- 각 환경(Dev/Stage/Prod) 컬럼에 값이 있는지 확인

## 파일 구조

```
Promiso/
├── scripts/
│   └── sync-secrets.sh      # 시크릿 동기화 스크립트
├── Config/
│   ├── Dev.xcconfig         # (자동 생성, .gitignore)
│   ├── Stage.xcconfig       # (자동 생성, .gitignore)
│   └── Prod.xcconfig        # (자동 생성, .gitignore)
├── Makefile                 # secrets-* 명령어 정의
└── .ai/guides/
    └── SECRETS_MANAGEMENT_GUIDE.md  # 이 문서
```

## 관련 문서

- [Notion FAQ 관리 가이드](./NOTION_FAQ_GUIDE.md)
- [Notion API 공식 문서](https://developers.notion.com/)
- [GitHub CLI 문서](https://cli.github.com/manual/)
