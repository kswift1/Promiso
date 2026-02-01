# Promiso Widget 구현 가이드

> **상태**: ✅ 구현 완료 (v2 Snapshot 기반)
> **마지막 업데이트**: 2025.02.01

## 개요

이 문서는 Promiso 홈 화면 위젯 구현을 위한 단계별 가이드입니다.

### v2 아키텍처 변경점

| 항목 | v1 (API 호출) | v2 (Snapshot) |
|------|--------------|---------------|
| 데이터 갱신 | Widget에서 API 호출 | Firestore Trigger로 자동 갱신 |
| API 역할 | 매번 그룹/약속 조회 및 계산 | 캐시된 스냅샷 읽기만 |
| Race Condition | 있음 (복잡한 Lock 필요) | 없음 |
| 비용 | 높음 (N+1 쿼리) | 낮음 (1 read) |

---

## 파일 구조

```
Projects/
├── App/
│   ├── Project.swift                    # Tuist 타겟 추가
│   ├── Sources/
│   │   ├── AppDelegate.swift            # Push 핸들러
│   │   └── RootTabFeature 연동          # Widget Token 요청
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
│           ├── WidgetDataManager.swift  # App Group + 서버 fetch + Token 관리
│           └── WidgetPromiseData.swift
├── Clients/
│   └── Sources/
│       └── AuthClient.swift             # Widget Token 요청 로직
└── Features/
    └── RootTabFeature/
        └── Sources/
            └── RootTabFeature.swift     # 앱 실행 시 Widget Token 요청

Cloud Functions:
infra/firebase/functions/src/functions/
├── widget.ts                            # getWidgetSnapshot, getWidgetSnapshotWithToken (캐시 읽기)
├── widgetToken.ts                       # generateWidgetToken
└── widgetSnapshotTrigger.ts             # Firestore Trigger (v2 핵심)
    ├── onPromiseWriteUpdateSnapshot     # 약속 CRUD → 스냅샷 갱신
    ├── onPromiseWriteUpdateSnapshotProd # Prod 환경용
    ├── scheduledSnapshotRefresh         # 매일 자정 전체 갱신
    └── updateWidgetSnapshot()           # 핵심 갱신 로직
```

---

## Phase 1: Widget Token 인증 (핵심)

### 1.1 문제 정의

```
Firebase ID Token:
- 유효 기간: 1시간 (고정, 변경 불가)
- 갱신: Firebase SDK 필요 (Widget Extension에서 불가)
- 결과: 앱 종료 후 1시간 경과 시 Widget API 호출 실패
```

### 1.2 해결책: Long-lived Widget Token

**서버 (widgetToken.ts)**:

```typescript
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {defineSecret} from "firebase-functions/params";
import * as jwt from "jsonwebtoken";

export const WIDGET_JWT_SECRET = defineSecret("WIDGET_JWT_SECRET");

interface WidgetTokenPayload {
  sub: string;      // userId
  scope: string;    // "widget:read"
  deviceId: string; // 기기 바인딩
  version: number;  // revocation용
  iat: number;
  exp: number;
}

export const generateWidgetToken = onCall<{deviceId: string; env?: string}>({
  region: "asia-northeast3",
  secrets: [WIDGET_JWT_SECRET],
}, async (request) => {
  // 1. Firebase ID Token 인증 확인
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다");
  }

  const userId = request.auth.uid;
  const {deviceId, env} = request.data;

  // 2. deviceId 유효성 검사
  if (!deviceId || deviceId.trim().length === 0) {
    throw new HttpsError("invalid-argument", "deviceId는 필수입니다");
  }

  // 3. 토큰 버전 조회 (revocation용)
  const db = admin.firestore();
  const userDoc = await db.collection(env === "stage" ? "stage" : "prod")
    .doc("root").collection("users").doc(userId).get();

  let tokenVersion = 1;
  if (userDoc.exists) {
    tokenVersion = (userDoc.data()?.widgetTokenVersion as number) || 1;
  }

  // 4. JWT 생성 (30일 유효)
  const now = Math.floor(Date.now() / 1000);
  const expiresAt = now + 30 * 24 * 60 * 60; // 30일

  const payload = {
    sub: userId,
    scope: "widget:read",
    deviceId: deviceId.trim(),
    version: tokenVersion,
  };

  const secret = WIDGET_JWT_SECRET.value();
  const widgetToken = jwt.sign(payload, secret, {expiresIn: "30d"});

  return {widgetToken, expiresAt};
});

// 검증 헬퍼
export function verifyWidgetToken(
  token: string,
  secret: string
): WidgetTokenPayload {
  const decoded = jwt.verify(token, secret) as WidgetTokenPayload;
  if (decoded.scope !== "widget:read") {
    throw new HttpsError("permission-denied", "Invalid token scope");
  }
  return decoded;
}
```

**Secret 설정**:
```bash
# Secret 생성
openssl rand -hex 32

# Firebase에 설정
echo "생성된_시크릿" | firebase functions:secrets:set WIDGET_JWT_SECRET
```

### 1.3 iOS 클라이언트 - AuthClient

**파일**: `Projects/Clients/Sources/Clients/AuthClient.swift`

```swift
public struct AuthClient: Sendable {
  // 기존 필드들...

  /// Widget Token 요청 (앱 실행 시 호출)
  public var requestWidgetToken: @Sendable () async -> Void
}

extension AuthClient: DependencyKey {
  public static var liveValue: AuthClient {
    AuthClient(
      // 기존 구현들...

      requestWidgetToken: {
        // 1. 이미 유효한 토큰이 있으면 스킵
        if WidgetTokenStore.isTokenValid() {
          AppLogger.widget.debug("Widget Token 유효, 재발급 스킵")
          return
        }

        // 2. 로그인 상태 확인
        guard Auth.auth().currentUser != nil else {
          AppLogger.widget.debug("로그인 필요, Widget Token 스킵")
          return
        }

        // 3. deviceId 가져오기
        let deviceId = await UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString

        // 4. Functions 호출
        let functions = Functions.functions(region: "asia-northeast3")
        let env = FirebaseEnvironmentManager.shared.current.firebaseEnv

        do {
          let result = try await functions.httpsCallable("generateWidgetToken")
            .call(["deviceId": deviceId, "env": env])

          guard let data = result.data as? [String: Any],
                let widgetToken = data["widgetToken"] as? String,
                let expiresAt = data["expiresAt"] as? Int else {
            AppLogger.widget.error("Widget Token 응답 파싱 실패")
            return
          }

          // 5. App Group에 저장
          WidgetTokenStore.save(token: widgetToken, expiresAt: TimeInterval(expiresAt))
          AppLogger.widget.info("Widget Token 발급 완료")
        } catch {
          AppLogger.widget.error("Widget Token 발급 실패: \(error)")
        }
      }
    )
  }
}

// MARK: - Widget Token Store

private enum WidgetTokenStore {
  private static let defaults = UserDefaults(suiteName: "group.com.promiso.shared")
  private static let tokenKey = "widget.auth.token"
  private static let expiryKey = "widget.auth.tokenExpiry"

  static func save(token: String, expiresAt: TimeInterval) {
    defaults?.set(token, forKey: tokenKey)
    defaults?.set(expiresAt, forKey: expiryKey)
  }

  static func isTokenValid() -> Bool {
    guard let expiresAt = defaults?.double(forKey: expiryKey),
          expiresAt > 0 else { return false }

    // 만료 7일 전이면 갱신 필요
    let refreshThreshold = Date().timeIntervalSince1970 + (7 * 24 * 60 * 60)
    return expiresAt > refreshThreshold
  }

  static func clear() {
    defaults?.removeObject(forKey: tokenKey)
    defaults?.removeObject(forKey: expiryKey)
  }
}
```

### 1.4 RootTabFeature - 앱 실행 시 토큰 요청

**파일**: `Projects/Features/RootTabFeature/Sources/RootTabFeature.swift`

```swift
case .view(.onAppear):
  return .merge(
    .send(.internal(.refreshWidgetAuthToken)),
    .send(.internal(.requestWidgetToken)),  // Widget Token 요청
    .send(.internal(.observePushToStartToken)),
    .send(.internal(.observeActivityUpdates))
  )

case .internal(.requestWidgetToken):
  return .run { [authClient] _ in
    await authClient.requestWidgetToken()
  }
```

---

## Phase 2: WidgetDataManager (서버 연동)

### 2.1 Widget Token 기반 API 호출

**파일**: `Projects/Shared/Sources/Widget/WidgetDataManager.swift`

```swift
import Foundation
import WidgetKit
import os.log

public enum WidgetDataManager {
  private static let suiteName = "group.com.promiso.shared"
  private static let promisesKey = "widget.promises"
  private static let userIdKey = "widget.userId"
  private static let lastUpdatedKey = "widget.lastUpdated"
  private static let widgetTokenKey = "widget.auth.token"
  private static let widgetTokenExpiryKey = "widget.auth.tokenExpiry"
  private static let idTokenKey = "widget.auth.idToken"
  private static let firestoreEnvKey = "widget.firestore.env"

  private static let logger = Logger(
    subsystem: "com.promiso",
    category: "WidgetDataManager"
  )

  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: suiteName)
  }

  // MARK: - 서버에서 데이터 가져오기 (핵심)

  /// 서버에서 위젯 스냅샷 조회 (Widget Token → ID Token → Cache)
  public static func fetchFromServer() async -> [WidgetPromiseData] {
    logger.info("fetchFromServer 시작")

    // 1. Widget Token으로 시도 (30일 유효)
    if let widgetToken = loadWidgetToken() {
      logger.info("Widget Token으로 시도")
      let result = await fetchWithWidgetToken(widgetToken)
      if !result.isEmpty {
        return result
      }
    }

    // 2. ID Token으로 시도 (1시간 유효, Fallback)
    if let idToken = loadIdToken() {
      logger.info("ID Token으로 시도 (Fallback)")
      let result = await fetchWithIdToken(idToken)
      if !result.isEmpty {
        return result
      }
    }

    // 3. 캐시 반환
    logger.info("캐시 반환")
    return loadPromises()
  }

  // MARK: - Widget Token API 호출

  private static func fetchWithWidgetToken(_ token: String) async -> [WidgetPromiseData] {
    let baseURL = "https://asia-northeast3-promiso-prod.cloudfunctions.net"
    guard let url = URL(string: "\(baseURL)/getWidgetSnapshotWithToken") else {
      return []
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let env = loadFirestoreEnv() ?? "prod"
    let body = ["data": ["env": env]]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        return []
      }

      // 401: Token 만료 또는 무효
      if httpResponse.statusCode == 401 {
        logger.warning("Widget Token 만료 또는 무효")
        return []
      }

      guard httpResponse.statusCode == 200 else {
        logger.error("HTTP 오류: \(httpResponse.statusCode)")
        return []
      }

      return parseSnapshotResponse(data)
    } catch {
      logger.error("Widget Token API 오류: \(error.localizedDescription)")
      return []
    }
  }

  // MARK: - ID Token API 호출 (Fallback)

  private static func fetchWithIdToken(_ token: String) async -> [WidgetPromiseData] {
    let baseURL = "https://asia-northeast3-promiso-prod.cloudfunctions.net"
    guard let url = URL(string: "\(baseURL)/getWidgetSnapshot") else {
      return []
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let env = loadFirestoreEnv() ?? "prod"
    let body = ["data": ["env": env]]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200 else {
        return []
      }

      return parseSnapshotResponse(data)
    } catch {
      logger.error("ID Token API 오류: \(error.localizedDescription)")
      return []
    }
  }

  // MARK: - 응답 파싱

  private static func parseSnapshotResponse(_ data: Data) -> [WidgetPromiseData] {
    guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let result = json["result"] as? [String: Any] else {
      return []
    }

    var promises: [WidgetPromiseData] = []
    let isoFormatter = ISO8601DateFormatter()

    // next, today, upcoming 배열 파싱
    let allPromiseArrays = [
      result["next"] as? [[String: Any]] ?? (result["next"] as? [String: Any]).map { [$0] } ?? [],
      result["today"] as? [[String: Any]] ?? [],
      result["upcoming"] as? [[String: Any]] ?? []
    ].flatMap { $0 }

    for item in allPromiseArrays {
      guard let id = item["id"] as? String,
            let title = item["title"] as? String,
            let startAtString = item["startAt"] as? String,
            let startAt = isoFormatter.date(from: startAtString) else {
        continue
      }

      let promise = WidgetPromiseData(
        id: id,
        title: title,
        emoji: (item["emoji"] as? String) ?? "📅",
        startAt: startAt,
        endAt: (item["endAt"] as? String).flatMap { isoFormatter.date(from: $0) },
        location: item["location"] as? String,
        groupId: (item["groupId"] as? String) ?? "",
        groupName: item["groupName"] as? String,
        isConfirmed: (item["isConfirmed"] as? Bool) ?? false,
        participantCount: (item["participantCount"] as? Int) ?? 0
      )
      promises.append(promise)
    }

    // 중복 제거 및 정렬
    let uniquePromises = Array(Set(promises)).sorted { $0.startAt < $1.startAt }

    // 캐시에 저장
    savePromises(uniquePromises)

    logger.info("서버에서 \(uniquePromises.count)개 약속 로드")
    return uniquePromises
  }

  // MARK: - Token 로드

  public static func loadWidgetToken() -> String? {
    guard let token = defaults?.string(forKey: widgetTokenKey) else {
      return nil
    }

    // 만료 확인
    let expiresAt = defaults?.double(forKey: widgetTokenExpiryKey) ?? 0
    if expiresAt > 0 && Date().timeIntervalSince1970 > expiresAt {
      logger.warning("Widget Token 만료됨")
      return nil
    }

    return token
  }

  public static func loadIdToken() -> String? {
    defaults?.string(forKey: idTokenKey)
  }

  public static func loadFirestoreEnv() -> String? {
    defaults?.string(forKey: firestoreEnvKey)
  }

  // MARK: - 캐시 관리 (기존 구현)

  public static func savePromises(_ promises: [WidgetPromiseData]) {
    guard let defaults = defaults,
          let data = try? JSONEncoder().encode(promises) else { return }
    defaults.set(data, forKey: promisesKey)
    defaults.set(Date(), forKey: lastUpdatedKey)
  }

  public static func loadPromises() -> [WidgetPromiseData] {
    guard let defaults = defaults,
          let data = defaults.data(forKey: promisesKey),
          let promises = try? JSONDecoder().decode([WidgetPromiseData].self, from: data)
    else { return [] }

    return promises
      .filter { $0.startAt > Date().addingTimeInterval(-3600) }
      .sorted { $0.startAt < $1.startAt }
  }

  public static func saveUserId(_ userId: String?) {
    if let userId = userId {
      defaults?.set(userId, forKey: userIdKey)
    } else {
      defaults?.removeObject(forKey: userIdKey)
    }
  }

  public static func isLoggedIn() -> Bool {
    defaults?.string(forKey: userIdKey) != nil
  }

  public static func lastUpdated() -> Date? {
    defaults?.object(forKey: lastUpdatedKey) as? Date
  }

  public static func clearAll() {
    defaults?.removeObject(forKey: promisesKey)
    defaults?.removeObject(forKey: userIdKey)
    defaults?.removeObject(forKey: lastUpdatedKey)
    defaults?.removeObject(forKey: widgetTokenKey)
    defaults?.removeObject(forKey: widgetTokenExpiryKey)
    defaults?.removeObject(forKey: idTokenKey)
  }

  public static func reloadWidgets() {
    WidgetCenter.shared.reloadTimelines(ofKind: "SmallPromiseWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "MediumPromiseWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "LargePromiseWidget")
  }
}
```

---

## Phase 3: Timeline Provider

### 3.1 PromiseTimelineProvider

**파일**: `Projects/App/Extensions/PromiseWidget/Sources/Provider/PromiseTimelineProvider.swift`

```swift
import WidgetKit
import PromisoShared
import os.log

struct PromiseTimelineProvider: TimelineProvider {
  typealias Entry = WidgetPromiseEntry

  private let logger = Logger(subsystem: "com.promiso.widget", category: "Timeline")

  func placeholder(in context: Context) -> Entry {
    .placeholder
  }

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    completion(createEntry(from: WidgetDataManager.loadPromises()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    logger.info("Timeline 갱신 시작")

    Task {
      // 서버에서 최신 데이터 가져오기 (Widget Token → ID Token → Cache)
      let promises = await WidgetDataManager.fetchFromServer()
      let entry = createEntry(from: promises)

      // 다음 갱신 시간 계산
      let refreshDate = calculateNextRefresh(promises: promises)
      logger.info("다음 갱신: \(refreshDate, privacy: .public)")

      let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
      completion(timeline)
    }
  }

  private func createEntry(from promises: [WidgetPromiseData]) -> Entry {
    guard WidgetDataManager.isLoggedIn() else {
      return Entry(date: Date(), promises: [], state: .notLoggedIn)
    }

    let state: Entry.WidgetState = promises.isEmpty ? .empty : .loaded
    return Entry(date: Date(), promises: promises, state: state)
  }

  private func calculateNextRefresh(promises: [WidgetPromiseData]) -> Date {
    let now = Date()

    guard let nextPromise = promises.first(where: { $0.startAt > now }) else {
      return now.addingTimeInterval(3600) // 1시간
    }

    let timeUntil = nextPromise.startAt.timeIntervalSince(now)

    if timeUntil <= 3600 {      // 1시간 이내
      return now.addingTimeInterval(300)   // 5분
    }
    if timeUntil <= 21600 {     // 6시간 이내
      return now.addingTimeInterval(1800)  // 30분
    }
    return now.addingTimeInterval(3600)    // 1시간
  }
}
```

---

## Phase 4: Firebase Functions 배포

### 4.1 widget.ts 업데이트

**파일**: `infra/firebase/functions/src/functions/widget.ts`

```typescript
// getWidgetSnapshotWithToken 추가 (Widget Token 인증)
export const getWidgetSnapshotWithToken = onRequest({
  region: REGION,
  secrets: [WIDGET_JWT_SECRET],
}, async (req, res) => {
  res.set("Access-Control-Allow-Origin", "*");
  res.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.set("Access-Control-Allow-Headers", "Content-Type, Authorization");

  if (req.method === "OPTIONS") {
    res.status(204).send("");
    return;
  }

  const authHeader = req.headers.authorization;
  if (!authHeader?.startsWith("Bearer ")) {
    res.status(401).json({error: "Missing Authorization header"});
    return;
  }

  const token = authHeader.split("Bearer ")[1];

  try {
    const secret = WIDGET_JWT_SECRET.value();
    const decoded = verifyWidgetToken(token, secret);

    // 토큰 버전 확인 (revocation 체크)
    const db = admin.firestore();
    const env = req.body?.data?.env === "stage" ? "stage" : "prod";
    const userDoc = await db.collection(env).doc("root")
      .collection("users").doc(decoded.sub).get();

    if (userDoc.exists) {
      const currentVersion = userDoc.data()?.widgetTokenVersion || 1;
      if (decoded.version < currentVersion) {
        res.status(401).json({error: "Token revoked"});
        return;
      }
    }

    const snapshot = await fetchWidgetSnapshot(decoded.sub, env, db);
    res.status(200).json({result: snapshot});
  } catch (error) {
    res.status(500).json({error: "Internal server error"});
  }
});
```

### 4.2 index.ts 업데이트

```typescript
export {
  getWidgetSnapshot,
  getWidgetSnapshotWithToken,
} from "./functions/widget";

export {generateWidgetToken} from "./functions/widgetToken";
```

### 4.3 배포

```bash
cd infra/firebase

# Secret 설정 (최초 1회)
echo "your-secret-here" | firebase functions:secrets:set WIDGET_JWT_SECRET

# Functions 배포
firebase deploy --only functions:generateWidgetToken,functions:getWidgetSnapshotWithToken,functions:getWidgetSnapshot
```

---

## Phase 5: Widget UI

### 5.1 SmallPromiseWidget

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
    if #available(iOS 26.0, *) {
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

---

## 구현 체크리스트

### Phase 1: Widget Token (핵심) ✅
- [x] widgetToken.ts 작성 (generateWidgetToken, verifyWidgetToken)
- [x] WIDGET_JWT_SECRET 시크릿 설정
- [x] widget.ts에 getWidgetSnapshotWithToken 추가
- [x] AuthClient.requestWidgetToken 구현
- [x] WidgetTokenStore 구현 (App Group 저장)
- [x] RootTabFeature에서 앱 실행 시 호출

### Phase 2: WidgetDataManager ✅
- [x] fetchFromServer() - Widget Token → ID Token → Cache
- [x] fetchWithWidgetToken() - HTTP API 호출
- [x] fetchWithIdToken() - Fallback 구현
- [x] parseSnapshotResponse() - JSON 파싱
- [x] Token 로드/저장 함수들

### Phase 3: Timeline Provider ✅
- [x] getTimeline()에서 fetchFromServer() 호출
- [x] 갱신 주기 계산 (5분/30분/1시간)
- [x] 로깅 추가

### Phase 4: Firebase Functions 배포 ✅
- [x] generateWidgetToken 배포
- [x] getWidgetSnapshotWithToken 배포
- [x] getWidgetSnapshot 유지

### Phase 5: Widget UI ✅
- [x] SmallPromiseWidget
- [x] MediumPromiseWidget
- [x] LargePromiseWidget
- [x] Glass Effect (iOS 26+)
- [x] 딥링크 설정

### Phase 6: Snapshot 기반 아키텍처 (v2) ✅
- [x] widgetSnapshotTrigger.ts 작성
- [x] onPromiseWriteUpdateSnapshot (Stage/Prod)
- [x] scheduledSnapshotRefresh (매일 자정)
- [x] updateWidgetSnapshot() 핵심 로직
- [x] widget.ts 단순화 (캐시 읽기만)
- [x] WidgetPromiseData.myVoteStatus 필드 추가
- [x] WidgetDataManager 단순화 (Lock 제거)

---

## 트러블슈팅

### Widget Token이 발급되지 않음

**증상**: Widget이 계속 캐시 데이터만 표시

**확인 방법**:
```swift
// Logger 출력 확인
"Widget Token 유효, 재발급 스킵"  // 정상
"Widget Token 발급 완료"         // 정상
"Widget Token 발급 실패: ..."    // 오류
```

**해결**:
1. Firebase 로그인 상태 확인
2. WIDGET_JWT_SECRET 시크릿 설정 확인
3. Functions 배포 상태 확인

### Widget Token이 만료됨 (401)

**증상**: Widget이 캐시로 폴백

**원인**: 토큰 30일 경과 또는 서버에서 revoke

**해결**: 앱을 한 번 열면 자동으로 새 토큰 발급

### Timeline Refresh가 안 됨

**증상**: Widget이 갱신되지 않음

**원인**: iOS가 Timeline refresh를 throttle

**참고**: `.after(date)`는 "요청"이며, iOS가 시스템 상태에 따라 실제 갱신 시점 결정
- 배터리 상태
- 위젯 사용 빈도
- 백그라운드 앱 활동

**해결**: 정상 동작임. 앱을 열면 즉시 갱신됨.

### os_log에 `<private>` 표시

**증상**: 로그에 `<private>` 출력

**원인**: os_log의 기본 개인정보 보호

**해결**: `privacy: .public` 추가
```swift
logger.info("값: \(value, privacy: .public)")
```

---

## 관련 문서

- [기술 스펙](../specs/WIDGET_SPEC.md)
- [프로젝트 컨텍스트](../PROJECT_CONTEXT.md)
- [Push Notification 가이드](../PUSH_NOTIFICATION_GUIDE.md)
