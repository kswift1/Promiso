# Firebase에서 Rust로: iOS 앱 서버 마이그레이션기

> Promiso iOS 앱의 Firebase 백엔드를 Rust 서버로 교체하는 전체 과정을 기록합니다.

## 시리즈 진행 상태

- [x] #1 왜 Firebase를 떠나는가 — 동기, 기술 선택, 마이그레이션 전략
- [ ] #2 서버 뼈대 잡기 — 인프라 선택(DB, 배포, 인증, 스토리지)부터 Axum + SQLx 환경 구축까지
- [ ] #3 인증 직접 구현 — Firebase Auth에서 Apple/Google OAuth + JWT로
- [ ] #4 스키마 재설계 — Firestore 비정규화에서 PostgreSQL 정규화로
- [ ] #5 핵심 API 전환 — 유저/그룹/약속 50개 Functions를 Rust로
- [ ] #6 실시간과 푸시 — Firestore Listener → WebSocket, FCM + APNs 직접 발송
- [ ] #7 고급 기능 — LiveActivity, 일정 충돌, 구독 검증, AI 브리핑
- [ ] #8 배포 파이프라인 — Cloud Run + GitHub Actions CI/CD
- [ ] #9 점진적 전환 — Branch by Abstraction으로 Dev → Stage → Prod
- [ ] #10 회고 — Firebase vs 자체 서버, 실제로 뭐가 달라졌나

## 메모

- 한글: velog | 영어: Medium
- 시리즈명 (한): "Firebase에서 Rust로: iOS 앱 서버 마이그레이션기"
- 시리즈명 (영): "From Firebase to Rust: An iOS App Server Migration"
- Rust 프로젝트: `infra/rust-backend/`
- 포스트 파일: `docs/blog/{순번}-{slug}.md` (한글) / `{순번}-{slug}.en.md` (영어)
