import Foundation
import PromisoShared

// MARK: - Schedule Model

/// 일정 도메인 모델
public struct ScheduleModel: Identifiable, Equatable, Hashable, Sendable, RangedEvent {
  // MARK: - 기본 정보
  public var id: String
  public var title: String
  public var emoji: String?
  public var description: String?
  public var descriptionBlocks: [DescriptionBlock]

  // MARK: - 관계
  public var hostId: String
  public var groupId: String
  public var group: GroupModel?  // UI 표시용 (옵셔널)

  // MARK: - 확정 조건
  public var minimumParticipants: Int

  // MARK: - 투표 정보
  public var votes: ScheduleVotesModel

  // MARK: - 시간
  public var startAt: Date
  public var endAt: Date?

  // MARK: - 위치
  public var location: LocationInfoModel?

  // MARK: - 이미지
  /// 첨부 이미지 URL 목록 (최대 3장)
  public var imageUrls: [String]

  // MARK: - LiveActivity 설정
  /// LiveActivity 시작 시간 (일정 시간 N분 전)
  public var trackingStartMinutesBefore: Int?

  // MARK: - 메타데이터
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String = UUID().uuidString,
    title: String = "",
    emoji: String? = nil,
    description: String? = nil,
    descriptionBlocks: [DescriptionBlock] = [],
    hostId: String = "",
    groupId: String = "",
    group: GroupModel? = nil,
    minimumParticipants: Int = 2,
    votes: ScheduleVotesModel = ScheduleVotesModel(),
    startAt: Date = Date().addingTimeInterval(3600),
    endAt: Date? = nil,
    location: LocationInfoModel? = nil,
    imageUrls: [String] = [],
    trackingStartMinutesBefore: Int? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.description = description
    self.descriptionBlocks = descriptionBlocks
    self.hostId = hostId
    self.groupId = groupId
    self.group = group
    self.minimumParticipants = minimumParticipants
    self.votes = votes
    self.startAt = startAt
    self.endAt = endAt
    self.location = location
    self.imageUrls = imageUrls
    self.trackingStartMinutesBefore = trackingStartMinutesBefore
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// 빈 일정 (생성용)
  public static var empty: ScheduleModel {
    ScheduleModel()
  }

  /// Preview/테스트용 Mock 데이터
  public static func mock(
    id: String = "mock-schedule-id",
    title: String = "Mock 일정",
    emoji: String? = "📌",
    description: String? = nil,
    descriptionBlocks: [DescriptionBlock] = [],
    hostId: String = "mock-host-id",
    groupId: String = "mock-group-id",
    group: GroupModel? = nil,
    minimumParticipants: Int = 2,
    votes: ScheduleVotesModel = ScheduleVotesModel(
      accepted: ["mock-host-id"],
      declined: [],
      until: Date().addingTimeInterval(86400)
    ),
    startAt: Date = Date().addingTimeInterval(3600),
    endAt: Date? = nil,
    location: LocationInfoModel? = nil,
    imageUrls: [String] = [],
    trackingStartMinutesBefore: Int? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) -> ScheduleModel {
    ScheduleModel(
      id: id,
      title: title,
      emoji: emoji,
      description: description,
      descriptionBlocks: descriptionBlocks,
      hostId: hostId,
      groupId: groupId,
      group: group,
      minimumParticipants: minimumParticipants,
      votes: votes,
      startAt: startAt,
      endAt: endAt,
      location: location,
      imageUrls: imageUrls,
      trackingStartMinutesBefore: trackingStartMinutesBefore,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

// MARK: - DTO -> Model 변환

extension ScheduleModel {
  /// DTO에서 Model 생성
  public init(dto: ScheduleDTO, id: String) {
    self.init(
      id: id,
      title: dto.title,
      emoji: dto.emoji,
      description: dto.description,
      descriptionBlocks: dto.descriptionBlocks ?? (dto.description.map { [DescriptionBlock(content: .text($0))] } ?? []),
      hostId: dto.hostId,
      groupId: dto.groupId,
      group: nil,
      minimumParticipants: dto.minimumParticipants,
      votes: ScheduleVotesModel(dto: dto.votes),
      startAt: dto.startAt.dateValue(),
      endAt: dto.endAt?.dateValue(),
      location: dto.location.map { LocationInfoModel(dto: $0) },
      imageUrls: dto.imageUrls ?? [],
      trackingStartMinutesBefore: dto.trackingStartMinutesBefore,
      createdAt: dto.createdAt.dateValue(),
      updatedAt: dto.updatedAt.dateValue()
    )
  }
}

// MARK: - Schedule Response Status

public enum ScheduleResponseStatus: String, Equatable, Sendable, Codable {
  case needResponse  // 내가 미응답 (투표 진행중)
  case expired       // 투표 마감 + 내가 미응답 (응답 기한 놓침)
  case responded     // 내가 응답함 (확정 대기)
  case confirmed     // 일정 확정됨
  case failed        // 일정 불발 (투표 마감 + 미확정)
}

// MARK: - Attendance Status

public enum ScheduleAttendanceStatus: String, Equatable, Sendable, Codable {
  case pending
  case accepted
  case declined
}

// MARK: - Computed Properties (비즈니스 로직)

extension ScheduleModel {
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

extension ScheduleModel {
  /// endAt이 없는 경우 단발성 일정 (시작 = 종료)
  public var effectiveEndAt: Date {
    endAt ?? startAt
  }


  /// 실시간 공유 가능 여부 (trackingStartMinutesBefore 전부터)
  public var isRealtimeShareable: Bool {
    guard let trackingMinutes = trackingStartMinutesBefore else { return false }
    let timeDifference = startAt.timeIntervalSince(Date())
    let trackingSeconds = Double(trackingMinutes * 60)
    return timeDifference >= 0 && timeDifference <= trackingSeconds
  }

  /// 일정이 진행 중인지 확인
  public var isOngoing: Bool {
    let now = Date()
    if let endAt = endAt {
      return now >= startAt && now <= endAt
    } else {
      return now >= startAt
    }
  }

  /// 일정이 지났는지 확인
  public var isPast: Bool {
    let now = Date()
    if let endAt = endAt {
      return now > endAt
    } else {
      return now > startAt
    }
  }

  /// 일정이 다가오는지 확인
  public var isUpcoming: Bool {
    return Date() < startAt
  }
}

// MARK: - UI Display Properties

extension ScheduleModel {
  /// 표시용 이모지 (없으면 기본값)
  public var displayEmoji: String {
    guard let emoji = emoji, !emoji.isEmpty else { return "📌" }
    return emoji
  }

  /// 시간 텍스트 (예: "오후 2:00" 또는 "14:00")
  public var timeText: String {
    startAt.formattedTime
  }

  /// 종료 시간 텍스트 (예: "오후 5:00" 또는 다음날이면 "1월 28일 오전 1:00")
  public var endTimeText: String? {
    guard let endAt = endAt else { return nil }
    return LocalizedDateFormatters.endTimeString(from: endAt, relativeTo: startAt)
  }

  /// 날짜 텍스트 (예: "오늘", "내일", "1월 15일")
  public var dateText: String {
    let calendar = Calendar.scheduleDisplay
    if calendar.isDateInToday(startAt) {
      return LocalizedStrings.DateFormat.today
    }
    if calendar.isDateInTomorrow(startAt) {
      return LocalizedStrings.DateFormat.tomorrow
    }
    return LocalizedDateFormatters.monthDayString(from: startAt)
  }

  /// 위치 텍스트 (없으면 기본값)
  public var locationText: String {
    location?.name ?? LocalizedStrings.Common.noLocation
  }

  /// 투표 마감까지 남은 시간 텍스트
  public var deadlineText: String? {
    let now = Date()
    guard votes.until > now else { return nil }

    let interval = votes.until.timeIntervalSince(now)
    let hours = Int(interval / 3600)
    let days = hours / 24

    if days > 0 {
      return LocalizedStrings.DateFormat.daysLater(days)
    } else if hours > 0 {
      return LocalizedStrings.DateFormat.hoursLater(hours)
    } else {
      let minutes = Int(interval / 60)
      return LocalizedStrings.DateFormat.minutesLater(minutes)
    }
  }

  /// 응답 상태 (우선순위: 불발 > 미응답 > 확정 > 응답완료)
  /// - Parameters:
  ///   - currentUserId: 현재 사용자 ID
  ///   - totalGroupMembers: 실제 그룹 멤버 수 (nil이면 투표 마감 기준으로만 판단)
  public func responseStatus(currentUserId: String?, totalGroupMembers: Int? = nil) -> ScheduleResponseStatus {
    // 1. 투표 마감 + 미확정 = 불발
    if isVotingClosed && !isConfirmed {
      return .failed
    }

    // 2. 모든 멤버 응답 완료 + 최소 인원 미달 = 불발
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

    // 3. 내가 미응답
    if let userId = currentUserId {
      let myStatus = votes.myStatus(userId: userId)
      if myStatus == .pending {
        // 투표 마감 전이면 응답 필요, 마감 후면 기한 만료
        return isVotingClosed ? .expired : .needResponse
      }
    }

    // 4. 일정이 확정됨 (isConfirmed: votes.accepted.count >= minimumParticipants)
    if isConfirmed {
      return .confirmed
    }

    // 5. 내가 응답함 (확정 대기)
    return .responded
  }
}

// MARK: - Validation (생성 시 검증)

extension ScheduleModel {
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
    minimumParticipants >= 1
  }

  /// 생성 가능 여부
  public var canCreate: Bool {
    isTitleValid && isGroupValid && isStartTimeValid && isEndTimeValid && isMinimumParticipantsValid
  }
}

// MARK: - Share

extension ScheduleModel {
  /// 공유용 텍스트
  public var shareText: String {
    var text = "\(displayEmoji) \(title)\n"
    text += "📅 \(dateText) \(timeText)\n"
    if let location = location {
      text += "📍 \(location.name)\n"
    }
    if !descriptionBlocks.isEmpty {
      if let blockText = descriptionBlocks.plainText {
        text += "\n\(blockText)"
      }
    } else if let description = description, !description.isEmpty {
      text += "\n\(description)"
    }
    return text
  }
}
