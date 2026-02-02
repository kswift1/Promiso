//
//  CalendarSyncPromise.swift
//  PromisoShared
//
//  캘린더 동기화용 약속 모델
//

import Foundation

/// 캘린더 동기화용 약속 정보 (최소 데이터)
public struct CalendarSyncPromise: Equatable, Sendable, Codable {
  public let id: String
  public let title: String
  public let emoji: String
  public let startAt: Date
  public let endAt: Date?
  public let location: String?
  public let groupId: String

  public init(
    id: String,
    title: String,
    emoji: String,
    startAt: Date,
    endAt: Date?,
    location: String?,
    groupId: String
  ) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.startAt = startAt
    self.endAt = endAt
    self.location = location
    self.groupId = groupId
  }
}
