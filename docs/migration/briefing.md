# Briefing 도메인 마이그레이션

## Firebase Functions → Rust 매핑

| 기존 경로 | Rust 엔드포인트 | 상태 |
|---|---|---|
| `generateBriefing` | `POST /api/v1/briefing/generate` | ✅ 완료 |

## iOS 클라이언트 전환 상태

| 클라이언트 | 현재 경로 | 상태 |
|---|---|---|
| `BriefingClient.generate` | Rust briefing API | ✅ Rust 고정 |

메모:

- `BriefingClient`의 Firebase Functions fallback은 제거됐다.

## 남은 항목

- 브리핑 관련 운영/어드민 경로가 추가되면 Rust API 기준으로만 확장
- iOS `Clients` scheme 실기기/시뮬레이터 검증

## 검증 현황

- iOS:
  - 현재 이 머신의 Xcode에는 iOS 26.4 simulator platform이 없어 `Clients` scheme unit test는 실행 불가
