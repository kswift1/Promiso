# Firebase에서 Rust로: iOS 앱 서버 마이그레이션기

> Promiso iOS 앱의 Firebase 백엔드를 Rust 서버로 교체하는 전체 과정을 기록합니다.

## 시리즈 진행 상태

- [x] #1 왜 Firebase를 떠나는가 — 동기, 기술 선택, 마이그레이션 전략
- [x] #2 서버 뼈대 잡기 — 인프라 선택(DB, 배포, 인증, 스토리지)부터 Axum + SQLx 환경 구축까지
- [x] #3 그룹 API 구현 — Firestore → PostgreSQL 스키마 설계 + 초대/가입/권한 로직
- [x] #4 일정 API 구현 — 개인일정/그룹일정 스키마 + 응답/확정 상태 머신
- [x] #5 알림과 푸시 — FCM 직접 발송 + 배지 + 그룹별 설정
- [ ] #6 실시간과 LiveActivity — SSE + APNs 직접 발송 + ETA 공유
- [ ] #7 나머지 기능 — 위젯, 쿠폰, AI 브리핑, 배포 파이프라인
- [ ] #8 점진적 전환 — Branch by Abstraction으로 Dev → Stage → Prod
- [ ] #9 인증 자체 구현 — Firebase Auth → Apple/Google OAuth + JWT (선택적)
- [ ] #10 회고 — Firebase vs 자체 서버, 실제로 뭐가 달라졌나

## 메모

- 한글: velog | 영어: Medium
- 시리즈명 (한): "Firebase에서 Rust로: iOS 앱 서버 마이그레이션기"
- 시리즈명 (영): "From Firebase to Rust: An iOS App Server Migration"
- Rust 프로젝트: `infra/rust-backend/`
- 포스트 파일: `docs/blog/{순번}-{slug}.md` (한글) / `{순번}-{slug}.en.md` (영어)
