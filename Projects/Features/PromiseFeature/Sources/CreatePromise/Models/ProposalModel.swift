//
//  ProposalModel.swift
//  PromiseFeatureExample
//
//  Created by 김성원 on 9/12/25.
//

import Foundation

public struct PromiseProposal: Equatable {
  var title: String
  var emoji: String?
  var group: GroupModel?
  var startedAt: Date
  var endedAt: Date?
  var minimumParticipants: Int?
  var place: String?
  var details: String?
  var reminder: Date?
  var arrivalSharingTime: Int? = nil // 도착 상황 공유 시작 시간 (분 단위)
}

extension PromiseProposal {
  static let empty: PromiseProposal = .init(
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
}

public struct ProposalModel: Equatable {
  var receivedProposals: [ProposalItem]
  var sentProposals: [ProposalItem]
  var confirmedProposals: [ProposalItem]
  
  /// 제안 아이템을 나타내는 구조체
  public struct ProposalItem: Equatable, Identifiable {
    public let id: String
    public let title: String
    public let emoji: String
    public let time: String
    public let location: String
    public let with: String
    public var status: ProposalStatus
    public let isReceived: Bool
    
    public enum ProposalStatus: Equatable {
      case pending
      case accepted
      case rejected
    }
  }
}

// FIXME:
extension ProposalModel {
  public static var example: ProposalModel = .init(
    receivedProposals: [
      ProposalItem(
        id: "1",
        title: "카페 데이트",
        emoji: "☕",
        time: "오후 2:00",
        location: "스타벅스 강남점",
        with: "지민",
        status: .pending,
        isReceived: true
      ),
      ProposalItem(
        id: "2",
        title: "주말 브런치",
        emoji: "🥐",
        time: "오전 11:00",
        location: "브런치 카페",
        with: "지민",
        status: .pending,
        isReceived: true
      )
    ],
    sentProposals: [
      ProposalItem(
        id: "3",
        title: "영화 관람",
        emoji: "🎬",
        time: "오후 7:00",
        location: "CGV 강남",
        with: "지민",
        status: .accepted,
        isReceived: false
      ),
      ProposalItem(
        id: "4",
        title: "저녁 식사",
        emoji: "🍽️",
        time: "오후 6:30",
        location: "맛집 레스토랑",
        with: "지민",
        status: .pending,
        isReceived: false
      )
    ],
    confirmedProposals: [
      ProposalItem(
        id: "3",
        title: "영화 관람",
        emoji: "🎬",
        time: "오후 7:00",
        location: "CGV 강남",
        with: "지민",
        status: .accepted,
        isReceived: false
      )
    ]
  )
}
