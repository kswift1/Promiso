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
