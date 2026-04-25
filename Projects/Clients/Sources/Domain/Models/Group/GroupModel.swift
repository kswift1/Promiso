//
//  GroupModel.swift
//  Shared
//
//  Created by 김성원 on 10/1/25.
//

import Foundation
import PromisoShared

/// groups 컬렉션 스키마에 대응하는 앱 모델
public struct GroupModel: Equatable, Hashable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let description: String?
  public let imageUrl: String?
  public let memberCount: Int
  public let maxMembers: Int
  public let inviteCode: String
  public let createdBy: String
  public let createdAt: Date
  public let updatedAt: Date

  public init(
    id: String,
    name: String,
    description: String? = nil,
    imageUrl: String? = nil,
    memberCount: Int = 0,
    maxMembers: Int,
    inviteCode: String,
    createdBy: String,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.imageUrl = imageUrl
    self.memberCount = memberCount
    self.maxMembers = maxMembers
    self.inviteCode = inviteCode
    self.createdBy = createdBy
    self.createdAt = createdAt
    self.updatedAt = updatedAt
  }
}
