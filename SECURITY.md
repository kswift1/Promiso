# 보안 정책 (Security Policy)

> **Promiso iOS App** - API Keys, Secrets, 민감 정보 관리 가이드

---

## 📋 목차

1. [보안 원칙](#보안-원칙)
2. [민감 정보 관리](#민감-정보-관리)
3. [Git 보안](#git-보안)
4. [로컬 개발 환경](#로컬-개발-환경)
5. [CI/CD 보안](#cicd-보안)
6. [팀원 온보딩/오프보딩](#팀원-온보딩오프보딩)
7. [보안 사고 대응](#보안-사고-대응)
8. [정기 점검](#정기-점검)

---

## 🔒 보안 원칙

### 핵심 원칙

1. **최소 권한 원칙 (Least Privilege)**
   - 팀원에게 필요한 최소한의 권한만 부여
   - 환경별로 접근 권한 분리 (Dev/Stage/Prod)

2. **정보 암호화 (Encryption)**
   - 모든 API Keys는 암호화된 상태로 저장
   - Git에는 템플릿만 커밋, 실제 값은 제외

3. **정기 로테이션 (Rotation)**
   - API Keys는 6개월마다 재발급
   - 퇴사자 발생 시 즉시 모든 키 교체

4. **감사 추적 (Audit Trail)**
   - 민감 정보 접근 기록 보관
   - GitHub Actions 로그 모니터링

---

## 🔐 민감 정보 관리

### 관리 대상 정보

#### 1. API Keys & Credentials

| 분류 | 항목 | 저장 위치 | 보안 등급 |
|------|------|----------|----------|
| **OAuth** | Google Client ID | xcconfig, GitHub Secrets | 🟡 중간 |
| **OAuth** | Kakao Native App Key | xcconfig, GitHub Secrets | 🟡 중간 |
| **Firebase** | API Key, Project ID | plist, GitHub Secrets | 🟢 낮음 (제한적 권한) |
| **AI** | Gemini API Key | .env, GitHub Secrets | 🔴 높음 |
| **API** | Notion API Key | .env, GitHub Secrets | 🟡 중간 |
| **Deploy** | Firebase Token | GitHub Secrets만 | 🔴 높음 |
| **Deploy** | App Store Connect API Key (P8) | GitHub Secrets만 | 🔴 높음 |

#### 2. 인증서 & 프로비저닝

| 항목 | 저장 위치 | 보안 등급 |
|------|----------|----------|
| P8 파일 (App Store Connect) | GitHub Secrets (Base64), 1Password | 🔴 높음 |
| Match Password | GitHub Secrets, 1Password | 🔴 높음 |
| Distribution Certificate | Fastlane Match Git (암호화) | 🔴 높음 |

---

## 🚫 Git 보안

### 절대 커밋하지 말아야 할 파일

```gitignore
# API Keys
Config/Dev.xcconfig
Config/Stage.xcconfig
Config/Prod.xcconfig
Secrets.xcconfig
*.xcconfig.local

# Firebase
GoogleService-Info.plist
Config/GoogleService-Info-*.plist
Projects/App/Resources-*/GoogleService-Info.plist

# Environment Variables
.env
.env.local
**/.env
**/.env.local

# Certificates
*.cer
*.p12
*.p8
*.mobileprovision
*.certSigningRequest

# Logs
firebase-debug.log
**/firebase-debug.log
```

### Git 커밋 전 체크리스트

**매 커밋마다 확인**:

```bash
# 1. .gitignore 확인
cat .gitignore | grep -E "xcconfig|GoogleService|\.env|\.p8"

# 2. 민감 정보가 커밋되지 않았는지 확인
git diff --cached | grep -iE "api_key|secret|password|token"

# 3. staged 파일 목록 확인
git status

# 4. 의심스러운 파일이 있으면 unstage
git reset HEAD <파일명>
```

### Pre-commit Hook 설정 (권장)

`.git/hooks/pre-commit` 파일 생성:

```bash
#!/bin/bash

# 민감 정보 체크
if git diff --cached | grep -iE "api_key|secret_key|password|private_key|token" > /dev/null; then
    echo "⚠️  경고: 민감 정보가 포함된 것 같습니다!"
    echo "커밋을 취소하려면 Ctrl+C를 누르세요."
    read -p "계속하시겠습니까? (y/N): " confirm
    if [ "$confirm" != "y" ]; then
        exit 1
    fi
fi

# .xcconfig 파일 체크
if git diff --cached --name-only | grep -E "Config/.*\.xcconfig$" | grep -v "template" > /dev/null; then
    echo "❌ 에러: xcconfig 파일은 커밋할 수 없습니다!"
    echo "템플릿 파일(.template)만 커밋하세요."
    exit 1
fi

# GoogleService-Info.plist 체크
if git diff --cached --name-only | grep "GoogleService-Info" | grep -v "README" > /dev/null; then
    echo "❌ 에러: GoogleService-Info.plist는 커밋할 수 없습니다!"
    exit 1
fi

exit 0
```

실행 권한 부여:
```bash
chmod +x .git/hooks/pre-commit
```

---

## 💻 로컬 개발 환경

### 초기 설정 보안 체크리스트

- [ ] `.env.template`을 복사하여 `.env` 생성
- [ ] xcconfig 템플릿 복사하여 실제 파일 생성
- [ ] Firebase 설정 파일 다운로드 및 배치
- [ ] 실제 API Keys 입력
- [ ] `.gitignore` 확인 (민감 파일 제외 확인)
- [ ] 파일 권한 설정 (`chmod 600 Config/*.xcconfig`)

### 파일 권한 설정

민감한 파일은 읽기 전용으로 설정:

```bash
# xcconfig 파일
chmod 600 Config/Dev.xcconfig
chmod 600 Config/Stage.xcconfig
chmod 600 Config/Prod.xcconfig

# .env 파일
chmod 600 .env
chmod 600 infra/firebase/functions/.env

# Firebase 설정
chmod 600 Config/GoogleService-Info-*.plist
```

### 로컬 백업

**주기**: 매월 1회

```bash
# Config 파일 백업 (암호화)
zip -er ~/Backups/Promiso-Config-$(date +%Y%m%d).zip Config/*.xcconfig Config/GoogleService-Info-*.plist .env infra/firebase/functions/.env

# 암호 입력 프롬프트 표시됨
# 강력한 암호 사용 (16자 이상, 특수문자 포함)
```

---

## 🤖 CI/CD 보안

### GitHub Actions Secrets 관리

**Secrets 등록 위치**: Repository Settings → Secrets and variables → Actions

#### 필수 Secrets 목록

**iOS 배포**:
```
APP_STORE_CONNECT_API_KEY              # P8 파일 (Base64)
APP_STORE_CONNECT_API_KEY_ID           # API Key ID
APP_STORE_CONNECT_API_KEY_ISSUER_ID    # Issuer ID
FASTLANE_USER                          # Apple ID
FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD
MATCH_PASSWORD                         # 인증서 암호
MATCH_GIT_BASIC_AUTHORIZATION         # Deploy Key
```

**Firebase 배포**:
```
FIREBASE_TOKEN                         # CLI Token
FIREBASE_SERVICE_ACCOUNT_STAGE        # Service Account JSON
FIREBASE_SERVICE_ACCOUNT_PROD         # Service Account JSON
```

**API Keys (환경별)**:
```
GOOGLE_CLIENT_ID_DEV
GOOGLE_REVERSED_CLIENT_ID_DEV
KAKAO_NATIVE_APP_KEY_DEV
KAKAO_REST_API_KEY_DEV

GOOGLE_CLIENT_ID_STAGE
GOOGLE_REVERSED_CLIENT_ID_STAGE
KAKAO_NATIVE_APP_KEY_STAGE
KAKAO_REST_API_KEY_STAGE

GOOGLE_CLIENT_ID_PROD
GOOGLE_REVERSED_CLIENT_ID_PROD
KAKAO_NATIVE_APP_KEY_PROD
KAKAO_REST_API_KEY_PROD
```

**Firebase 설정 (Base64)**:
```
GOOGLE_SERVICE_INFO_DEV
GOOGLE_SERVICE_INFO_STAGE
GOOGLE_SERVICE_INFO_PROD
```

#### Secrets 업데이트 방법

**GitHub CLI 사용**:
```bash
# 단일 값
gh secret set SECRET_NAME -b"actual_value"

# 파일에서 읽기
gh secret set SECRET_NAME < file.txt

# Base64 인코딩 (P8, plist)
base64 -i AuthKey_ABC123.p8 | gh secret set APP_STORE_CONNECT_API_KEY

# JSON 파일 (Service Account)
cat firebase-service-account-stage.json | gh secret set FIREBASE_SERVICE_ACCOUNT_STAGE
```

**웹 UI 사용**:
1. Repository → Settings → Secrets and variables → Actions
2. "New repository secret" 클릭
3. Name과 Value 입력
4. "Add secret" 클릭

### CI/CD 로그 보안

**주의사항**:
- GitHub Actions 로그에 민감 정보 노출 금지
- `echo $SECRET` 절대 사용하지 않기
- 에러 메시지에 API Keys 포함 여부 확인

**안전한 로깅**:
```bash
# ❌ 위험
echo "API Key: $GOOGLE_CLIENT_ID_DEV"

# ✅ 안전
echo "Google Client ID가 설정되었습니다."

# ✅ 마스킹된 값만 표시
echo "API Key: ${GOOGLE_CLIENT_ID_DEV:0:10}..."
```

---

## 👥 팀원 온보딩/오프보딩

### 온보딩 (신규 팀원 합류)

**체크리스트**:

- [ ] Notion 백업 페이지 접근 권한 부여 (Read Only)
- [ ] GitHub Repository 접근 권한 부여
- [ ] Slack 채널 초대
- [ ] Config 파일 백업 공유 (암호화 zip)
- [ ] 로컬 환경 설정 가이드 제공
- [ ] 보안 교육 실시 (이 문서 숙지)
- [ ] 서명된 보안 서약서 수령

**설정 지원**:
1. 저장소 클론
2. Config 파일 생성 (템플릿 또는 백업)
3. 빌드 및 실행 확인
4. 문제 발생 시 지원

### 오프보딩 (퇴사자 발생)

**즉시 조치 (당일)**:

- [ ] Notion 접근 권한 제거
- [ ] GitHub Repository 접근 제거
- [ ] Slack 채널 제거
- [ ] Apple Developer 계정 제거 (App Store Connect)
- [ ] Firebase 프로젝트 권한 제거

**긴급 키 교체 (48시간 이내)**:

- [ ] 모든 API Keys 재발급 (Google, Kakao 등)
- [ ] Firebase Token 재발급
- [ ] App Store Connect API Key 재발급 (P8)
- [ ] Match Password 변경
- [ ] Slack Webhook URL 재발급

**팀원 공지 (72시간 이내)**:

- [ ] 새 Config 파일 배포
- [ ] GitHub Actions Secrets 업데이트 완료 공지
- [ ] 로컬 환경 재설정 가이드 공유

---

## 🚨 보안 사고 대응

### 민감 정보 노출 시 대응 절차

#### 1단계: 즉시 조치 (발견 후 1시간 이내)

**Git에 커밋된 경우**:
```bash
# 1. 커밋 취소 (아직 push 안 한 경우)
git reset HEAD~1

# 2. 이미 push한 경우 - 히스토리에서 제거
git filter-branch --force --index-filter \
  "git rm --cached --ignore-unmatch Config/Dev.xcconfig" \
  --prune-empty --tag-name-filter cat -- --all

# 3. Force push (위험! 팀원과 협의 후)
git push origin --force --all

# 4. GitHub에서 완전 삭제 확인
# Settings → Security → Secret scanning alerts 확인
```

**Public Repository에 노출된 경우**:
1. Repository를 즉시 Private으로 전환
2. 노출된 모든 키 즉시 무효화
3. 새로운 키 발급 및 교체
4. GitHub Support에 캐시 삭제 요청

#### 2단계: 피해 평가 (1~4시간)

- [ ] 어떤 정보가 노출되었는가?
- [ ] 노출된 기간은?
- [ ] 접근한 사람은?
- [ ] 악용 가능성은?

#### 3단계: 키 교체 (4~24시간)

**우선순위 높음** (즉시 교체):
- Firebase Token
- App Store Connect API Key
- Service Account Keys

**우선순위 중간** (24시간 이내):
- Google Client ID
- Kakao API Keys
- Gemini API Key

**우선순위 낮음** (48시간 이내):
- Slack Webhook URL
- Notion API Key

#### 4단계: 재발 방지

- [ ] .gitignore 재확인
- [ ] Pre-commit Hook 설정
- [ ] 팀원 보안 교육
- [ ] 사고 보고서 작성
- [ ] 프로세스 개선

### 연락처

**보안 사고 발생 시 즉시 연락**:
- 담당자: [이름]
- 긴급 연락처: [전화번호]
- Slack: @[username] 또는 #promiso-security

---

## 🔍 정기 점검

### 월간 점검 (매월 1일)

- [ ] .gitignore 확인 (민감 파일 제외 여부)
- [ ] GitHub Actions Secrets 유효성 확인
- [ ] Config 파일 백업 (로컬)
- [ ] Notion 백업 페이지 업데이트 확인

### 분기별 점검 (3/6/9/12월 1일)

- [ ] API Keys 만료일 확인
- [ ] 팀원 접근 권한 검토 (Notion, GitHub, Firebase)
- [ ] 퇴사자 권한 제거 확인
- [ ] 보안 정책 업데이트 검토
- [ ] CI/CD 로그 점검 (민감 정보 노출 여부)

### 연간 점검 (매년 1월)

- [ ] **모든 API Keys 로테이션** (재발급)
- [ ] Firebase Security Rules 감사
- [ ] App Store Connect API Key 갱신
- [ ] Match Password 변경
- [ ] 보안 교육 실시
- [ ] 보안 정책 전면 검토

### 점검 체크리스트 템플릿

```markdown
## 보안 점검 [YYYY-MM-DD]

### 점검자
- 이름: [이름]
- 날짜: [날짜]

### 점검 항목
- [ ] .gitignore 확인
- [ ] GitHub Secrets 유효성
- [ ] Config 백업
- [ ] Notion 업데이트
- [ ] 팀원 권한 검토
- [ ] CI/CD 로그 확인

### 발견 사항
[이슈가 있으면 기록]

### 조치 사항
[취한 조치 기록]

### 다음 점검일
[날짜]
```

---

## 📚 관련 문서

- [Config 디렉토리 README](Config/README.md)
- [Notion 백업 템플릿](docs/SECRETS_BACKUP_NOTION.md)
- [로컬 환경 설정](docs/LOCAL_SETUP.md)
- [백업 체크리스트](docs/BACKUP_CHECKLIST.md)

---

## 📞 보안 문의

**일반 문의**:
- Slack: #promiso-security
- Email: [이메일]

**긴급 사고**:
- 담당자: [이름]
- 긴급 연락처: [전화번호]
- Slack DM: @[username]

---

## 📝 보안 정책 변경 이력

| 날짜 | 변경 내용 | 작성자 |
|------|----------|--------|
| 2026-02-04 | 초기 보안 정책 작성 | Claude Sonnet 4.5 |
| [날짜] | [내용] | [이름] |

---

**마지막 검토일**: 2026-02-04
**다음 검토 예정일**: 2026-03-01 (월간)
**작성자**: Claude Sonnet 4.5
