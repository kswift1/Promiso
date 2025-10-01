import Foundation

// MARK: - Promise Domain Model

public struct PromiseModel: Identifiable, Equatable, Hashable {
  public let id: String
  public let emoji: String?
  public let title: String
  public let description: String?
  
  // MARK: - 확정 조건
  public let minimumParticipants: Int
  public let requiredCount: Int
  public var isConfirmed: Bool
  public var confirmedAt: Date?
  
  // MARK: - 관계
  public let host: User
  public let group: Group
  
  // MARK: - 카운터
  public var counts: PromiseCounts
  
  // MARK: - 시간
  public let startAt: Date
  public let endAt: Date?
  
  // MARK: - 상태
  public var status: PromiseStatus
  
  // MARK: - 위치
  public let location: LocationInfo?
  
  // MARK: - 메타데이터
  public let createdAt: Date
  public var updatedAt: Date
  public var isDeleted: Bool
  
  // MARK: - Firestore 최적화 필드
  public let localYyyymm: String
  public let localYyyymmdd: String
  public let localTz: String
  public let titleLower: String
  
  public init(
    id: String = UUID().uuidString,
    emoji: String? = nil,
    title: String,
    description: String? = nil,
    minimumParticipants: Int,
    requiredCount: Int,
    isConfirmed: Bool = false,
    confirmedAt: Date? = nil,
    host: User,
    group: Group,
    counts: PromiseCounts = PromiseCounts(),
    startAt: Date,
    endAt: Date? = nil,
    status: PromiseStatus = .draft,
    location: LocationInfo? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    isDeleted: Bool = false,
    localYyyymm: String? = nil,
    localYyyymmdd: String? = nil,
    localTz: String? = nil,
    titleLower: String? = nil
  ) {
    self.id = id
    self.emoji = emoji
    self.title = title
    self.description = description
    self.minimumParticipants = minimumParticipants
    self.requiredCount = requiredCount
    self.isConfirmed = isConfirmed
    self.confirmedAt = confirmedAt
    self.host = host
    self.group = group
    self.counts = counts
    self.startAt = startAt
    self.endAt = endAt
    self.status = status
    self.location = location
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.isDeleted = isDeleted
    
    // Firestore 최적화 필드 자동 생성
    let calendar = Calendar.current
    let components = calendar.dateComponents([.year, .month, .day], from: startAt)
    let yyyy = String(format: "%04d", components.year ?? 0)
    let mm = String(format: "%02d", components.month ?? 0)
    let dd = String(format: "%02d", components.day ?? 0)
    
    self.localYyyymm = localYyyymm ?? "\(yyyy)\(mm)"
    self.localYyyymmdd = localYyyymmdd ?? "\(yyyy)\(mm)\(dd)"
    self.localTz = localTz ?? TimeZone.current.identifier
    self.titleLower = titleLower ?? title.lowercased()
  }
}

// MARK: - Business Logic
extension PromiseModel {
  /// 실시간 공유 가능 여부 (30분 전부터)
  public var isRealtimeShareable: Bool {
    let timeDifference = startAt.timeIntervalSince(Date())
    return timeDifference >= 0 && timeDifference <= 1800 // 30분
  }
  
  /// 약속이 진행 중인지 확인
  public var isOngoing: Bool {
    let now = Date()
    if let endAt = endAt {
      return now >= startAt && now <= endAt
    } else {
      return now >= startAt
    }
  }
  
  /// 약속이 지났는지 확인
  public var isPast: Bool {
    let now = Date()
    if let endAt = endAt {
      return now > endAt
    } else {
      return now > startAt
    }
  }
  
  /// 약속이 다가오는지 확인
  public var isUpcoming: Bool {
    return Date() < startAt
  }
}
