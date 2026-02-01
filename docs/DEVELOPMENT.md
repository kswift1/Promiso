# 개발 가이드

> Promiso 프로젝트의 Feature 개발, 테스트, 컨벤션에 대한 종합 가이드

## 목차

- [1. 개발 시작하기](#1-개발-시작하기)
- [2. Feature 개발 가이드](#2-feature-개발-가이드)
- [3. 테스트 작성](#3-테스트-작성)
- [4. 코드 컨벤션](#4-코드-컨벤션)
- [5. 디버깅 팁](#5-디버깅-팁)
- [6. 성능 최적화](#6-성능-최적화)

---

## 1. 개발 시작하기

### 1.1 환경 설정

#### 필수 요구사항

- **Xcode**: 26.0+
- **Swift**: 6.2+
- **iOS 타겟**: 18.0+
- **Tuist**: 4.65.7+

#### 초기 설정

```bash
# 1. 저장소 클론
git clone https://github.com/kswift1/Promiso.git
cd Promiso

# 2. Tuist 설치 (없는 경우)
curl -Ls https://install.tuist.io | bash

# 3. 의존성 설치 및 프로젝트 생성
tuist install
tuist generate

# 4. Xcode에서 열기
open Promiso.xcworkspace
```

### 1.2 Tuist 기본 명령어

```bash
# 프로젝트 생성
tuist generate

# 의존성 설치 (SPM 패키지)
tuist install

# 빌드
tuist build                    # 전체 빌드
tuist build Promiso           # 메인 앱 빌드
tuist build GroupFeature      # 특정 Feature 빌드

# 테스트
tuist test                     # 전체 테스트
tuist test GroupFeatureTests   # 특정 Feature 테스트

# 캐시 정리
tuist clean
```

### 1.3 Makefile 명령어

```bash
# Feature 관리
make feature FEATURE_NAME=Notification           # Feature 생성
make remove-feature FEATURE_NAME=Notification    # Feature 삭제

# 개발 도구
make deps                      # 의존성 그래프 시각화
make color                     # 컬러 에셋 재생성

# Firebase
make emulator-start            # Firebase 에뮬레이터 실행
make functions-build           # Functions 빌드
make functions-api-preview     # OpenAPI 미리보기

# 도움말
make help
```

---

## 2. Feature 개발 가이드

### 2.1 Feature 생성

#### 자동 생성 (권장)

```bash
# Makefile 사용 (권장)
make feature FEATURE_NAME=Notification

# 또는 Tuist Scaffold 직접 사용
tuist scaffold feature --name Notification
```

생성되는 구조:

```
Projects/Features/NotificationFeature/
├── Project.swift                           # Tuist 프로젝트 설정
├── Sources/
│   ├── NotificationFeature.swift           # TCA Reducer
│   ├── NotificationView.swift              # SwiftUI View (optional)
│   └── ExportedImports.swift               # 재수출 의존성
└── Tests/
    └── Sources/
        └── NotificationFeatureTests.swift  # 테스트 파일
```

### 2.2 TCA Feature 구조

#### Namespace 패턴 (필수)

모든 Feature는 Namespace enum을 사용합니다.

```swift
import ComposableArchitecture

// MARK: - Feature Namespace

public enum Notification {}

// MARK: - Feature Implementation

extension Notification {

  // MARK: - Reducer

  @Reducer
  public struct Feature {

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      public var notifications: [NotificationItem] = []
      public var isLoading: Bool = false
      public var errorMessage: String?

      public init() {}
    }

    // MARK: - Action

    public enum Action {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
    }

    public enum View: Sendable {
      case onAppear
      case notificationTapped(NotificationItem.ID)
      case refreshTapped
    }

    public enum Internal: Sendable {
      case notificationsResponse(Result<[NotificationItem], Error>)
    }

    public enum Delegate: Equatable {
      case notificationSelected(NotificationItem)
    }

    // MARK: - Dependencies

    @Dependency(\.notificationClient) var notificationClient

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {

        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            state.isLoading = true
            state.errorMessage = nil
            return .run { send in
              await send(.internal(.notificationsResponse(
                Result { try await notificationClient.fetchNotifications() }
              )))
            }

          case let .notificationTapped(id):
            guard let notification = state.notifications.first(where: { $0.id == id }) else {
              return .none
            }
            return .send(.delegate(.notificationSelected(notification)))

          case .refreshTapped:
            return .send(.view(.onAppear))
          }

        case .internal(let internalAction):
          switch internalAction {
          case let .notificationsResponse(.success(notifications)):
            state.isLoading = false
            state.notifications = notifications
            return .none

          case let .notificationsResponse(.failure(error)):
            state.isLoading = false
            state.errorMessage = error.localizedDescription
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}
```

#### Action 계층 구조 (필수)

모든 Action은 3가지 카테고리로 분리:

1. **View**: 사용자 인터랙션
   - 네이밍: `View` 또는 `ViewAction` (둘 다 허용)
   - `Sendable` 프로토콜 준수 필수

2. **Internal**: 내부 상태 변경 및 비동기 응답
   - 네이밍: `Internal` 또는 `InternalAction` (둘 다 허용)
   - `Sendable` 프로토콜 준수 필수

3. **Delegate**: 부모 Feature와 통신
   - 네이밍: `Delegate` 또는 `DelegateAction` (둘 다 허용)
   - `Equatable` 프로토콜 준수

### 2.3 View 작성 가이드

#### 기본 구조

```swift
extension Notification {
  public struct RootView: View {

    let store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          headerSection
          notificationList
        }
        .padding()
      }
      .auroraBackground()  // 주요 화면에 적용
      .navigationTitle("알림")
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - View Builders

    @ViewBuilder
    private var headerSection: some View {
      HStack {
        Text("알림 센터")
          .font(.title)
          .fontWeight(.bold)
        Spacer()
        refreshButton
      }
    }

    @ViewBuilder
    private var notificationList: some View {
      if store.isLoading {
        ProgressView()
      } else if let error = store.errorMessage {
        ErrorView(message: error)
      } else {
        ForEach(store.notifications) { notification in
          NotificationRow(notification: notification) {
            store.send(.view(.notificationTapped(notification.id)))
          }
        }
      }
    }

    @ViewBuilder
    private var refreshButton: some View {
      Button {
        store.send(.view(.refreshTapped))
      } label: {
        Image(systemName: "arrow.clockwise")
          .font(.headline)
      }
      .disabled(store.isLoading)
    }
  }
}

// MARK: - Preview

#Preview {
  Notification.RootView(
    store: Store(initialState: Notification.Feature.State()) {
      Notification.Feature()
    }
  )
}
```

#### UI 스타일 규칙

##### 색상 사용 (Critical)

```swift
// ✅ 올바른 사용 - Color.pm* 필수
Color.pmindigo.n500       // Indigo 스케일 (n50 ~ n900)
Color.pmaurora.purple     // Aurora 색상
Color.pmaurora.indigo
Color.pmaurora.pink
Color.pmbrand.primary     // 브랜드 색상
Color.pmbrand.secondary
Color.pmpurple.n500       // Purple 스케일

// ❌ 금지 - 하드코딩 색상
Color(red: 0.5, green: 0.3, blue: 0.8)
Color(UIColor.systemBlue)
Color(hex: "1A1A2E")
```

##### Glass Effect + Fallback (Critical)

```swift
// iOS 26+ Glass Effect 사용 시 반드시 Fallback 포함
if #available(iOS 26.0, *) {
  content
    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
} else {
  content
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
}
```

##### Aurora Background (권장)

```swift
// 로그인, 메인 탭, 모달 등 주요 화면에 적용
var body: some View {
  ScrollView {
    // 콘텐츠
  }
  .auroraBackground()
}
```

##### Button 탭 영역 확보 (Critical)

```swift
// Spacer를 포함한 Button은 반드시 .contentShape() 추가
Button {
  // action
} label: {
  HStack {
    Text("Label")
    Spacer()  // ← 이 부분도 탭 가능하게
  }
  .contentShape(Rectangle())  // ← 필수!
}
```

### 2.4 의존성 주입

#### Client 생성

```swift
// Projects/Clients/NotificationClient/Sources/NotificationClient.swift

import ComposableArchitecture
import Foundation

@DependencyClient
public struct NotificationClient {
  public var fetchNotifications: @Sendable () async throws -> [NotificationItem]
  public var markAsRead: @Sendable (NotificationItem.ID) async throws -> Void
  public var deleteNotification: @Sendable (NotificationItem.ID) async throws -> Void
}

// MARK: - Live Implementation

extension NotificationClient: DependencyKey {
  public static let liveValue = Self(
    fetchNotifications: {
      // Firebase/API 실제 구현
      let db = Firestore.firestore()
      let snapshot = try await db.collection("notifications").getDocuments()
      return snapshot.documents.compactMap { doc in
        try? doc.data(as: NotificationItem.self)
      }
    },
    markAsRead: { id in
      let db = Firestore.firestore()
      try await db.collection("notifications").document(id).updateData([
        "isRead": true
      ])
    },
    deleteNotification: { id in
      let db = Firestore.firestore()
      try await db.collection("notifications").document(id).delete()
    }
  )
}

// MARK: - Test & Preview Values

extension NotificationClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    fetchNotifications: { NotificationItem.mocks },
    markAsRead: { _ in },
    deleteNotification: { _ in }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var notificationClient: NotificationClient {
    get { self[NotificationClient.self] }
    set { self[NotificationClient.self] = newValue }
  }
}
```

#### Feature에서 사용

```swift
@Reducer
public struct Feature {

  @Dependency(\.notificationClient) var notificationClient

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .view(.onAppear):
        return .run { send in
          let notifications = try await notificationClient.fetchNotifications()
          await send(.internal(.notificationsResponse(.success(notifications))))
        } catch: { error, send in
          await send(.internal(.notificationsResponse(.failure(error))))
        }

      // ...
      }
    }
  }
}
```

### 2.5 Feature 간 통신 (Delegate 패턴)

#### Parent Feature (Coordinator)

```swift
@Reducer
public struct RootTab {

  @Reducer
  public enum Destination {
    case notification(Notification.Feature)
    case settings(Settings.Feature)
  }

  @ObservableState
  public struct State: Equatable {
    @Presents var destination: Destination.State?
  }

  public enum Action {
    case view(View)
    case destination(PresentationAction<Destination.Action>)
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {

      case .view(.notificationButtonTapped):
        state.destination = .notification(Notification.Feature.State())
        return .none

      // Child Feature의 Delegate 처리
      case .destination(.presented(.notification(.delegate(.notificationSelected(let item))))):
        // 알림 선택 시 처리
        state.destination = nil
        return .run { send in
          // 상세 화면으로 이동 등
        }

      case .destination:
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}
```

---

## 3. 테스트 작성

### 3.1 Swift Testing 사용

Promiso는 **Swift Testing** 프레임워크를 사용합니다 (`import Testing`).

#### 기본 테스트 구조

```swift
import ComposableArchitecture
import Testing
@testable import NotificationFeature

@Suite("Notification Feature Tests")
@MainActor
struct NotificationFeatureTests {

  @Test("사용자가 화면에 진입하면 알림 목록을 로드한다")
  func testOnAppear() async {
    let store = TestStore(initialState: Notification.Feature.State()) {
      Notification.Feature()
    } withDependencies: {
      // Mock 의존성 주입
      $0.notificationClient.fetchNotifications = {
        [.mock1, .mock2]
      }
    }

    // When
    await store.send(.view(.onAppear)) {
      $0.isLoading = true
      $0.errorMessage = nil
    }

    // Then
    await store.receive(\.internal.notificationsResponse.success) {
      $0.isLoading = false
      $0.notifications = [.mock1, .mock2]
    }
  }

  @Test("알림 탭 시 delegate 이벤트가 전달된다")
  func testNotificationTapped() async {
    let store = TestStore(
      initialState: Notification.Feature.State(
        notifications: [.mock1, .mock2]
      )
    ) {
      Notification.Feature()
    }

    // When
    await store.send(.view(.notificationTapped(.mock1.id)))

    // Then
    await store.receive(\.delegate.notificationSelected) {
      #expect($0 == .mock1)
    }
  }

  @Test("네트워크 에러 시 에러 메시지가 표시된다")
  func testNetworkError() async {
    let store = TestStore(initialState: Notification.Feature.State()) {
      Notification.Feature()
    } withDependencies: {
      $0.notificationClient.fetchNotifications = {
        throw URLError(.notConnectedToInternet)
      }
    }

    await store.send(.view(.onAppear)) {
      $0.isLoading = true
      $0.errorMessage = nil
    }

    await store.receive(\.internal.notificationsResponse.failure) {
      $0.isLoading = false
      $0.errorMessage != nil
    }
  }
}
```

### 3.2 Mock 데이터 작성

#### Model+Mock.swift 패턴

```swift
// NotificationItem+Mock.swift
extension NotificationItem {
  static let mock1 = NotificationItem(
    id: "1",
    title: "새 메시지",
    message: "그룹에 초대되었습니다",
    timestamp: Date(),
    isRead: false
  )

  static let mock2 = NotificationItem(
    id: "2",
    title: "약속 알림",
    message: "내일 약속이 있습니다",
    timestamp: Date().addingTimeInterval(-3600),
    isRead: true
  )

  static let mocks = [mock1, mock2]
}
```

### 3.3 TestStore 고급 기법

#### exhaustivity 설정

```swift
let store = TestStore(initialState: State()) {
  Feature()
}

// 특정 Action만 검증하고 나머지는 무시
store.exhaustivity = .off

// 또는 특정 케이스만 검증
store.exhaustivity = .off(showSkippedAssertions: true)
```

#### confirmation으로 비동기 검증

```swift
@Test("API 호출 횟수 검증")
func testAPICallCount() async {
  await confirmation("API called exactly once", expectedCount: 1) { @Sendable confirm in
    let store = Store(initialState: Notification.Feature.State()) {
      Notification.Feature()
    } withDependencies: {
      $0.notificationClient.fetchNotifications = {
        confirm()
        return [.mock1]
      }
    }

    await store.send(.view(.onAppear))
    try? await Task.sleep(for: .milliseconds(100))
  }
}
```

### 3.4 테스트 실행

```bash
# 전체 테스트
tuist test

# 특정 Feature 테스트
tuist test NotificationFeatureTests

# Xcode에서 실행
# Cmd + U (전체 테스트)
# Cmd + 6 → Test Navigator → 개별 테스트 실행
```

---

## 4. 코드 컨벤션

### 4.1 Swift 스타일 가이드

#### 들여쓰기 및 포맷팅

```swift
// ✅ 올바른 스타일
// - 들여쓰기: 2 spaces
// - 네이밍: camelCase (변수/함수), PascalCase (타입)
// - 공백: 연산자 앞뒤 1칸

public struct NotificationFeature {
  public var notifications: [NotificationItem] = []

  public func fetchNotifications() async throws {
    let items = try await client.fetch()
    self.notifications = items
  }
}

// ❌ 잘못된 스타일
public struct NotificationFeature{  // ← 중괄호 전 공백 필요
  public var Notifications:[NotificationItem]=[]  // ← 네이밍, 공백

  public func FetchNotifications()async throws{  // ← 네이밍, 공백
    let Items=try await client.fetch()  // ← 네이밍, 공백
    self.Notifications=Items  // ← 공백
  }
}
```

#### 네이밍 규칙

```swift
// ✅ 올바른 네이밍
let userName: String
func fetchUserProfile() async throws
class UserProfileManager

// ❌ 잘못된 네이밍 (축약)
let usrName: String
let btn: UIButton
let lbl: UILabel
```

### 4.2 TCA 1.22.2 필수 API

#### 사용할 것 (✅)

```swift
@Reducer struct MyFeature { }
@ObservableState struct State { }
enum Action: ViewAction { }
@Dependency(\.client) var client
Effect.run { }
Effect.send()
```

#### 사용하지 말 것 (❌ Critical)

```swift
@BindingState        // → @ObservableState 사용
.task { }            // → Effect.run { } 사용
.fireAndForget { }   // → Effect.run { } 사용
```

### 4.3 강제 언래핑 금지 (Critical)

```swift
// ❌ 금지
let user = users.first!
let id = notification.id!

// ✅ 올바른 방법
guard let user = users.first else {
  return .none
}

guard let id = notification.id else {
  return .none
}
```

### 4.4 Git 커밋 메시지 규칙

#### 포맷

```
<type>: <subject>    ← 한글, 50자 이내

<body>

Co-Authored-By: Claude <모델명> <noreply@anthropic.com>
```

#### Type 규칙 (소문자)

- `feat`: 새 기능
- `fix`: 버그 수정
- `refactor`: 리팩터링 (기능 변경 없음)
- `test`: 테스트 추가/수정
- `docs`: 문서 변경
- `chore`: 빌드/설정 변경
- `style`: 코드 포맷팅 (로직 변경 없음)

#### 예시

```bash
✅ 올바른 예시:
feat: 알림 설정 Feature 추가
fix: 그룹 목록 중복 렌더링 버그 수정
refactor: FirestoreClient 쿼리 로직 개선

❌ 잘못된 예시:
Add notification settings feature    # 영어 금지
feat: 알림 설정 기능을 추가했습니다  # 명령형 아님
알림 설정 추가                        # type 없음
```

### 4.5 컨벤션 자동 검사

#### Critical 검사 스크립트

```bash
# TCA Deprecated API
grep -rn "@BindingState\|\.task\s*{\|\.fireAndForget" --include="*.swift" .

# 강제 언래핑
grep -rn "!" --include="*.swift" . | grep -v "!="

# 하드코딩 색상
grep -rn "Color(red:\|Color(UIColor" --include="*.swift" .

# Glass Effect Fallback 누락
grep -l "\.glassEffect" --include="*.swift" . | xargs grep -L "#available(iOS 26"

# Button contentShape 누락
grep -l "Spacer()" --include="*.swift" . | xargs grep -L "contentShape"
```

#### Warning 검사 스크립트

```bash
# 축약 네이밍
grep -rn "\(btn\|lbl\|txt\|img\)" --include="*.swift" .

# print 문
grep -rn "print(" --include="*.swift" .

# 500라인 이상 파일
find . -name "*.swift" -exec wc -l {} \; | awk '$1 > 500 {print $2}'
```

---

## 5. 디버깅 팁

### 5.1 Xcode Breakpoint

```swift
// 조건부 Breakpoint
// Breakpoint Navigator → Right Click → Edit Breakpoint
// Condition: state.isLoading == true

// 로그 메시지 Breakpoint
// Breakpoint Navigator → Right Click → Edit Breakpoint
// Add Action: Log Message
// Message: Action received: @action@
```

### 5.2 TCA Reducer Debugging

```swift
public var body: some ReducerOf<Self> {
  Reduce { state, action in
    // ...
  }
  ._printChanges()  // State 변경 사항 출력
}
```

### 5.3 Firebase Emulator 사용

```bash
# Firebase Emulator 실행
make emulator-start

# 브라우저에서 Emulator UI 열기
# http://127.0.0.1:4000

# Firestore 데이터 확인
# Auth 사용자 관리
# Functions 로그 확인
```

### 5.4 의존성 그래프 확인

```bash
# 의존성 그래프 시각화
make deps

# 순환 참조 확인
# 생성된 PDF 파일에서 화살표 방향 확인
```

### 5.5 빌드 에러 해결

#### "Module not found" 에러

```bash
# 1. Tuist 캐시 정리
tuist clean

# 2. 프로젝트 재생성
tuist generate

# 3. Xcode 재시작
```

#### "Duplicate symbols" 에러

```bash
# Tuist 의존성 재설치
tuist install
tuist generate
```

---

## 6. 성능 최적화

### 6.1 State 최적화

#### State는 최소한으로 유지

```swift
// ❌ 비효율적 - 불필요한 State
@ObservableState
public struct State: Equatable {
  var notifications: [NotificationItem] = []
  var notificationCount: Int = 0  // ← 계산 가능한 값
  var hasNotifications: Bool = false  // ← 계산 가능한 값
}

// ✅ 효율적 - 계산 프로퍼티 사용
@ObservableState
public struct State: Equatable {
  var notifications: [NotificationItem] = []

  var notificationCount: Int {
    notifications.count
  }

  var hasNotifications: Bool {
    !notifications.isEmpty
  }
}
```

#### Equatable 최적화

```swift
@ObservableState
public struct State: Equatable {
  var largeArray: [Item] = []
  var metadata: Metadata = Metadata()

  // ⚠️ Equatable이 큰 배열을 비교하면 성능 저하
  // → IdentifiedArray 사용 권장
  var items: IdentifiedArrayOf<Item> = []
}
```

### 6.2 Effect 최적화

#### 불필요한 API 호출 방지

```swift
public var body: some ReducerOf<Self> {
  Reduce { state, action in
    switch action {
    case .view(.onAppear):
      // ❌ 매번 API 호출
      return .run { send in
        let items = try await client.fetch()
        await send(.internal(.itemsResponse(items)))
      }

      // ✅ 캐시 확인 후 필요시에만 호출
      if !state.items.isEmpty {
        return .none  // 이미 데이터가 있으면 호출 안 함
      }
      return .run { send in
        let items = try await client.fetch()
        await send(.internal(.itemsResponse(items)))
      }
    }
  }
}
```

#### Effect 취소 관리

```swift
enum CancelID { case fetchData }

public var body: some ReducerOf<Self> {
  Reduce { state, action in
    switch action {
    case .view(.searchTextChanged(let text)):
      // 이전 검색 취소
      return .run { send in
        try await Task.sleep(for: .milliseconds(300))  // Debounce
        let results = try await client.search(text)
        await send(.internal(.searchResults(results)))
      }
      .cancellable(id: CancelID.fetchData, cancelInFlight: true)

    case .view(.cancelSearch):
      return .cancel(id: CancelID.fetchData)
    }
  }
}
```

### 6.3 SwiftUI 최적화

#### LazyVStack/LazyHStack 사용

```swift
// ❌ 비효율적 - 모든 뷰를 즉시 생성
ScrollView {
  VStack {
    ForEach(items) { item in
      ItemRow(item: item)
    }
  }
}

// ✅ 효율적 - 필요할 때만 생성 (Lazy Loading)
ScrollView {
  LazyVStack {
    ForEach(items) { item in
      ItemRow(item: item)
    }
  }
}
```

#### ViewBuilder 분리

```swift
// ❌ body가 복잡하면 재계산 비용 증가
var body: some View {
  VStack {
    // 200줄의 뷰 코드...
  }
}

// ✅ ViewBuilder로 분리
var body: some View {
  VStack {
    headerSection
    contentSection
    footerSection
  }
}

@ViewBuilder
private var headerSection: some View {
  // ...
}

@ViewBuilder
private var contentSection: some View {
  // ...
}
```

#### onAppear/onDisappear 최적화

```swift
// ❌ 중복 실행 가능
.onAppear {
  store.send(.view(.onAppear))
}
.onAppear {
  store.send(.view(.trackScreenView))
}

// ✅ 한 번만 실행되도록
.task {
  await store.send(.view(.onAppear)).finish()
  await store.send(.view(.trackScreenView)).finish()
}
```

### 6.4 Firebase 최적화

#### Firestore 쿼리 최적화

```swift
// ❌ 전체 문서 조회 후 필터링
let allPromises = try await db.collection("promises").getDocuments()
let userPromises = allPromises.documents.filter { doc in
  (doc.data()["userId"] as? String) == userId
}

// ✅ 서버 측 필터링
let query = db.collection("promises")
  .whereField("userId", isEqualTo: userId)
  .limit(to: 50)
let snapshot = try await query.getDocuments()
```

#### 인덱스 활용

```bash
# Firestore 콘솔에서 복합 인덱스 생성
# Collection: promises
# Fields: userId (Ascending), createdAt (Descending)
# Query scope: Collection
```

---

## 참고 문서

- [프로젝트 아키텍처](ARCHITECTURE.md)
- [환경 설정](ENVIRONMENT.md)
- [CI/CD 가이드](CI_CD.md)
- [배포 가이드](DEPLOYMENT.md)
- [TCA 공식 문서](https://pointfreeco.github.io/swift-composable-architecture/)
- [Point-Free Episodes](https://www.pointfree.co)

---

**마지막 업데이트**: 2026-02-01
