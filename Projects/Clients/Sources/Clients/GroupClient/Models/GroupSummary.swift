//
//  GroupSummary.swift
//  Clients
//
//  Minimal group model for navigation menus
//

import Foundation

/// 그룹 네비게이션용 요약 모델 (users/{userId}/groups 스키마 기반)
public struct GroupSummary: Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let role: GroupRole?
  public let joinedAt: Date?
  public let notifications: Bool?

  public init(
    id: String,
    name: String,
    role: GroupRole? = nil,
    joinedAt: Date? = nil,
    notifications: Bool? = nil
  ) {
    self.id = id
    self.name = name
    self.role = role
    self.joinedAt = joinedAt
    self.notifications = notifications
  }
}
