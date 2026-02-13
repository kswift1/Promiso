# 개발 가이드

> Promiso 프로젝트의 Feature 개발, 테스트, 컨벤션에 대한 종합 가이드

## 문서 메타

- 목적: 일상 개발 작업의 구현/테스트/컨벤션 기준 제공
- 대상 독자: iOS 기능 개발자
- 최종 수정일: 2026-02-13
- 관련 문서: [README.md](README.md) · [ARCHITECTURE.md](ARCHITECTURE.md) · [ENVIRONMENT.md](ENVIRONMENT.md)

## 범위 안내

- 이 문서: 기능 구현, 테스트, 코드 컨벤션
- 개발 환경 파일/키 구성: [ENVIRONMENT.md](ENVIRONMENT.md)
- 온보딩 초기 세팅: [SETUP_GUIDE.md](SETUP_GUIDE.md)

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
// 1. Namespace 선언
public enum Notification {}

// 2. Reducer 구현
extension Notification {
  @Reducer
  public struct Feature {
    @ObservableState
    public struct State: Equatable {
      public var notifications: [NotificationItem] = []
      public var isLoading = false
      // ...
    }

    public enum Action {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
    }

    // ViewAction, InternalAction, DelegateAction 정의
    public enum View: Sendable { /* ... */ }
    public enum Internal: Sendable { /* ... */ }
    public enum Delegate: Equatable { /* ... */ }

    @Dependency(\.notificationClient) var notificationClient

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        // Action 처리 로직
      }
    }
  }
}

// 3. View 구현
extension Notification {
  public struct RootView: View {
    let store: StoreOf<Feature>
    // UI 구현
  }
}
```

> 📘 **구조 상세**: [ARCHITECTURE.md - Features Layer](ARCHITECTURE.md#features-layer)

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

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          headerSection
          contentSection
        }
      }
      .auroraBackground()  // 주요 화면
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    @ViewBuilder
    private var headerSection: some View {
      // 헤더 구현
    }

    @ViewBuilder
    private var contentSection: some View {
      // 로딩/에러/데이터 표시 로직
    }
  }
}

#Preview {
  Notification.RootView(
    store: Store(initialState: Notification.Feature.State()) {
      Notification.Feature()
    }
  )
}
```

**View 작성 원칙**:
- `@ViewBuilder`로 섹션 분리 (가독성)
- Preview 필수 작성
- Store를 통한 단방향 데이터 흐름
- `.auroraBackground()` 주요 화면 적용

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
// 1. Client 인터페이스 정의
@DependencyClient
public struct NotificationClient {
  public var fetchNotifications: @Sendable () async throws -> [NotificationItem]
  public var markAsRead: @Sendable (NotificationItem.ID) async throws -> Void
  // ... 기타 메서드
}

// 2. Live 구현
extension NotificationClient: DependencyKey {
  public static let liveValue = Self(
    fetchNotifications: {
      // Firebase/API 실제 구현
    },
    // ...
  )
}

// 3. Test/Preview 구현
extension NotificationClient: TestDependencyKey {
  public static let testValue = Self()  // Mock
  public static let previewValue = Self(...)  // Preview용 데이터
}

// 4. 의존성 등록
extension DependencyValues {
  public var notificationClient: NotificationClient {
    get { self[NotificationClient.self] }
    set { self[NotificationClient.self] = newValue }
  }
}
```

**Client 작성 원칙**:
- `@DependencyClient`로 인터페이스 정의
- 모든 메서드에 `@Sendable` 표시
- liveValue, testValue, previewValue 모두 제공

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

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      // Child 화면 표시
      case .view(.showNotification):
        state.destination = .notification(...)
        return .none

      // Child Delegate 처리
      case .destination(.presented(.notification(.delegate(.selected(let item))))):
        state.destination = nil
        // 다른 Child에게 전달 또는 네비게이션
        return .none
      }
    }
    .ifLet(\.$destination, action: \.destination)
  }
}
```

**Parent Feature 역할**:
- 자식 Feature들 조합 및 네비게이션
- Delegate 이벤트 수신 및 중계
- 자식 간 통신 조율

> 📘 **구조 상세**: [ARCHITECTURE.md - Feature 간 통신](ARCHITECTURE.md#feature-간-통신)

---

## 3. 테스트 작성

### 3.1 BestPractice 참조

> **기준 파일**: `Projects/Features/AppEntryFeature/Tests/Sources/AppEntryFeatureTests.swift`

새 Feature 테스트 작성 시 이 파일의 패턴을 따릅니다.

- **테스트 설계 기준** (무엇을 테스트할지): [.ai/TEST_POLICY.md](../.ai/TEST_POLICY.md)
- **의존성/패턴 상세 규칙** (어떻게 테스트할지): [TESTING_DEPENDENCY_RULES.md](TESTING_DEPENDENCY_RULES.md)

### 3.2 핵심 규칙 요약

```swift
import Testing                      // Swift Testing 필수, XCTest 금지
@testable import {Name}Feature      // Feature 모듈만 의존

@Suite("{Name}.Feature 테스트")      // 한글 Suite 설명
@MainActor
struct {Name}FeatureTests {
  @Test("한글 설명")                  // 한글 @Test 설명
  func action_condition_result() async {  // 영어 함수명
    let store = TestStore(initialState: .init()) {
      Feature()
    } withDependencies: {
      $0.client.method = { ... }    // 필요한 것만 override
    }

    await store.send(.view(.action)) { $0.prop = value }
    await store.receive(\.internal.response) { $0.data = result }
  }
}
```

| 항목 | 규칙 |
|------|------|
| 프레임워크 | Swift Testing (`@Test`, `#expect`) — XCTest 금지 |
| import | `Testing` + `@testable import Feature`만 |
| exhaustivity | 기본 on, child reducer 영향 시에만 off |
| 구독 정리 | subscription 시작 시 `cancelSubscriptions` 필수 |
| 에러/조건 분기 | 성공/실패, 허용/거부 쌍으로 테스트 |
| 헬퍼 | `private extension`에 `make*` 팩토리, 체인 헬퍼 |
| 전역 상태 | `defer`로 원래 값 복원 |

### 3.3 테스트 실행

```bash
# 모듈 단위 테스트
make test-module MODULE={Name}Feature

# 전체 테스트
tuist test

# 특정 Feature 테스트
tuist test {Name}FeatureTests
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
// ❌ 계산 가능한 값을 State에 저장
var items: [Item] = []
var itemCount: Int = 0  // ← 불필요
var hasItems: Bool = false  // ← 불필요

// ✅ 계산 프로퍼티 사용
var items: [Item] = []
var itemCount: Int { items.count }
var hasItems: Bool { !items.isEmpty }
```

**원칙**:
- 계산 가능한 값은 State에 저장하지 않기
- 큰 배열은 `IdentifiedArrayOf<T>` 사용 (Equatable 최적화)
- 불필요한 State는 제거

### 6.2 Effect 최적화

#### 불필요한 API 호출 방지

```swift
case .view(.onAppear):
  // 캐시 확인
  if !state.items.isEmpty {
    return .none
  }
  // 필요시에만 호출
  return .run { ... }
```

#### Effect 취소 관리

```swift
enum CancelID { case search }

case .view(.searchTextChanged(let text)):
  return .run {
    try await Task.sleep(for: .milliseconds(300))  // Debounce
    let results = try await client.search(text)
    await send(.internal(.searchResults(results)))
  }
  .cancellable(id: CancelID.search, cancelInFlight: true)

case .view(.cancelSearch):
  return .cancel(id: CancelID.search)
```

**원칙**:
- 캐시 활용으로 중복 호출 방지
- `.cancellable`로 중복 요청 취소
- Debounce로 검색 최적화

### 6.3 SwiftUI 최적화

#### LazyVStack 사용

```swift
// ❌ 모든 뷰를 즉시 생성
ScrollView {
  VStack {
    ForEach(items) { ItemRow($0) }
  }
}

// ✅ Lazy Loading
ScrollView {
  LazyVStack {
    ForEach(items) { ItemRow($0) }
  }
}
```

#### ViewBuilder 분리

```swift
var body: some View {
  VStack {
    headerSection  // ← 분리
    contentSection
    footerSection
  }
}

@ViewBuilder
private var headerSection: some View { /* ... */ }
```

**원칙**:
- 긴 리스트는 `LazyVStack`/`LazyHStack`
- 복잡한 View는 `@ViewBuilder`로 분리
- `.task`로 중복 실행 방지

### 6.4 Firebase 최적화

#### Firestore 쿼리 최적화

```swift
// ❌ 클라이언트 측 필터링
let all = try await db.collection("promises").getDocuments()
let filtered = all.documents.filter { ... }

// ✅ 서버 측 필터링
let query = db.collection("promises")
  .whereField("userId", isEqualTo: userId)
  .limit(to: 50)
```

**원칙**:
- 서버 측 필터링 사용 (`.whereField`)
- `.limit()` 로 결과 제한
- 복합 인덱스 활용 (Firestore 콘솔에서 생성)

---

## 참고 문서

- [프로젝트 아키텍처](ARCHITECTURE.md)
- [환경 설정](ENVIRONMENT.md)
- [CI/CD 가이드](CI_CD.md)
- [배포 가이드](DEPLOYMENT.md)
- [TCA 공식 문서](https://pointfreeco.github.io/swift-composable-architecture/)
- [Point-Free Episodes](https://www.pointfree.co)

---

**마지막 업데이트**: 2026-02-13
