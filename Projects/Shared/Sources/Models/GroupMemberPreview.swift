//
//  GroupMemberPreview.swift
//  Shared
//
//  Created by Claude on 1/4/26.
//

import Foundation

/// 그룹 멤버 미리보기 정보
public struct GroupMemberPreview: Equatable, Identifiable, Sendable {
  public var id: String { userId }

  public let userId: String
  public let name: String
  public let profileImage: RemoteImage?

  public init(
    userId: String,
    name: String,
    profileImage: RemoteImage? = nil
  ) {
    self.userId = userId
    self.name = name
    self.profileImage = profileImage
  }
}
