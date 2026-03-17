# WS4: 확정 애니메이션 + LA 격상 + 확정 후 자동 세팅

**브랜치**: `feat/confirm-animation-la-auto` (release/v1.2.0에서 분기)
**의존성**: WS1+WS2 완료 후 rebase. 4번째 머지.
**머지 순서**: WS1 머지 → WS2 rebase+머지 → WS4 rebase

---

## Phase A: 확정 애니메이션 (Day 1~3, 병렬 가능)

### ScheduleGlassCard.swift

경로: `Projects/Features/HomeFeature/Sources/Components/Timeline/ScheduleGlassCard.swift`

- 확정 상태(isConfirmed) 체크마크에 scale + opacity 트랜지션
- bounce 애니메이션: `.spring(response: 0.5, dampingFraction: 0.6)`
- `@State private var showConfirmedAnimation = false`, onAppear에서 트리거

### TodayScheduleCard.swift

경로: `Projects/Features/HomeFeature/Sources/Components/TodaySchedule/TodayScheduleCard.swift`

- 확정 일정의 타임라인 시각적 강조 (라인 컬러 + 서틀 펄스)
- TimelineItemView에 confirmed 상태 전달

### TimelineItemView.swift

경로: `Projects/Features/HomeFeature/Sources/Components/TodaySchedule/TimelineItemView.swift`

- `isConfirmed: Bool` 파라미터 추가
- 확정 시 왼쪽 라인 색상: `Color.green`
- 체크 아이콘 bounce 애니메이션

---

## Phase B: LA 격상 + 확정 후 자동 세팅 (Day 3~5, WS1+WS2 머지 후)

### HomeFeature.swift (departure 영역만)

경로: `Projects/Features/HomeFeature/Sources/HomeFeature.swift`

- 확정 이벤트 수신 시 자동 세팅 트리거
- **절대 건드리지 않을 영역**: calendar/banner/sheet (WS1), 브리핑 트리거 (WS2)

자동 세팅 파이프라인:

```
약속 확정 이벤트 수신
├── ① 날씨 조회 (WeatherClient) → 카드에 표시 (이미 구현됨, 연결만)
├── ② TransportationClient.getTransportation(fromLat, fromLng, toLat, toLng) → 이동시간 조회 → 출발시간 역산
├── ③ LocalNotificationClient.schedule(id, title, body, triggerDate, userInfo) → 로컬 알림 자동 등록
│   - 알림 문구: "{title}, 지금 나가시면 딱 맞아요"
│   - userInfo에 scheduleId 포함
├── ④ 알림 탭 → 딥링크로 LiveActivity 자동 시작
└── ⑤ 요약 알림: "약속 준비 완료. 날씨 확인했고, 출발 알림도 맞춰뒀어요"
```

---

## 재활용 API (수정 불필요)

- `TransportationClient.getTransportation(fromLat, fromLng, toLat, toLng) async throws -> TransportationResult`
  - TransportationResult: `transitRoutes[TransitRouteInfo]`, `driving(DrivingInfo?)`, `walkingMinutes`
- `LocalNotificationClient.schedule(id, title, body, triggerDate, userInfo) async throws`
- `LiveActivityClient.start(attributes, initialState) async throws -> String`
- `WeatherClient` — HomeFeature.swift에 이미 `@Dependency`로 있음 (기존 코드 사용만, 수정 없음)

---

## 알림 탭 딥링크

- 알림 userInfo: `["type": "departureReminder", "scheduleId": "xxx"]`
- 기존 딥링크 핸들러에서 type 분기 추가
- `departureReminder` → `LiveActivityClient.start` 호출

---

## 컨벤션

- TCA: Namespace 패턴, Action 3분할
- 애니메이션: `.spring()` 기반, `.easeInOut` 보조
- Glass Effect 분기 (`#available(iOS 26)`)
- 색상: `Color.pm*`
- 카피 톤: WS2 기준 따름
