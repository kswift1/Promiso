import Foundation

// MARK: - Schedule Conflict Model

/// 일정 충돌 정보 모델
public struct ScheduleConflict: Equatable, Sendable, Identifiable {
  public var id: String  // scheduleId 또는 eventId

  /// 충돌 소스 타입
  public enum Source: Equatable, Sendable {
    case schedule    // 그룹 일정
    case personalEvent  // 개인 일정
  }

  /// 충돌 심각도
  public enum Severity: Equatable, Sendable {
    case confirmed  // 수락+확정 (그룹) 또는 개인 일정
    case pending    // 수락+미확정 (그룹)
  }

  public let source: Source
  public let severity: Severity
  public let title: String
  public let emoji: String?
  public let startAt: Date
  public let endAt: Date?
  public let overlapMinutes: Int
  public let gapMinutes: Int  // 두 일정 사이 여유 시간 (분). 겹치면 0, 안 겹치면 양수

  public init(
    id: String,
    source: Source,
    severity: Severity,
    title: String,
    emoji: String?,
    startAt: Date,
    endAt: Date?,
    overlapMinutes: Int,
    gapMinutes: Int = 0
  ) {
    self.id = id
    self.source = source
    self.severity = severity
    self.title = title
    self.emoji = emoji
    self.startAt = startAt
    self.endAt = endAt
    self.overlapMinutes = overlapMinutes
    self.gapMinutes = gapMinutes
  }
}
