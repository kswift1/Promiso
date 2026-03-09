// MARK: - CalendarModels.swift
// 캘린더 UI용 모델 및 목업 데이터

import SwiftUI
import SharedFeature
import Clients

#if canImport(UIKit)
import UIKit
#endif

// MARK: - Calendar Display Mode

/// 캘린더 표시 모드 (3가지 모드)
public enum CalendarDisplayMode: Equatable, Sendable, CaseIterable {
  case week           // 주간 뷰 + 24시간 타임라인
  case month          // 월간 축약 (dot 인디케이터 + 하단 약속 리스트)
  case monthExpanded  // 월간 확장 (풀 인디케이터 바 + 스크롤)

  /// 다음 모드 (순환: week → month → monthExpanded → week)
  public var next: CalendarDisplayMode {
    switch self {
    case .week: return .month
    case .month: return .monthExpanded
    case .monthExpanded: return .week
    }
  }

  /// 모드별 SF Symbol 이름
  public var iconName: String {
    switch self {
    case .week: return "calendar.day.timeline.left"
    case .month: return "calendar"
    case .monthExpanded: return "square.grid.3x3"
    }
  }

  /// 모드 표시 이름
  public var label: String {
    switch self {
    case .week: return LocalizedStrings.Calendar.modeWeek
    case .month: return LocalizedStrings.Calendar.modeMonth
    case .monthExpanded: return LocalizedStrings.Calendar.modeMonthExpanded
    }
  }

  /// 월간 모드인지 여부
  public var isMonthMode: Bool {
    self == .month || self == .monthExpanded
  }
}

// MARK: - Mock Promise Status

/// 약속 상태 (UI 표시용)
public enum MockPromiseStatus: String, Equatable, Sendable, CaseIterable {
  case proposed   // 내 응답 대기
  case pending    // 투표 진행중
  case confirmed  // 확정
  case rejected   // 거절/무산

  var color: Color {
    switch self {
    case .proposed:  return .yellow
    case .pending:   return .orange
    case .confirmed: return .green
    case .rejected:  return Color(UIColor.systemGray3)
    }
  }

  var statusText: String {
    switch self {
    case .proposed:  return "응답 대기"
    case .pending:   return "투표중"
    case .confirmed: return "확정"
    case .rejected:  return "무산"
    }
  }

  var icon: String {
    switch self {
    case .proposed:  return "questionmark.circle.fill"
    case .pending:   return "clock.fill"
    case .confirmed: return "checkmark.circle.fill"
    case .rejected:  return "xmark.circle.fill"
    }
  }
}

// MARK: - Mock Promise

/// UI 확인용 목업 약속 모델
public struct MockPromise: Identifiable, Equatable, Sendable {
  public let id: String
  public let title: String
  public let emoji: String
  public let date: Date
  public let startTime: Date
  public let endTime: Date?
  public let location: String?
  public let status: MockPromiseStatus
  public let participants: [MockParticipant]
  public let totalParticipants: Int
  public let acceptedCount: Int
  public let deadlineText: String?
  public let needsMyResponse: Bool

  public init(
    id: String = UUID().uuidString,
    title: String,
    emoji: String = "📌",
    date: Date,
    startTime: Date,
    endTime: Date? = nil,
    location: String? = nil,
    status: MockPromiseStatus,
    participants: [MockParticipant] = [],
    totalParticipants: Int = 4,
    acceptedCount: Int = 0,
    deadlineText: String? = nil,
    needsMyResponse: Bool = false
  ) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.date = date
    self.startTime = startTime
    self.endTime = endTime
    self.location = location
    self.status = status
    self.participants = participants
    self.totalParticipants = totalParticipants
    self.acceptedCount = acceptedCount
    self.deadlineText = deadlineText
    self.needsMyResponse = needsMyResponse
  }

  // MARK: - Computed Properties

  public var timeText: String {
    guard let endTime = endTime else {
      return LocalizedDateFormatters.time.string(from: startTime)
    }

    let calendar = Calendar.current
    if calendar.isDate(startTime, inSameDayAs: endTime) {
      return "\(LocalizedDateFormatters.time.string(from: startTime)) ~ \(LocalizedDateFormatters.time.string(from: endTime))"
    } else {
      return "\(LocalizedDateFormatters.monthDayTimeString(from: startTime)) ~ \(LocalizedDateFormatters.monthDayTimeString(from: endTime))"
    }
  }

  public var participantsSummary: String {
    guard !participants.isEmpty else { return "" }

    let names = participants.prefix(2).map { $0.name }
    let remaining = participants.count - 2

    if remaining > 0 {
      return names.joined(separator: ", ") + " +\(remaining)"
    }
    return names.joined(separator: ", ")
  }

  public var statusDetailText: String {
    switch status {
    case .confirmed:
      return "\(status.statusText) · \(acceptedCount)/\(totalParticipants)"
    case .pending:
      if let deadline = deadlineText {
        return "\(status.statusText) · \(acceptedCount)/\(totalParticipants) · 마감 \(deadline)"
      }
      return "\(status.statusText) · \(acceptedCount)/\(totalParticipants)"
    case .proposed:
      return "내 응답 대기중"
    case .rejected:
      return "약속 무산"
    }
  }
}

// MARK: - Mock Participant

/// 목업 참여자 모델
public struct MockParticipant: Identifiable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let profileEmoji: String

  public init(
    id: String = UUID().uuidString,
    name: String,
    profileEmoji: String = "👤"
  ) {
    self.id = id
    self.name = name
    self.profileEmoji = profileEmoji
  }
}

// MARK: - Schedule Indicator Types

extension CalendarFeature {
  /// multi-day 일정에서 해당 날짜의 위치
  public enum SpanPosition: Equatable, Sendable {
    case single
    case start
    case middle
    case end
  }

  /// 인디케이터 소스 타입 (탭 시 상세 화면 이동에 사용)
  public enum ScheduleSourceType: Equatable, Sendable {
    case promise(id: String, groupId: String)
    case personalEvent(id: String)
    case calendarEvent(id: String)
    case unknown
  }

  /// 날짜 셀에 표시할 일정 인디케이터 (colored bar + truncated title)
  public struct ScheduleIndicator: Equatable, Identifiable, Sendable {
    public let id: String
    public let color: Color
    public let title: String
    public let spanPosition: SpanPosition
    public let startAt: Date
    public let endAt: Date?
    public let emoji: String?
    public let sourceType: ScheduleSourceType
    // 프리뷰용 상세 정보
    public let description: String?
    public let locationName: String?
    public let imageUrls: [String]
    public let groupName: String?
    public let groupImageUrl: String?

    public init(
      id: String,
      color: Color,
      title: String,
      spanPosition: SpanPosition = .single,
      startAt: Date = .distantPast,
      endAt: Date? = nil,
      emoji: String? = nil,
      sourceType: ScheduleSourceType = .unknown,
      description: String? = nil,
      locationName: String? = nil,
      imageUrls: [String] = [],
      groupName: String? = nil,
      groupImageUrl: String? = nil
    ) {
      self.id = id
      self.color = color
      self.title = title
      self.spanPosition = spanPosition
      self.startAt = startAt
      self.endAt = endAt
      self.emoji = emoji
      self.sourceType = sourceType
      self.description = description
      self.locationName = locationName
      self.imageUrls = imageUrls
      self.groupName = groupName
      self.groupImageUrl = groupImageUrl
    }

    public static let personalColor = Color.pmindigo.n500
    public static let systemEventColor = Color.gray
  }

  /// 24시간 타임라인에서 표시할 통합 일정 아이템
  public enum ScheduleItem: Identifiable, Equatable {
    case promise(PromiseModel)
    case personalEvent(PersonalEventModel)
    case calendarEvent(CalendarEvent)

    public var id: String {
      switch self {
      case .promise(let p): return "promise-\(p.id)"
      case .personalEvent(let e): return "personal-\(e.id)"
      case .calendarEvent(let e): return "calendar-\(e.id)"
      }
    }

    public var startAt: Date {
      switch self {
      case .promise(let p): return p.startAt
      case .personalEvent(let e): return e.startAt
      case .calendarEvent(let e): return e.startDate
      }
    }

    public var endAt: Date? {
      switch self {
      case .promise(let p): return p.endAt
      case .personalEvent(let e): return e.endAt
      case .calendarEvent(let e): return e.endDate
      }
    }

    public var effectiveEndAt: Date {
      endAt ?? startAt
    }

    public var displayEmoji: String {
      switch self {
      case .promise(let p): return p.displayEmoji
      case .personalEvent(let e): return e.displayEmoji
      case .calendarEvent(let e): return e.displayEmoji ?? ""
      }
    }

    public var title: String {
      switch self {
      case .promise(let p): return p.title
      case .personalEvent(let e): return e.title
      case .calendarEvent(let e): return e.displayTitle
      }
    }

    public var location: LocationInfoModel? {
      switch self {
      case .promise(let p): return p.location
      case .personalEvent(let e): return e.location
      case .calendarEvent: return nil
      }
    }
  }
}

// MARK: - Mock Data Generator

public enum MockDataGenerator {

  /// 목업 데이터 생성
  public static func generateMockPromises() -> [MockPromise] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())

    // 참여자 목업
    let participants: [MockParticipant] = [
      MockParticipant(name: "민수", profileEmoji: "🧑"),
      MockParticipant(name: "지영", profileEmoji: "👩"),
      MockParticipant(name: "현우", profileEmoji: "🧔"),
      MockParticipant(name: "서연", profileEmoji: "👧")
    ]

    var promises: [MockPromise] = []

    // 오늘: 확정된 약속 1개
    if let todayNoon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: today),
       let todayEnd = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: today) {
      promises.append(MockPromise(
        title: "점심 약속",
        emoji: "🍽️",
        date: today,
        startTime: todayNoon,
        endTime: todayEnd,
        location: "강남역 맛집",
        status: .confirmed,
        participants: Array(participants.prefix(3)),
        totalParticipants: 4,
        acceptedCount: 4
      ))
    }

    // 오늘: 투표중인 약속 1개
    if let todayEvening = calendar.date(bySettingHour: 19, minute: 30, second: 0, of: today) {
      promises.append(MockPromise(
        title: "저녁 회식",
        emoji: "🍻",
        date: today,
        startTime: todayEvening,
        location: "홍대 술집",
        status: .pending,
        participants: Array(participants.prefix(2)),
        totalParticipants: 4,
        acceptedCount: 2,
        deadlineText: "3시간"
      ))
    }

    // 내일: 내 응답 대기 약속 1개
    if let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
       let tomorrowAfternoon = calendar.date(bySettingHour: 15, minute: 0, second: 0, of: tomorrow) {
      promises.append(MockPromise(
        title: "카페 데이트",
        emoji: "☕",
        date: tomorrow,
        startTime: tomorrowAfternoon,
        location: "스타벅스 신촌점",
        status: .proposed,
        participants: [participants[1]],
        totalParticipants: 2,
        acceptedCount: 1,
        deadlineText: "내일 오전",
        needsMyResponse: true
      ))
    }

    // 모레: 확정된 약속 1개
    if let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today),
       let morningTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: dayAfterTomorrow) {
      promises.append(MockPromise(
        title: "운동 모임",
        emoji: "🏃",
        date: dayAfterTomorrow,
        startTime: morningTime,
        location: "한강공원",
        status: .confirmed,
        participants: Array(participants),
        totalParticipants: 4,
        acceptedCount: 4
      ))
    }

    // 4일 후: 투표중인 약속
    if let day4 = calendar.date(byAdding: .day, value: 4, to: today),
       let eveningTime = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day4) {
      promises.append(MockPromise(
        title: "영화 관람",
        emoji: "🎬",
        date: day4,
        startTime: eveningTime,
        location: "CGV 용산",
        status: .pending,
        participants: Array(participants.prefix(2)),
        totalParticipants: 4,
        acceptedCount: 2,
        deadlineText: "2일"
      ))
    }

    // 5일 후: 확정된 약속
    if let day5 = calendar.date(byAdding: .day, value: 5, to: today),
       let lunchTime = calendar.date(bySettingHour: 12, minute: 30, second: 0, of: day5) {
      promises.append(MockPromise(
        title: "브런치",
        emoji: "🥞",
        date: day5,
        startTime: lunchTime,
        location: "이태원 카페",
        status: .confirmed,
        participants: Array(participants.prefix(2)),
        totalParticipants: 2,
        acceptedCount: 2
      ))
    }

    // 다음 주: 내 응답 대기 약속
    if let nextWeek = calendar.date(byAdding: .day, value: 8, to: today),
       let afternoonTime = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: nextWeek) {
      promises.append(MockPromise(
        title: "스터디 모임",
        emoji: "📚",
        date: nextWeek,
        startTime: afternoonTime,
        location: "도서관 스터디룸",
        status: .proposed,
        participants: Array(participants.prefix(3)),
        totalParticipants: 4,
        acceptedCount: 3,
        deadlineText: "5일",
        needsMyResponse: true
      ))
    }

    return promises
  }
}
