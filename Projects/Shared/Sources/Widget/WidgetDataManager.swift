import Foundation
import os.log
import WidgetKit

let widgetLogger = Logger(subsystem: "com.promiso.widget", category: "DataManager")

// MARK: - Widget Snapshot Response DTO

/// 스냅샷 메타 정보
private struct WidgetSnapshotMeta: Decodable {
  let todayCount: Int
  let upcomingCount: Int
  let updatedAt: String
  let version: Int
}

/// 위젯 스냅샷 응답 모델
///
/// 서버에서 그룹 일정과 개인 일정을 통합하여 today/upcoming에 반환.
/// 각 항목의 `type` 필드로 일정/개인 일정을 구분.
private struct WidgetSnapshotResponse: Decodable {
  let next: WidgetScheduleDTO?
  let today: [WidgetScheduleDTO]
  let upcoming: [WidgetScheduleDTO]
  let meta: WidgetSnapshotMeta?

  // Legacy 호환
  let updatedAt: String?
}

/// 서버에서 받아오는 투표 정보 DTO
private struct WidgetVotesDTO: Decodable {
  let accepted: [String]
  let declined: [String]
}

/// 서버에서 받아오는 통합 일정 DTO (일정 + 개인 일정)
///
/// `type` 필드로 구분:
/// - "schedule" (기본값): 그룹 일정 → groupId, votes 등 존재
/// - "personal": 개인 일정 → groupId/votes 등 없음
private struct WidgetScheduleDTO: Decodable {
  let id: String
  let title: String
  let emoji: String?
  let startAt: String  // ISO 8601
  let endAt: String?
  let location: String?
  let locationName: String?
  let type: String?  // "schedule" | "personal" (nil이면 schedule)
  let scheduleType: String?

  // 일정 전용 필드 (개인 일정은 nil)
  let groupId: String?
  let groupName: String?
  let isConfirmed: Bool?
  let votes: WidgetVotesDTO?
  let myVoteStatus: String?  // "pending" | "voted" | "declined"

  /// WidgetScheduleData로 변환
  func toWidgetScheduleData() -> WidgetScheduleData? {
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

  private func createData(startDate: Date, isoFormatter: ISO8601DateFormatter) -> WidgetScheduleData {
    let endDate: Date?
    if let endAtString = endAt {
      endDate = isoFormatter.date(from: endAtString)
    } else {
      endDate = nil
    }

    let resolvedType: ScheduleType = ((type ?? scheduleType) == "personal") ? .personal : .schedule

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

    return WidgetScheduleData(
      type: resolvedType,
      id: id,
      title: title,
      emoji: emoji ?? "📅",
      startAt: startDate,
      endAt: endDate,
      location: location ?? locationName,
      groupId: groupId ?? "",
      groupName: groupName,
      isConfirmed: isConfirmed ?? true,
      participantCount: votes?.accepted.count ?? 0,
      myVoteStatus: voteStatus
    )
  }
}

/// Widget과 App 간 데이터 공유를 위한 매니저
///
/// ## 아키텍처
/// - **저장**: 2개의 캐시 키 (schedules / personalEvents) 사용
///   - App과 Widget Extension이 별도 프로세스이므로 독립적 쓰기 안전성 확보
///   - App에서 schedules/personalEvents를 각각 다른 시점에 저장
/// - **로드**: `loadAllItems()`로 2개 키를 병합하여 startAt 정렬 반환
/// - **서버 Fetch**: 서버에서 통합된 응답을 받아 type별로 분리 저장
// MARK: - Widget Kind 상수

/// 위젯 kind 식별자 상수
public enum WidgetKind {
  /// 홈 화면 위젯 (systemSmall) - 다음 일정 1개 표시
  public static let systemSmall = "ScheduleSystemSmall"
  /// 홈 화면 위젯 (systemMedium) - 오늘 일정 2-3개 표시
  public static let systemMedium = "ScheduleSystemMedium"
  /// 홈 화면 위젯 (systemLarge) - 오늘 + 다가오는 일정 표시
  public static let systemLarge = "ScheduleSystemLarge"
  /// 잠금 화면 위젯 (accessoryCircular) - D-Day 표시
  public static let accessoryCircular = "ScheduleAccessoryCircular"
  /// 잠금 화면 위젯 (accessoryRectangular) - 다음 일정 정보
  public static let accessoryRectangular = "ScheduleAccessoryRectangular"

  /// 모든 위젯 kind 목록
  public static let all: [String] = [
    systemSmall, systemMedium, systemLarge,
    accessoryCircular, accessoryRectangular,
  ]
}

// MARK: - WidgetDataManager

public enum WidgetDataManager {
  // MARK: - Constants

  /// 과거 일정 필터링 기준 (1시간 전까지 표시)
  private static let pastScheduleThreshold: TimeInterval = -1 * 60 * 60

  // MARK: - Keys

  private static let suiteName = LiveActivityIntentKey.suiteName
  private static let schedulesKey = "widget.schedules"
  private static let personalEventsKey = "widget.personalEvents"
  private static let userIdKey = "widget.userId"
  private static let lastUpdatedKey = "widget.lastUpdated"
  private static let lastFetchAtKey = "widget.lastFetchAt"

  // MARK: - TTL Settings

  /// Manual refresh TTL: 서버 호출 최소 간격 (15초)
  private static let manualRefreshTTL: TimeInterval = 15.0

  /// Rust API 기본 URL
  #if DEBUG
  private static let rustBaseURL = "https://promiso-api-809932911903.asia-northeast3.run.app"
  #else
  private static let rustBaseURL = "https://promiso-api-809932911903.asia-northeast3.run.app"
  #endif

  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: suiteName)
  }

  // MARK: - App에서 호출 (저장)

  /// 그룹 일정 목록 저장
  public static func saveSchedules(_ schedules: [WidgetScheduleData]) {
    guard let defaults = defaults,
          let data = try? JSONEncoder().encode(schedules) else { return }
    defaults.set(data, forKey: schedulesKey)
    defaults.set(Date(), forKey: lastUpdatedKey)
  }

  /// 개인 일정 목록 저장
  public static func savePersonalEvents(_ events: [WidgetScheduleData]) {
    guard let defaults = defaults,
          let data = try? JSONEncoder().encode(events) else { return }
    defaults.set(data, forKey: personalEventsKey)
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

  /// 서버 access token fallback 로드 (Widget Token 없을 때 사용)
  public static func loadAuthToken() -> String? {
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

  /// 그룹 일정만 로드
  public static func loadSchedules() -> [WidgetScheduleData] {
    loadItems(forKey: schedulesKey)
  }

  /// 개인 일정만 로드
  public static func loadPersonalEvents() -> [WidgetScheduleData] {
    loadItems(forKey: personalEventsKey)
  }

  /// 전체 통합 일정 로드 (그룹 일정 + 개인 일정, startAt 정렬)
  public static func loadAllItems() -> [WidgetScheduleData] {
    let schedules = loadItems(forKey: schedulesKey)
    let personalEvents = loadItems(forKey: personalEventsKey)
    return (schedules + personalEvents).sorted { $0.startAt < $1.startAt }
  }

  /// 특정 키에서 항목 로드 (과거 필터링 + 정렬)
  private static func loadItems(forKey key: String) -> [WidgetScheduleData] {
    guard let defaults = defaults,
          let data = defaults.data(forKey: key),
          let items = try? JSONDecoder().decode([WidgetScheduleData].self, from: data)
    else { return [] }

    return items
      .filter { $0.startAt > Date().addingTimeInterval(pastScheduleThreshold) }
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
    defaults?.removeObject(forKey: schedulesKey)
    defaults?.removeObject(forKey: personalEventsKey)
    defaults?.removeObject(forKey: userIdKey)
    defaults?.removeObject(forKey: lastUpdatedKey)
  }

  // MARK: - Widget 갱신 트리거

  /// 모든 Widget 타임라인 갱신
  public static func reloadWidgets() {
    for kind in WidgetKind.all {
      WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
  }

  // MARK: - Server Refresh

  /// 서버에서 위젯 스냅샷을 받아와 캐시 업데이트 (앱에서 호출)
  /// - Returns: 성공 여부
  @discardableResult
  public static func refreshFromServer() async -> Bool {
    if let widgetToken = loadWidgetToken() {
      let result = await fetchSnapshotFromRust(token: widgetToken, allowAuthFallback: true)
      return !result.hadError
    }

    if let authToken = loadAuthToken() {
      let result = await fetchSnapshotFromRust(token: authToken, allowAuthFallback: false)
      return !result.hadError
    }

    widgetLogger.warning("❌ refreshFromServer: 토큰 없음")
    return false
  }

  // MARK: - Widget Direct Fetch (iOS 17+)

  /// 위젯 데이터 Fetch 결과
  public struct FetchResult {
    public let items: [WidgetScheduleData]
    public let hadError: Bool

    public init(items: [WidgetScheduleData], hadError: Bool) {
      self.items = items
      self.hadError = hadError
    }
  }

  /// 위젯에서 직접 API 호출하여 데이터 가져오기
  ///
  /// @architecture 서버 통합 방식
  /// - 서버에서 그룹 일정 + 개인 일정을 통합하여 반환
  /// - 클라이언트는 type 필드로 구분하여 캐시 저장
  ///
  /// - Returns: FetchResult (통합 일정 목록 + 에러 발생 여부)
  public static func fetchFromServer() async -> FetchResult {
    // 0. TTL 체크 (불필요한 API 호출 방지)
    if let remaining = checkTTL() {
      widgetLogger.info("⏭️ TTL \(remaining, privacy: .public)초 남음")
      return FetchResult(items: loadAllItems(), hadError: false)
    }

    // 1. Widget Token 우선 시도 (30일 유효)
    if let widgetToken = loadWidgetToken() {
      return await fetchWithWidgetToken(widgetToken)
    }

    // 2. Fallback: 서버 access token
    if let authToken = loadAuthToken() {
      widgetLogger.info("🔑 access token fallback")
      return await fetchSnapshotFromRust(token: authToken, allowAuthFallback: false)
    }

    // 3. 토큰 없음 → 캐시 반환 (에러 아님, 단순히 토큰 만료)
    widgetLogger.warning("❌ 토큰 없음 → 캐시 반환")
    return FetchResult(items: loadAllItems(), hadError: false)
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

  private static func loadWidgetDeviceId() -> String? {
    defaults?.string(forKey: LiveActivityIntentKey.widgetDeviceIdKey)
  }

  /// Widget Token으로 Rust API 호출
  private static func fetchWithWidgetToken(_ token: String) async -> FetchResult {
    await fetchSnapshotFromRust(token: token, allowAuthFallback: true)
  }

  /// Rust API로 위젯 스냅샷 호출 (GET /api/v1/widget/snapshot)
  private static func fetchSnapshotFromRust(
    token: String,
    allowAuthFallback: Bool
  ) async -> FetchResult {
    guard let url = URL(string: "\(rustBaseURL)/api/v1/widget/snapshot") else {
      widgetLogger.error("❌ Rust URL 생성 실패")
      return FetchResult(items: loadAllItems(), hadError: true)
    }

    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    if let deviceId = loadWidgetDeviceId() {
      request.setValue(deviceId, forHTTPHeaderField: "X-Device-Id")
    }

    do {
      let (data, response) = try await URLSession.shared.data(for: request)

      guard let httpResponse = response as? HTTPURLResponse else {
        widgetLogger.error("❌ HTTP 응답 아님 (Rust)")
        return FetchResult(items: loadAllItems(), hadError: true)
      }

      guard httpResponse.statusCode == 200 else {
        widgetLogger.error("❌ HTTP \(httpResponse.statusCode, privacy: .public) (Rust)")
        // 401: widget token 만료/무효화 → server access token fallback
        if allowAuthFallback, httpResponse.statusCode == 401, let authToken = loadAuthToken() {
          widgetLogger.info("🔄 Widget token 401 → access token fallback")
          return await fetchSnapshotFromRust(token: authToken, allowAuthFallback: false)
        }
        return FetchResult(items: loadAllItems(), hadError: true)
      }

      // Rust API 응답 형식: { "data": { ... } }
      let decoder = JSONDecoder()
      decoder.keyDecodingStrategy = .convertFromSnakeCase
      decoder.dateDecodingStrategy = .iso8601
      let wrapper = try decoder.decode(RustSnapshotResponseWrapper.self, from: data)
      let allItems = convertSnapshotToItems(wrapper.data)

      // 캐시 업데이트 + TTL 기록
      saveItemsByType(allItems)
      markFetchedNow()

      widgetLogger.info("✅ Rust API 성공 → \(allItems.count, privacy: .public)개 항목")
      return FetchResult(items: allItems, hadError: false)
    } catch {
      widgetLogger.error("❌ 네트워크 (Rust): \(error.localizedDescription, privacy: .public)")
      return FetchResult(items: loadAllItems(), hadError: true)
    }
  }

  // MARK: - Private Helpers

  /// 서버 응답을 통합 항목 배열로 변환
  private static func convertSnapshotToItems(_ snapshot: WidgetSnapshotResponse) -> [WidgetScheduleData] {
    var allItems: [WidgetScheduleData] = []
    var seenIds: Set<String> = []

    // next 추가
    if let next = snapshot.next?.toWidgetScheduleData() {
      allItems.append(next)
      seenIds.insert(next.id)
    }

    // today 추가 (중복 제거 - O(1) lookup)
    for dto in snapshot.today {
      if let item = dto.toWidgetScheduleData(),
         !seenIds.contains(item.id) {
        allItems.append(item)
        seenIds.insert(item.id)
      }
    }

    // upcoming 추가 (중복 제거 - O(1) lookup)
    for dto in snapshot.upcoming {
      if let item = dto.toWidgetScheduleData(),
         !seenIds.contains(item.id) {
        allItems.append(item)
        seenIds.insert(item.id)
      }
    }

    return allItems
  }

  /// type별로 분리하여 캐시 저장
  ///
  /// App과 Widget Extension이 별도 프로세스이므로,
  /// 2개의 캐시 키를 사용하여 독립적 쓰기 안전성을 확보합니다.
  private static func saveItemsByType(_ items: [WidgetScheduleData]) {
    let schedules = items.filter { $0.type == .schedule }
    let personalEvents = items.filter { $0.type == .personal }
    saveSchedules(schedules)
    savePersonalEvents(personalEvents)
  }
}

// MARK: - Rust API Response Wrapper

private struct RustSnapshotResponseWrapper: Decodable {
  let data: WidgetSnapshotResponse
}
