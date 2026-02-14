import Foundation

// MARK: - Schedule Type

/// 일정 타입 (그룹 약속 vs 개인 일정)
public enum ScheduleType: String, Codable, Sendable {
  case promise   // 그룹 약속
  case personal  // 개인 일정
}

// MARK: - Vote Status

/// 내 투표 상태
public enum MyVoteStatus: String, Codable, Sendable {
  case pending   // 투표 필요
  case voted     // 참여 의사 표시함
  case declined  // 불참 의사 표시함
}

/// Widget에서 사용하는 통합 일정 모델 (그룹 약속 + 개인 일정)
public struct WidgetPromiseData: Codable, Identifiable, Equatable, Sendable {
  // MARK: - Constants

  /// 캐시 유효 시간 (2시간)
  private static let staleCacheThreshold: TimeInterval = 2 * 60 * 60

  // MARK: - 일정 타입

  public let type: ScheduleType

  // MARK: - 식별자

  public let id: String

  // MARK: - 약속 정보

  public let title: String
  public let emoji: String
  public let startAt: Date
  public let endAt: Date?
  public let location: String?

  // MARK: - 그룹 정보 (개인 일정은 빈 값)

  public let groupId: String
  public let groupName: String?

  // MARK: - 상태 (개인 일정은 기본값)

  public let isConfirmed: Bool
  public let participantCount: Int
  public let myVoteStatus: MyVoteStatus

  // MARK: - 캐시 메타데이터

  public let cachedAt: Date

  // MARK: - Initializer

  public init(
    type: ScheduleType = .promise,
    id: String,
    title: String,
    emoji: String,
    startAt: Date,
    endAt: Date?,
    location: String?,
    groupId: String = "",
    groupName: String? = nil,
    isConfirmed: Bool = true,
    participantCount: Int = 0,
    myVoteStatus: MyVoteStatus = .pending,
    cachedAt: Date = Date()
  ) {
    self.type = type
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
    self.myVoteStatus = myVoteStatus
    self.cachedAt = cachedAt
  }

  // MARK: - Computed Properties

  /// 개인 일정 여부
  public var isPersonalEvent: Bool {
    type == .personal
  }

  /// 캐시 유효성 (2시간 초과 시 stale)
  public var isStale: Bool {
    Date().timeIntervalSince(cachedAt) > Self.staleCacheThreshold
  }

  /// 딥링크 URL (경로 기반 - DeeplinkURLParser와 일치)
  public var deeplinkURL: URL? {
    switch type {
    case .promise:
      return URL(string: "promiso://promise/\(id)/\(groupId)")
    case .personal:
      return URL(string: "promiso://personalEvent/\(id)")
    }
  }

  // MARK: - Placeholder & Preview Data

  /// 위젯 갤러리용 플레이스홀더 데이터
  public static var placeholder: WidgetPromiseData {
    WidgetPromiseData(
      type: .promise,
      id: "placeholder",
      title: "점심 약속",
      emoji: "🍜",
      startAt: Date().addingTimeInterval(3600),
      endAt: nil,
      location: "강남역",
      groupId: "",
      groupName: "친구들",
      isConfirmed: true,
      participantCount: 3,
      myVoteStatus: .voted
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
        participantCount: 4,
        myVoteStatus: .voted
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
        isConfirmed: false,
        participantCount: 3,
        myVoteStatus: .pending
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
        participantCount: 5,
        myVoteStatus: .voted
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
        participantCount: 8,
        myVoteStatus: .voted
      ),
      WidgetPromiseData(
        id: "upcoming3",
        title: "동창회 모임",
        emoji: "🍻",
        startAt: calendar.date(bySettingHour: 19, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 3, to: now) ?? now) ?? now,
        endAt: nil,
        location: "이태원 펍",
        groupId: "g4",
        groupName: "고등학교",
        isConfirmed: true,
        participantCount: 6,
        myVoteStatus: .voted
      ),
      WidgetPromiseData(
        id: "upcoming4",
        title: "치과 예약",
        emoji: "🏥",
        startAt: calendar.date(bySettingHour: 10, minute: 30, second: 0, of: calendar.date(byAdding: .day, value: 4, to: now) ?? now) ?? now,
        endAt: nil,
        location: nil,
        groupId: "g5",
        groupName: "개인",
        isConfirmed: true,
        participantCount: 1,
        myVoteStatus: .voted
      ),
      WidgetPromiseData(
        id: "upcoming5",
        title: "팀 회식",
        emoji: "🥘",
        startAt: calendar.date(bySettingHour: 18, minute: 30, second: 0, of: calendar.date(byAdding: .day, value: 6, to: now) ?? now) ?? now,
        endAt: nil,
        location: "강남 고기집",
        groupId: "g6",
        groupName: "회사",
        isConfirmed: false,
        participantCount: 10,
        myVoteStatus: .pending
      ),
      WidgetPromiseData(
        id: "upcoming6",
        title: "독서 모임",
        emoji: "📖",
        startAt: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: calendar.date(byAdding: .day, value: 8, to: now) ?? now) ?? now,
        endAt: nil,
        location: "교보문고 카페",
        groupId: "g7",
        groupName: "독서클럽",
        isConfirmed: true,
        participantCount: 4,
        myVoteStatus: .voted
      )
    ]
  }

  /// 전체 프리뷰 샘플 (오늘 + 다가오는)
  public static var previewAllPromises: [WidgetPromiseData] {
    previewTodayPromises + previewUpcomingPromises
  }

  // MARK: - Personal Event Preview Samples

  /// 오늘 개인 일정 샘플
  public static var previewTodayPersonalEvents: [WidgetPromiseData] {
    let calendar = Calendar.current
    let now = Date()
    let todayAfternoon = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: now) ?? now

    return [
      WidgetPromiseData(
        type: .personal,
        id: "pe_today1",
        title: "병원 예약",
        emoji: "🏥",
        startAt: todayAfternoon,
        endAt: nil,
        location: "서울대병원"
      ),
    ]
  }

  /// 다가오는 개인 일정 샘플
  public static var previewUpcomingPersonalEvents: [WidgetPromiseData] {
    let calendar = Calendar.current
    let now = Date()
    let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: now) ?? now

    return [
      WidgetPromiseData(
        type: .personal,
        id: "pe_upcoming1",
        title: "헬스장",
        emoji: "💪",
        startAt: calendar.date(bySettingHour: 7, minute: 0, second: 0, of: dayAfterTomorrow) ?? dayAfterTomorrow,
        endAt: nil,
        location: nil
      ),
    ]
  }

  /// 전체 개인 일정 프리뷰 샘플
  public static var previewAllPersonalEvents: [WidgetPromiseData] {
    previewTodayPersonalEvents + previewUpcomingPersonalEvents
  }
  #endif
}
