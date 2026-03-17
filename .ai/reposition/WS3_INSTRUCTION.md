# WS3: 약속 시간 추천

**브랜치**: `feat/time-suggestion` (release/v1.2.0에서 분기)
**의존성**: 없음 (독립, 3번째 머지)

---

## 수정 파일

### CreateScheduleFeature.swift

경로: `Projects/Features/CreateScheduleFeature/Sources/Core/CreateScheduleFeature.swift`

- State에 `suggestedTimeSlots: [TimeSlot]` 추가
- EventKitClient `@Dependency` 추가
- ViewAction: `suggestedTimeTapped(TimeSlot)` → startDate 자동 설정
- InternalAction: `timeSlotsCalculated([TimeSlot])`
- CancelID에 `timeSlotCalculation` 추가
- 날짜 선택 시 Effect로 시간 추천 재계산 (디바운스 500ms)

### CreateScheduleStep2View.swift

경로: `Projects/Features/CreateScheduleFeature/Sources/Views/Step2/CreateScheduleStep2View.swift`

- StartDateTimeSection 위에 `TimeSlotChipsView` 조건부 표시 (`suggestedTimeSlots` 비어있지 않을 때)

---

## 신규 파일

### TimeSlotChipsView.swift

위치: `Projects/Features/CreateScheduleFeature/Sources/Views/Step2/TimeSlotChipsView.swift`

- 수평 ScrollView + Capsule 스타일 칩
- 칩 탭 → `suggestedTimeTapped` Action
- `Color.pmindigo.n500` 기본, 선택 시 filled
- 라벨: "토 오후 6시" 형식
- Glass Effect 분기 (`#available(iOS 26)`)

### TimeSlotCalculator.swift

위치: `Projects/Features/CreateScheduleFeature/Sources/Core/TimeSlotCalculator.swift`

- 순수 함수 (`static func`)
- 입력: `[CalendarEvent]`, `[ScheduleConflict]`, `Date` (기준일), `DateRange?`
- 출력: `[TimeSlot]`

### TimeSlot.swift

위치: `Projects/Features/CreateScheduleFeature/Sources/Models/TimeSlot.swift`

```swift
public struct TimeSlot: Equatable, Identifiable, Sendable {
  public var id: String { "\(startTime.timeIntervalSince1970)" }
  public let startTime: Date
  public let endTime: Date
  public let label: String // "토 오후 6시"
}
```

---

## 알고리즘

**기본 날짜 결정**
- Step2 진입 시 날짜 미선택 → 오늘 기준 향후 7일
- 날짜 선택 후 → 해당일

**추천 로직 (7단계)**

1. 기준 범위 결정
2. `EventKitClient.fetchEvents(기준 범위)` → Apple Calendar 이벤트 조회
3. `ScheduleConflictClient.checkConflicts(userId, 기준 범위)` → Promiso 일정 충돌 조회
4. 점유 시간대 병합
5. 09:00~22:00 빈 1시간 블록 추출
6. 랭킹: 주말 저녁 > 주말 오후 > 평일 저녁 > 평일 오후 > 기타
7. 상위 3개 반환

**Calendar 권한 없는 경우**: Promiso 데이터만으로 추천

---

## 재활용 API (수정 불필요)

### EventKitClient

```swift
EventKitClient.fetchEvents(startDate:endDate:) async throws -> [CalendarEvent]
```

`CalendarEvent` 프로퍼티: `id`, `title`, `startDate`, `endDate`, `location`, `isAllDay`

### ScheduleConflictClient

```swift
ScheduleConflictClient.checkConflicts(userId, startAt, endAt, excludeIds, minGapMinutes) async throws -> [ScheduleConflict]
```

`ScheduleConflict` 프로퍼티: `id`, `source`, `title`, `startAt`, `endAt`, `overlapMinutes`

---

## 컨벤션

- TCA: Namespace 패턴, Action 3분할 (View / Internal / Delegate)
- `@ObservableState` (not `@BindingState`)
- Glass Effect 분기 (`#available(iOS 26)`)
- 색상: `Color.pm*` (하드코딩 금지)
- Effect: `Effect.run { }` 사용 (`.task`, `.fireAndForget` 금지)
- Client 레이어 통과 (Feature에서 Firebase 직접 호출 금지)
- 테스트: `TimeSlotCalculator`는 순수 함수이므로 Swift Testing `@Test` + `#expect` 사용
