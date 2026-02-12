# 위젯 (Widget) 도메인 규칙

> 상위 문서: [DOMAIN_RULES.md](../DOMAIN_RULES.md)

---

## 1. 제약 조건 (Constraints)

| ID | 규칙 | 값 | iOS | Backend |
|----|------|-----|:---:|:-------:|
| W1 | Widget Token 유효기간 | 30일 | — | ✅ |
| W2 | Widget Token 갱신 권장 | 만료 7일 전 | — | ✅ |
| W3 | Widget Token scope | `widget:read` (읽기 전용) | — | ✅ |
| W4 | 위젯 데이터 최대 | today + upcoming = 7개 | — | ✅ |
| W5 | 캐시 유효 기간 | 2시간 | ✅ | — |
| W6 | 수동 새로고침 최소 간격 | 15초 | ✅ | — |

---

## 2. 권한 (Permissions)

| ID | 규칙 | 조건 |
|----|------|------|
| W7 | 디바이스 바인딩 | deviceId 불일치 시 토큰 거부 |
| W8 | 토큰 버전 기반 무효화 | `widgetTokenVersion` increment로 기존 토큰 전체 무효화 |

---

## 3. 동작 규칙 (Behaviors)

| ID | 규칙 | 상세 |
|----|------|------|
| W9 | 과거 약속 표시 범위 | 종료 후 1시간까지 |
| W10 | 날짜 분류 | KST (Asia/Seoul) 기준 |
| W11 | Firebase ID 토큰 만료 마진 | 만료 5분 전 갱신 |

---

## 4. 표시 규칙 (Display)

| ID | 규칙 | 값 |
|----|------|-----|
| W12 | 위젯 딥링크 형식 | `promiso://promise?id={id}&groupId={groupId}` |
| W13 | 위젯 종류 | Small, Medium, Large (3종) |

---

## 5. 코드 매핑 (Code Mapping)

> 마지막 매핑: 2026-02-12

### 제약 조건

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| W1~W4 | — (Backend only) | — | — |
| W5 | `WidgetPromiseData.swift` `staleCacheThreshold = 2 * 60 * 60` + `isStale` | — | ❌ |
| W6 | `WidgetDataManager.swift` `manualRefreshTTL = 15.0` + `checkTTL()` | — | ❌ |

### 권한 / 동작 규칙

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| W7~W11 | — (Backend only 또는 iOS 간접 처리) | — | — |

### 표시 규칙

| ID | 구현 | 테스트 | 상태 |
|----|------|--------|:----:|
| W12 | `WidgetPromiseData.swift` `deeplinkURL` (`promiso://promise?id=&groupId=`) | — | ❌ |
| W13 | `SmallPromiseWidget.swift` / `MediumPromiseWidget.swift` / `LargePromiseWidget.swift` | Preview만 | ⚠️ |

### 핵심 파일

| 구현 파일 | 경로 | 관련 규칙 |
|----------|------|----------|
| WidgetPromiseData.swift | `Shared/Sources/Widget/` | W5,W12 |
| WidgetDataManager.swift | `Shared/Sources/Widget/` | W6 |
| SmallPromiseWidget.swift | `App/Extensions/PromiseWidget/Sources/Widgets/` | W13 |
| MediumPromiseWidget.swift | `App/Extensions/PromiseWidget/Sources/Widgets/` | W13 |
| LargePromiseWidget.swift | `App/Extensions/PromiseWidget/Sources/Widgets/` | W13 |
