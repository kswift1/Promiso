# Firebase에서 Rust로: iOS 앱 서버 마이그레이션기

> Promiso iOS 앱의 Firebase 백엔드를 Rust 서버로 교체하는 전체 과정을 기록합니다.

## 시리즈 진행 상태

### Phase 1 — 왜, 그리고 어떻게

- [ ] #1 왜 Firebase를 떠나는가 — 비용, 성능, 한계 그리고 결심
- [ ] #2 아키텍처 설계 — Firestore에서 PostgreSQL로, Functions에서 Axum으로
- [ ] #3 개발 환경 세팅 — Rust, Docker, PostgreSQL 로컬 환경 구축

### Phase 2 — 서버의 뼈대

- [ ] #4 첫 번째 API 서버 — Axum Hello World에서 라우터 구조까지
- [ ] #5 에러 처리 설계 — Cloud Functions의 HttpsError를 대체하는 방법
- [ ] #6 DB 연결 — SQLx로 PostgreSQL 붙이기

### Phase 3 — 인증 마이그레이션

- [ ] #7 Firebase Auth 없이 로그인 — Apple Sign In 서버 검증 직접 구현
- [ ] #8 Google Sign In 서버 검증
- [ ] #9 JWT 설계 — Access Token, Refresh Token, 그리고 위젯용 토큰까지

### Phase 4 — 데이터 마이그레이션

- [ ] #10 스키마 설계 — Firestore 비정규화에서 PostgreSQL 정규화로
- [ ] #11 마이그레이션 도구 — Firestore 데이터를 PostgreSQL로 옮기기
- [ ] #12 Firebase Storage → Cloud Storage presigned URL

### Phase 5 — 핵심 API 마이그레이션

- [ ] #13 유저 API — createUser, deleteUser를 Functions에서 Rust로
- [ ] #14 그룹 API — 초대 코드, 호스트 양도, 멤버 추방까지
- [ ] #15 약속 API — 투표 로직과 확정 판정
- [ ] #16 개인 일정 API — 반복 일정 포함
- [ ] #17 알림 — Firestore 트리거를 대체하는 이벤트 기반 FCM 발송

### Phase 6 — 실시간 & 고급 기능

- [ ] #18 실시간 업데이트 — Firestore Listener에서 WebSocket으로
- [ ] #19 LiveActivity — APNs Push to Start 직접 구현
- [ ] #20 예약 작업 — Cloud Tasks 없이 LiveActivity 스케줄링
- [ ] #21 일정 충돌 감지 — Firestore 트리거에서 SQL 쿼리로
- [ ] #22 구독 검증 — StoreKit Server API + 자체 entitlement 관리
- [ ] #23 AI 브리핑 — Gemini API 연동

### Phase 7 — 배포 & 전환

- [ ] #24 Cloud Run 배포 — Dockerfile부터 auto-scaling까지
- [ ] #25 CI/CD — GitHub Actions로 자동 배포 파이프라인
- [ ] #26 iOS Client 교체 — Firebase SDK를 걷어내고 REST로
- [ ] #27 데이터 전환 실행 — 무중단 마이그레이션 전략
- [ ] #28 회고 — Firebase vs 자체 서버, 실제로 뭐가 달라졌나

## 메모

- 블로그 플랫폼: Medium
- 시리즈명: "Firebase에서 Rust로: iOS 앱 서버 마이그레이션기"
- Rust 프로젝트: `infra/rust-backend/`
- 포스트 파일: `docs/blog/{순번}-{slug}.md`
