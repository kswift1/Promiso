import Foundation
import os.log
import WidgetKit
import ExternalDependency

let widgetLogger = Logger(subsystem: "com.promiso.widget", category: "DataManager")

// MARK: - Widget Snapshot Response DTO

/// 스냅샷 메타 정보
private struct WidgetSnapshotMeta: Decodable {
  let todayCount: Int
  let upcomingCount: Int
  let updatedAt: String
  let version: Int
}

/// Firebase Functions getWidgetSnapshot 응답 모델
private struct WidgetSnapshotResponse: Decodable {
  let next: WidgetPromiseDTO?
  let today: [WidgetPromiseDTO]
  let upcoming: [WidgetPromiseDTO]
  let meta: WidgetSnapshotMeta?

  // Legacy 호환
  let updatedAt: String?
}

/// 서버에서 받아오는 투표 정보 DTO
private struct WidgetVotesDTO: Decodable {
  let accepted: [String]
  let declined: [String]
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
  let votes: WidgetVotesDTO
  let myVoteStatus: String?  // "pending" | "voted" | "declined"

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

    // myVoteStatus 변환
    let voteStatus: MyVoteStatus
    switch myVoteStatus {
    case "voted":
      voteStatus = .voted
    case "declined":
      voteStatus = .declined
    default:
      voteStatus = .pending
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
      participantCount: votes.accepted.count,
      myVoteStatus: voteStatus
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
  private static let lastFetchAtKey = "widget.lastFetchAt"

  // MARK: - TTL Settings

  /// Manual refresh TTL: 서버 호출 최소 간격 (15초)
  private static let manualRefreshTTL: TimeInterval = 15.0

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

  /// Widget 전용 Long-lived Token 로드 (30일 유효)
  /// - Returns: Widget Token (없거나 만료 시 nil)
  public static func loadWidgetToken() -> String? {
    guard let token = defaults?.string(forKey: LiveActivityIntentKey.widgetTokenKey) else {
      return nil
    }

    // 만료 체크
    if let expiry = defaults?.object(forKey: LiveActivityIntentKey.widgetTokenExpiryKey) as? Date {
      if expiry < Date() {
        return nil
      }
    }

    return token
  }

  /// Firebase ID Token 로드 (Legacy - Widget Token 없을 때 fallback)
  public static func loadIdToken() -> String? {
    guard let token = defaults?.string(forKey: LiveActivityIntentKey.authTokenKey) else {
      return nil
    }

    // 만료 체크 (5분 여유)
    if let expiry = defaults?.object(forKey: LiveActivityIntentKey.authTokenExpiryKey) as? Date {
      let expiryWithMargin = expiry.addingTimeInterval(-300)
      if expiryWithMargin < Date() {
        return nil
      }
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
      let result = try await functions.httpsCallable("getWidgetSnapshot").call([:])

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

  /// 위젯 데이터 Fetch 결과
  public struct FetchResult {
    public let promises: [WidgetPromiseData]
    public let hadError: Bool

    public init(promises: [WidgetPromiseData], hadError: Bool) {
      self.promises = promises
      self.hadError = hadError
    }
  }

  /// 위젯에서 직접 API 호출하여 데이터 가져오기
  ///
  /// @architecture Snapshot 기반 (v2)
  /// - 서버에서 미리 계산된 스냅샷을 읽기만 함
  /// - Race Condition 문제 없음 (같은 문서를 여러 프로세스가 읽어도 OK)
  /// - TTL로 불필요한 API 호출만 방지
  ///
  /// - Returns: FetchResult (약속 목록 + 에러 발생 여부)
  public static func fetchFromServer() async -> FetchResult {
    // 0. TTL 체크 (불필요한 API 호출 방지)
    if let remaining = checkTTL() {
      widgetLogger.info("⏭️ TTL \(remaining, privacy: .public)초 남음")
      return FetchResult(promises: loadPromises(), hadError: false)
    }

    // 1. Widget Token 우선 시도 (30일 유효)
    if let widgetToken = loadWidgetToken() {
      return await fetchWithWidgetToken(widgetToken)
    }

    // 2. Fallback: Firebase ID Token (1시간 유효)
    if let idToken = loadIdToken() {
      widgetLogger.info("🔑 ID Token fallback")
      return await fetchWithIdToken(idToken)
    }

    // 3. 토큰 없음 → 캐시 반환 (에러 아님, 단순히 토큰 만료)
    widgetLogger.warning("❌ 토큰 없음 → 캐시 반환")
    return FetchResult(promises: loadPromises(), hadError: false)
  }

  /// TTL 체크 (15초 이내 재요청 시 남은 시간 반환)
  private static func checkTTL() -> Int? {
    guard let defaults = defaults else { return nil }

    let now = Date().timeIntervalSince1970
    let lastFetch = defaults.double(forKey: lastFetchAtKey)

    if lastFetch > 0 && (now - lastFetch) < manualRefreshTTL {
      return Int(manualRefreshTTL - (now - lastFetch))
    }

    return nil
  }

  /// 서버 호출 시간 기록 (API 성공 시 호출)
  private static func markFetchedNow() {
    defaults?.set(Date().timeIntervalSince1970, forKey: lastFetchAtKey)
  }

  /// Widget Token으로 API 호출 (getWidgetSnapshotWithToken 엔드포인트)
  private static func fetchWithWidgetToken(_ token: String) async -> FetchResult {
    guard let url = URL(string: "\(functionsBaseURL)/getWidgetSnapshotWithToken") else {
      widgetLogger.error("❌ URL 생성 실패")
      return FetchResult(promises: loadPromises(), hadError: true)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpBody = try? JSONSerialization.data(withJSONObject: ["data": [:]])

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        widgetLogger.error("❌ HTTP 응답 아님")
        return FetchResult(promises: loadPromises(), hadError: true)
      }

      guard httpResponse.statusCode == 200 else {
        widgetLogger.error("❌ HTTP \(httpResponse.statusCode, privacy: .public)")
        // 401 에러면 토큰 만료/무효화 → ID Token으로 fallback 시도
        if httpResponse.statusCode == 401, let idToken = loadIdToken() {
          widgetLogger.info("🔄 Widget Token 401 → ID Token fallback")
          return await fetchWithIdToken(idToken)
        }
        return FetchResult(promises: loadPromises(), hadError: true)
      }

      // Firebase Functions 응답 형식: { "result": { ... } }
      let wrapper = try JSONDecoder().decode(FunctionsResponseWrapper.self, from: data)
      let promises = convertSnapshotToPromises(wrapper.result)

      // 캐시 업데이트 + TTL 기록
      savePromises(promises)
      markFetchedNow()

      widgetLogger.info("✅ API 성공 → \(promises.count, privacy: .public)개 약속")
      return FetchResult(promises: promises, hadError: false)
    } catch {
      widgetLogger.error("❌ 네트워크: \(error.localizedDescription, privacy: .public)")
      return FetchResult(promises: loadPromises(), hadError: true)
    }
  }

  /// Firebase ID Token으로 API 호출 (기존 getWidgetSnapshot 엔드포인트)
  private static func fetchWithIdToken(_ token: String) async -> FetchResult {
    guard let url = URL(string: "\(functionsBaseURL)/getWidgetSnapshot") else {
      widgetLogger.error("❌ URL 생성 실패")
      return FetchResult(promises: loadPromises(), hadError: true)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.httpBody = try? JSONSerialization.data(withJSONObject: ["data": [:]])

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        widgetLogger.error("❌ HTTP 응답 아님")
        return FetchResult(promises: loadPromises(), hadError: true)
      }

      guard httpResponse.statusCode == 200 else {
        widgetLogger.error("❌ HTTP \(httpResponse.statusCode, privacy: .public)")
        return FetchResult(promises: loadPromises(), hadError: true)
      }

      // Firebase Functions 응답 형식: { "result": { ... } }
      let wrapper = try JSONDecoder().decode(FunctionsResponseWrapper.self, from: data)
      let promises = convertSnapshotToPromises(wrapper.result)

      // 캐시 업데이트 + TTL 기록
      savePromises(promises)
      markFetchedNow()

      widgetLogger.info("✅ API 성공 (ID Token) → \(promises.count, privacy: .public)개 약속")
      return FetchResult(promises: promises, hadError: false)
    } catch {
      widgetLogger.error("❌ 네트워크: \(error.localizedDescription, privacy: .public)")
      return FetchResult(promises: loadPromises(), hadError: true)
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
