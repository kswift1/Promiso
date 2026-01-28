import Foundation

/// Widget에서 사용하는 경량화된 약속 모델
public struct WidgetPromiseData: Codable, Identifiable, Equatable, Sendable {
  // MARK: - 식별자

  public let id: String

  // MARK: - 약속 정보

  public let title: String
  public let emoji: String
  public let startAt: Date
  public let endAt: Date?
  public let location: String?

  // MARK: - 그룹 정보

  public let groupId: String
  public let groupName: String?

  // MARK: - 상태

  public let isConfirmed: Bool
  public let participantCount: Int

  // MARK: - 캐시 메타데이터

  public let cachedAt: Date

  // MARK: - Initializer

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

  /// 캐시 유효성 (2시간 초과 시 stale)
  public var isStale: Bool {
    Date().timeIntervalSince(cachedAt) > 7200
  }

  /// 딥링크 URL (URLComponents로 안전한 URL 인코딩)
  public var deeplinkURL: URL? {
    var components = URLComponents(string: "promiso://promise")
    components?.queryItems = [
      URLQueryItem(name: "id", value: id),
      URLQueryItem(name: "groupId", value: groupId)
    ]
    return components?.url
  }

  // MARK: - Placeholder & Preview Data

  /// 위젯 갤러리용 플레이스홀더 데이터
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

  #if DEBUG
  // MARK: - Preview Samples

  /// 오늘 약속 샘플들
  public static var previewTodayPromises: [WidgetPromiseData] {
    let calendar = Calendar.current
    let now = Date()
    let todayNoon = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: now) ?? now
    let todayEvening = calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now

    return [
      WidgetPromiseData(
        id: "today1",
        title: "점심 약속",
        emoji: "🍜",
        startAt: todayNoon,
        endAt: nil,
        location: "강남역 2번 출구",
        groupId: "g1",
        groupName: "대학 동기",
        isConfirmed: true,
        participantCount: 4
      ),
      WidgetPromiseData(
        id: "today2",
        title: "영화 관람",
        emoji: "🎬",
        startAt: todayEvening,
        endAt: nil,
        location: "CGV 용산",
        groupId: "g2",
        groupName: "영화 동호회",
        isConfirmed: true,
        participantCount: 3
      )
    ]
  }

  /// 다가오는 약속 샘플들
  public static var previewUpcomingPromises: [WidgetPromiseData] {
    let calendar = Calendar.current
    let now = Date()
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
    let nextWeek = calendar.date(byAdding: .day, value: 5, to: now) ?? now

    return [
      WidgetPromiseData(
        id: "upcoming1",
        title: "스터디 모임",
        emoji: "📚",
        startAt: calendar.date(bySettingHour: 14, minute: 0, second: 0, of: tomorrow) ?? tomorrow,
        endAt: nil,
        location: "스타벅스 역삼점",
        groupId: "g3",
        groupName: "개발 스터디",
        isConfirmed: true,
        participantCount: 5
      ),
      WidgetPromiseData(
        id: "upcoming2",
        title: "생일 파티 🎂",
        emoji: "🎉",
        startAt: calendar.date(bySettingHour: 18, minute: 0, second: 0, of: nextWeek) ?? nextWeek,
        endAt: nil,
        location: "홍대 레스토랑",
        groupId: "g1",
        groupName: "대학 동기",
        isConfirmed: true,
        participantCount: 8
      )
    ]
  }

  /// 전체 프리뷰 샘플 (오늘 + 다가오는)
  public static var previewAllPromises: [WidgetPromiseData] {
    previewTodayPromises + previewUpcomingPromises
  }
  #endif
}
