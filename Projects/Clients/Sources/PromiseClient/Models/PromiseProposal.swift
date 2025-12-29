//
//  PromiseProposal.swift
//  Clients
//
//  Created by 김성원 on 9/12/25.
//

import Foundation
import Shared

/// Feature에서 사용하는 약속 제안 모델
public struct PromiseProposal: Equatable, Sendable {
  public var title: String
  public var emoji: String?
  public var group: GroupModel?
  public var startedAt: Date
  public var endedAt: Date?
  public var minimumParticipants: Int?
  public var place: String?
  public var details: String?
  public var reminder: Date?
  public var arrivalSharingTime: Int? = nil // 도착 상황 공유 시작 시간 (분 단위)

  public init(
    title: String,
    emoji: String? = nil,
    group: GroupModel? = nil,
    startedAt: Date,
    endedAt: Date? = nil,
    minimumParticipants: Int? = nil,
    place: String? = nil,
    details: String? = nil,
    reminder: Date? = nil,
    arrivalSharingTime: Int? = nil
  ) {
    self.title = title
    self.emoji = emoji
    self.group = group
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.minimumParticipants = minimumParticipants
    self.place = place
    self.details = details
    self.reminder = reminder
    self.arrivalSharingTime = arrivalSharingTime
  }
}

extension PromiseProposal {
  public static let empty: PromiseProposal = .init(
    title: "",
    emoji: nil,
    group: nil,
    startedAt: Date().addingTimeInterval(3600),
    endedAt: nil,
    minimumParticipants: nil,
    place: nil,
    details: nil,
    reminder: nil
  )
  
  /// PromiseProposal (Feature 모델) → PromiseModel (Shared 모델) 변환
  public func toDomainModel(hostId: String, group: GroupModel) -> PromiseModel {
    PromiseModel(
      id: UUID().uuidString,
      emoji: emoji,
      title: title,
      description: details,
      minimumParticipants: minimumParticipants ?? 2,
      requiredCount: minimumParticipants ?? 2,
      isConfirmed: false,
      host: UserModel(id: hostId, email: "", nickname: ""),
      group: Group(id: group.id, name: group.title),
      startAt: startedAt,
      endAt: endedAt,
      status: .active,
      location: place.map { LocationInfo(name: $0) }
    )
  }
}
