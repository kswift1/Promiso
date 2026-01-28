import Foundation
import WidgetKit
import ExternalDependency

// MARK: - Widget Snapshot Response DTO

/// Firebase Functions getWidgetSnapshot 응답 모델
private struct WidgetSnapshotResponse: Decodable {
  let next: WidgetPromiseDTO?
  let today: [WidgetPromiseDTO]
  let upcoming: [WidgetPromiseDTO]
  let updatedAt: String
}

/// 서버에서 받아오는 약속 DTO
private struct WidgetPromiseDTO: Decodable {
  let id: String
  let title: String
  let emoji: String
  let startAt: String  // ISO 8601
  let endAt: String?
  let location: String?
  let groupId: String
  let groupName: String?
  let isConfirmed: Bool
  let participantCount: Int

  /// WidgetPromiseData로 변환
  func toWidgetPromiseData() -> WidgetPromiseData? {
    let isoFormatter = ISO8601DateFormatter()
    isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    guard let startDate = isoFormatter.date(from: startAt) else {
      // fractionalSeconds 없이 다시 시도
      isoFormatter.formatOptions = [.withInternetDateTime]
      guard let startDate = isoFormatter.date(from: startAt) else {
        return nil
      }
      return createData(startDate: startDate, isoFormatter: isoFormatter)
    }

    return createData(startDate: startDate, isoFormatter: isoFormatter)
  }

  private func createData(startDate: Date, isoFormatter: ISO8601DateFormatter) -> WidgetPromiseData {
    let endDate: Date?
    if let endAtString = endAt {
      endDate = isoFormatter.date(from: endAtString)
    } else {
      endDate = nil
    }

    return WidgetPromiseData(
      id: id,
      title: title,
      emoji: emoji,
      startAt: startDate,
      endAt: endDate,
      location: location,
      groupId: groupId,
      groupName: groupName,
      isConfirmed: isConfirmed,
      participantCount: participantCount
    )
  }
}

/// Widget과 App 간 데이터 공유를 위한 매니저
/// App Group UserDefaults를 통해 데이터를 공유합니다.
public enum WidgetDataManager {
  // MARK: - Constants

  /// 과거 약속 필터링 기준 (1시간 전까지 표시)
  private static let pastPromiseThreshold: TimeInterval = -1 * 60 * 60

  // MARK: - Keys

  private static let suiteName = LiveActivityIntentKey.suiteName
  private static let promisesKey = "widget.promises"
  private static let userIdKey = "widget.userId"
  private static let lastUpdatedKey = "widget.lastUpdated"
  private static let firestoreEnvKey = "widget.firestoreEnv"

  /// Firebase Functions 엔드포인트
  private static let functionsBaseURL = "https://asia-northeast3-\(LiveActivityIntentKey.firebaseProjectId).cloudfunctions.net"

  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: suiteName)
  }

  // MARK: - App에서 호출 (저장)

  /// 약속 목록 저장
  public static func savePromises(_ promises: [WidgetPromiseData]) {
    guard let defaults = defaults,
          let data = try? JSONEncoder().encode(promises) else { return }
    defaults.set(data, forKey: promisesKey)
    defaults.set(Date(), forKey: lastUpdatedKey)
  }

  /// 사용자 ID 저장 (로그인 시)
  public static func saveUserId(_ userId: String?) {
    if let userId = userId {
      defaults?.set(userId, forKey: userIdKey)
    } else {
      defaults?.removeObject(forKey: userIdKey)
    }
  }

  /// Firestore 환경 저장 (앱에서 호출 - FirebaseEnvironment.firebaseEnv 값)
  public static func saveFirestoreEnv(_ env: String) {
    defaults?.set(env, forKey: firestoreEnvKey)
  }

  /// Firestore 환경 로드 (Widget에서 호출)
  public static func loadFirestoreEnv() -> String {
    defaults?.string(forKey: firestoreEnvKey) ?? "stage"
  }

  /// Firebase ID Token 로드 (AuthClient에서 저장한 토큰 사용)
  public static func loadIdToken() -> String? {
    guard let token = defaults?.string(forKey: LiveActivityIntentKey.authTokenKey) else { return nil }

    // 만료 체크 (5분 여유)
    if let expiry = defaults?.object(forKey: LiveActivityIntentKey.authTokenExpiryKey) as? Date,
       expiry.addingTimeInterval(-300) < Date() {
      return nil // 만료됨
    }

    return token
  }

  // MARK: - Widget에서 호출 (읽기)

  /// 약속 목록 로드
  public static func loadPromises() -> [WidgetPromiseData] {
    guard let defaults = defaults,
          let data = defaults.data(forKey: promisesKey),
          let promises = try? JSONDecoder().decode([WidgetPromiseData].self, from: data)
    else { return [] }

    // 과거 약속 필터링 + 시간순 정렬
    return promises
      .filter { $0.startAt > Date().addingTimeInterval(pastPromiseThreshold) }
      .sorted { $0.startAt < $1.startAt }
  }

  /// 로그인 상태 확인
  public static func isLoggedIn() -> Bool {
    defaults?.string(forKey: userIdKey) != nil
  }

  /// 마지막 업데이트 시간
  public static func lastUpdated() -> Date? {
    defaults?.object(forKey: lastUpdatedKey) as? Date
  }

  // MARK: - 초기화

  /// 모든 데이터 삭제 (로그아웃 시)
  /// Note: 토큰 삭제는 AuthClient.clearWidgetAuthToken()에서 처리
  public static func clearAll() {
    defaults?.removeObject(forKey: promisesKey)
    defaults?.removeObject(forKey: userIdKey)
    defaults?.removeObject(forKey: lastUpdatedKey)
  }

  // MARK: - Widget 갱신 트리거

  /// 모든 Widget 타임라인 갱신
  public static func reloadWidgets() {
    WidgetCenter.shared.reloadTimelines(ofKind: "SmallPromiseWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "MediumPromiseWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "LargePromiseWidget")
  }

  // MARK: - Server Refresh (Silent Push용 - Fallback)

  /// 서버에서 위젯 스냅샷을 받아와 캐시 업데이트 (앱에서 호출)
  /// - Returns: 성공 여부
  @discardableResult
  public static func refreshFromServer() async -> Bool {
    let functions = Functions.functions(region: "asia-northeast3")

    do {
      let result = try await functions.httpsCallable("getWidgetSnapshot").call(["env": loadFirestoreEnv()])

      guard let data = result.data as? [String: Any] else {
        AppLogger.notification.error("❌ [WidgetDataManager] Invalid response format")
        return false
      }

      // JSON으로 변환 후 디코딩
      let jsonData = try JSONSerialization.data(withJSONObject: data)
      let snapshot = try JSONDecoder().decode(WidgetSnapshotResponse.self, from: jsonData)

      // 캐시 저장 및 위젯 갱신
      let promises = convertSnapshotToPromises(snapshot)
      savePromises(promises)
      reloadWidgets()

      AppLogger.notification.info("✅ [WidgetDataManager] 서버에서 위젯 데이터 갱신 완료 - \(promises.count)개 약속")
      return true
    } catch {
      AppLogger.notification.error("❌ [WidgetDataManager] 서버 호출 실패: \(error.localizedDescription)")
      return false
    }
  }

  // MARK: - Widget Direct Fetch (iOS 17+)


  /// 위젯에서 직접 API 호출하여 데이터 가져오기
  /// - Returns: 약속 목록 (실패 시 캐시된 데이터 반환)
  public static func fetchFromServer() async -> [WidgetPromiseData] {
    let token = loadIdToken()

    guard let url = URL(string: "\(functionsBaseURL)/getWidgetSnapshot") else {
      return loadPromises()
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    // 토큰이 있으면 사용, 없으면 빈 값 (서버에서 401 에러 발생 → 로그 확인용)
    request.setValue("Bearer \(token ?? "NO_TOKEN")", forHTTPHeaderField: "Authorization")
    request.httpBody = try? JSONSerialization.data(withJSONObject: ["data": ["env": loadFirestoreEnv()]])

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse,
            httpResponse.statusCode == 200 else {
        return loadPromises()
      }

      // Firebase Functions 응답 형식: { "result": { ... } }
      let wrapper = try JSONDecoder().decode(FunctionsResponseWrapper.self, from: data)
      let promises = convertSnapshotToPromises(wrapper.result)

      // 캐시 업데이트
      savePromises(promises)

      return promises
    } catch {
      // 실패 시 캐시 반환
      return loadPromises()
    }
  }

  // MARK: - Private Helpers

  private static func convertSnapshotToPromises(_ snapshot: WidgetSnapshotResponse) -> [WidgetPromiseData] {
    var allPromises: [WidgetPromiseData] = []
    var seenIds: Set<String> = []

    // next 추가
    if let next = snapshot.next?.toWidgetPromiseData() {
      allPromises.append(next)
      seenIds.insert(next.id)
    }

    // today 추가 (중복 제거 - O(1) lookup)
    for dto in snapshot.today {
      if let promise = dto.toWidgetPromiseData(),
         !seenIds.contains(promise.id) {
        allPromises.append(promise)
        seenIds.insert(promise.id)
      }
    }

    // upcoming 추가 (중복 제거 - O(1) lookup)
    for dto in snapshot.upcoming {
      if let promise = dto.toWidgetPromiseData(),
         !seenIds.contains(promise.id) {
        allPromises.append(promise)
        seenIds.insert(promise.id)
      }
    }

    return allPromises
  }
}

// MARK: - Firebase Functions Response Wrapper

private struct FunctionsResponseWrapper: Decodable {
  let result: WidgetSnapshotResponse
}
