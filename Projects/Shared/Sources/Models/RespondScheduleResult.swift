//
//  RespondScheduleResult.swift
//  PromisoShared
//
//  일정 응답 결과 모델 (캘린더 동기화용)
//

import Foundation

/// 일정 응답 API 결과
public struct RespondScheduleResult: Equatable, Sendable {
  public let scheduleId: String
  public let status: String
  public let isConfirmed: Bool
  public let confirmedSchedule: CalendarSyncSchedule?

  public init(
    scheduleId: String,
    status: String,
    isConfirmed: Bool,
    confirmedSchedule: CalendarSyncSchedule? = nil
  ) {
    self.scheduleId = scheduleId
    self.status = status
    self.isConfirmed = isConfirmed
    self.confirmedSchedule = confirmedSchedule
  }
}
