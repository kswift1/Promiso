import CryptoKit
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

  // MARK: - 시간
  public var startAt: Date
  public var endAt: Date?

  // MARK: - 위치
  public var location: LocationInfoModel?

  // MARK: - 이미지
  /// 첨부 이미지 URL 목록 (최대 3장)
  public var imageUrls: [String]

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
    startAt: Date = Date().addingTimeInterval(3600),
    endAt: Date? = nil,
    location: LocationInfoModel? = nil,
    imageUrls: [String] = [],
    reminderMinutesBefore: Int? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.description = description
    self.startAt = startAt
    self.endAt = endAt
    self.location = location
    self.imageUrls = imageUrls
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
    startAt: Date = Date().addingTimeInterval(3600),
    endAt: Date? = nil,
    location: LocationInfoModel? = nil,
    imageUrls: [String] = [],
    reminderMinutesBefore: Int? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) -> PersonalEventModel {
    PersonalEventModel(
      id: id,
      title: title,
      emoji: emoji,
      description: description,
      startAt: startAt,
      endAt: endAt,
      location: location,
      imageUrls: imageUrls,
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
      startAt: dto.startAt.dateValue(),
      endAt: dto.endAt?.dateValue(),
      location: dto.location.map { LocationInfoModel(dto: $0) },
      imageUrls: dto.imageUrls ?? [],
      reminderMinutesBefore: dto.reminderMinutesBefore,
      createdAt: dto.createdAt.dateValue(),
      updatedAt: dto.updatedAt.dateValue()
    )
  }
}

// MARK: - Time-based Properties

extension PersonalEventModel {
  /// endAt이 없는 경우 기본 종료 시간 (startAt + 1시간)
  public var effectiveEndAt: Date {
    endAt ?? startAt.addingTimeInterval(3600)
  }

  /// 일정이 진행 중인지 확인
  public var isOngoing: Bool {
    let now = Date()
    return now >= startAt && now <= effectiveEndAt
  }

  /// 일정이 지났는지 확인
  public var isPast: Bool {
    Date() > effectiveEndAt
  }

  /// 일정이 다가오는지 확인 (시작 전)
  public var isUpcoming: Bool {
    Date() < startAt
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

  /// 날짜 텍스트 (예: "오늘", "내일", "어제", "1월 15일")
  public var dateText: String {
    let calendar = Calendar.current
    if calendar.isDateInToday(startAt) {
      return "오늘"
    }
    if calendar.isDateInTomorrow(startAt) {
      return "내일"
    }
    if calendar.isDateInYesterday(startAt) {
      return "어제"
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

// MARK: - Calendar Sync Properties

extension PersonalEventModel {
  /// 캘린더 sync용 콘텐츠 해시 (CalendarSyncPromise 패턴과 동일)
  public var contentHash: String {
    let startTimestamp = Int(startAt.timeIntervalSince1970)
    let endTimestamp = endAt.map { Int($0.timeIntervalSince1970) } ?? 0
    let content = "\(title)|\(location?.name ?? "")|\(startTimestamp)|\(endTimestamp)"
    let data = Data(content.utf8)
    let hash = SHA256.hash(data: data)
    return hash.prefix(4).map { String(format: "%02x", $0) }.joined()
  }

  /// 캘린더 이벤트 제목 (이모지 + 제목)
  public var calendarTitle: String {
    "\(displayEmoji) \(title)"
  }
}

// MARK: - Notification Helpers

extension PersonalEventModel {
  /// 로컬 알림 식별자
  public var notificationId: String { "personal_reminder_\(id)" }

  /// 알림 발송 시각 (startAt - reminderMinutesBefore)
  public var reminderDate: Date? {
    guard let minutes = reminderMinutesBefore else { return nil }
    return startAt.addingTimeInterval(-Double(minutes) * 60)
  }

  /// 알림 스케줄 가능 여부 (미래 시점 + 리마인더 설정됨)
  public var canScheduleReminder: Bool {
    guard let date = reminderDate else { return false }
    return date > Date()
  }

  /// 알림 제목
  public var notificationTitle: String { "\(displayEmoji) \(title)" }

  /// 알림 본문
  public var notificationBody: String {
    guard let minutes = reminderMinutesBefore else { return "" }
    switch minutes {
    case 0:
      return "지금 시작하는 일정입니다"
    case let m where m >= 10080 && m % (1440 * 7) == 0:
      return "\(m / (1440 * 7))주 후 시작하는 일정입니다"
    case let m where m >= 1440:
      return "\(m / 1440)일 후 시작하는 일정입니다"
    case let m where m >= 60:
      return "\(m / 60)시간 후 시작하는 일정입니다"
    default:
      return "\(minutes)분 후 시작하는 일정입니다"
    }
  }
}

// MARK: - Example Data

extension PersonalEventModel {
  /// 다양한 상태의 개인 일정 예시
  public static let examples: [PersonalEventModel] = [
    // 1. 오늘 일정 - 진행 예정
    PersonalEventModel(
      id: "event-today-1",
      title: "아침 운동",
      emoji: "🏃",
      description: "한강 러닝 5km",
      startAt: Date().addingTimeInterval(7200),
      endAt: Date().addingTimeInterval(10800),
      location: LocationInfoModel(name: "여의도 한강공원"),
      reminderMinutesBefore: 30
    ),
    // 2. 오늘 일정 - 종료 시간 없음
    PersonalEventModel(
      id: "event-today-2",
      title: "친구 만남",
      emoji: "☕️",
      description: "카페에서 수다",
      startAt: Date().addingTimeInterval(14400),
      location: LocationInfoModel(name: "스타벅스 강남점")
    ),
    // 3. 내일 일정
    PersonalEventModel(
      id: "event-tomorrow-1",
      title: "치과 예약",
      emoji: "🦷",
      startAt: Date().addingTimeInterval(108000),
      endAt: Date().addingTimeInterval(112200),
      location: LocationInfoModel(name: "서울치과"),
      reminderMinutesBefore: 60
    ),
    // 4. 다음 주 일정
    PersonalEventModel(
      id: "event-next-week-1",
      title: "프로젝트 발표",
      emoji: "💼",
      description: "Q1 성과 발표 준비",
      startAt: Date().addingTimeInterval(604800),
      endAt: Date().addingTimeInterval(608400),
      reminderMinutesBefore: 120
    ),
    // 5. 과거 일정
    PersonalEventModel(
      id: "event-past-1",
      title: "점심 약속",
      emoji: "🍜",
      startAt: Date().addingTimeInterval(-7200),
      endAt: Date().addingTimeInterval(-3600),
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
