import Foundation
import PromisoShared

// MARK: - Personal Event Model

/// 개인 일정 도메인 모델
public struct PersonalEventModel: Identifiable, Equatable, Hashable, Sendable {
  // MARK: - 기본 정보
  public var id: String
  public var title: String
  public var emoji: String?
  public var description: String?

  // MARK: - 소유자
  public var userId: String

  // MARK: - 시간
  public var startAt: Date
  public var endAt: Date?

  // MARK: - 위치
  public var location: LocationInfoModel?

  // MARK: - 알림
  public var reminderMinutesBefore: Int?

  // MARK: - 메타데이터
  public var createdAt: Date
  public var updatedAt: Date

  public init(
    id: String = UUID().uuidString,
    title: String = "",
    emoji: String? = nil,
    description: String? = nil,
    userId: String = "",
    startAt: Date = Date().addingTimeInterval(3600),
    endAt: Date? = nil,
    location: LocationInfoModel? = nil,
    reminderMinutesBefore: Int? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.description = description
    self.userId = userId
    self.startAt = startAt
    self.endAt = endAt
    self.location = location
    self.reminderMinutesBefore = reminderMinutesBefore
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }

  /// 빈 개인 일정 (생성용)
  public static var empty: PersonalEventModel {
    PersonalEventModel()
  }

  /// Preview/테스트용 Mock 데이터
  public static func mock(
    id: String = "mock-event-id",
    title: String = "Mock 개인 일정",
    emoji: String? = "📅",
    description: String? = nil,
    userId: String = "mock-user-id",
    startAt: Date = Date().addingTimeInterval(3600),
    endAt: Date? = nil,
    location: LocationInfoModel? = nil,
    reminderMinutesBefore: Int? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) -> PersonalEventModel {
    PersonalEventModel(
      id: id,
      title: title,
      emoji: emoji,
      description: description,
      userId: userId,
      startAt: startAt,
      endAt: endAt,
      location: location,
      reminderMinutesBefore: reminderMinutesBefore,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }
}

// MARK: - DTO -> Model 변환

extension PersonalEventModel {
  /// DTO에서 Model 생성
  public init(dto: PersonalEventDTO, id: String) {
    self.init(
      id: id,
      title: dto.title,
      emoji: dto.emoji,
      description: dto.description,
      userId: dto.userId,
      startAt: dto.startAt.dateValue(),
      endAt: dto.endAt?.dateValue(),
      location: dto.location.map { LocationInfoModel(dto: $0) },
      reminderMinutesBefore: dto.reminderMinutesBefore,
      createdAt: dto.createdAt.dateValue(),
      updatedAt: dto.updatedAt.dateValue()
    )
  }
}

// MARK: - Time-based Properties

extension PersonalEventModel {
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

extension PersonalEventModel {
  /// 표시용 이모지 (없으면 기본값)
  public var displayEmoji: String {
    guard let emoji = emoji, !emoji.isEmpty else { return "📅" }
    return emoji
  }

  /// 시간 텍스트 (예: "오후 2:00" 또는 "14:00")
  public var timeText: String {
    startAt.formattedTime
  }

  /// 종료 시간 텍스트 (예: "오후 5:00" 또는 다음날이면 "1월 28일 오전 1:00")
  public var endTimeText: String? {
    guard let endAt = endAt else { return nil }
    return KoreanDateFormatters.endTimeString(from: endAt, relativeTo: startAt)
  }

  /// 시간 범위 텍스트 (예: "오후 2:00 ~ 오후 5:00" 또는 "오후 2:00 ~ 1월 28일 오전 1:00")
  public var timeRangeText: String {
    if let endTimeText = endTimeText {
      return "\(timeText) ~ \(endTimeText)"
    }
    return timeText
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
}

// MARK: - Validation (생성 시 검증)

extension PersonalEventModel {
  /// 제목 유효성
  public var isTitleValid: Bool {
    !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

  /// 생성 가능 여부
  public var canCreate: Bool {
    isTitleValid && isStartTimeValid && isEndTimeValid
  }
}

// MARK: - Share

extension PersonalEventModel {
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

// MARK: - Example Data

extension PersonalEventModel {
  /// Preview용 현재 유저 ID
  public static let previewCurrentUserId = "preview-user"

  /// 다양한 상태의 개인 일정 예시
  public static let examples: [PersonalEventModel] = [
    // 1. 오늘 일정 - 진행 예정
    PersonalEventModel(
      id: "event-today-1",
      title: "아침 운동",
      emoji: "🏃",
      description: "한강 러닝 5km",
      userId: previewCurrentUserId,
      startAt: Date().addingTimeInterval(7200),  // 2시간 후
      endAt: Date().addingTimeInterval(10800),  // 3시간 후
      location: LocationInfoModel(name: "여의도 한강공원"),
      reminderMinutesBefore: 30
    ),
    // 2. 오늘 일정 - 종료 시간 없음
    PersonalEventModel(
      id: "event-today-2",
      title: "친구 만남",
      emoji: "☕️",
      description: "카페에서 수다",
      userId: previewCurrentUserId,
      startAt: Date().addingTimeInterval(14400),  // 4시간 후
      location: LocationInfoModel(name: "스타벅스 강남점")
    ),
    // 3. 내일 일정
    PersonalEventModel(
      id: "event-tomorrow-1",
      title: "치과 예약",
      emoji: "🦷",
      userId: previewCurrentUserId,
      startAt: Date().addingTimeInterval(108000),  // 30시간 후
      endAt: Date().addingTimeInterval(112200),  // 31.17시간 후
      location: LocationInfoModel(name: "서울치과"),
      reminderMinutesBefore: 60
    ),
    // 4. 다음 주 일정
    PersonalEventModel(
      id: "event-next-week-1",
      title: "프로젝트 발표",
      emoji: "💼",
      description: "Q1 성과 발표 준비",
      userId: previewCurrentUserId,
      startAt: Date().addingTimeInterval(604800),  // 7일 후
      endAt: Date().addingTimeInterval(608400),  // 7일 1시간 후
      reminderMinutesBefore: 120
    ),
    // 5. 과거 일정
    PersonalEventModel(
      id: "event-past-1",
      title: "점심 약속",
      emoji: "🍜",
      userId: previewCurrentUserId,
      startAt: Date().addingTimeInterval(-7200),  // 2시간 전
      endAt: Date().addingTimeInterval(-3600),  // 1시간 전
      location: LocationInfoModel(name: "이치란 라멘")
    )
  ]

  /// 활성 일정만 필터링 (Preview용)
  public static var activeExamples: [PersonalEventModel] {
    examples.filter { !$0.isPast }
  }

  /// 과거 일정만 필터링 (Preview용)
  public static var pastExamples: [PersonalEventModel] {
    examples.filter { $0.isPast }
  }
}
