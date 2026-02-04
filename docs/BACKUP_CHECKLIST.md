# API Keys & Secrets 백업 체크리스트

> **Promiso** - 민감 정보 백업 및 관리 체크리스트

---

## 📅 정기 백업 일정

| 주기 | 날짜 | 담당자 | 작업 |
|------|------|--------|------|
| **월간** | 매월 1일 | [담당자] | Config 파일 백업, Notion 업데이트 확인 |
| **분기** | 3/6/9/12월 1일 | [담당자] | API Keys 만료일 확인, 팀원 권한 검토 |
| **연간** | 매년 1월 1일 | [관리자] | 모든 API Keys 로테이션, 보안 정책 검토 |

---

## 📋 월간 백업 체크리스트 (매월 1일)

### 1️⃣ Config 파일 백업

- [ ] Config 디렉토리 파일 확인
  ```bash
  ls -la Config/
  ```

- [ ] 백업 zip 파일 생성 (암호화)
  ```bash
  zip -er ~/Backups/Promiso-Config-$(date +%Y%m%d).zip \
    Config/*.xcconfig \
    Config/GoogleService-Info-*.plist \
    .env \
    infra/firebase/functions/.env
  ```

- [ ] 암호 기록 (1Password 또는 별도 문서)
- [ ] 백업 파일 안전한 곳에 저장 (iCloud Drive, Google Drive 등)

### 2️⃣ Notion 백업 페이지 확인

- [ ] Notion 페이지 접속
- [ ] 최근 업데이트 날짜 확인
- [ ] 모든 API Keys가 최신 상태인지 확인
- [ ] 첨부 파일들이 손상되지 않았는지 확인
- [ ] 마지막 검증일 업데이트

### 3️⃣ .gitignore 검증

- [ ] 민감 파일이 .gitignore에 등록되어 있는지 확인
  ```bash
  cat .gitignore | grep -E "xcconfig|GoogleService|\.env|\.p8"
  ```

- [ ] Git status 확인 (민감 파일이 staged 되지 않았는지)
  ```bash
  git status
  ```

### 4️⃣ GitHub Actions Secrets 확인

- [ ] Repository → Settings → Secrets 접속
- [ ] 모든 필수 Secrets가 등록되어 있는지 확인
  - iOS 배포 관련 (8개)
  - Firebase 배포 관련 (3개)
  - API Keys Dev (4개)
  - API Keys Stage (4개)
  - API Keys Prod (4개)
  - Firebase 설정 Base64 (3개)
  - 기타 (2개)

- [ ] Secrets 만료 여부 확인 (해당되는 경우)

### 5️⃣ CI/CD 로그 확인

- [ ] 최근 GitHub Actions 실행 로그 확인
- [ ] 민감 정보가 노출되지 않았는지 검토
- [ ] 에러 메시지에 API Keys가 포함되지 않았는지 확인

---

## 📋 분기별 점검 체크리스트 (3/6/9/12월 1일)

### 1️⃣ API Keys 만료일 확인

- [ ] Google OAuth Client ID 만료일 확인
- [ ] Kakao API Keys 만료일 확인
- [ ] Firebase Token 만료일 확인
- [ ] App Store Connect API Key 만료일 확인
- [ ] 만료 예정 키가 있으면 재발급 계획 수립

### 2️⃣ 팀원 접근 권한 검토

#### Notion
- [ ] Notion 백업 페이지 접근 권한 목록 확인
- [ ] 퇴사자 권한 제거 확인
- [ ] 신규 팀원 권한 부여 필요 여부 확인

#### GitHub
- [ ] Repository Collaborators 목록 확인
- [ ] 퇴사자 제거 확인
- [ ] 신규 팀원 추가 필요 여부 확인
- [ ] Repository Secrets 접근 기록 확인

#### Firebase
- [ ] 각 프로젝트(Dev/Stage/Prod)의 IAM 권한 확인
- [ ] 불필요한 계정 제거
- [ ] 최소 권한 원칙 준수 여부 확인

#### Apple Developer
- [ ] App Store Connect 팀원 목록 확인
- [ ] 역할 및 권한 적절성 검토

### 3️⃣ 보안 정책 업데이트

- [ ] SECURITY.md 문서 검토
- [ ] 새로운 보안 위협 반영
- [ ] 팀원들에게 변경사항 공지
- [ ] 보안 교육 필요 여부 확인

### 4️⃣ 백업 복구 테스트

- [ ] 백업 zip 파일 압축 해제 테스트
- [ ] Config 파일 복원 테스트
- [ ] 빌드 및 실행 확인
- [ ] 복구 프로세스 문서 업데이트 (필요시)

---

## 📋 연간 점검 체크리스트 (매년 1월)

### 1️⃣ 모든 API Keys 로테이션

#### Google OAuth
- [ ] Dev 환경 Client ID 재발급
- [ ] Stage 환경 Client ID 재발급
- [ ] Prod 환경 Client ID 재발급
- [ ] .env 파일 업데이트
- [ ] GitHub Secrets 업데이트
- [ ] Notion 백업 페이지 업데이트

#### Kakao API
- [ ] Dev 환경 Native App Key 재발급
- [ ] Stage 환경 Native App Key 재발급
- [ ] Prod 환경 Native App Key 재발급
- [ ] REST API Keys 재발급
- [ ] .env 파일 업데이트
- [ ] GitHub Secrets 업데이트

#### Firebase
- [ ] Firebase CLI Token 재발급
- [ ] Service Account Keys 재발급 (Stage/Prod)
- [ ] GitHub Secrets 업데이트
- [ ] CI/CD 테스트

#### 기타 API
- [ ] Gemini API Key 재발급
- [ ] Notion API Key 재발급
- [ ] Slack Webhook URL 재발급

#### Apple Certificates
- [ ] App Store Connect API Key 갱신
- [ ] Match Password 변경
- [ ] Distribution Certificate 갱신 (필요시)
- [ ] Provisioning Profile 갱신

### 2️⃣ Firebase Security Rules 감사

- [ ] Firestore Rules 검토
- [ ] Storage Rules 검토
- [ ] 불필요한 권한 제거
- [ ] 보안 취약점 패치
- [ ] Rules 테스트 실행

### 3️⃣ 보안 교육 실시

- [ ] 보안 정책 문서 공유
- [ ] API Keys 관리 교육
- [ ] Git 보안 교육
- [ ] CI/CD 보안 교육
- [ ] 사고 대응 절차 교육
- [ ] 교육 자료 업데이트

### 4️⃣ 보안 정책 전면 검토

- [ ] SECURITY.md 전면 검토
- [ ] .gitignore 검토 및 업데이트
- [ ] Pre-commit Hook 검토
- [ ] CI/CD 워크플로우 보안 검토
- [ ] 새로운 보안 도구 도입 검토

### 5️⃣ 문서 업데이트

- [ ] Notion 백업 템플릿 업데이트
- [ ] Config README 업데이트
- [ ] LOCAL_SETUP 가이드 업데이트
- [ ] 변경 이력 기록
- [ ] 팀원들에게 공지

---

## 📋 신규 API Key 추가 시 체크리스트

새로운 API Key나 Secret이 필요할 때:

### 1️⃣ API Key 발급

- [ ] 해당 서비스에서 API Key 발급
- [ ] 환경별로 분리 필요 여부 확인 (Dev/Stage/Prod)
- [ ] 권한 최소화 설정
- [ ] 만료일 설정 (가능한 경우)

### 2️⃣ 문서화

- [ ] Notion 백업 페이지에 추가
  - Key 이름
  - 값
  - 용도
  - 발급 위치
  - 만료일
  - 환경 (Dev/Stage/Prod)

- [ ] Config/README.md 업데이트
- [ ] SECURITY.md 업데이트 (필요시)

### 3️⃣ 템플릿 파일 업데이트

- [ ] `.env.template` 업데이트
  ```bash
  NEW_API_KEY_DEV=your-new-api-key-dev
  NEW_API_KEY_STAGE=your-new-api-key-stage
  NEW_API_KEY_PROD=your-new-api-key-prod
  ```

- [ ] `Config/*.xcconfig.template` 업데이트 (필요시)

### 4️⃣ 로컬 환경 설정

- [ ] `.env` 파일에 실제 값 추가
- [ ] `./scripts/generate-xcconfig.sh` 스크립트 업데이트 (필요시)
- [ ] 빌드 테스트

### 5️⃣ GitHub Secrets 등록

- [ ] Repository → Settings → Secrets에 추가
- [ ] `.github/workflows/*.yml` 파일 업데이트
- [ ] CI/CD 테스트

### 6️⃣ 팀원 공지

- [ ] Slack #promiso-dev 채널에 공지
- [ ] 새 API Key 추가 사실 공유
- [ ] 팀원들의 로컬 환경 업데이트 요청
- [ ] 질문 답변

---

## 📋 팀원 온보딩 시 체크리스트

새로운 팀원이 합류했을 때:

### 1️⃣ 접근 권한 부여

- [ ] GitHub Repository 초대 (적절한 권한)
- [ ] Notion 백업 페이지 공유 (Read Only)
- [ ] Slack 채널 초대 (#promiso-dev, #promiso-deploy)
- [ ] Firebase 프로젝트 권한 부여 (필요시)
- [ ] Apple Developer 계정 추가 (필요시)

### 2️⃣ 문서 공유

- [ ] LOCAL_SETUP.md 가이드 공유
- [ ] SECURITY.md 보안 정책 공유
- [ ] Config/README.md 설정 가이드 공유
- [ ] 개발 컨벤션 문서 공유

### 3️⃣ Config 파일 설정 지원

- [ ] Notion 백업 페이지 접근 확인
- [ ] Config 백업 zip 공유 (암호화)
- [ ] 로컬 환경 설정 지원
- [ ] 빌드 및 실행 확인

### 4️⃣ 보안 교육

- [ ] 보안 정책 설명
- [ ] Git 보안 규칙 교육
- [ ] API Keys 관리 방법 교육
- [ ] 사고 대응 절차 안내
- [ ] 서명된 보안 서약서 수령

### 5️⃣ 개발 환경 검증

- [ ] Xcode 설치 확인
- [ ] Tuist 설치 확인
- [ ] 빌드 성공 확인
- [ ] 시뮬레이터 실행 확인
- [ ] Git commit/push 권한 확인

---

## 📋 팀원 퇴사 시 체크리스트

팀원이 퇴사할 때:

### 1️⃣ 즉시 조치 (당일)

- [ ] Notion 백업 페이지 접근 제거
- [ ] GitHub Repository 접근 제거
- [ ] Slack 채널 제거
- [ ] Firebase IAM 권한 제거
- [ ] Apple Developer 계정 제거
- [ ] 기타 접근 권한 제거

### 2️⃣ 긴급 키 교체 계획 (48시간 이내)

- [ ] 교체할 API Keys 목록 작성
- [ ] 우선순위 지정 (높음/중간/낮음)
- [ ] 교체 일정 수립
- [ ] 팀원들에게 공지

### 3️⃣ API Keys 재발급 (48~72시간)

#### 높은 우선순위
- [ ] Firebase Token
- [ ] App Store Connect API Key
- [ ] Service Account Keys

#### 중간 우선순위
- [ ] Google Client ID (모든 환경)
- [ ] Kakao API Keys (모든 환경)
- [ ] Gemini API Key

#### 낮은 우선순위
- [ ] Slack Webhook URL
- [ ] Notion API Key

### 4️⃣ GitHub Secrets 업데이트

- [ ] 재발급된 모든 Keys를 GitHub Secrets에 업데이트
- [ ] CI/CD 워크플로우 테스트
- [ ] 배포 성공 확인

### 5️⃣ Config 파일 배포

- [ ] 새 Config 파일 생성
- [ ] 암호화 zip 파일 생성
- [ ] 팀원들에게 배포
- [ ] Notion 백업 페이지 업데이트

### 6️⃣ 팀원 공지

- [ ] Slack에 API Keys 교체 완료 공지
- [ ] 로컬 환경 재설정 가이드 공유
- [ ] 질문 답변
- [ ] 업데이트 확인

---

## 📋 보안 사고 발생 시 체크리스트

민감 정보 노출 등 보안 사고 발생 시:

### 1️⃣ 즉시 조치 (1시간 이내)

- [ ] 사고 내용 파악
  - 어떤 정보가 노출되었는가?
  - 언제 노출되었는가?
  - 누가 접근 가능한가?

- [ ] 노출된 정보 무효화
  - Git에 커밋된 경우: 히스토리에서 제거
  - Public repository: Private으로 전환
  - API Keys: 즉시 비활성화

- [ ] 관계자 통보
  - 팀 리더
  - 보안 담당자
  - 영향받는 팀원들

### 2️⃣ 피해 평가 (1~4시간)

- [ ] 노출 범위 확인
- [ ] 접근 로그 분석
- [ ] 악용 여부 확인
- [ ] 영향도 평가

### 3️⃣ 키 교체 (4~24시간)

- [ ] 노출된 모든 Keys 재발급
- [ ] GitHub Secrets 업데이트
- [ ] Config 파일 재배포
- [ ] Notion 백업 페이지 업데이트

### 4️⃣ 재발 방지

- [ ] .gitignore 재확인
- [ ] Pre-commit Hook 강화
- [ ] 보안 교육 실시
- [ ] 사고 보고서 작성
- [ ] 프로세스 개선

### 5️⃣ 문서화

- [ ] 사고 경위 기록
- [ ] 조치 내용 기록
- [ ] 재발 방지 대책 기록
- [ ] 팀원들과 공유

---

## 📝 체크리스트 기록 템플릿

### 월간 백업 기록

```markdown
## 월간 백업 - [YYYY-MM]

### 백업 실행
- 날짜: [YYYY-MM-DD]
- 담당자: [이름]

### 체크리스트
- [x] Config 파일 백업 완료
- [x] Notion 페이지 확인 완료
- [x] .gitignore 검증 완료
- [x] GitHub Secrets 확인 완료
- [x] CI/CD 로그 확인 완료

### 이슈
[발견된 이슈가 있으면 기록]

### 조치
[취한 조치 내용]

### 다음 백업 예정일
[YYYY-MM-DD]
```

### 분기별 점검 기록

```markdown
## 분기별 점검 - [YYYY-Q1/Q2/Q3/Q4]

### 점검 실행
- 날짜: [YYYY-MM-DD]
- 담당자: [이름]

### 체크리스트
- [x] API Keys 만료일 확인
- [x] 팀원 권한 검토 (Notion, GitHub, Firebase, Apple)
- [x] 보안 정책 업데이트
- [x] 백업 복구 테스트

### 만료 예정 Keys
[목록]

### 권한 변경 사항
[추가/제거된 팀원]

### 이슈 및 조치
[내용]

### 다음 점검 예정일
[YYYY-MM-DD]
```

---

## 📞 문의

백업 및 보안 관련 문의:

- **일반 문의**: #promiso-dev (Slack)
- **보안 사고**: [담당자 이름] (@username)
- **긴급 연락**: [전화번호]

---

**작성자**: Claude Sonnet 4.5
**마지막 업데이트**: 2026-02-04
**다음 월간 백업 예정일**: 2026-03-01
