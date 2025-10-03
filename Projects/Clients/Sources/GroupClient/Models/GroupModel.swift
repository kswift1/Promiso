//
//  GroupModel.swift
//  Clients
//
//  Created by 김성원 on 10/1/25.
//

import Foundation

/// Feature에서 사용하는 그룹 모델
public struct GroupModel: Equatable, Identifiable, Sendable {
  public let id: String
  public let emoji: String
  public let title: String
  public let memberCount: Int

  public init(
    id: String,
    emoji: String,
    title: String,
    memberCount: Int
  ) {
    self.id = id
    self.emoji = emoji
    self.title = title
    self.memberCount = memberCount
  }
}
