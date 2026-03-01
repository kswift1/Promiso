import Foundation

// MARK: - Schedule Conflict Model

/// 일정 충돌 정보 모델
public struct ScheduleConflict: Equatable, Sendable, Identifiable {
  public var id: String  // promiseId 또는 eventId

  /// 충돌 소스 타입
  public enum Source: Equatable, Sendable {
    case promise    // 그룹 약속
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

  public init(
    id: String,
    source: Source,
    severity: Severity,
    title: String,
    emoji: String?,
    startAt: Date,
    endAt: Date?,
    overlapMinutes: Int
  ) {
    self.id = id
    self.source = source
    self.severity = severity
    self.title = title
    self.emoji = emoji
    self.startAt = startAt
    self.endAt = endAt
    self.overlapMinutes = overlapMinutes
  }
}
