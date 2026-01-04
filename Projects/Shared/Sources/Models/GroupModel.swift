//
//  GroupModel.swift
//  Shared
//
//  Created by 김성원 on 10/1/25.
//

import Foundation

/// groups 컬렉션 스키마에 대응하는 앱 모델
public struct GroupModel: Equatable, Identifiable, Sendable {
  public let id: String
  public let name: String
  public let description: String?
  public let emoji: String
  public let themeColor: String?
  public let photo: RemoteImage?
  public let memberCount: Int
  public let activePromiseCount: Int
  public let maxMembers: Int?
  public let requireApproval: Bool
  public let defaultMinimumParticipants: Int
  public let inviteCode: String
  public let createdBy: String
  public let createdAt: Date
  public let updatedAt: Date
  public let isDeleted: Bool

  /// 멤버 미리보기 리스트 (미리보기 응답에서만 사용, 최대 10명)
  public let members: [GroupMemberPreview]?

  public init(
    id: String,
    name: String,
    description: String? = nil,
    emoji: String = "👥",
    themeColor: String? = nil,
    photo: RemoteImage? = nil,
    memberCount: Int = 0,
    activePromiseCount: Int = 0,
    maxMembers: Int? = nil,
    requireApproval: Bool = false,
    defaultMinimumParticipants: Int = 2,
    inviteCode: String = "",
    createdBy: String = "",
    createdAt: Date = Date(),
    updatedAt: Date = Date(),
    isDeleted: Bool = false,
    members: [GroupMemberPreview]? = nil
  ) {
    self.id = id
    self.name = name
    self.description = description
    self.emoji = emoji
    self.themeColor = themeColor
    self.photo = photo
    self.memberCount = memberCount
    self.activePromiseCount = activePromiseCount
    self.maxMembers = maxMembers
    self.requireApproval = requireApproval
    self.defaultMinimumParticipants = defaultMinimumParticipants
    self.inviteCode = inviteCode
    self.createdBy = createdBy
    self.createdAt = createdAt
    self.updatedAt = updatedAt
    self.isDeleted = isDeleted
    self.members = members
  }
}
