# Promiso - 프로젝트 아키텍처 문서

> **Last Updated**: 2025-12-16
> **Author**: 김성원
> **Purpose**: Promiso 프로젝트의 전체 구조, 아키텍처, 기술 스택, 주요 기능 및 설계 원칙을 기록

---

## 📋 목차

1. [프로젝트 개요](#프로젝트-개요)
2. [기술 스택](#기술-스택)
3. [앱 구조 및 화면 흐름](#앱-구조-및-화면-흐름)
4. [주요 Feature 모듈](#주요-feature-모듈)
5. [TCA 아키텍처](#tca-아키텍처)
6. [Clean Architecture](#clean-architecture)
7. [데이터 흐름](#데이터-흐름)
8. [프로젝트 구조](#프로젝트-구조)
9. [개발 규칙](#개발-규칙)
10. [TODO 및 개선 사항](#todo-및-개선-사항)

---

## 프로젝트 개요

### 📱 Promiso란?

**Promiso**는 "약속을 지키는 습관"을 만드는 iOS 애플리케이션입니다.

친구, 가족, 동료들과 함께 약속을 관리하고, 실시간으로 위치를 공유하여 약속 시간에 늦지 않도록 돕는 소셜 약속 관리 앱입니다.

### 🎯 핵심 가치

- **약속 지키기**: 약속 시간 30분 전부터 실시간 위치 공유
- **그룹 관리**: 가족, 친구, 동료 등 다양한 그룹별로 약속 관리
- **민주적 약속**: 제안/수락 시스템으로 모두가 참여 가능한 약속 결정
- **투명한 소통**: 실시간 위치 공유로 지각 여부 즉시 확인

### 🌟 주요 기능

#### 1. 사용자 인증 및 프로필
- **소셜 로그인**: Apple, Google 로그인 지원
- **프로필 설정**: 닉네임, 프로필 사진 설정 (3단계 온보딩)
- **자동 프로필 사진**: Google/Apple 계정의 프로필 이미지 자동 연동

#### 2. 그룹 관리
- **그룹 생성**: 2명 이상의 멤버로 그룹 생성
- **그룹 참여**: 초대 코드로 그룹 참여
- **다중 그룹**: 여러 그룹에 동시 소속 가능
- **그룹 핀**: 자주 사용하는 그룹 고정

#### 3. 약속 제안 및 확정
- **3단계 약속 생성**:
  - Step 1: 제목 및 그룹 선택 (AI 이모지 추천)
  - Step 2: 날짜/시간 및 최소 참석 인원 설정
  - Step 3: 세부사항 및 실시간 위치 공유 시간 설정
- **제안 시스템**: 약속 제안 후 그룹 멤버들이 수락/거절
- **확정 조건**: 최소 참석 인원 충족 시 자동 확정
- **약속 필터**: 전체/확정됨/제안됨/지난 약속 필터링

#### 4. 실시간 위치 공유
- **도착 시간 공유**: 약속 시작 30분 전부터 실시간 위치 공유 가능
- **Live Activity**: iOS 동적 섬(Dynamic Island)에 실시간 위치 표시 (계획 중)
- **지각 알림**: 늦을 것 같은 멤버 자동 감지

#### 5. 홈 대시보드
- **오늘의 확정 약속**: 당일 확정된 약속 목록
- **다가오는 약속**: 향후 예정된 약속
- **대기 중인 응답**: 답변이 필요한 약속 제안
- **주간 요약**: 이번 주 약속 개수 및 응답 현황

---

## 기술 스택

### 📦 Core Technologies

| 기술 | 버전 | 용도 |
|-----|------|------|
| **Swift** | 6.0 | 프로그래밍 언어 |
| **SwiftUI** | iOS 18.0+ | UI 프레임워크 |
| **TCA** | 1.22.2 | 상태 관리 아키텍처 |
| **Tuist** | 4.32.1 | 프로젝트 관리 도구 |
| **Xcode** | 15.0+ | 개발 환경 |

### ☁️ Backend & Services

| 서비스 | 용도 |
|--------|------|
| **Firebase Auth** | 사용자 인증 (Apple, Google) |
| **Firestore** | NoSQL 데이터베이스 |
| **Firebase Storage** | 프로필 이미지 저장 |
| **CoreLocation** | 실시간 위치 추적 |

### 🎨 UI & Design

- **Custom Design System**: `ResourceKit` 모듈로 컬러/폰트 관리
- **Aurora Background**: 그라데이션 배경 효과
- **Glass Morphism**: iOS 26 `glassEffect()` API 활용
- **Material Design**: iOS 25 이하는 `.ultraThinMaterial` 대체
- **Typewriter Animation**: 온보딩 타이핑 애니메이션

### 📚 Dependencies

```swift
// Package.swift
dependencies: [
  .package(url: "https://github.com/pointfreeco/swift-composable-architecture", exact: "1.22.2"),
  .package(url: "https://github.com/pointfreeco/swift-dependencies", exact: "1.9.4"),
  .package(url: "https://github.com/pointfreeco/swift-perception", exact: "2.0.6"),
  .package(url: "https://github.com/pointfreeco/swift-navigation", exact: "2.4.2"),
  // Firebase (SPM)
]
```

---

## 앱 구조 및 화면 흐름

### 🔄 사용자 여정 (User Journey)

```
┌─────────────────────────────────────────────────────────┐
│                     앱 시작                              │
│                  (AppEntryFeature)                       │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────┐
        │   세션 확인 (Splash)    │
        │   - 로그인 여부 체크     │
        └────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
    [미인증]                  [인증됨]
         │                       │
         ▼                       ▼
┌─────────────────┐    ┌─────────────────┐
│  Auth Screen    │    │  프로필 확인      │
│  (AuthFeature)  │    └─────────────────┘
│                 │              │
│ - Apple 로그인   │    ┌─────────┴─────────┐
│ - Google 로그인  │    │                   │
└─────────────────┘    ▼                   ▼
         │         [프로필 없음]         [프로필 있음]
         │              │                   │
         └──────────────┤                   │
                        ▼                   │
              ┌─────────────────┐           │
              │ Profile Setup   │           │
              │ (ProfileSetup)  │           │
              │                 │           │
              │ Step 1: 이름     │           │
              │ Step 2: 닉네임   │           │
              │ Step 3: 사진     │           │
              └─────────────────┘           │
                        │                   │
                        └───────────────────┤
                                            ▼
                                  ┌─────────────────┐
                                  │   Main Tabs     │
                                  │ (RootTabFeature)│
                                  └─────────────────┘
                                            │
                        ┌───────────────────┴───────────────────┐
                        │                                       │
                        ▼                                       ▼
              ┌─────────────────┐                    ┌─────────────────┐
              │   홈 탭          │                    │   그룹 탭        │
              │ (HomeFeature)    │                    │ (GroupFeature)   │
              │                 │                    │                 │
              │ - 오늘의 약속    │                    │ - 그룹별 약속    │
              │ - 대기 응답      │                    │ - 제안 수락/거절 │
              │ - 다가오는 약속  │                    │ - 약속 필터링    │
              └─────────────────┘                    └─────────────────┘
                                                               │
                                          ┌────────────────────┴────────────────────┐
                                          │                                         │
                                          ▼                                         ▼
                                ┌─────────────────┐                      ┌─────────────────┐
                                │  약속 만들기     │                      │  그룹 만들기     │
                                │ (CreatePromise) │                      │ (CreateGroup)   │
                                │                 │                      │                 │
                                │ Step 1: 제목/그룹│                      │ - 그룹명 입력    │
                                │ Step 2: 날짜/시간│                      │ - 멤버 초대      │
                                │ Step 3: 세부사항│                      │ - 초대 코드 생성 │
                                └─────────────────┘                      └─────────────────┘
```

### 📱 주요 화면

#### 1. Splash & Auth (인증 전)
- **Splash Screen**: 앱 로고 + 세션 확인
- **Auth Screen**: 타이핑 애니메이션 + Apple/Google 로그인

#### 2. Profile Setup (최초 가입)
- **Step 1 - 이름**: 실명 입력 (선택적)
- **Step 2 - 닉네임**: 앱 내 표시 이름 (2-12자, 공백 불가)
- **Step 3 - 사진**: 프로필 사진 선택 (카메라/갤러리/계정 이미지)

#### 3. Main Tabs (메인 화면)
- **홈 탭**: 오늘의 일정, 대기 응답, 주간 요약
- **그룹 탭**: 그룹별 약속 목록, 약속 제안 관리

#### 4. Side Drawer (사이드 메뉴)
- 그룹 목록 (활성 그룹 표시)
- 그룹 추가하기
- 프로필 / 알림 설정 / 도움말
- 로그아웃

---

## 주요 Feature 모듈

### 🧩 AppEntryFeature

**역할**: 앱 진입점, 인증 상태 관리, 화면 라우팅

**주요 기능**:
- 세션 확인 (Splash Animation)
- 인증 상태에 따른 라우팅
  - 미인증 → `AuthFeature`
  - 인증 + 프로필 없음 → `ProfileSetup`
  - 인증 + 프로필 있음 → `RootTabFeature`
- 로그아웃 처리

**State**:
```swift
@ObservableState
public struct State {
  public enum Route: Equatable {
    case auth        // 인증 화면
    case profile     // 프로필 설정
    case main        // 메인 탭
  }

  public var route: Route = .auth
  var showSplash: Bool = true
  var shouldAnimateOut: Bool = false
  public var auth: Auth.Feature.State
  public var profile: ProfileSetup.State
  public var currentUser: UserModel?
  public var main: RootTab.Feature.State?
}
```

**파일 위치**: `Projects/Features/AppEntryFeature/Sources/`

---

### 🔐 AuthFeature

**역할**: 소셜 로그인 (Apple, Google)

**주요 기능**:
- Apple Sign In (ASAuthorizationController)
- Google Sign In (GIDSignIn)
- 타이핑 애니메이션 온보딩
- Glass Morphism 로그인 시트 (iOS 26 `glassEffect()`)

**UI 특징**:
- **Typewriter Animation**: "약속을 / 더 특별하게." 타이핑 효과
- **Aurora Background**: 그라데이션 배경
- **Glass Login Sheet**: Material Design + iOS 26 Glass Effect

**iOS 26 API 활용**:
```swift
// AuthFeature.swift:570-576
if #available(iOS 26.0, *) {
  Color.clear
    .glassEffect(
      .regular.tint(.white.opacity(0.1)),
      in: .rect(cornerRadius: 36)
    )
} else {
  // iOS 25 이하: .ultraThinMaterial + Gradient
}
```

**파일 위치**: `Projects/Features/AuthFeature/Sources/`

---

### 👤 ProfileSetup (AppEntryFeature 내부)

**역할**: 최초 가입 시 프로필 설정 (3단계 온보딩)

**주요 기능**:
- **Step 1**: 실명 입력 (선택적, 계정 정보 자동 입력)
- **Step 2**: 닉네임 설정 (2-12자, 공백 불가, 중복 확인)
- **Step 3**: 프로필 사진 선택 (카메라/갤러리/계정 이미지)

**애니메이션**:
- 최초 진입 시에만 타이핑 애니메이션 표시
- 뒤로가기 후 재진입 시 애니메이션 스킵

**도메인 검증**:
```swift
// Domain Layer의 검증 로직 사용
if let error = UserModel.validateNickname(state.nickname) {
  state.nicknameError = error.message
  return .none
}
```

**Delegate**:
```swift
public enum DelegateAction: Equatable {
  case completed(UserModel)  // Domain Model 전달
}
```

**파일 위치**: `Projects/Features/AppEntryFeature/Sources/ProfileSetup/`

---

### 🏠 RootTabFeature

**역할**: 메인 탭 네비게이션 (Home, Group) + 사이드 드로어

**주요 기능**:
- **TabView**: Home / Group 탭 전환
- **Side Drawer**: 그룹 목록, 설정, 로그아웃
- **Drag Gesture**: 사이드 드로어 스와이프 제스처 (구현 계획)

**State**:
```swift
@ObservableState
public struct State {
  var selectedTab: Tab = .home
  var sideDrawer: SideDrawerFeature.State
  var home: Home.Feature.State
  var groupMain: GroupMain.Feature.State

  public init(currentUser: UserModel) {
    self.groupMain = GroupMain.Feature.State(currentUser: currentUser)
  }
}
```

**파일 위치**: `Projects/Features/RootTabFeature/Sources/`

---

### 🏡 HomeFeature

**역할**: 오늘의 약속 대시보드

**주요 기능**:
- **오늘의 확정 약속**: 당일 확정된 약속 목록
  - Live Activity 시작 버튼 (30분 전부터 활성화)
  - 약속 시간/장소/참여자 표시
- **대기 중인 응답**: 답변이 필요한 제안 목록
  - 수락/거절 버튼
  - 남은 일수 표시
- **다가오는 약속**: 향후 예정된 약속 (구현 계획)
- **주간 요약**: 이번 주 약속 7개, 대기 응답 3개

**UI 구성**:
```swift
ScrollView {
  LazyVStack {
    TodayPromiseSection(store: store)      // 오늘의 약속
    UpcomingPromiseSection(store: store)   // 다가오는 약속
    PendingResponseSection(store: store)   // 대기 응답
  }
}
.auroraBackground()
```

**파일 위치**: `Projects/Features/HomeFeature/Sources/`

---

### 👥 GroupMainFeature (GroupFeature)

**역할**: 그룹별 약속 목록 관리

**주요 기능**:
- **그룹 선택**: 상단 타이틀 메뉴에서 그룹 전환
- **약속 필터링**: 전체/확정됨/제안됨/지난 약속
- **제안 수락/거절**: 약속 제안에 대한 응답
- **약속 타임라인**: 시간순 약속 목록 표시
- **Empty State**: 그룹이 없을 때 "그룹 만들기" / "초대 코드로 참여하기"

**State**:
```swift
@ObservableState
public struct State {
  var isInitialized: Bool = false
  let currentUser: UserModel  // non-optional

  var selectedFilter: StatusFilter = .all
  var promisesState: LoadingState<[PromiseItem]> = .idle
  var proposalResponding: [String: RespondingState] = [:]

  var allGroups: [GroupModel]?
  var currentGroup: GroupModel?

  @Presents var createPromise: CreatePromise.Feature.State?
  @Presents var createGroup: CreateGroup.Feature.State?
}
```

**로딩 상태 관리**:
```swift
public enum LoadingState<T: Equatable>: Equatable {
  case idle
  case loading
  case loaded(T)
  case failed(Error)
}
```

**파일 위치**: `Projects/Features/GroupFeature/Sources/GroupMain/`

---

### ➕ CreatePromiseFeature (GroupFeature)

**역할**: 약속 제안 생성 (3단계)

**주요 기능**:

#### Step 1 - 제목 및 그룹 선택
- 약속 제목 입력 (AI 이모지 추천)
- 그룹 선택 (LoadingState로 그룹 목록 관리)
- 디바운스 기반 이모지 추천 (1초 딜레이)

#### Step 2 - 날짜 및 시간
- 시작 날짜/시간 선택
- 종료 시간 선택 (선택적)
- 최소 참석 인원 설정 (2명 ~ 그룹 인원수)
- 유효성 검증 (시작 시간 > 현재, 종료 시간 > 시작 시간)

#### Step 3 - 세부사항
- 약속 설명 (최대 500자)
- 실시간 위치 공유 시간 설정 (30분 전 ~ 당일)
- 약속 미리보기

**State**:
```swift
@ObservableState
public struct State {
  var currentStep: CreatePromiseStep = .first
  var promiseProposal: PromiseProposal = .empty
  var groupListState: LoadingState<[GroupModel]> = .idle
  var isCreatingPromise: Bool = false
  var creationError: PromiseClientError?

  var firstButtonDisabled: Bool { ... }
  var secondButtonDisabled: Bool { ... }
  var thirdButtonDisabled: Bool { ... }
}
```

**AI 이모지 추천**:
```swift
case .titleDebounced(let title):
  return .run { [title] send in
    let picks = await EmojiSuggestorProvider.shared.suggest(for: title, topK: 10)
    await send(.internal(.emojiSuggestionsResponse(picks)))
  }
```

**파일 위치**: `Projects/Features/GroupFeature/Sources/CreatePromise/`

---

### 🏢 CreateGroupFeature (GroupFeature)

**역할**: 그룹 생성 및 멤버 초대

**주요 기능**:
- 그룹명 입력
- 멤버 초대 (초대 코드 생성)
- 그룹 생성 완료 시 자동으로 그룹 목록 갱신

**파일 위치**: `Projects/Features/GroupFeature/Sources/CreateGroup/`

---

## TCA 아키텍처

### 🏗️ TCA (The Composable Architecture) 1.22.2

TCA는 **단방향 데이터 흐름**과 **상태 기반 UI**를 제공하는 Swift 아키텍처입니다.

### 핵심 개념

```
┌─────────────────────────────────────────────────────────┐
│                    TCA Data Flow                        │
└─────────────────────────────────────────────────────────┘

    User Interaction
           │
           ▼
    ┌─────────────┐
    │   Action    │  ← 사용자 이벤트 / 시스템 이벤트
    └─────────────┘
           │
           ▼
    ┌─────────────┐
    │  Reducer    │  ← 비즈니스 로직 / State 변경
    └─────────────┘
           │
           ├──────────────┐
           │              │
           ▼              ▼
    ┌─────────────┐  ┌─────────────┐
    │   State     │  │   Effect    │  ← 비동기 작업
    └─────────────┘  └─────────────┘
           │              │
           ▼              │
    ┌─────────────┐      │
    │    View     │ ◄────┘
    └─────────────┘
```

### TCA 1.22.2 주요 특징

#### 1. @Reducer Macro
```swift
@Reducer
public struct Feature {
  @ObservableState
  public struct State { ... }

  public enum Action { ... }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      // 비즈니스 로직
    }
  }
}
```

#### 2. @ObservableState (Observation Framework)
Swift 5.9의 `@Observable`을 TCA에 통합. `@Published` 대신 직접적인 관찰 가능.

```swift
@ObservableState
public struct State {
  var isLoading: Bool = false
  var errorMessage: String?
  var currentUser: UserModel?
}
```

#### 3. @Dependency (Dependency Injection)
```swift
@Reducer
public struct Feature {
  @Dependency(\.authClient) var authClient
  @Dependency(\.userProfileClient) var userProfileClient

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      case .loginButtonTapped:
        return .run { send in
          let user = try await authClient.login()
          await send(.loginSuccess(user))
        }
    }
  }
}
```

#### 4. Action 구조 (View / Internal / Delegate)
```swift
public enum Action {
  case view(View)          // View에서 발생
  case `internal`(Internal)  // Reducer 내부
  case delegate(Delegate)    // 부모에게 전달
}

public enum View: Sendable {
  case onAppear
  case buttonTapped
}

public enum Internal: Sendable {
  case apiResponse(Result<Data, Error>)
  case dataProcessed
}

public enum Delegate: Equatable {
  case completed(UserModel)
  case dismissed
}
```

#### 5. Scope & Composition
```swift
public var body: some ReducerOf<Self> {
  // 하위 Reducer 통합
  Scope(state: \.auth, action: \.auth) {
    Auth.Feature()
  }

  Scope(state: \.profile, action: \.profile) {
    ProfileSetup()
  }

  // 메인 Reducer
  Reduce { state, action in
    // ...
  }

  // 옵셔널 State 처리
  .ifLet(\.$createPromise, action: \.createPromise) {
    CreatePromise.Feature()
  }
}
```

#### 6. @Presents (Sheet/FullScreenCover)
```swift
@ObservableState
public struct State {
  @Presents var createPromise: CreatePromise.Feature.State?
  @Presents var createGroup: CreateGroup.Feature.State?
}

public enum Action {
  case createPromise(PresentationAction<CreatePromise.Feature.Action>)
  case createGroup(PresentationAction<CreateGroup.Feature.Action>)
}

// View
.fullScreenCover(
  store: store.scope(state: \.$createPromise, action: \.createPromise)
) { childStore in
  CreatePromise.RootView(store: childStore)
}
```

#### 7. Effect (비동기 작업)
```swift
return .run { send in
  do {
    let user = try await authClient.login()
    await send(.internal(.loginSuccess(user)))
  } catch {
    await send(.internal(.loginFailure(error)))
  }
}
```

#### 8. Debounce & Cancellation
```swift
private enum CancelID: Hashable {
  case emojiSuggestDebounce
}

case .setTitle(let title):
  state.promiseProposal.title = title
  return .merge(
    .cancel(id: CancelID.emojiSuggestDebounce),
    .run { [clock, title] send in
      try await clock.sleep(for: .milliseconds(1_000))
      await send(.internal(.titleDebounced(title)))
    }
    .cancellable(id: CancelID.emojiSuggestDebounce, cancelInFlight: true)
  )
```

### TCA 사용 규칙

✅ **권장사항**:
- Action을 `View`, `Internal`, `Delegate`로 구분
- State는 `@ObservableState`로 관찰 가능하게
- Effect는 `.run` closure로 작성
- Child Reducer는 `Scope`로 통합

❌ **금지사항**:
- Reducer 내부에서 직접 API 호출 (Dependency 사용)
- State 직접 변경 (Action을 통해서만)
- View에서 비즈니스 로직 작성

---

## Clean Architecture

### 🏛️ 4-Layer 구조

이 프로젝트는 **Clean Architecture의 4-Layer 구조**를 따릅니다.

```
┌─────────────────────────────────────────┐
│         Presentation Layer              │
│    (Features - TCA Reducers & Views)    │
│    - UI 로직, 사용자 인터랙션            │
│    - Domain Model 사용                   │
└─────────────────────────────────────────┘
                    ↓ depends on
┌─────────────────────────────────────────┐
│          Adapter Layer                  │
│       (Clients - TCA Dependencies)      │
│    - DTO ↔ Domain Model 변환             │
│    - 외부 ↔ 내부 경계                    │
└─────────────────────────────────────────┘
                    ↓ depends on
┌─────────────────────────────────────────┐
│         Domain Layer                    │
│    (Business Logic & Protocols)         │
│    - 순수 비즈니스 모델                   │
│    - 도메인 로직                         │
│    - 외부 의존성 없음                     │
└─────────────────────────────────────────┘
                    ↑ implements
┌─────────────────────────────────────────┐
│      Infrastructure Layer               │
│    (Core - Firebase Implementation)     │
│    - 외부 시스템 구현                     │
│    - Firestore, Auth, Storage           │
└─────────────────────────────────────────┘
```

### 핵심 원칙

1. **의존성 규칙 (Dependency Rule)**
   - 외부 레이어 → 내부 레이어로만 의존
   - Domain Layer는 어떤 레이어도 의존하지 않음 (순수성)

2. **관심사의 분리 (Separation of Concerns)**
   - UI 로직 ≠ 비즈니스 로직 ≠ 데이터 로직

3. **의존성 역전 원칙 (DIP)**
   - Repository는 Domain의 Protocol을 구현

### 레이어별 책임

#### 1. Presentation Layer (`Projects/Features/`)
- **책임**: UI 렌더링, 사용자 인터랙션, TCA State 관리
- **사용 모델**: Domain Model만 사용
- **금지**: DTO 직접 다루기, Infrastructure 직접 접근

```swift
// ✅ GOOD
case .profile(.delegate(.completed(let userModel))):  // UserModel (Domain)
  state.currentUser = userModel
  state.main = RootTab.Feature.State(currentUser: userModel)

// ❌ BAD
case .profile(.delegate(.completed(let profile))):  // UserProfile (DTO)
  let userModel = profile.toDomain(uid: uid)  // 변환은 Adapter 책임
```

#### 2. Adapter Layer (`Projects/Clients/`)
- **책임**: DTO ↔ Domain Model 변환, TCA Dependencies 제공
- **사용 모델**: DTO, Domain Model
- **변환 로직**: `UserProfile+Domain.swift`에 `toDomain()` 메서드

```swift
// UserProfileClient.swift
public var saveProfile: @Sendable (_ uid: String, _ profile: UserProfile) async throws -> UserModel {
  // 1. Infrastructure에 DTO 전달
  try await repository.saveProfile(uid: uid, profile: profile)

  // 2. Adapter가 변환
  return profile.toDomain(uid: uid)  // DTO → Domain
}

// UserProfile+Domain.swift
extension UserProfile {
  func toDomain(uid: String) -> UserModel {
    return UserModel(
      id: uid,
      email: email ?? "",
      nickname: nickname,
      // ... DTO 필드 → Domain 필드 매핑
    )
  }
}
```

#### 3. Domain Layer (`Projects/Domain/`)
- **책임**: 순수 비즈니스 모델, 도메인 로직, Protocol 정의
- **사용 모델**: Domain Model만
- **금지**: 다른 레이어 import, UIKit/SwiftUI import

```swift
// UserModel.swift
public struct UserModel: Identifiable, Equatable, Sendable {
  public let id: String
  public let email: String
  public let nickname: String
  // ...

  // 도메인 로직
  public var displayName: String {
    return nickname.isEmpty ? email : nickname
  }

  public static func validateNickname(_ nickname: String) -> NicknameValidationError? {
    let trimmed = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.count < 2 { return .tooShort(minimum: 2) }
    if trimmed.count > 12 { return .tooLong(maximum: 12) }
    // ...
    return nil
  }
}
```

#### 4. Infrastructure Layer (`Projects/Core/`)
- **책임**: Firebase 구현, Domain Protocol 구현, DTO ↔ Firestore 변환
- **사용 모델**: DTO만
- **금지**: Domain Model 직접 다루기

```swift
// FirebaseUserRepository.swift
class FirebaseUserRepository: UserRepositoryProtocol {
  func saveProfile(uid: String, profile: UserProfile) async throws {
    let data = profile.toFirestoreData()  // DTO → Firestore
    try await firestore.collection("users").document(uid).setData(data)
  }

  func getProfile(uid: String) async throws -> UserProfile? {
    let doc = try await firestore.collection("users").document(uid).getDocument()
    return try UserProfile.fromFirestoreData(doc.data())  // Firestore → DTO
  }
}
```

### 모델 정의

| 모델 종류 | 위치 | 특징 | 예시 |
|----------|------|------|------|
| **Domain Model** | `Projects/Domain/Sources/Models/` | 순수 Swift, 비즈니스 로직 포함 | `UserModel`, `PromiseModel` |
| **DTO** | `Projects/Clients/Sources/*/Models/` | `Codable` 준수, Firestore 직렬화용 | `UserProfile` |
| **Presentation Model** | `Projects/Features/*/Models/` | UI 전용, Domain에서 파생 | (선택적) |

### 도메인 로직

**도메인 로직**은 비즈니스 규칙과 계산을 의미하며, 외부 의존성 없이 순수하게 실행 가능해야 합니다.

| 도메인 로직 | 비즈니스 규칙 | 위치 |
|-------------|--------------|------|
| 사용자 표시 이름 | 닉네임 우선, 없으면 이메일 | `UserModel.displayName` |
| 닉네임 검증 | 2-12자, 공백 불가 | `UserModel.validateNickname()` |
| 실시간 공유 가능 | 약속 시작 30분 전부터 | `PromiseModel.isRealtimeShareable` |
| 약속 진행 중 판단 | 시작~종료 시간 사이 | `PromiseModel.isOngoing` |
| 약속 확정 조건 | 수락자 1명 이상 | `PromiseCounts.isConfirmed` |

---

## 데이터 흐름

### 의존성 방향 vs 데이터 흐름

#### 의존성 방향 (누가 누구를 알고 있는가?)
```
Feature → Client → Domain ← Repository
(import)  (import)         (import)
```

#### 데이터 흐름 (저장)
```
Feature → Client → Repository → Firestore
  ↓         ↓
Domain    Domain
Model     Model
(사용)    (변환 후 반환)
```

#### 데이터 흐름 (조회)
```
Firestore → Repository → Client → Feature
              ↓           ↓
            DTO       Domain Model
           (반환)      (변환)
```

**핵심**: Domain Layer는 **경유하지 않음**, **타입만 제공**함

---

## 프로젝트 구조

```
Promiso/
├── Projects/
│   ├── App/                          # 앱 진입점
│   │   └── Sources/
│   │       └── PromisoApp.swift
│   │
│   ├── Domain/                       # Domain Layer
│   │   └── Sources/
│   │       ├── Models/
│   │       │   ├── User.swift        # UserModel + 도메인 로직
│   │       │   ├── Promise.swift     # PromiseModel + 도메인 로직
│   │       │   └── Group.swift       # GroupModel
│   │       ├── Protocols/
│   │       │   ├── UserRepositoryProtocol.swift
│   │       │   ├── PromiseRepositoryProtocol.swift
│   │       │   └── GroupRepositoryProtocol.swift
│   │       └── Errors/
│   │
│   ├── Clients/                      # Adapter Layer
│   │   └── Sources/
│   │       ├── UserProfileClient/
│   │       │   ├── UserProfileClient.swift
│   │       │   └── Models/
│   │       │       ├── UserProfile.swift       # DTO
│   │       │       └── UserProfile+Domain.swift # 변환
│   │       ├── GroupClient/
│   │       ├── PromiseClient/
│   │       └── AuthClient/
│   │
│   ├── Core/                         # Infrastructure Layer
│   │   ├── CoreInfrastructure/
│   │   │   └── Sources/
│   │   │       ├── Firebase/
│   │   │       │   ├── FirebaseUserRepository.swift
│   │   │       │   ├── FirebasePromiseRepository.swift
│   │   │       │   └── FirebaseGroupRepository.swift
│   │   │       └── Storage/
│   │   └── CoreNetworking/
│   │
│   ├── Features/                     # Presentation Layer
│   │   ├── AppEntryFeature/          # 앱 진입, 인증
│   │   │   └── Sources/
│   │   │       ├── AppEntryFeature.swift
│   │   │       └── ProfileSetup/
│   │   │           └── ProfileSetup.swift
│   │   ├── AuthFeature/              # 소셜 로그인
│   │   ├── RootTabFeature/           # 탭 네비게이션
│   │   ├── HomeFeature/              # 홈 대시보드
│   │   └── GroupFeature/             # 그룹 관리
│   │       └── Sources/
│   │           ├── GroupMain/
│   │           │   └── GroupMainFeature.swift
│   │           ├── CreatePromise/
│   │           │   └── CreatePromiseFeature.swift
│   │           └── CreateGroup/
│   │               └── CreateGroupFeature.swift
│   │
│   ├── Shared/                       # 공유 컴포넌트
│   │   └── Sources/
│   │       ├── Extensions/
│   │       ├── Views/
│   │       │   ├── TypewriterLinesView.swift
│   │       │   ├── SplashView.swift
│   │       │   └── ToolbarButton.swift
│   │       └── Utilities/
│   │
│   └── ResourceKit/                  # 디자인 시스템
│       └── Sources/
│           ├── Colors/
│           ├── Fonts/
│           └── Assets/
│
├── Tuist/                            # Tuist 설정
│   └── ProjectDescriptionHelpers/
│
└── AGENTS.md                         # 이 문서
```

---

## 개발 규칙

### 1. 의존성 규칙

```
✅ 허용:
  Feature → Client
  Feature → Domain
  Client → Domain
  Repository → Domain

❌ 금지:
  Domain → 다른 레이어 (순환 의존성)
  Repository → Client
  Feature → Repository (직접 접근)
```

### 2. 모델 사용 규칙

| 레이어 | 사용 가능한 모델 | 금지 |
|--------|-----------------|------|
| **Feature** | Domain Model | DTO 직접 다루기 |
| **Client** | Domain Model, DTO | - |
| **Domain** | Domain Model만 | DTO, Presentation Model |
| **Repository** | DTO | Domain Model |

### 3. 변환 규칙

| 변환 | 위치 | 책임 |
|------|------|------|
| **Firestore ↔ DTO** | Infrastructure (Repository) | `toFirestoreData()`, `fromFirestoreData()` |
| **DTO ↔ Domain** | Adapter (Client) | `toDomain()` extension |
| **Domain → Presentation** | Feature | init 또는 computed property |

### 4. 파일 네이밍 규칙

```
Domain Model:      UserModel.swift
DTO:               UserProfile.swift
DTO 변환:          UserProfile+Domain.swift
Client:            UserProfileClient.swift
Repository:        FirebaseUserRepository.swift
Feature:           GroupMainFeature.swift
TCA Reducer:       CreatePromiseFeature.swift
```

### 5. import 규칙

**Domain Layer** (순수성 유지):
```swift
// ✅ 허용
import Foundation

// ❌ 금지
import Clients
import Core
import SwiftUI
import FirebaseFirestore
```

**Client Layer**:
```swift
// ✅ 허용
import Foundation
import Domain
import ComposableArchitecture

// ❌ 금지
import SwiftUI (UI 로직 포함하지 않음)
```

**Feature Layer**:
```swift
// ✅ 허용
import SwiftUI
import Domain
import Clients
import ComposableArchitecture
```

### 6. TCA 사용 규칙

**Action 구조**:
```swift
public enum Action {
  case view(ViewAction)       // View에서 발생
  case `internal`(InternalAction)  // Reducer 내부
  case delegate(DelegateAction)    // 부모에게 전달
}
```

**State 구조**:
```swift
@ObservableState
public struct State {
  // Domain Model 저장
  var currentUser: UserModel

  // UI State
  var isLoading: Bool = false
  var errorMessage: String?

  // Nested State
  var ui: UIState = UIState()
}
```

### 7. Tuist 워크플로우

```bash
# 프로젝트 생성
tuist generate

# 의존성 설치
tuist install

# 빌드
tuist build

# 테스트
tuist test

# 의존성 그래프 확인
tuist graph
```

---

## TODO 및 개선 사항

### 🚧 진행 중

1. **Live Activity 구현**
   - 실시간 위치 공유를 동적 섬(Dynamic Island)에 표시
   - 약속 시작 30분 전부터 활성화

2. **약속 알림**
   - 약속 1시간 전, 30분 전 푸시 알림
   - 제안 수락/거절 알림

3. **그룹 참여**
   - 초대 코드 생성 및 공유
   - QR 코드로 그룹 참여

### 📋 계획

1. **GroupModel 정리**
   - 현재: `Clients/GroupClient/Models/GroupModel.swift`
   - 문제: Domain Model인지 DTO인지 불명확
   - 해결: Domain Model로 이동하고, DTO 별도 생성

2. **PromiseItem 정리**
   - 현재: `Clients/PromiseClient/Models/PromiseFeatureModel.swift`
   - 문제: "Feature용"이라고 명시되어 있지만 Clients에 위치
   - 해결: Presentation Model로 정의하고 Features로 이동

3. **Validation 로직 일관성**
   - ✅ 완료: 닉네임 검증 → Domain Layer로 이동
   - TODO: 다른 검증 로직도 Domain Layer로 이동 검토

4. **Protocol 정의 강화**
   - Repository Protocol을 Domain Layer에서 정의
   - Use Case Pattern 도입 검토

5. **사이드 드로어 제스처**
   - 현재: 주석 처리된 DragGesture 구현
   - 해결: 스크롤과 구분되는 안정적인 제스처 구현

6. **에러 처리 개선**
   - 전역 에러 처리 시스템
   - 사용자 친화적 에러 메시지

---

## 변경 이력

| 날짜 | 변경 내용 | 작성자 |
|------|-----------|--------|
| 2025-12-16 | 초기 문서 작성 (Clean Architecture만) | 김성원 |
| 2025-12-16 | Clean Architecture 4-Layer 구조 확정 | 김성원 |
| 2025-12-16 | 닉네임 검증 로직 Domain Layer로 이동 | 김성원 |
| 2025-12-16 | **전체 재작성**: 앱 전반 맥락 포함, TCA 1.22.2 특징, 주요 Feature 설명, 화면 흐름 추가 | 김성원 |

---

## 참고 자료

- [The Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture)
- [Clean Architecture (Robert C. Martin)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [Tuist Documentation](https://docs.tuist.io)
- [Swift Observation Framework](https://developer.apple.com/documentation/observation)
- [iOS 26 API Documentation](https://developer.apple.com/documentation/ios-ipados-release-notes)

---

**끝.**
