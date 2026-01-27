# Promiso Widget 구현 가이드

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
│           │   │   └── WidgetPromiseEntry.swift
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
│           ├── WidgetDataManager.swift
│           └── WidgetPromiseData.swift
└── Features/
    └── HomeFeature/
        └── Sources/
            └── HomeFeature.swift        # Widget 캐시 업데이트
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

### 4.1 Cloud Functions

**파일**: `infra/firebase/functions/src/widget/widgetPushTrigger.ts`

```typescript
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { getFirestore } from "firebase-admin/firestore";

export const onPromiseChange = onDocumentWritten(
  "promises/{promiseId}",
  async (event) => {
    const promise = event.data?.after?.data();
    if (!promise) return;

    const groupId = promise.groupId;
    const db = getFirestore();

    // 그룹 멤버 조회
    const groupDoc = await db.collection("groups").doc(groupId).get();
    const group = groupDoc.data();
    if (!group) return;

    const memberIds: string[] = group.members || [];

    // 멤버들의 FCM 토큰 조회
    const tokens: string[] = [];
    for (const memberId of memberIds) {
      const userDoc = await db.collection("users").doc(memberId).get();
      const fcmToken = userDoc.data()?.fcmToken;
      if (fcmToken) tokens.push(fcmToken);
    }

    if (tokens.length === 0) return;

    // Silent Push 발송
    const messaging = getMessaging();
    await messaging.sendEachForMulticast({
      tokens,
      data: {
        type: "widget_refresh",
      },
      apns: {
        headers: {
          "apns-priority": "5",
          "apns-push-type": "background",
        },
        payload: {
          aps: {
            "content-available": 1,
          },
        },
      },
    });
  }
);
```

### 4.2 AppDelegate 핸들러

**파일**: `Projects/App/Sources/AppDelegate.swift` (추가)

```swift
func application(
  _ application: UIApplication,
  didReceiveRemoteNotification userInfo: [AnyHashable: Any],
  fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
) {
  guard userInfo["type"] as? String == "widget_refresh" else {
    completionHandler(.noData)
    return
  }

  Task {
    do {
      @Dependency(\.promiseClient) var promiseClient
      @Dependency(\.groupClient) var groupClient

      let groups = try await groupClient.getMyGroups()
      let groupIds = groups.map { $0.id }
      let promises = try await promiseClient.getUpcomingPromises(groupIds, 20)

      let widgetData = promises.map { WidgetPromiseData(from: $0) }
      WidgetDataManager.savePromises(widgetData)
      WidgetDataManager.reloadWidgets()

      completionHandler(.newData)
    } catch {
      completionHandler(.failed)
    }
  }
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

### Phase 1: 기반
- [ ] Tuist 타겟 추가 (`Project.swift`)
- [ ] App Group Entitlements
- [ ] WidgetDataManager 구현
- [ ] WidgetPromiseData 모델 (+ placeholder)
- [ ] `tuist generate` 실행

### Phase 2: Provider
- [ ] WidgetPromiseEntry 모델 (+ WidgetState)
- [ ] TimelineProvider 구현
  - [ ] placeholder(in:)
  - [ ] getSnapshot(in:completion:)
  - [ ] getTimeline(in:completion:)
- [ ] 갱신 정책 로직 (+ 1시간 fallback)

### Phase 3: UI
- [ ] SmallPromiseWidget
- [ ] MediumPromiseWidget
- [ ] LargePromiseWidget
- [ ] EmptyWidgetView
- [ ] NotLoggedInView
- [ ] PromiseRowView
- [ ] PromiseWidgetBundle

### Phase 4: Push
- [ ] Cloud Functions 트리거 (`widgetPushTrigger.ts`)
- [ ] AppDelegate Silent Push 핸들러
- [ ] 위젯 갱신 호출

### Phase 5: 연동
- [ ] HomeFeature 캐시 업데이트
- [ ] 로그인 시 userId 저장 + 위젯 갱신
- [ ] 로그아웃 시 데이터 초기화 + 위젯 갱신
- [ ] 딥링크 라우팅 확인

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

## 관련 문서

- [기술 스펙](../specs/WIDGET_SPEC.md)
- [프로젝트 컨텍스트](../PROJECT_CONTEXT.md)
