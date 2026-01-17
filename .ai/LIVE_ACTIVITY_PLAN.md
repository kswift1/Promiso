# Promiso 라이브액티비티 구현 계획 (iOS 18+ Broadcast)

## 개요

약속 당일 실시간 도착 상황을 Dynamic Island와 잠금화면에서 공유하는 기능.
**iOS 18+ Broadcast Push Notifications**를 활용하여 서버에서 모든 참여자에게 동시 업데이트.

## 아키텍처

```
┌─────────────────────────────────────────────────────────────────┐
│                        Firebase Functions                        │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │ Channel Manager │  │ Broadcast Sender│  │ Scheduler       │  │
│  │ - create        │  │ - start         │  │ - 30분 전 감지  │  │
│  │ - delete        │  │ - update        │  │ - 자동 종료     │  │
│  └────────┬────────┘  │ - end           │  └────────┬────────┘  │
│           │           └────────┬────────┘           │           │
└───────────┼────────────────────┼────────────────────┼───────────┘
            │                    │                    │
            ▼                    ▼                    ▼
┌─────────────────────────────────────────────────────────────────┐
│                        APNs (Broadcast)                          │
│         단일 요청 → 채널 구독자 전원에게 동시 전송                 │
└─────────────────────────────────────────────────────────────────┘
            │
            ▼
┌─────────────────────────────────────────────────────────────────┐
│                         iOS App                                  │
│  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────┐ │
│  │ LiveActivityWidget│  │ LiveActivityClient│  │PromiseDetail  │ │
│  │ - Dynamic Island │  │ - subscribe      │  │ - 도착 버튼    │ │
│  │ - Lock Screen    │  │ - unsubscribe    │  │ - 상태 표시    │ │
│  └──────────────────┘  └──────────────────┘  └────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

## 현재 상태

| 항목 | 상태 | 비고 |
|------|------|------|
| Widget Extension | ❌ 없음 | 신규 생성 필요 |
| App Groups | ✅ 있음 | `group.com.promiso.shared` |
| APNs Entitlement | ✅ 있음 | `aps-environment` |
| iOS Target | ✅ 18.0+ | Broadcast 지원 |
| PromiseModel | ✅ 있음 | `isRealtimeShareable` 속성 |
| Firebase Functions | ✅ 있음 | FCM 통합 완료 |

## 구현 단계

---

### Phase 1: Widget Extension 설정

#### 1.1 폴더 구조

```
Projects/App/
├── Sources/
├── Resources/
├── Promiso.entitlements
├── Project.swift                    # App + Extension 타겟 함께 정의
└── Extensions/
    └── LiveActivityWidget/
        ├── Sources/
        │   ├── LiveActivityWidgetBundle.swift
        │   ├── PromiseLiveActivity.swift
        │   └── Views/
        │       └── LockScreenView.swift
        └── LiveActivityWidget.entitlements
```

#### 1.2 Tuist 타겟 수정

**파일:** `Projects/App/Project.swift`

```swift
import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
  name: AppConfig.name,
  targets: [
    // 메인 앱 타겟
    .target(
      name: AppConfig.name,
      destinations: .iOS,
      product: .app,
      bundleId: AppConfig.bundleId,
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: AppConfig.infoPlist),
      sources: ["Sources/**"],
      resources: ["Resources/**"],
      entitlements: .file(path: "Promiso.entitlements"),
      dependencies: AppFeatureDeps.allDeps + [
        .target(name: "LiveActivityWidgetExtension")  // Extension embed
      ],
      settings: .standard()
    ),
    // 라이브액티비티 위젯 Extension
    .target(
      name: "LiveActivityWidgetExtension",
      destinations: .iOS,
      product: .appExtension,
      bundleId: "\(AppConfig.bundleId).liveactivity",
      deploymentTargets: .iOS(AppConfig.deploymentTargets),
      infoPlist: .extendingDefault(with: [
        "CFBundleDisplayName": "Promiso Live Activity",
        "NSExtension": [
          "NSExtensionPointIdentifier": "com.apple.widgetkit-extension"
        ]
      ]),
      sources: ["Extensions/LiveActivityWidget/Sources/**"],
      entitlements: .file(path: "Extensions/LiveActivityWidget/LiveActivityWidget.entitlements"),
      dependencies: [
        .project(target: "PromisoShared", path: "../Shared")
      ]
    )
  ]
)
```

#### 1.3 Entitlements 파일

**파일:** `Projects/App/Extensions/LiveActivityWidget/LiveActivityWidget.entitlements`

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

#### 1.3 App Info.plist 수정

**파일:** `Tuist/ProjectDescriptionHelpers/AppConfig.swift`

```swift
// infoPlist에 추가
"NSSupportsLiveActivities": true,
"NSSupportsLiveActivitiesFrequentUpdates": true
```

#### 1.4 App Entitlements 수정

**파일:** `Projects/App/Promiso.entitlements`

```xml
<!-- 추가 -->
<key>com.apple.developer.push-to-talk</key>
<true/>
```

---

### Phase 2: 공유 모델 정의

**파일:** `Projects/Shared/Sources/LiveActivity/PromiseActivityAttributes.swift`

```swift
import ActivityKit
import Foundation

/// 라이브액티비티 속성 (변하지 않는 값)
public struct PromiseActivityAttributes: ActivityAttributes {
  /// 약속 ID
  public let promiseId: String
  /// 약속 제목
  public let title: String
  /// 이모지
  public let emoji: String
  /// 약속 시작 시간
  public let startAt: Date
  /// 장소명 (옵셔널)
  public let locationName: String?
  /// 그룹 ID
  public let groupId: String
  /// 총 참여 인원
  public let totalParticipants: Int

  public init(
    promiseId: String,
    title: String,
    emoji: String,
    startAt: Date,
    locationName: String?,
    groupId: String,
    totalParticipants: Int
  ) {
    self.promiseId = promiseId
    self.title = title
    self.emoji = emoji
    self.startAt = startAt
    self.locationName = locationName
    self.groupId = groupId
    self.totalParticipants = totalParticipants
  }

  /// 실시간 변경되는 상태
  public struct ContentState: Codable, Hashable {
    /// 멤버별 도착 상태
    public let memberStatuses: [MemberArrivalStatus]
    /// 마지막 업데이트 시간
    public let lastUpdatedAt: Date
    /// 종료 여부
    public let isEnded: Bool

    public init(
      memberStatuses: [MemberArrivalStatus],
      lastUpdatedAt: Date = Date(),
      isEnded: Bool = false
    ) {
      self.memberStatuses = memberStatuses
      self.lastUpdatedAt = lastUpdatedAt
      self.isEnded = isEnded
    }

    /// 도착한 인원 수
    public var arrivedCount: Int {
      memberStatuses.filter(\.hasArrived).count
    }

    /// 초기 상태 (모두 미도착)
    public static func initial(memberIds: [String], memberNames: [String]) -> ContentState {
      let statuses = zip(memberIds, memberNames).map { id, name in
        MemberArrivalStatus(memberId: id, memberName: name)
      }
      return ContentState(memberStatuses: statuses, isEnded: false)
    }
  }
}

/// 멤버 도착 상태
public struct MemberArrivalStatus: Codable, Hashable, Identifiable {
  public var id: String { memberId }

  /// 멤버 ID
  public let memberId: String
  /// 멤버 이름 (표시용)
  public let memberName: String
  /// 도착 여부
  public let hasArrived: Bool
  /// 도착 시간 (도착한 경우)
  public let arrivedAt: Date?

  public init(
    memberId: String,
    memberName: String,
    hasArrived: Bool = false,
    arrivedAt: Date? = nil
  ) {
    self.memberId = memberId
    self.memberName = memberName
    self.hasArrived = hasArrived
    self.arrivedAt = arrivedAt
  }

  /// 도착 처리
  public func arrived() -> MemberArrivalStatus {
    MemberArrivalStatus(
      memberId: memberId,
      memberName: memberName,
      hasArrived: true,
      arrivedAt: Date()
    )
  }
}
```

---

### Phase 3: LiveActivityClient 구현

**파일:** `Projects/Clients/Sources/Clients/LiveActivityClient.swift`

```swift
import ActivityKit
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct LiveActivityClient: Sendable {
  /// 라이브액티비티 지원 여부
  public var isSupported: @Sendable () -> Bool = { false }

  /// 현재 활성화된 라이브액티비티가 있는지
  public var hasActiveActivity: @Sendable () -> Bool = { false }

  /// 현재 활성화된 약속 ID
  public var activePromiseId: @Sendable () -> String? = { nil }

  /// 라이브액티비티 시작 (Broadcast 채널 구독)
  /// - Parameters:
  ///   - attributes: 약속 속성
  ///   - initialState: 초기 상태
  ///   - channelId: APNs Broadcast 채널 ID
  /// - Returns: Activity ID
  public var start: @Sendable (
    _ attributes: PromiseActivityAttributes,
    _ initialState: PromiseActivityAttributes.ContentState,
    _ channelId: String
  ) async throws -> String = { _, _, _ in "" }

  /// 로컬 업데이트 (앱에서 직접 업데이트)
  public var updateLocal: @Sendable (
    _ activityId: String,
    _ state: PromiseActivityAttributes.ContentState
  ) async throws -> Void = { _, _ in }

  /// 라이브액티비티 종료
  public var end: @Sendable (_ activityId: String) async throws -> Void = { _ in }

  /// 모든 라이브액티비티 종료
  public var endAll: @Sendable () async -> Void = { }
}

// MARK: - Live Implementation

extension LiveActivityClient {
  public static let live: Self = {
    return Self(
      isSupported: {
        ActivityAuthorizationInfo().areActivitiesEnabled
      },
      hasActiveActivity: {
        !Activity<PromiseActivityAttributes>.activities.isEmpty
      },
      activePromiseId: {
        Activity<PromiseActivityAttributes>.activities.first?.attributes.promiseId
      },
      start: { attributes, initialState, channelId in
        let content = ActivityContent(
          state: initialState,
          staleDate: nil
        )
        let activity = try Activity.request(
          attributes: attributes,
          content: content,
          pushType: .channel(channelId)  // iOS 18+ Broadcast
        )
        return activity.id
      },
      updateLocal: { activityId, state in
        guard let activity = Activity<PromiseActivityAttributes>.activities
          .first(where: { $0.id == activityId }) else {
          return
        }
        let content = ActivityContent(state: state, staleDate: nil)
        await activity.update(content)
      },
      end: { activityId in
        guard let activity = Activity<PromiseActivityAttributes>.activities
          .first(where: { $0.id == activityId }) else {
          return
        }
        await activity.end(nil, dismissalPolicy: .immediate)
      },
      endAll: {
        for activity in Activity<PromiseActivityAttributes>.activities {
          await activity.end(nil, dismissalPolicy: .immediate)
        }
      }
    )
  }()
}

// MARK: - Dependency Registration

extension LiveActivityClient: DependencyKey {
  public static let liveValue: LiveActivityClient = .live
  public static let testValue: LiveActivityClient = LiveActivityClient()
}

extension DependencyValues {
  public var liveActivityClient: LiveActivityClient {
    get { self[LiveActivityClient.self] }
    set { self[LiveActivityClient.self] = newValue }
  }
}
```

---

### Phase 4: Widget UI 구현

#### 4.1 Widget Bundle

**파일:** `Projects/App/Extensions/LiveActivityWidget/Sources/LiveActivityWidgetBundle.swift`

```swift
import SwiftUI
import WidgetKit

@main
struct LiveActivityWidgetBundle: WidgetBundle {
  var body: some Widget {
    PromiseLiveActivity()
  }
}
```

#### 4.2 Live Activity 정의

**파일:** `Projects/App/Extensions/LiveActivityWidget/Sources/PromiseLiveActivity.swift`

```swift
import ActivityKit
import SwiftUI
import WidgetKit
import PromisoShared

struct PromiseLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: PromiseActivityAttributes.self) { context in
      // 잠금화면 UI
      LockScreenView(
        attributes: context.attributes,
        state: context.state
      )
    } dynamicIsland: { context in
      DynamicIsland {
        // Expanded Region
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 4) {
            Text(context.attributes.emoji)
              .font(.title2)
            Text(context.attributes.title)
              .font(.headline)
              .lineLimit(1)
          }
        }

        DynamicIslandExpandedRegion(.trailing) {
          ArrivalCountBadge(
            arrived: context.state.arrivedCount,
            total: context.attributes.totalParticipants
          )
        }

        DynamicIslandExpandedRegion(.bottom) {
          MemberStatusRow(members: context.state.memberStatuses)
        }

      } compactLeading: {
        // Compact Leading
        Text(context.attributes.emoji)
          .font(.caption)
      } compactTrailing: {
        // Compact Trailing
        Text("\(context.state.arrivedCount)/\(context.attributes.totalParticipants)")
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
      } minimal: {
        // Minimal (다른 라이브액티비티와 공존 시)
        Text(context.attributes.emoji)
          .font(.caption)
      }
    }
  }
}
```

#### 4.3 잠금화면 뷰

**파일:** `Projects/App/Extensions/LiveActivityWidget/Sources/Views/LockScreenView.swift`

```swift
import SwiftUI
import WidgetKit
import PromisoShared

struct LockScreenView: View {
  let attributes: PromiseActivityAttributes
  let state: PromiseActivityAttributes.ContentState

  var body: some View {
    HStack(spacing: 16) {
      // 왼쪽: 약속 정보
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(attributes.emoji)
            .font(.title2)
          Text(attributes.title)
            .font(.headline)
            .lineLimit(1)
        }

        if let location = attributes.locationName {
          Label(location, systemImage: "mappin")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Text(attributes.startAt, style: .time)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      // 오른쪽: 도착 현황
      VStack(alignment: .trailing, spacing: 4) {
        ArrivalCountBadge(
          arrived: state.arrivedCount,
          total: attributes.totalParticipants
        )

        Text("도착")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding()
    .activityBackgroundTint(.black.opacity(0.7))
  }
}

struct ArrivalCountBadge: View {
  let arrived: Int
  let total: Int

  var body: some View {
    Text("\(arrived)/\(total)")
      .font(.title2.bold().monospacedDigit())
      .foregroundStyle(arrived == total ? .green : .primary)
  }
}

struct MemberStatusRow: View {
  let members: [MemberArrivalStatus]

  var body: some View {
    HStack(spacing: 8) {
      ForEach(members.prefix(5)) { member in
        MemberAvatar(member: member)
      }

      if members.count > 5 {
        Text("+\(members.count - 5)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }
}

struct MemberAvatar: View {
  let member: MemberArrivalStatus

  var body: some View {
    VStack(spacing: 2) {
      ZStack {
        Circle()
          .fill(member.hasArrived ? .green : .gray.opacity(0.3))
          .frame(width: 32, height: 32)

        Text(String(member.memberName.prefix(1)))
          .font(.caption.bold())
          .foregroundStyle(.white)

        if member.hasArrived {
          Image(systemName: "checkmark.circle.fill")
            .font(.caption2)
            .foregroundStyle(.green)
            .offset(x: 10, y: 10)
        }
      }

      Text(member.memberName)
        .font(.caption2)
        .lineLimit(1)
    }
  }
}
```

---

### Phase 5: Firebase Functions (Broadcast)

#### 5.1 채널 관리 & 브로드캐스트

**파일:** `infra/firebase/functions/src/liveActivity.ts`

```typescript
import * as functions from "firebase-functions/v2";
import * as admin from "firebase-admin";
import * as jwt from "jsonwebtoken";
import * as https from "https";

const APNS_HOST = "api.push.apple.com";
const APNS_HOST_SANDBOX = "api.sandbox.push.apple.com";
const BUNDLE_ID = "com.promiso";

// APNs P8 키 (환경변수에서 로드)
const APNS_KEY_ID = functions.params.defineString("APNS_KEY_ID");
const APNS_TEAM_ID = functions.params.defineString("APNS_TEAM_ID");
const APNS_AUTH_KEY = functions.params.defineSecret("APNS_AUTH_KEY");

interface BroadcastPayload {
  aps: {
    timestamp: number;
    event: "start" | "update" | "end";
    "content-state"?: {
      memberStatuses: Array<{
        memberId: string;
        memberName: string;
        hasArrived: boolean;
        arrivedAt?: number;
      }>;
      lastUpdatedAt: number;
      isEnded: boolean;
    };
    "attributes-type"?: string;
    attributes?: {
      promiseId: string;
      title: string;
      emoji: string;
      startAt: number;
      locationName?: string;
      groupId: string;
      totalParticipants: number;
    };
    "dismissal-date"?: number;
  };
}

/**
 * APNs JWT 토큰 생성
 */
function generateAPNsToken(authKey: string): string {
  const token = jwt.sign({}, authKey, {
    algorithm: "ES256",
    keyid: APNS_KEY_ID.value(),
    issuer: APNS_TEAM_ID.value(),
    expiresIn: "1h",
  });
  return token;
}

/**
 * APNs Broadcast 전송
 */
async function sendBroadcast(
  channelId: string,
  payload: BroadcastPayload,
  authKey: string,
  sandbox: boolean = false
): Promise<void> {
  const host = sandbox ? APNS_HOST_SANDBOX : APNS_HOST;
  const token = generateAPNsToken(authKey);

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: host,
        port: 443,
        path: `/4/broadcasts/apps/${BUNDLE_ID}`,
        method: "POST",
        headers: {
          authorization: `bearer ${token}`,
          "apns-push-type": "liveactivity",
          "apns-priority": "10",
          "apns-channel-id": channelId,
          "content-type": "application/json",
        },
      },
      (res) => {
        if (res.statusCode === 200) {
          resolve();
        } else {
          reject(new Error(`APNs error: ${res.statusCode}`));
        }
      }
    );

    req.on("error", reject);
    req.write(JSON.stringify(payload));
    req.end();
  });
}

/**
 * 약속 생성 시 채널 ID 생성 및 저장
 */
export const createLiveActivityChannel = functions.firestore.onDocumentCreated(
  "promises/{promiseId}",
  async (event) => {
    const promiseId = event.params.promiseId;
    const channelId = `promise_${promiseId}`;

    // Firestore에 채널 ID 저장
    await admin.firestore().doc(`promises/${promiseId}`).update({
      liveActivityChannelId: channelId,
    });

    functions.logger.info(`Created channel: ${channelId}`);
  }
);

/**
 * 약속 30분 전 자동 라이브액티비티 시작 (스케줄러)
 */
export const startLiveActivityScheduler = functions.scheduler.onSchedule(
  "every 5 minutes",
  async () => {
    const now = new Date();
    const thirtyMinutesLater = new Date(now.getTime() + 30 * 60 * 1000);
    const twentyFiveMinutesLater = new Date(now.getTime() + 25 * 60 * 1000);

    // 30분 이내 시작하는 확정된 약속 조회
    const snapshot = await admin
      .firestore()
      .collection("promises")
      .where("startAt", ">=", admin.firestore.Timestamp.fromDate(twentyFiveMinutesLater))
      .where("startAt", "<=", admin.firestore.Timestamp.fromDate(thirtyMinutesLater))
      .where("isDeleted", "==", false)
      .get();

    for (const doc of snapshot.docs) {
      const promise = doc.data();
      const channelId = promise.liveActivityChannelId;

      if (!channelId || promise.liveActivityStarted) continue;

      // 참여자 정보 조회
      const acceptedIds: string[] = promise.votes?.accepted || [];
      const members = await Promise.all(
        acceptedIds.map(async (uid) => {
          const userDoc = await admin.firestore().doc(`users/${uid}`).get();
          return {
            memberId: uid,
            memberName: userDoc.data()?.displayName || "Unknown",
            hasArrived: false,
          };
        })
      );

      // 브로드캐스트 전송 (start)
      const payload: BroadcastPayload = {
        aps: {
          timestamp: Math.floor(Date.now() / 1000),
          event: "start",
          "attributes-type": "PromiseActivityAttributes",
          attributes: {
            promiseId: doc.id,
            title: promise.title,
            emoji: promise.emoji || "📌",
            startAt: promise.startAt.toDate().getTime() / 1000,
            locationName: promise.location?.name,
            groupId: promise.groupId,
            totalParticipants: acceptedIds.length,
          },
          "content-state": {
            memberStatuses: members,
            lastUpdatedAt: Math.floor(Date.now() / 1000),
            isEnded: false,
          },
        },
      };

      try {
        await sendBroadcast(channelId, payload, APNS_AUTH_KEY.value());
        await doc.ref.update({ liveActivityStarted: true });
        functions.logger.info(`Started live activity for promise: ${doc.id}`);
      } catch (error) {
        functions.logger.error(`Failed to start live activity: ${error}`);
      }
    }
  }
);

/**
 * 멤버 도착 상태 업데이트 시 브로드캐스트
 */
export const updateArrivalStatus = functions.https.onCall(
  { secrets: [APNS_AUTH_KEY] },
  async (request) => {
    const { promiseId, memberId } = request.data;
    const uid = request.auth?.uid;

    if (!uid || uid !== memberId) {
      throw new functions.https.HttpsError("permission-denied", "Unauthorized");
    }

    const promiseDoc = await admin.firestore().doc(`promises/${promiseId}`).get();
    const promise = promiseDoc.data();

    if (!promise?.liveActivityChannelId) {
      throw new functions.https.HttpsError("not-found", "Channel not found");
    }

    // 도착 상태 업데이트
    const arrivals = promise.arrivals || {};
    arrivals[memberId] = {
      arrivedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await promiseDoc.ref.update({ arrivals });

    // 업데이트된 상태로 브로드캐스트
    const acceptedIds: string[] = promise.votes?.accepted || [];
    const members = await Promise.all(
      acceptedIds.map(async (id) => {
        const userDoc = await admin.firestore().doc(`users/${id}`).get();
        const arrival = arrivals[id];
        return {
          memberId: id,
          memberName: userDoc.data()?.displayName || "Unknown",
          hasArrived: !!arrival,
          arrivedAt: arrival?.arrivedAt?.toDate().getTime() / 1000,
        };
      })
    );

    const payload: BroadcastPayload = {
      aps: {
        timestamp: Math.floor(Date.now() / 1000),
        event: "update",
        "content-state": {
          memberStatuses: members,
          lastUpdatedAt: Math.floor(Date.now() / 1000),
          isEnded: false,
        },
      },
    };

    await sendBroadcast(promise.liveActivityChannelId, payload, APNS_AUTH_KEY.value());

    return { success: true };
  }
);

/**
 * 약속 종료 시 라이브액티비티 종료
 */
export const endLiveActivity = functions.https.onCall(
  { secrets: [APNS_AUTH_KEY] },
  async (request) => {
    const { promiseId } = request.data;

    const promiseDoc = await admin.firestore().doc(`promises/${promiseId}`).get();
    const promise = promiseDoc.data();

    if (!promise?.liveActivityChannelId) {
      throw new functions.https.HttpsError("not-found", "Channel not found");
    }

    const payload: BroadcastPayload = {
      aps: {
        timestamp: Math.floor(Date.now() / 1000),
        event: "end",
        "dismissal-date": Math.floor(Date.now() / 1000) + 60, // 1분 후 자동 dismiss
        "content-state": {
          memberStatuses: [],
          lastUpdatedAt: Math.floor(Date.now() / 1000),
          isEnded: true,
        },
      },
    };

    await sendBroadcast(promise.liveActivityChannelId, payload, APNS_AUTH_KEY.value());
    await promiseDoc.ref.update({
      liveActivityStarted: false,
      liveActivityEnded: true,
    });

    return { success: true };
  }
);
```

---

### Phase 6: Feature 통합

#### 6.1 PromiseDetailFeature 수정

**파일:** `Projects/Features/SharedFeature/Sources/PromiseDetail/PromiseDetailFeature.swift`

추가할 내용:

```swift
// State에 추가
var isLiveActivityActive: Bool = false
var liveActivityId: String?

// ViewAction에 추가
case liveActivityStartTapped
case liveActivityStopTapped
case markArrivedTapped

// Internal에 추가
case fetchChannelId
case channelIdFetched(String)
case liveActivityStarted(id: String)
case liveActivityFailed(error: AppError)
case markArrivalDone
case markArrivalFailed(error: AppError)

// Reducer body에 추가
case .view(.liveActivityStartTapped):
  guard state.promise.isRealtimeShareable,
        state.promise.isConfirmed,
        !state.isLiveActivityActive else { return .none }
  return .send(.internal(.fetchChannelId))

case .view(.liveActivityStopTapped):
  guard let activityId = state.liveActivityId else { return .none }
  return .run { [liveActivityClient] send in
    try await liveActivityClient.end(activityId)
  }

case .view(.markArrivedTapped):
  let promiseId = state.promise.id
  return .run { send in
    // Firebase Functions 호출
    // try await functionsClient.updateArrivalStatus(promiseId)
    await send(.internal(.markArrivalDone))
  }

case .internal(.fetchChannelId):
  let promiseId = state.promise.id
  return .run { send in
    // Firestore에서 channelId 조회
    // let channelId = try await promiseClient.getChannelId(promiseId)
    // await send(.internal(.channelIdFetched(channelId)))
  }

case .internal(.channelIdFetched(let channelId)):
  let attributes = PromiseActivityAttributes(
    promiseId: state.promise.id,
    title: state.promise.title,
    emoji: state.promise.displayEmoji,
    startAt: state.promise.startAt,
    locationName: state.promise.location?.name,
    groupId: state.promise.groupId,
    totalParticipants: state.promise.votes.acceptedCount
  )
  let initialState = PromiseActivityAttributes.ContentState.initial(
    memberIds: state.promise.votes.accepted,
    memberNames: state.groupMembers?.map(\.displayName) ?? []
  )
  return .run { [liveActivityClient] send in
    do {
      let id = try await liveActivityClient.start(attributes, initialState, channelId)
      await send(.internal(.liveActivityStarted(id: id)))
    } catch {
      await send(.internal(.liveActivityFailed(error: AppError(error))))
    }
  }

case .internal(.liveActivityStarted(let id)):
  state.isLiveActivityActive = true
  state.liveActivityId = id
  return .none
```

#### 6.2 PromiseDetailView 수정

**파일:** `Projects/Features/SharedFeature/Sources/PromiseDetail/PromiseDetailView.swift`

추가할 내용:

```swift
// 실시간 공유 버튼 섹션
if store.promise.isRealtimeShareable && store.promise.isConfirmed {
  Section {
    if store.isLiveActivityActive {
      // 도착 버튼
      Button {
        store.send(.view(.markArrivedTapped))
      } label: {
        Label("도착 완료", systemImage: "checkmark.circle.fill")
      }
      .tint(.green)

      // 종료 버튼
      Button(role: .destructive) {
        store.send(.view(.liveActivityStopTapped))
      } label: {
        Label("실시간 공유 종료", systemImage: "stop.circle")
      }
    } else {
      // 시작 버튼
      Button {
        store.send(.view(.liveActivityStartTapped))
      } label: {
        Label("실시간 공유 시작", systemImage: "dot.radiowaves.left.and.right")
      }
      .tint(.indigo)
    }
  } header: {
    Text("실시간 공유")
  }
}
```

---

## 핵심 파일 요약

| 파일 | 설명 |
|------|------|
| `Projects/App/Project.swift` | App + Extension 타겟 정의 |
| `Projects/Shared/Sources/LiveActivity/PromiseActivityAttributes.swift` | 공유 모델 |
| `Projects/Clients/Sources/Clients/LiveActivityClient.swift` | TCA Client |
| `Projects/App/Extensions/LiveActivityWidget/Sources/PromiseLiveActivity.swift` | Widget 정의 |
| `Projects/App/Extensions/LiveActivityWidget/Sources/Views/LockScreenView.swift` | 잠금화면 UI |
| `infra/firebase/functions/src/liveActivity.ts` | Broadcast 서버 |
| `Projects/Features/SharedFeature/Sources/PromiseDetail/*` | Feature 통합 |

---

## 의존성 구조

```
Projects/App/
├─ Promiso (App Target)
│  ├─ embed ──► LiveActivityWidgetExtension
│  └─ Features/SharedFeature/PromiseDetail
│              └─ Clients/LiveActivityClient
│
└─ LiveActivityWidgetExtension (App Extension Target)
   └─ PromisoShared (PromiseActivityAttributes만 참조)

Projects/Clients/
└─ LiveActivityClient

Projects/Shared/
└─ LiveActivity/PromiseActivityAttributes  ◄── 공유 모델

Firebase Functions
└─ liveActivity.ts (APNs Broadcast 전송)
```

---

## 검증 방법

### 1. 빌드 확인
```bash
tuist generate
# App 타겟에 Extension 포함 확인
open Promiso.xcworkspace
# Promiso 스킴 → LiveActivityWidgetExtension이 embed 되었는지 확인

xcodebuild -workspace Promiso.xcworkspace -scheme Promiso -destination 'platform=iOS Simulator,name=iPhone 16 Pro'
```

### 2. 기능 테스트 (실기기 필수)
1. 약속 생성 → 30분 전 → "실시간 공유 시작" 버튼 활성화
2. 버튼 탭 → Dynamic Island/잠금화면에 라이브액티비티 표시
3. "도착 완료" 탭 → 다른 참여자 화면에 도착 상태 반영
4. "실시간 공유 종료" → 라이브액티비티 사라짐

### 3. Broadcast 테스트
```bash
# Firebase Functions 로컬 테스트
cd infra/firebase/functions
npm run serve

# APNs 브로드캐스트 테스트 (sandbox)
curl -X POST https://api.sandbox.push.apple.com/4/broadcasts/apps/com.promiso \
  -H "authorization: bearer <JWT_TOKEN>" \
  -H "apns-push-type: liveactivity" \
  -H "apns-channel-id: promise_<ID>" \
  -d '{"aps":{"timestamp":1234567890,"event":"update",...}}'
```

---

## 구현 순서 (권장)

1. **Phase 2**: 공유 모델 (PromiseActivityAttributes) - 먼저 정의
2. **Phase 1**: Widget Extension 타겟 설정
3. **Phase 3**: LiveActivityClient 구현
4. **Phase 4**: Widget UI (LockScreen → Dynamic Island)
5. **Phase 6**: PromiseDetailFeature 통합 (앱 단독 테스트)
6. **Phase 5**: Firebase Functions (서버 연동)

---

## 제외 범위 (향후 확장)

- GPS 기반 자동 도착 감지
- 도착 예상 시간 표시
- 멤버 위치 실시간 공유 (지도)
- 채널 자동 정리 (Cloud Scheduler)
