# WS1: 온보딩 카피 + Calendar 연동 + 홈 첫 액션 유도

**브랜치**: `feat/onboarding-calendar` (release/v1.2.0에서 분기)
**난이도**: M | **기간**: Day 1~4
**의존성**: 없음 (1번째 머지)

---

## 작업 개요

이 워크스페이스는 4개의 독립적인 서브태스크로 구성됩니다.

| 서브태스크 | 내용 | 난이도 |
|------------|------|--------|
| 1-A | 온보딩 ①~⑥ 카피 비서 톤 전환 | S |
| 1-B | Calendar 연동 유도 화면 (Auth 이후 마지막 단계) | M |
| 1-C | 홈 첫 액션 유도 Bottom Sheet | M |
| 1-D | Calendar 미연동 배너 | S |

---

## 1-A. 온보딩 ①~⑥ 카피 비서 톤 전환

온보딩 6개 화면의 카피를 "비서 프레이밍" 톤으로 전환합니다. 기존 기능 설명 중심에서 사용자 대신 처리해주는 비서 관점으로 바꿉니다.

### 변경 대상 파일 및 내용

#### ① CinematicHeroView
- **파일**: `Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/CinematicHeroView.swift`
- **변경 없음** — 기존 카피 유지

#### ② ProblemEmpathyView
- **파일**: `Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/ProblemEmpathyView.swift`
- **상단 카피** (라인 28-29 근처)
  - AS-IS: `"약속 하나에 앱 N개"`
  - TO-BE: `"약속 하나 잡으려면"`
- **하단 카피** (라인 78-83 근처)
  - AS-IS: `"같은 약속인데 이렇게 흩어져 있어요"`
  - TO-BE: `"이제 Promiso 하나면 돼요"`

#### ③ BenefitConfirmView
- **파일**: `Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/BenefitConfirmView.swift`
- **상단 카피** (라인 33-34, 36-37 근처)
  - AS-IS: `"함께 잡는 약속, 인원이 모이면 자동 확정"`
  - TO-BE: `"약속 잡느라 매번 연락하지 마세요"`
- **하단 카피** (라인 63-64, 66-67 근처)
  - AS-IS: `"확정되면 모두에게 알림이 가요"`
  - TO-BE: `"Promiso가 대신 모으고, 알려줘요"`
- **Push 배너** (라인 203 근처)
  - AS-IS 제목: `"🎓 대학 동기 모임 일정 확정! 🎉"`
  - AS-IS 본문: `"내일 오후 6:00에 만나요!"`
  - TO-BE 제목: `"Promiso가 약속을 확정했어요"`
  - TO-BE 본문: `"따로 연락 안 해도 돼요. 내일 오후 6:00에 만나요!"`

#### ④ BenefitHomeView
- **파일**: `Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/BenefitHomeView.swift`
- **카피** (라인 44-49 근처)
  - AS-IS 메인: `"Promiso가 알아서 챙길게요"`
  - AS-IS 서브: `"그룹 약속도, 개인 일정도, 응답할 것까지"`
  - TO-BE 메인: `"열기만 하면, 오늘 뭐 할지 다 보여요"`
  - TO-BE 서브: `"캘린더 일정도, 친구 약속도, 한 곳에서"`

#### ⑤ BenefitLiveView
- **파일**: `Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/BenefitLiveView.swift`
- **카피** (라인 93-99 근처)
  - AS-IS 메인: `"약속 당일엔, 이런 것까지"`
  - AS-IS 서브: `"각자 상태만 공유하면 잠금화면에서도 확인돼요"`
  - TO-BE 메인: `"약속 당일, '지금 어디야?' 안 물어도 돼요"`
  - TO-BE 서브: `"Promiso가 모두의 상태를 알아서 보여줘요"`

#### ⑥ BenefitProView
- **파일**: `Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/BenefitProView.swift`
- **카피** (라인 40-41, 43-44 근처)
  - AS-IS 메인: `"똑똑한 일정 비서, Pro"`
  - AS-IS 서브: `"날씨, 충돌, 출발 시간까지 알아서 챙겨요"`
  - TO-BE 메인: `"비서가 더 똑똑해져요"`
  - TO-BE 서브: `"교통, 출발 시간, 매일 브리핑까지"`

### Localizable.xcstrings 처리

카피가 xcstrings에 키로 등록된 경우 해당 키 값도 동일하게 변경합니다.
xcstrings 수정 시 **Edit 도구로 필요한 부분만 수정** — 전체 재직렬화 금지.

---

## 1-B. Calendar 연동 유도 화면 (신규 화면 추가)

### 화면 진입 위치

Auth 이후 권한 요청 단계의 **마지막 스텝**으로 추가합니다.

```
Auth → ProfileSetup → NotificationPermission → CalendarConnect (신규) → Main(RootTab)
```

Benefit 화면들 사이가 아닙니다. Auth 플로우 완료 후 권한 요청 단계입니다.

### 플로우 컨트롤러 수정

- **파일**: `AppEntryFeature.swift` (또는 Auth 플로우 컨트롤러 파일)
- NotificationPermission 완료 후 → `CalendarConnect`로 전환
- CalendarConnect 완료/스킵 후 → `Main(RootTab)`으로 이동

수정 대상을 찾는 방법: `NotificationPermission` 처리 후 `Main` 혹은 `RootTab`으로 전환하는 코드를 찾아 중간에 `CalendarConnect` 단계를 삽입합니다.

### 신규 파일: CalendarConnectView + Reducer

**위치**: `Projects/Features/AppEntryFeature/Sources/Auth/` 하위 (NotificationPermission과 동일한 디렉토리)

**파일명 예시**:
- `CalendarConnectFeature.swift`
- `CalendarConnectView.swift`

#### Reducer (CalendarConnectFeature)

```swift
@Reducer
struct CalendarConnectFeature {
    @ObservableState
    struct State: Equatable {
        var authorizationStatus: EKAuthorizationStatus = .notDetermined
        var importedEventCount: Int = 0
        var isLoading: Bool = false
    }

    @CasePathable
    enum Action {
        case view(ViewAction)
        case _internal(InternalAction)
        case delegate(DelegateAction)
    }

    @CasePathable
    enum ViewAction {
        case connectTapped
        case skipTapped
    }

    @CasePathable
    enum InternalAction {
        case authorizationResponse(EKAuthorizationStatus)
        case fetchEventsResponse(Int)  // 가져온 이벤트 개수
    }

    @CasePathable
    enum DelegateAction {
        case completed  // 연동 완료 또는 스킵
    }

    @Dependency(\.eventKitClient) var eventKitClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .view(.connectTapped):
                state.isLoading = true
                return .run { send in
                    let status = await eventKitClient.requestAccess()
                    await send(._internal(.authorizationResponse(status)))
                }

            case .view(.skipTapped):
                return .send(.delegate(.completed))

            case ._internal(.authorizationResponse(let status)):
                state.authorizationStatus = status
                if status == .authorized || status == .fullAccess {
                    return .run { send in
                        let now = Date()
                        let oneYear = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now
                        let events = try? await eventKitClient.fetchEvents(now, oneYear)
                        await send(._internal(.fetchEventsResponse(events?.count ?? 0)))
                    }
                } else {
                    state.isLoading = false
                    return .send(.delegate(.completed))
                }

            case ._internal(.fetchEventsResponse(let count)):
                state.isLoading = false
                state.importedEventCount = count
                // 성공 피드백 후 0.8초 뒤 완료
                return .run { send in
                    try? await Task.sleep(for: .milliseconds(800))
                    await send(.delegate(.completed))
                }

            case .delegate:
                return .none
            }
        }
    }
}
```

#### View (CalendarConnectView)

**UI 요구사항**:
- 헤더: `"먼저 기존 일정 가져올게요"` (비서 톤)
- 서브: `"Promiso가 캘린더 일정을 읽어서 약속과 함께 보여드려요"`
- 캘린더 아이콘 또는 일러스트 (SF Symbol: `calendar`)
- CTA 버튼: `"캘린더 연결하기"`
- 스킵 버튼: `"나중에 하기"` (텍스트 버튼)
- 연동 성공 후: `"일정 N개를 가져왔어요"` 피드백 텍스트 표시
- iOS 26 Glass Effect 분기 필수 (`#available(iOS 26)`)
- 색상: `Color.pm*` 사용 (하드코딩 금지)

#### 재활용 API (이미 존재하는 Client)

```swift
// EventKitClient — 이미 존재하는 API
eventKitClient.requestAccess()               // EKAuthorizationStatus 반환
eventKitClient.fetchEvents(startDate:endDate:) // [EKEvent] 반환
eventKitClient.authorizationStatus()         // 현재 상태 확인
```

`@Dependency(\.eventKitClient)` 로 주입합니다.

---

## 1-C. 홈 첫 액션 유도 Bottom Sheet

처음 앱을 사용하는 유저(Promiso 약속이 0개인 경우)에게 약속 만들기를 유도하는 바텀 시트입니다.

### 트리거 조건

- **Promiso 약속(promises) 개수 = 0** 인 경우에만 표시
- Apple Calendar 일정 개수는 무관
- `@Shared(.appStorage("firstActionSheetShown"))` 로 1회만 표시

### HomeFeature.swift 수정

**파일**: `Projects/Features/HomeFeature/Sources/HomeFeature.swift`

> **주의**: HomeFeature.swift는 WS2(briefing 영역), WS4(departure 영역)도 수정합니다.
> 이 워크스페이스는 **calendar state, banner, sheet 영역만** 수정합니다.
> departure 영역(하단)과 briefing 영역은 절대 건드리지 않습니다.

추가할 State:

```swift
@ObservableState
struct State: Equatable {
    // 기존 state ...

    // [WS1] 첫 액션 유도 시트
    var showFirstActionSheet: Bool = false
    @Shared(.appStorage("firstActionSheetShown")) var firstActionSheetShown: Bool = false

    // [WS1] Calendar 배너
    var calendarAuthorizationStatus: EKAuthorizationStatus = .notDetermined
}
```

추가할 ViewAction:

```swift
enum ViewAction {
    // 기존 action ...

    // [WS1]
    case firstActionSheetDismissed
    case createFirstScheduleTapped
    case calendarConnectBannerTapped
    case calendarConnectBannerDismissed
}
```

Reducer 로직:

```swift
case .view(.firstActionSheetDismissed):
    state.showFirstActionSheet = false
    state.$firstActionSheetShown.withLock { $0 = true }
    return .none

case .view(.createFirstScheduleTapped):
    state.showFirstActionSheet = false
    state.$firstActionSheetShown.withLock { $0 = true }
    // 약속 만들기 화면으로 이동 (기존 createSchedule delegate 재활용)
    return .send(.delegate(.createScheduleTapped))

case .view(.calendarConnectBannerTapped):
    // 설정 앱으로 이동 또는 CalendarConnect 화면 present
    return .run { _ in
        await UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
    }

case .view(.calendarConnectBannerDismissed):
    state.calendarAuthorizationStatus = .denied  // 배너 숨김 처리
    return .none
```

홈 진입 시 첫 액션 시트 트리거 (기존 onAppear/task 로직에 추가):

```swift
// promises 로드 완료 후
if !state.firstActionSheetShown && state.promises.isEmpty {
    state.showFirstActionSheet = true
}
// calendar 상태 확인
state.calendarAuthorizationStatus = await eventKitClient.authorizationStatus()
```

### HomeRootView.swift 수정

**파일**: `Projects/Features/HomeFeature/Sources/HomeRootView.swift`

바텀 시트 표시:

```swift
.sheet(isPresented: $store.showFirstActionSheet.sending(\.view.firstActionSheetDismissed)) {
    FirstActionSheet(store: store)
}
```

Calendar 배너 표시 (조건부):

```swift
// 홈 상단 또는 적절한 위치에
if store.calendarAuthorizationStatus != .authorized && store.calendarAuthorizationStatus != .fullAccess {
    CalendarConnectBanner(
        onTap: { store.send(.view(.calendarConnectBannerTapped)) },
        onDismiss: { store.send(.view(.calendarConnectBannerDismissed)) }
    )
}
```

### 신규 파일: FirstActionSheet.swift

**위치**: `Projects/Features/HomeFeature/Sources/Components/FirstActionSheet.swift`

**UI 요구사항**:
- 제목: `"첫 약속을 만들어볼까요?"`
- 서브: `"Promiso와 함께 첫 약속을 잡아봐요"`
- Calendar 연동 완료 상태인 경우 추가 문구: `"캘린더 일정도 함께 보여드릴게요"`
- 주요 CTA: `"약속 만들기"` 버튼 (`.pmPrimary` 스타일)
- 보조 액션: `"나중에"` 텍스트 버튼 → dismiss
- iOS 26 Glass Effect 분기 (`#available(iOS 26)`)
- `.contentShape(Rectangle())` 탭 영역 설정

```swift
struct FirstActionSheet: View {
    let store: StoreOf<HomeFeature>

    var body: some View {
        VStack(spacing: 24) {
            // 아이콘
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Color.pmPrimary)

            // 텍스트
            VStack(spacing: 8) {
                Text("첫 약속을 만들어볼까요?")
                    .font(.title2.bold())
                    .foregroundStyle(Color.pmLabel)
                Text("Promiso와 함께 첫 약속을 잡아봐요")
                    .font(.subheadline)
                    .foregroundStyle(Color.pmSecondaryLabel)
            }

            // CTA
            Button {
                store.send(.view(.createFirstScheduleTapped))
            } label: {
                Text("약속 만들기")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.pmPrimary)
            .contentShape(Rectangle())

            // 스킵
            Button {
                store.send(.view(.firstActionSheetDismissed))
            } label: {
                Text("나중에")
                    .foregroundStyle(Color.pmSecondaryLabel)
            }
            .contentShape(Rectangle())
        }
        .padding(24)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
```

---

## 1-D. Calendar 미연동 배너

Calendar 권한이 없는 유저에게 홈 상단에 배너를 표시합니다.

### 신규 파일: CalendarConnectBanner.swift

**위치**: `Projects/Features/HomeFeature/Sources/Components/CalendarConnectBanner.swift`

**UI 요구사항**:
- 메시지: `"캘린더를 연동하면 비서가 더 똑똑해져요"`
- 오른쪽: `"연결하기"` 텍스트 버튼
- X 버튼으로 영구 닫기
- iOS 26 Glass Effect 분기 (`#available(iOS 26)`)

```swift
struct CalendarConnectBanner: View {
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(Color.pmPrimary)

            Text("캘린더를 연동하면 비서가 더 똑똑해져요")
                .font(.footnote)
                .foregroundStyle(Color.pmLabel)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("연결하기") {
                onTap()
            }
            .font(.footnote.bold())
            .foregroundStyle(Color.pmPrimary)
            .contentShape(Rectangle())

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.footnote)
                    .foregroundStyle(Color.pmSecondaryLabel)
            }
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            if #available(iOS 26, *) {
                // Glass Effect
                RoundedRectangle(cornerRadius: 12)
                    .glassEffect()
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.pmSurface)
            }
        }
        .padding(.horizontal, 16)
    }
}
```

---

## 컨벤션 체크리스트

구현 전 반드시 `.ai/CONVENTIONS.md` 확인. 핵심 항목:

| 항목 | 규칙 |
|------|------|
| TCA Reducer | Namespace 패턴 (`@Reducer struct XFeature`) |
| Action 구조 | `view` / `_internal` / `delegate` 3분할 |
| Observable | `@ObservableState` (BindingState 금지) |
| Effect | `Effect.run { }` 사용 (`.task`, `.fireAndForget` 금지) |
| 색상 | `Color.pm*` 사용 (하드코딩 금지) |
| Glass Effect | `#available(iOS 26)` 분기 필수 |
| 탭 영역 | `.contentShape(Rectangle())` |
| Firebase 직접 호출 | Feature에서 금지 — Client 레이어 통과 필수 |

---

## 빌드 확인

작업 완료 후:

```bash
make test-module MODULE=AppEntryFeature
make test-module MODULE=HomeFeature
```

빌드 실패 시 즉시 수정합니다.

---

## 주요 파일 경로 요약

| 파일 | 작업 |
|------|------|
| `Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/ProblemEmpathyView.swift` | 1-A 카피 수정 |
| `Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/BenefitConfirmView.swift` | 1-A 카피 수정 |
| `Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/BenefitHomeView.swift` | 1-A 카피 수정 |
| `Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/BenefitLiveView.swift` | 1-A 카피 수정 |
| `Projects/Features/AppEntryFeature/Sources/Onboarding/Screens/BenefitProView.swift` | 1-A 카피 수정 |
| `AppEntryFeature.swift` (플로우 컨트롤러) | 1-B 플로우 수정 |
| `Projects/Features/AppEntryFeature/Sources/Auth/CalendarConnectFeature.swift` | 1-B 신규 생성 |
| `Projects/Features/AppEntryFeature/Sources/Auth/CalendarConnectView.swift` | 1-B 신규 생성 |
| `Projects/Features/HomeFeature/Sources/HomeFeature.swift` | 1-C, 1-D state/action 추가 |
| `Projects/Features/HomeFeature/Sources/HomeRootView.swift` | 1-C, 1-D UI 연결 |
| `Projects/Features/HomeFeature/Sources/Components/FirstActionSheet.swift` | 1-C 신규 생성 |
| `Projects/Features/HomeFeature/Sources/Components/CalendarConnectBanner.swift` | 1-D 신규 생성 |

---

## HomeFeature.swift 수정 범위 제한 (중요)

HomeFeature.swift는 여러 워크스페이스가 동시에 수정하는 파일입니다.

- WS1(이 작업): calendar state, banner, sheet 영역
- WS2: briefing 영역
- WS4: departure 영역

**이 워크스페이스에서 절대 건드리지 않을 영역**:
- departure 관련 코드 (WS4 담당)
- briefing 관련 코드 (WS2 담당)

수정 시 명확하게 `// [WS1]` 주석을 추가하여 병합 충돌 시 구분이 쉽도록 합니다.
