//
//  RespondPromiseResult.swift
//  PromisoShared
//
//  약속 응답 결과 모델 (캘린더 동기화용)
//

import Foundation

/// 약속 응답 API 결과
public struct RespondPromiseResult: Equatable, Sendable {
  public let promiseId: String
  public let status: String
  public let isConfirmed: Bool
  public let confirmedPromise: CalendarSyncPromise?

  public init(
    promiseId: String,
    status: String,
    isConfirmed: Bool,
    confirmedPromise: CalendarSyncPromise? = nil
  ) {
    self.promiseId = promiseId
    self.status = status
    self.isConfirmed = isConfirmed
    self.confirmedPromise = confirmedPromise
  }
}
