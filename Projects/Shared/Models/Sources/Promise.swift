import Foundation

// MARK: - Promise Model

/// 약속 정보를 나타내는 도메인 모델
public struct Promise: Equatable, Codable, Identifiable, Sendable {
  public let id: UUID
  public let title: String
  public let description: String?
  public let createdBy: UUID // User ID
  public let groupId: UUID?
  public let scheduledAt: Date
  public let location: PromiseLocation?
  public let createdAt: Date
  public let updatedAt: Date
  public let status: PromiseStatus
  public let visibility: PromiseVisibility
  public let settings: PromiseSettings
  public let metadata: PromiseMetadata
  
  public init(
    id: UUID = UUID(),
    title: String,
    description: String? = nil,
    createdBy: UUID,
    groupId: UUID? = nil,
    scheduledAt: Date,
    location: PromiseLocation? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    status: PromiseStatus = .scheduled,
    visibility: PromiseVisibility = .group,
    settings: PromiseSettings = PromiseSettings(),
    metadata: PromiseMetadata = PromiseMetadata()
  ) {
    self.id = id
    self.title = title
    self.description = description
    self.createdBy = createdBy
    self.groupId = groupId
    self.scheduledAt = scheduledAt
    self.location = location
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.status = status
    self.visibility = visibility
    self.settings = settings
    self.metadata = metadata
  }
}

// MARK: - Promise Status

/// 약속 상태
public enum PromiseStatus: String, CaseIterable, Codable, Sendable {
  case scheduled = "scheduled"      // 예정됨
  case ongoing = "ongoing"          // 진행 중
  case completed = "completed"      // 완료됨
  case missed = "missed"           // 놓침
  case cancelled = "cancelled"      // 취소됨
  
  public var displayName: String {
    switch self {
    case .scheduled: return "예정됨"
    case .ongoing: return "진행 중"
    case .completed: return "완료됨"
    case .missed: return "놓침"
    case .cancelled: return "취소됨"
    }
  }
  
  public var emoji: String {
    switch self {
    case .scheduled: return "🕒"
    case .ongoing: return "🏃‍♂️"
    case .completed: return "✅"
    case .missed: return "❌"
    case .cancelled: return "🚫"
    }
  }
  
  public var isActive: Bool {
    self == .scheduled || self == .ongoing
  }
  
  public var isFinished: Bool {
    self == .completed || self == .missed || self == .cancelled
  }
}

// MARK: - Promise Location

/// 약속 위치
public struct PromiseLocation: Equatable, Codable, Sendable {
  public let name: String
  public let address: String?
  public let latitude: Double?
  public let longitude: Double?
  public let radius: Double? // 미터 단위
  
  public init(
    name: String,
    address: String? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil,
    radius: Double? = nil
  ) {
    self.name = name
    self.address = address
    self.latitude = latitude
    self.longitude = longitude
    self.radius = radius
  }
}

// MARK: - Promise Settings

/// 약속 설정
public struct PromiseSettings: Equatable, Codable, Sendable {
  public let allowLateJoin: Bool
  public let requireConfirmation: Bool
  public let sendReminders: Bool
  public let reminderIntervals: [Int] // 분 단위
  public let autoCompleteOnTime: Bool
  public let trackLocation: Bool
  public let maxParticipants: Int?
  
  public init(
    allowLateJoin: Bool = true,
    requireConfirmation: Bool = false,
    sendReminders: Bool = true,
    reminderIntervals: [Int] = [60, 30, 15], // 1시간, 30분, 15분 전
    autoCompleteOnTime: Bool = false,
    trackLocation: Bool = false,
    maxParticipants: Int? = nil
  ) {
    self.allowLateJoin = allowLateJoin
    self.requireConfirmation = requireConfirmation
    self.sendReminders = sendReminders
    self.reminderIntervals = reminderIntervals
    self.autoCompleteOnTime = autoCompleteOnTime
    self.trackLocation = trackLocation
    self.maxParticipants = maxParticipants
  }
}

// MARK: - Promise Metadata

/// 약속 메타데이터
public struct PromiseMetadata: Equatable, Codable, Sendable {
  public let participantCount: Int
  public let confirmedCount: Int
  public let completedCount: Int
  public let lastActivityAt: Date?
  public let tags: [String]
  public let priority: PromisePriority
  public let category: PromiseCategory?
  
  public init(
    participantCount: Int = 0,
    confirmedCount: Int = 0,
    completedCount: Int = 0,
    lastActivityAt: Date? = nil,
    tags: [String] = [],
    priority: PromisePriority = .normal,
    category: PromiseCategory? = nil
  ) {
    self.participantCount = participantCount
    self.confirmedCount = confirmedCount
    self.completedCount = completedCount
    self.lastActivityAt = lastActivityAt
    self.tags = tags
    self.priority = priority
    self.category = category
  }
}

// MARK: - Promise Priority

/// 약속 우선순위
public enum PromisePriority: String, CaseIterable, Codable, Sendable {
  case low = "low"
  case normal = "normal"
  case high = "high"
  case urgent = "urgent"
  
  public var displayName: String {
    switch self {
    case .low: return "낮음"
    case .normal: return "보통"
    case .high: return "높음"
    case .urgent: return "긴급"
    }
  }
  
  public var emoji: String {
    switch self {
    case .low: return "🔵"
    case .normal: return "🟡"
    case .high: return "🟠"
    case .urgent: return "🔴"
    }
  }
  
  public var sortOrder: Int {
    switch self {
    case .urgent: return 4
    case .high: return 3
    case .normal: return 2
    case .low: return 1
    }
  }
}

// MARK: - Promise Category

/// 약속 카테고리
public enum PromiseCategory: String, CaseIterable, Codable, Sendable {
  case work = "work"
  case social = "social"
  case family = "family"
  case health = "health"
  case education = "education"
  case hobby = "hobby"
  case travel = "travel"
  case other = "other"
  
  public var displayName: String {
    switch self {
    case .work: return "업무"
    case .social: return "사교"
    case .family: return "가족"
    case .health: return "건강"
    case .education: return "교육"
    case .hobby: return "취미"
    case .travel: return "여행"
    case .other: return "기타"
    }
  }
  
  public var emoji: String {
    switch self {
    case .work: return "💼"
    case .social: return "👥"
    case .family: return "👨‍👩‍👧‍👦"
    case .health: return "🏥"
    case .education: return "📚"
    case .hobby: return "🎨"
    case .travel: return "✈️"
    case .other: return "📝"
    }
  }
}

// MARK: - Promise Participant

/// 약속 참가자
public struct PromiseParticipant: Equatable, Codable, Identifiable, Sendable {
  public let id: UUID
  public let promiseId: UUID
  public let userId: UUID
  public let joinedAt: Date
  public let status: ParticipantStatus
  public let confirmationRequired: Bool
  public let confirmedAt: Date?
  public let completedAt: Date?
  public let location: ParticipantLocation?
  public let notes: String?
  
  // 캐시된 사용자 정보 (옵셔널)
  public let user: User?
  
  public init(
    id: UUID = UUID(),
    promiseId: UUID,
    userId: UUID,
    joinedAt: Date = Date(),
    status: ParticipantStatus = .joined,
    confirmationRequired: Bool = false,
    confirmedAt: Date? = nil,
    completedAt: Date? = nil,
    location: ParticipantLocation? = nil,
    notes: String? = nil,
    user: User? = nil
  ) {
    self.id = id
    self.promiseId = promiseId
    self.userId = userId
    self.joinedAt = joinedAt
    self.status = status
    self.confirmationRequired = confirmationRequired
    self.confirmedAt = confirmedAt
    self.completedAt = completedAt
    self.location = location
    self.notes = notes
    self.user = user
  }
}

// MARK: - Participant Status

/// 참가자 상태
public enum ParticipantStatus: String, CaseIterable, Codable, Sendable {
  case joined = "joined"           // 참가함
  case confirmed = "confirmed"     // 확인함
  case completed = "completed"     // 완료함
  case missed = "missed"          // 놓침
  case cancelled = "cancelled"     // 취소함
  case left = "left"              // 나감
  
  public var displayName: String {
    switch self {
    case .joined: return "참가함"
    case .confirmed: return "확인함"
    case .completed: return "완료함"
    case .missed: return "놓침"
    case .cancelled: return "취소함"
    case .left: return "나감"
    }
  }
  
  public var emoji: String {
    switch self {
    case .joined: return "👋"
    case .confirmed: return "👍"
    case .completed: return "✅"
    case .missed: return "❌"
    case .cancelled: return "🚫"
    case .left: return "👋"
    }
  }
  
  public var isActive: Bool {
    self == .joined || self == .confirmed
  }
}

// MARK: - Participant Location

/// 참가자 위치 정보
public struct ParticipantLocation: Equatable, Codable, Sendable {
  public let latitude: Double
  public let longitude: Double
  public let accuracy: Double
  public let timestamp: Date
  public let isAtLocation: Bool
  public let distanceFromPromise: Double? // 미터 단위
  
  public init(
    latitude: Double,
    longitude: Double,
    accuracy: Double,
    timestamp: Date = Date(),
    isAtLocation: Bool = false,
    distanceFromPromise: Double? = nil
  ) {
    self.latitude = latitude
    self.longitude = longitude
    self.accuracy = accuracy
    self.timestamp = timestamp
    self.isAtLocation = isAtLocation
    self.distanceFromPromise = distanceFromPromise
  }
}

// MARK: - Promise Extensions

public extension Promise {
  /// 약속이 과거인지 확인
  var isPast: Bool {
    scheduledAt < Date()
  }
  
  /// 약속이 미래인지 확인
  var isFuture: Bool {
    scheduledAt > Date()
  }
  
  /// 약속이 오늘인지 확인
  var isToday: Bool {
    Calendar.current.isDateInToday(scheduledAt)
  }
  
  /// 약속이 이번 주인지 확인
  var isThisWeek: Bool {
    let calendar = Calendar.current
    let now = Date()
    return calendar.isDate(scheduledAt, equalTo: now, toGranularity: .weekOfYear)
  }
  
  /// 약속까지 남은 시간 (초 단위)
  var timeUntilPromise: TimeInterval {
    scheduledAt.timeIntervalSinceNow
  }
  
  /// 약속까지 남은 시간을 문자열로 표시
  var timeUntilString: String {
    let interval = timeUntilPromise
    
    if interval < 0 {
      return "지남"
    } else if interval < 60 {
      return "\(Int(interval))초 후"
    } else if interval < 3600 {
      return "\(Int(interval / 60))분 후"
    } else if interval < 86400 {
      return "\(Int(interval / 3600))시간 후"
    } else {
      return "\(Int(interval / 86400))일 후"
    }
  }
  
  /// 개인 약속인지 확인
  var isPersonal: Bool {
    groupId == nil
  }
  
  /// 그룹 약속인지 확인
  var isGroup: Bool {
    groupId != nil
  }
}

public extension PromiseLocation {
  /// 좌표가 있는지 확인
  var hasCoordinates: Bool {
    latitude != nil && longitude != nil
  }
  
  /// 반경이 설정되어 있는지 확인
  var hasRadius: Bool {
    radius != nil && radius! > 0
  }
}

public extension PromiseParticipant {
  /// 참가자가 확인했는지
  var isConfirmed: Bool {
    status == .confirmed && confirmedAt != nil
  }
  
  /// 참가자가 완료했는지
  var isCompleted: Bool {
    status == .completed && completedAt != nil
  }
  
  /// 참가자의 표시 이름
  var displayName: String {
    user?.displayName ?? "Unknown User"
  }
  
  /// 참가자가 위치에 있는지
  var isAtPromiseLocation: Bool {
    location?.isAtLocation ?? false
  }
}

public extension ParticipantLocation {
  /// 위치 정보가 최신인지 확인 (5분 이내)
  var isFresh: Bool {
    Date().timeIntervalSince(timestamp) < 300
  }
  
  /// 위치 정보가 정확한지 확인 (100m 이내)
  var isAccurate: Bool {
    accuracy <= 100
  }
}