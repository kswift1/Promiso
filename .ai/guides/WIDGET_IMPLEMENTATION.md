# Promiso Widget 구현 가이드

> **상태**: ✅ 구현 완료 (2025.01)
> **마지막 업데이트**: 2025.01.28

## 개요

이 문서는 Promiso 홈 화면 위젯 구현을 위한 단계별 가이드입니다.

---

## 파일 구조

```
Projects/
├── App/
│   ├── Project.swift                    # Tuist 타겟 추가
│   ├── Sources/
│   │   └── AppDelegate.swift            # Silent Push 핸들러
│   └── Extensions/
│       └── PromiseWidget/
│           ├── Sources/
│           │   ├── PromiseWidgetBundle.swift
│           │   ├── Provider/
│           │   │   ├── PromiseTimelineProvider.swift
│           │   │   ├── WidgetPromiseEntry.swift
│           │   │   └── WidgetPushHandler.swift     # iOS 26 대비
│           │   ├── Widgets/
│           │   │   ├── SmallPromiseWidget.swift
│           │   │   ├── MediumPromiseWidget.swift
│           │   │   └── LargePromiseWidget.swift
│           │   └── Views/
│           │       ├── PromiseRowView.swift
│           │       ├── EmptyWidgetView.swift
│           │       └── NotLoggedInView.swift
│           └── PromiseWidget.entitlements
├── Shared/
│   ├── Project.swift                    # 소스 경로 추가
│   └── Sources/
│       └── Widget/
│           ├── WidgetDataManager.swift  # App Group + 서버 fetch
│           └── WidgetPromiseData.swift
├── Features/
│   └── AppEntryFeature/
│       └── Sources/
│           └── AppEntryFeature.swift    # Widget 캐시 + 로그인 연동
└── Tuist/
    └── ProjectDescriptionHelpers/
        └── AppConfig.swift              # Firebase Swizzling 비활성화
```

**Cloud Functions**:
```
infra/firebase/functions/src/functions/
├── widget.ts                            # getWidgetSnapshot (데이터 조회)
└── widgetPush.ts                        # Silent Push 트리거
```

---

## Phase 1: 기반 구조

### 1.1 Tuist 타겟 추가

**파일**: `Projects/App/Project.swift`

```swift
let project = Project(
  name: AppConfig.name,
  targets: [
    // 기존 메인 앱 타겟
    .target(
      name: AppConfig.name,
      // ...
      dependencies: AppFeatureDeps.allDeps + [
        .target(name: "LiveActivityWidgetExtension"),
        .target(name: "PromiseWidgetExtension")  // 추가
      ]
    ),

    // 기존 LiveActivity 타겟
    .target(name: "LiveActivityWidgetExtension", ...),

    // 신규 Promise Widget 타겟
    .target(
      name: "PromiseWidgetExtension",
      destinations: .iOS,
      product: .appExtension,
      bundleId: "\(AppConfig.bundleId).promisewidget",
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": "Promiso",
        "NSExtension": [
          "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
        ]
      ]),
      sources: ["Extensions/PromiseWidget/Sources/**"],
      entitlements: .file(path: "Extensions/PromiseWidget/PromiseWidget.entitlements"),
      dependencies: [
        .project(target: "PromisoShared", path: "../Shared"),
        .project(target: "ResourceKit", path: "../ResourceKit")
      ],
      settings: .standard()
    )
  ]
)
```

### 1.2 Entitlements 생성

**파일**: `Projects/App/Extensions/PromiseWidget/PromiseWidget.entitlements`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.security.application-groups</key>
  <array>
    <string>group.com.promiso.shared</string>
  </array>
</dict>
</plist>
```

### 1.3 WidgetDataManager 구현

**파일**: `Projects/Shared/Sources/Widget/WidgetDataManager.swift`

```swift
import Foundation
import WidgetKit

public enum WidgetDataManager {
  private static let suiteName = "group.com.promiso.shared"
  private static let promisesKey = "widget.promises"
  private static let userIdKey = "widget.userId"
  private static let lastUpdatedKey = "widget.lastUpdated"

  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: suiteName)
  }

  // MARK: - App에서 호출 (저장)

  public static func savePromises(_ promises: [WidgetPromiseData]) {
    guard let defaults = defaults,
          let data = try? JSONEncoder().encode(promises) else { return }
    defaults.set(data, forKey: promisesKey)
    defaults.set(Date(), forKey: lastUpdatedKey)
  }

  public static func saveUserId(_ userId: String?) {
    if let userId = userId {
      defaults?.set(userId, forKey: userIdKey)
    } else {
      defaults?.removeObject(forKey: userIdKey)
    }
  }

  // MARK: - Widget에서 호출 (읽기)

  public static func loadPromises() -> [WidgetPromiseData] {
    guard let defaults = defaults,
          let data = defaults.data(forKey: promisesKey),
          let promises = try? JSONDecoder().decode([WidgetPromiseData].self, from: data)
    else { return [] }

    // 과거 약속 필터링 + 시간순 정렬
    return promises
      .filter { $0.startAt > Date().addingTimeInterval(-3600) } // 1시간 전까지 포함
      .sorted { $0.startAt < $1.startAt }
  }

  public static func isLoggedIn() -> Bool {
    defaults?.string(forKey: userIdKey) != nil
  }

  public static func lastUpdated() -> Date? {
    defaults?.object(forKey: lastUpdatedKey) as? Date
  }

  // MARK: - 초기화

  public static func clearAll() {
    defaults?.removeObject(forKey: promisesKey)
    defaults?.removeObject(forKey: userIdKey)
    defaults?.removeObject(forKey: lastUpdatedKey)
  }

  // MARK: - Widget 갱신 트리거

  public static func reloadWidgets() {
    WidgetCenter.shared.reloadTimelines(ofKind: "SmallPromiseWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "MediumPromiseWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "LargePromiseWidget")
  }
}
```

### 1.4 WidgetPromiseData 모델

**파일**: `Projects/Shared/Sources/Widget/WidgetPromiseData.swift`

```swift
import Foundation

public struct WidgetPromiseData: Codable, Identifiable, Equatable, Sendable {
  public let id: String
  public let title: String
  public let emoji: String
  public let startAt: Date
  public let endAt: Date?
  public let location: String?
  public let groupId: String
  public let groupName: String?
  public let isConfirmed: Bool
  public let participantCount: Int
  public let cachedAt: Date

  public init(
    id: String,
    title: String,
    emoji: String,
    startAt: Date,
    endAt: Date?,
    location: String?,
    groupId: String,
    groupName: String?,
    isConfirmed: Bool,
    participantCount: Int,
    cachedAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.startAt = startAt
    self.endAt = endAt
    self.location = location
    self.groupId = groupId
    self.groupName = groupName
    self.isConfirmed = isConfirmed
    self.participantCount = participantCount
    self.cachedAt = cachedAt
  }

  // MARK: - Computed Properties

  public var isStale: Bool {
    Date().timeIntervalSince(cachedAt) > 7200 // 2시간
  }

  public var deeplinkURL: URL? {
    URL(string: "promiso://promise?id=\(id)&groupId=\(groupId)")
  }

  // MARK: - Placeholder

  public static var placeholder: WidgetPromiseData {
    WidgetPromiseData(
      id: "placeholder",
      title: "점심 약속",
      emoji: "🍜",
      startAt: Date().addingTimeInterval(3600),
      endAt: nil,
      location: "강남역",
      groupId: "",
      groupName: "친구들",
      isConfirmed: true,
      participantCount: 3
    )
  }
}

// MARK: - PromiseModel 변환

import Clients

extension WidgetPromiseData {
  public init(from model: PromiseModel) {
    self.init(
      id: model.id,
      title: model.title,
      emoji: model.displayEmoji,
      startAt: model.startAt,
      endAt: model.endAt,
      location: model.location?.name,
      groupId: model.groupId,
      groupName: model.group?.name,
      isConfirmed: model.isConfirmed,
      participantCount: model.votes.acceptedCount
    )
  }
}
```

---

## Phase 2: Timeline Provider

### 2.1 WidgetPromiseEntry

**파일**: `Projects/App/Extensions/PromiseWidget/Sources/Provider/WidgetPromiseEntry.swift`

```swift
import WidgetKit
import PromisoShared

struct WidgetPromiseEntry: TimelineEntry {
  let date: Date
  let promises: [WidgetPromiseData]
  let state: WidgetState

  enum WidgetState: Equatable {
    case loaded
    case empty
    case notLoggedIn
  }

  var nextPromise: WidgetPromiseData? {
    promises.first { $0.startAt > Date() }
  }

  var todayPromises: [WidgetPromiseData] {
    promises.filter { Calendar.current.isDateInToday($0.startAt) }
  }

  var upcomingPromises: [WidgetPromiseData] {
    promises.filter {
      !Calendar.current.isDateInToday($0.startAt) && $0.startAt > Date()
    }
  }

  var hasStaleData: Bool {
    promises.contains { $0.isStale }
  }

  static var placeholder: WidgetPromiseEntry {
    WidgetPromiseEntry(
      date: Date(),
      promises: [.placeholder],
      state: .loaded
    )
  }
}
```

### 2.2 PromiseTimelineProvider

**파일**: `Projects/App/Extensions/PromiseWidget/Sources/Provider/PromiseTimelineProvider.swift`

```swift
import WidgetKit
import PromisoShared

struct PromiseTimelineProvider: TimelineProvider {
  typealias Entry = WidgetPromiseEntry

  func placeholder(in context: Context) -> Entry {
    .placeholder
  }

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    completion(createEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let entry = createEntry()
    let refreshDate = calculateNextRefresh(promises: entry.promises)
    let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
    completion(timeline)
  }

  private func createEntry() -> Entry {
    guard WidgetDataManager.isLoggedIn() else {
      return Entry(date: Date(), promises: [], state: .notLoggedIn)
    }

    let promises = WidgetDataManager.loadPromises()
    let state: Entry.WidgetState = promises.isEmpty ? .empty : .loaded
    return Entry(date: Date(), promises: promises, state: state)
  }

  private func calculateNextRefresh(promises: [WidgetPromiseData]) -> Date {
    let now = Date()
    let maxInterval: TimeInterval = 3600 // 1시간

    guard let nextPromise = promises.first(where: { $0.startAt > now }) else {
      return now.addingTimeInterval(7200) // 2시간
    }

    let timeUntil = nextPromise.startAt.timeIntervalSince(now)

    if timeUntil <= 3600 { // 1시간 이내
      return now.addingTimeInterval(min(900, maxInterval))
    }
    if timeUntil <= 21600 { // 6시간 이내
      return now.addingTimeInterval(min(1800, maxInterval))
    }
    return now.addingTimeInterval(maxInterval)
  }
}
```

---

## Phase 3: Widget UI

### 3.1 SmallPromiseWidget

**파일**: `Projects/App/Extensions/PromiseWidget/Sources/Widgets/SmallPromiseWidget.swift`

```swift
import SwiftUI
import WidgetKit
import PromisoShared
import ResourceKit

struct SmallPromiseWidget: Widget {
  let kind: String = "SmallPromiseWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PromiseTimelineProvider()) { entry in
      SmallPromiseWidgetView(entry: entry)
        .containerBackground(for: .widget) {
          widgetBackground
        }
    }
    .configurationDisplayName("다음 약속")
    .description("다음 약속을 확인하세요")
    .supportedFamilies([.systemSmall])
  }

  @ViewBuilder
  private var widgetBackground: some View {
    if #available(iOS 18.0, *) {
      Color.clear.glassEffect(.regular)
    } else {
      Color(.systemBackground).opacity(0.9)
    }
  }
}

struct SmallPromiseWidgetView: View {
  let entry: WidgetPromiseEntry

  var body: some View {
    switch entry.state {
    case .notLoggedIn:
      NotLoggedInView()
    case .empty:
      EmptyWidgetView(message: "예정된 약속이 없어요")
    case .loaded:
      if let promise = entry.nextPromise {
        promiseView(promise)
      } else {
        EmptyWidgetView(message: "예정된 약속이 없어요")
      }
    }
  }

  @ViewBuilder
  private func promiseView(_ promise: WidgetPromiseData) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(promise.emoji)
          .font(.title2)
        Spacer()
        if promise.isStale {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.caption2)
            .foregroundStyle(.orange)
        }
      }

      Spacer()

      Text(promise.title)
        .font(.subheadline.bold())
        .lineLimit(2)

      Text(formatTime(promise.startAt))
        .font(.headline)
        .foregroundStyle(Color.pmindigo.n500)

      if let location = promise.location {
        Text(location)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding()
    .widgetURL(promise.deeplinkURL)
  }

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }
}
```

### 3.2 MediumPromiseWidget

**파일**: `Projects/App/Extensions/PromiseWidget/Sources/Widgets/MediumPromiseWidget.swift`

```swift
import SwiftUI
import WidgetKit
import PromisoShared
import ResourceKit

struct MediumPromiseWidget: Widget {
  let kind: String = "MediumPromiseWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PromiseTimelineProvider()) { entry in
      MediumPromiseWidgetView(entry: entry)
        .containerBackground(for: .widget) {
          widgetBackground
        }
    }
    .configurationDisplayName("오늘의 약속")
    .description("오늘 예정된 약속을 확인하세요")
    .supportedFamilies([.systemMedium])
  }

  @ViewBuilder
  private var widgetBackground: some View {
    if #available(iOS 18.0, *) {
      Color.clear.glassEffect(.regular)
    } else {
      Color(.systemBackground).opacity(0.9)
    }
  }
}

struct MediumPromiseWidgetView: View {
  let entry: WidgetPromiseEntry

  var body: some View {
    switch entry.state {
    case .notLoggedIn:
      NotLoggedInView()
    case .empty:
      EmptyWidgetView(message: "오늘 예정된 약속이 없어요")
    case .loaded:
      contentView
    }
  }

  @ViewBuilder
  private var contentView: some View {
    let promises = entry.todayPromises.prefix(3)

    if promises.isEmpty {
      EmptyWidgetView(message: "오늘 예정된 약속이 없어요")
    } else {
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("오늘의 약속")
            .font(.subheadline.bold())
          Text("(\(promises.count))")
            .font(.subheadline)
            .foregroundStyle(.secondary)
          Spacer()
        }

        Divider()

        ForEach(Array(promises)) { promise in
          Link(destination: promise.deeplinkURL!) {
            PromiseRowView(promise: promise)
          }
        }

        Spacer(minLength: 0)
      }
      .padding()
    }
  }
}
```

### 3.3 공통 뷰 컴포넌트

**파일**: `Projects/App/Extensions/PromiseWidget/Sources/Views/PromiseRowView.swift`

```swift
import SwiftUI
import PromisoShared

struct PromiseRowView: View {
  let promise: WidgetPromiseData

  var body: some View {
    HStack(spacing: 8) {
      Text(promise.emoji)
        .font(.body)

      Text(promise.title)
        .font(.subheadline)
        .lineLimit(1)

      Spacer()

      Text(formatTime(promise.startAt))
        .font(.subheadline.bold())
        .foregroundStyle(Color.pmindigo.n500)

      if let location = promise.location {
        Text(location)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .contentShape(Rectangle())
  }

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }
}
```

**파일**: `Projects/App/Extensions/PromiseWidget/Sources/Views/EmptyWidgetView.swift`

```swift
import SwiftUI

struct EmptyWidgetView: View {
  let message: String

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "calendar")
        .font(.largeTitle)
        .foregroundStyle(.secondary)

      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
```

**파일**: `Projects/App/Extensions/PromiseWidget/Sources/Views/NotLoggedInView.swift`

```swift
import SwiftUI

struct NotLoggedInView: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "person.crop.circle.badge.questionmark")
        .font(.largeTitle)
        .foregroundStyle(.secondary)

      Text("로그인이 필요해요")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Text("탭하여 앱 열기")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetURL(URL(string: "promiso://home"))
  }
}
```

### 3.4 PromiseWidgetBundle

**파일**: `Projects/App/Extensions/PromiseWidget/Sources/PromiseWidgetBundle.swift`

```swift
import WidgetKit
import SwiftUI

@main
struct PromiseWidgetBundle: WidgetBundle {
  var body: some Widget {
    SmallPromiseWidget()
    MediumPromiseWidget()
    LargePromiseWidget()
  }
}
```

---

## Phase 4: Silent Push 연동

### 4.1 Firebase Swizzling 비활성화 (필수!)

> ⚠️ **중요**: Firebase Method Swizzling이 활성화되어 있으면 `didReceiveRemoteNotification`이 호출되지 않음

**파일**: `Tuist/ProjectDescriptionHelpers/AppConfig.swift`

```swift
public static var infoPlist: [String: Plist.Value] {
  return [
    // ... 기존 설정들 ...

    // Firebase Swizzling 비활성화 (Silent Push 직접 처리)
    "FirebaseAppDelegateProxyEnabled": .boolean(false),
  ]
}
```

### 4.2 Cloud Functions - Silent Push 트리거

**파일**: `infra/firebase/functions/src/functions/widgetPush.ts`

```typescript
import {
  onDocumentCreated,
  onDocumentUpdated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";
import {admin, REGION} from "../config";

async function sendWidgetSilentPush(
  userIds: string[],
  env: "stage" | "prod" | null = null
): Promise<void> {
  // FCM 토큰 수집
  const allTokens: string[] = [];
  // ... 토큰 조회 로직 ...

  // Silent Push 전송 (APNs 필수 헤더 포함)
  const bundleId = "com.promiso";
  const message: admin.messaging.MulticastMessage = {
    tokens: allTokens,
    apns: {
      headers: {
        "apns-push-type": "background",    // Silent Push 필수
        "apns-priority": "5",               // 배터리 최적화
        "apns-topic": bundleId,             // iOS 13+ 필수
        "apns-collapse-id": "widget-refresh", // 중복 방지
      },
      payload: {
        aps: {
          "content-available": 1,
        },
        type: "widget_refresh",             // ⚠️ payload 내부에 위치!
      },
    },
  };

  await admin.messaging().sendEachForMulticast(message);
}

// 트리거: 약속 생성/수정/삭제
export const onPromiseCreatedWidgetPush = onDocumentCreated(
  { document: "{env}/root/promises/{promiseId}", region: REGION },
  async (event) => { /* ... */ }
);

export const onPromiseUpdatedWidgetPush = onDocumentUpdated(
  { document: "{env}/root/promises/{promiseId}", region: REGION },
  async (event) => {
    // 주요 필드 변경 시에만 발송
    const significantChange =
      before.title !== after.title ||
      before.startAt?.toMillis() !== after.startAt?.toMillis() ||
      JSON.stringify(before.votes) !== JSON.stringify(after.votes) ||
      before.isConfirmed !== after.isConfirmed;
    // ...
  }
);

export const onPromiseDeletedWidgetPush = onDocumentDeleted(/* ... */);
```

### 4.3 AppDelegate 핸들러

**파일**: `Projects/App/Sources/AppDelegate.swift`

```swift
// MARK: - Silent Push (Widget Refresh)

func application(
  _ application: UIApplication,
  didReceiveRemoteNotification userInfo: [AnyHashable: Any],
  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
  // type 필드는 APNs payload에서 직접 전달됨
  guard let type = userInfo["type"] as? String, type == "widget_refresh" else {
    completionHandler(.noData)
    return
  }

  AppLogger.notification.debug("Widget refresh silent push received")

  // 서버에서 위젯 스냅샷 조회 → 캐시 저장 → 위젯 갱신
  Task {
    let success = await WidgetDataManager.refreshFromServer()
    completionHandler(success ? .newData : .failed)
  }
}
```

### 4.4 WidgetDataManager - 서버 연동

```swift
// MARK: - Server Refresh (Silent Push용)

/// Firebase Functions에서 위젯 스냅샷 조회
@discardableResult
public static func refreshFromServer() async -> Bool {
  let functions = Functions.functions(region: "asia-northeast3")

  do {
    let result = try await functions.httpsCallable("getWidgetSnapshot")
      .call(["env": loadFirestoreEnv()])

    // JSON 파싱 → 캐시 저장 → 위젯 갱신
    let promises = convertSnapshotToPromises(snapshot)
    savePromises(promises)
    reloadWidgets()

    return true
  } catch {
    return false
  }
}

// MARK: - Widget Direct Fetch (iOS 17+ Timeline Provider용)

public static func fetchFromServer() async -> [WidgetPromiseData] {
  // URLSession으로 직접 API 호출
  // 실패 시 캐시 반환
}
```

---

## Phase 5: 앱 연동

### 5.1 HomeFeature 캐시 업데이트

**파일**: `Projects/Features/HomeFeature/Sources/HomeFeature.swift` (수정)

```swift
case .internal(.promisesLoaded(let promises)):
  state.allPromises = promises

  // Widget 캐시 업데이트
  let widgetData = promises
    .filter { $0.isConfirmed }
    .map { WidgetPromiseData(from: $0) }
  WidgetDataManager.savePromises(widgetData)

  return .none
```

### 5.2 로그인/로그아웃 처리

**파일**: `Projects/Clients/Sources/Clients/AuthClient.swift` (수정)

```swift
// 로그인 성공 시
WidgetDataManager.saveUserId(user.id)
WidgetDataManager.reloadWidgets()

// 로그아웃 시
WidgetDataManager.clearAll()
WidgetDataManager.reloadWidgets()
```

---

## 구현 체크리스트

### Phase 1: 기반 ✅
- [x] Tuist 타겟 추가 (`Project.swift`)
- [x] App Group Entitlements
- [x] WidgetDataManager 구현
- [x] WidgetPromiseData 모델 (+ placeholder)
- [x] `tuist generate` 실행

### Phase 2: Provider ✅
- [x] WidgetPromiseEntry 모델 (+ WidgetState)
- [x] TimelineProvider 구현
  - [x] placeholder(in:)
  - [x] getSnapshot(in:completion:)
  - [x] getTimeline(in:completion:) + iOS 17 direct fetch
- [x] 갱신 정책 로직 (15분/30분/1시간)

### Phase 3: UI ✅
- [x] SmallPromiseWidget
- [x] MediumPromiseWidget
- [x] LargePromiseWidget
- [x] EmptyWidgetView
- [x] NotLoggedInView
- [x] PromiseRowView
- [x] PromiseWidgetBundle

### Phase 4: Push ✅
- [x] Firebase Swizzling 비활성화 (`AppConfig.swift`)
- [x] Cloud Functions 트리거 (`widgetPush.ts`)
  - [x] APNs 필수 헤더 (apns-topic, apns-collapse-id)
  - [x] type 필드 위치 수정 (payload 내부)
- [x] AppDelegate Silent Push 핸들러
- [x] 위젯 갱신 호출

### Phase 5: 연동 ✅
- [x] AppEntryFeature 캐시 업데이트
- [x] 로그인 시 userId + firestoreEnv 저장
- [x] 로그아웃 시 데이터 초기화 + 위젯 갱신
- [x] 딥링크 라우팅 확인
- [x] 알림 권한 체크 플로우 수정 (기존 사용자 포함)

### Phase 6: iOS 26 Widget Push 🔜
- [ ] Widget Push API 연동
- [ ] apns-topic 변경 (`com.promiso.push-type.widgets`)
- [ ] onPushNotification 핸들러 구현
- [ ] 기존 Silent Push와 병행 운영

---

## 테스트 시나리오

### 1. 위젯 추가 테스트
1. 시뮬레이터에서 홈 화면 길게 누르기
2. '+' 버튼 → Promiso 검색
3. Small/Medium/Large 위젯 추가
4. 각 크기별 레이아웃 확인

### 2. 데이터 표시 테스트
1. 앱에서 약속 생성
2. 위젯에 새 약속 표시 확인
3. 오늘/다가오는 약속 분류 확인

### 3. 딥링크 테스트
1. 위젯의 약속 탭
2. 앱 열리고 해당 약속 상세 화면으로 이동 확인

### 4. 상태별 UI 테스트
1. 로그아웃 → NotLoggedInView 표시
2. 약속 없음 → EmptyWidgetView 표시
3. 캐시 2시간 초과 → Stale 인디케이터 표시

### 5. 오프라인 테스트
1. 비행기 모드 활성화
2. 위젯에 캐시된 데이터 표시 확인

---

## 트러블슈팅

### Silent Push가 수신되지 않음

**증상**: 서버 로그에 "Widget push sent" 표시되지만 앱에서 콜백 안 됨

**원인**: Firebase Method Swizzling이 APNs 콜백을 가로챔

**해결**:
```swift
// AppConfig.swift
"FirebaseAppDelegateProxyEnabled": .boolean(false)
```

### type 필드가 userInfo에 없음

**증상**: `userInfo["type"]`가 nil

**원인**: `type` 필드가 FCM `data`에 있으면 iOS에서 전달 안 됨

**해결**: APNs `payload` 내부에 위치시킴
```typescript
apns: {
  payload: {
    aps: { "content-available": 1 },
    type: "widget_refresh",  // ✅ 여기!
  },
}
```

### 알림 권한이 없어서 Silent Push 실패

**증상**: 앱 재설치 후 알림 권한 요청 안 됨

**원인**: 기존 사용자 플로우에서 권한 체크 누락

**해결**: `AppEntryFeature`에서 기존 사용자도 알림 권한 체크
```swift
case .profileCheckResponse(let user, let profile):
  if let userModel = profile {
    // 기존 사용자도 알림 권한 체크
    return .send(.internal(.checkNotificationPermission(userModel)))
  }
```

### APNs 필수 헤더 누락

**증상**: Silent Push 발송 실패 또는 불안정

**해결**: 모든 필수 헤더 추가
```typescript
headers: {
  "apns-push-type": "background",  // Silent Push 필수
  "apns-priority": "5",
  "apns-topic": "com.promiso",      // iOS 13+ 필수
  "apns-collapse-id": "widget-refresh",
}
```

---

## 관련 문서

- [기술 스펙](../specs/WIDGET_SPEC.md)
- [프로젝트 컨텍스트](../PROJECT_CONTEXT.md)
- [Push Notification 가이드](../PUSH_NOTIFICATION_GUIDE.md)
