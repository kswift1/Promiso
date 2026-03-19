//
//  CalendarImportResult.swift
//  PromisoShared
//
//  캘린더 임포트 결과 및 그룹 모델
//

import Foundation

// MARK: - Calendar Import Result

/// 캘린더 임포트 결과
public struct CalendarImportResult: Equatable, Sendable {
  public let totalImported: Int
  public let thisWeekCount: Int

  public init(totalImported: Int, thisWeekCount: Int) {
    self.totalImported = totalImported
    self.thisWeekCount = thisWeekCount
  }
}
