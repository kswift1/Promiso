import Foundation

// MARK: - Promise Model

/// 약속 도메인 모델
public struct PromiseModel: Identifiable, Equatable, Hashable, Sendable {
  // MARK: - 기본 정보
  public var id: String
  public var title: String
  public var emoji: String?
  public var description: String?

  // MARK: - 관계
  public var hostId: String
  public var groupId: String
  public var group: GroupModel?  // UI 표시용 (옵셔널)

  // MARK: - 확정 조건
  public var minimumParticipants: Int

  // MARK: - 투표 정보
  public var votes: PromiseVotesModel

  // MARK: - 시간
  public var startAt: Date
  public var endAt: Date?

  // MARK: - 위치
  public var location: LocationInfoModel?

  // MARK: - LiveActivity 설정
  /// LiveActivity 시작 시간 (약속 시간 N분 전)
  public var trackingStartMinutesBefore: Int?

  // MARK: - 메타데이터
  public var createdAt: Date
  public var updatedAt: Date
  public var isDeleted: Bool

  public init(
    id: String = UUID().uuidString,
    title: String = "",
    emoji: String? = nil,
    description: String? = nil,
    hostId: String = "",
    groupId: String = "",
    group: GroupModel? = nil,
    minimumParticipants: Int = 2,
    votes: PromiseVotesModel = PromiseVotesModel(),
    startAt: Date = Date().addingTimeInterval(3600),
    endAt: Date? = nil,
    location: LocationInfoModel? = nil,
    trackingStartMinutesBefore: Int? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    isDeleted: Bool = false
  ) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.description = description
    self.hostId = hostId
    self.groupId = groupId
    self.group = group
    self.minimumParticipants = minimumParticipants
    self.votes = votes
    self.startAt = startAt
    self.endAt = endAt
    self.location = location
    self.trackingStartMinutesBefore = trackingStartMinutesBefore
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.isDeleted = isDeleted
  }

  /// 빈 약속 (생성용)
  public static var empty: PromiseModel {
    PromiseModel()
  }
}

// MARK: - DTO -> Model 변환

extension PromiseModel {
  /// DTO에서 Model 생성
  public init(dto: PromiseDTO, id: String) {
    self.init(
      id: id,
      title: dto.title,
      emoji: dto.emoji,
      description: dto.description,
      hostId: dto.hostId,
      groupId: dto.groupId,
      group: nil,
      minimumParticipants: dto.minimumParticipants,
      votes: PromiseVotesModel(dto: dto.votes),
      startAt: dto.startAt.dateValue(),
      endAt: dto.endAt?.dateValue(),
      location: dto.location.map { LocationInfoModel(dto: $0) },
      trackingStartMinutesBefore: dto.trackingStartMinutesBefore,
      createdAt: dto.createdAt.dateValue(),
      updatedAt: dto.updatedAt.dateValue(),
      isDeleted: dto.isDeleted
    )
  }
}

// MARK: - Promise Response Status

public enum PromiseResponseStatus: String, Equatable, Sendable, Codable {
  case needResponse  // 내가 미응답
  case responded     // 내가 응답함 (확정 대기)
  case confirmed     // 약속 확정됨
  case failed        // 약속 불발 (투표 마감 + 미확정)
}

// MARK: - Attendance Status

public enum PromiseAttendanceStatus: String, Equatable, Sendable, Codable {
  case pending
  case accepted
  case declined
}

// MARK: - Computed Properties (비즈니스 로직)

extension PromiseModel {
  /// 확정 여부 (accepted >= minimumParticipants)
  public var isConfirmed: Bool {
    votes.isConfirmed(minimumParticipants: minimumParticipants)
  }

  /// 호스트 여부
  public func isHost(userId: String) -> Bool {
    hostId == userId
  }

  /// 내 투표 상태
  public func myVoteStatus(userId: String) -> VoteStatus {
    votes.myStatus(userId: userId)
  }

  /// 투표 마감 여부
  public var isVotingClosed: Bool {
    Date() > votes.until
  }
}

// MARK: - Time-based Properties

extension PromiseModel {
  /// 실시간 공유 가능 여부 (trackingStartMinutesBefore 전부터)
  public var isRealtimeShareable: Bool {
    guard let trackingMinutes = trackingStartMinutesBefore else { return false }
    let timeDifference = startAt.timeIntervalSince(Date())
    let trackingSeconds = Double(trackingMinutes * 60)
    return timeDifference >= 0 && timeDifference <= trackingSeconds
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

// MARK: - UI Display Properties

extension PromiseModel {
  /// 표시용 이모지 (없으면 기본값)
  public var displayEmoji: String {
    guard let emoji = emoji, !emoji.isEmpty else { return "📌" }
    return emoji
  }

  /// 시간 텍스트 (예: "오후 2:00")
  public var timeText: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: startAt)
  }

  /// 날짜 텍스트 (예: "오늘", "내일", "1월 15일")
  public var dateText: String {
    let calendar = Calendar.current
    if calendar.isDateInToday(startAt) {
      return "오늘"
    }
    if calendar.isDateInTomorrow(startAt) {
      return "내일"
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    return formatter.string(from: startAt)
  }

  /// 위치 텍스트 (없으면 기본값)
  public var locationText: String {
    location?.name ?? "장소 미정"
  }

  /// 투표 마감까지 남은 시간 텍스트
  public var deadlineText: String? {
    let now = Date()
    guard votes.until > now else { return nil }

    let interval = votes.until.timeIntervalSince(now)
    let hours = Int(interval / 3600)
    let days = hours / 24

    if days > 0 {
      return "\(days)일 후"
    } else if hours > 0 {
      return "\(hours)시간 후"
    } else {
      let minutes = Int(interval / 60)
      return "\(minutes)분 후"
    }
  }

  /// 응답 상태 (우선순위: 확정 > 불발 > 미응답 > 응답완료)
  /// - Parameters:
  ///   - currentUserId: 현재 사용자 ID
  ///   - totalGroupMembers: 실제 그룹 멤버 수 (nil이면 투표 마감 기준으로만 판단)
  public func responseStatus(currentUserId: String?, totalGroupMembers: Int? = nil) -> PromiseResponseStatus {
    // 1. 약속이 확정됨 (isConfirmed: votes.accepted.count >= minimumParticipants)
    if isConfirmed {
      return .confirmed
    }

    // 2. 투표 마감 + 미확정 = 불발
    if isVotingClosed && !isConfirmed {
      return .failed
    }

    // 3. 모든 멤버 응답 완료 + 최소 인원 미달 = 불발
    if let totalMembers = totalGroupMembers {
      let respondedCount = votes.acceptedCount + votes.declinedCount
      let allResponded = respondedCount >= totalMembers
      let cannotReachMinimum = (totalMembers - votes.declinedCount) < minimumParticipants

      if allResponded && !isConfirmed {
        return .failed
      }

      // 남은 인원이 모두 찬성해도 최소 인원 도달 불가 = 불발
      if cannotReachMinimum {
        return .failed
      }
    }

    // 4. 내가 미응답
    if let userId = currentUserId {
      let myStatus = votes.myStatus(userId: userId)
      if myStatus == .pending {
        return .needResponse
      }
    }

    // 5. 내가 응답함 (확정 대기)
    return .responded
  }
}

// MARK: - Validation (생성 시 검증)

extension PromiseModel {
  /// 제목 유효성
  public var isTitleValid: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// 그룹 유효성
  public var isGroupValid: Bool {
    !groupId.isEmpty || group != nil
  }

  /// 시작 시간 유효성 (현재보다 미래)
  public var isStartTimeValid: Bool {
    startAt > Date()
  }

  /// 종료 시간 유효성 (시작 시간보다 이후)
  public var isEndTimeValid: Bool {
    guard let endAt = endAt else { return true }
    return endAt > startAt
  }

  /// 최소 참가 인원 유효성
  public var isMinimumParticipantsValid: Bool {
    minimumParticipants >= 2
  }

  /// 생성 가능 여부
  public var canCreate: Bool {
    isTitleValid && isGroupValid && isStartTimeValid && isEndTimeValid && isMinimumParticipantsValid
  }
}

// MARK: - Share

extension PromiseModel {
  /// 공유용 텍스트
  public var shareText: String {
    var text = "\(displayEmoji) \(title)\n"
    text += "📅 \(dateText) \(timeText)\n"
    if let location = location {
      text += "📍 \(location.name)\n"
    }
    if let description = description, !description.isEmpty {
      text += "\n\(description)"
    }
    return text
  }
}
