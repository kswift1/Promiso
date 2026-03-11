//
//  SupportingTypesTests.swift
//  Clients
//
//  Supporting Types 모델 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Domain/Models/SupportingTypes.swift`
//  - `Clients/Sources/Domain/Models/MapTypes.swift`
//
//  ## 테스트 목적
//  - ScheduleVotesModel: acceptedCount, declinedCount, votedCount, isConfirmed, myStatus, pendingMembers 검증
//  - LocationInfoModel: 초기화, 속성 검증
//  - VoteStatus: rawValue 검증
//  - Coordinate, Place: 초기화, displayAddress, toLocationInfo 변환 검증
//  - Proposal, ProposalStatus: 초기화, rawValue 검증
//

import Foundation
import Testing
@testable import Clients

// MARK: - ScheduleVotesModel 테스트

@Suite("ScheduleVotesModel 테스트")
struct ScheduleVotesModelTests {

  @Test("acceptedCount는 accepted 배열 길이")
  func acceptedCount_returnsArrayCount() {
    let votes = TestFactories.makeVotes(accepted: ["u1", "u2", "u3"])
    #expect(votes.acceptedCount == 3)
  }

  @Test("declinedCount는 declined 배열 길이")
  func declinedCount_returnsArrayCount() {
    let votes = TestFactories.makeVotes(declined: ["u1", "u2"])
    #expect(votes.declinedCount == 2)
  }

  @Test("votedCount는 accepted + declined 합계")
  func votedCount_returnsTotalVoted() {
    let votes = TestFactories.makeVotes(accepted: ["u1", "u2"], declined: ["u3"])
    #expect(votes.votedCount == 3)
  }

  @Test("빈 투표의 votedCount는 0")
  func votedCount_whenEmpty_returnsZero() {
    let votes = TestFactories.makeVotes()
    #expect(votes.votedCount == 0)
  }

  @Test("isConfirmed: accepted >= minimumParticipants 이면 true")
  func isConfirmed_whenMeetsMinimum_returnsTrue() {
    let votes = TestFactories.makeVotes(accepted: ["u1", "u2"])
    #expect(votes.isConfirmed(minimumParticipants: 2) == true)
  }

  @Test("isConfirmed: accepted < minimumParticipants 이면 false")
  func isConfirmed_whenBelowMinimum_returnsFalse() {
    let votes = TestFactories.makeVotes(accepted: ["u1"])
    #expect(votes.isConfirmed(minimumParticipants: 2) == false)
  }

  @Test("myStatus: accepted에 있으면 .accepted")
  func myStatus_whenInAccepted_returnsAccepted() {
    let votes = TestFactories.makeVotes(accepted: ["u1"])
    #expect(votes.myStatus(userId: "u1") == .accepted)
  }

  @Test("myStatus: declined에 있으면 .declined")
  func myStatus_whenInDeclined_returnsDeclined() {
    let votes = TestFactories.makeVotes(declined: ["u1"])
    #expect(votes.myStatus(userId: "u1") == .declined)
  }

  @Test("myStatus: 어디에도 없으면 .pending")
  func myStatus_whenNotInAny_returnsPending() {
    let votes = TestFactories.makeVotes(accepted: ["u1"], declined: ["u2"])
    #expect(votes.myStatus(userId: "u3") == .pending)
  }

  @Test("pendingMembers: accepted, declined에 없는 멤버만 반환")
  func pendingMembers_returnsOnlyPendingUsers() {
    let votes = TestFactories.makeVotes(accepted: ["u1"], declined: ["u2"])
    let pending = votes.pendingMembers(memberIds: ["u1", "u2", "u3", "u4"])
    #expect(pending == ["u3", "u4"])
  }

  @Test("pendingCount: pending 멤버 수 반환")
  func pendingCount_returnsCorrectCount() {
    let votes = TestFactories.makeVotes(accepted: ["u1"], declined: ["u2"])
    let count = votes.pendingCount(memberIds: ["u1", "u2", "u3", "u4"])
    #expect(count == 2)
  }

  @Test("기본 초기화 시 빈 배열과 현재 시간")
  func defaultInit_hasEmptyArrays() {
    let votes = ScheduleVotesModel()
    #expect(votes.accepted.isEmpty)
    #expect(votes.declined.isEmpty)
    #expect(votes.acceptedCount == 0)
    #expect(votes.declinedCount == 0)
  }
}

// MARK: - VoteStatus 테스트

@Suite("VoteStatus 테스트")
struct VoteStatusTests {

  @Test("VoteStatus rawValue 올바름")
  func rawValues() {
    #expect(VoteStatus.pending.rawValue == "pending")
    #expect(VoteStatus.accepted.rawValue == "accepted")
    #expect(VoteStatus.declined.rawValue == "declined")
  }
}

// MARK: - LocationInfoModel 테스트

@Suite("LocationInfoModel 테스트")
struct LocationInfoModelTests {

  @Test("기본 속성 초기화")
  func init_setsProperties() {
    let location = TestFactories.makeLocation(
      name: "강남역",
      address: "서울 강남구",
      latitude: 37.498,
      longitude: 127.027
    )
    #expect(location.name == "강남역")
    #expect(location.address == "서울 강남구")
    #expect(location.latitude == 37.498)
    #expect(location.longitude == 127.027)
  }

  @Test("옵셔널 필드 nil 허용")
  func init_allowsNilOptionals() {
    let location = TestFactories.makeLocation(name: "장소")
    #expect(location.name == "장소")
    #expect(location.address == nil)
    #expect(location.latitude == nil)
    #expect(location.longitude == nil)
  }
}

// MARK: - Coordinate 테스트

@Suite("Coordinate 테스트")
struct CoordinateTests {

  @Test("좌표 초기화 및 속성 확인")
  func init_setsCoordinates() {
    let coord = Coordinate(latitude: 37.5665, longitude: 126.9780)
    #expect(coord.latitude == 37.5665)
    #expect(coord.longitude == 126.9780)
  }

  @Test("좌표 동등성 비교")
  func equatable_sameCoordinates_areEqual() {
    let coord1 = Coordinate(latitude: 37.5, longitude: 127.0)
    let coord2 = Coordinate(latitude: 37.5, longitude: 127.0)
    #expect(coord1 == coord2)
  }

  @Test("다른 좌표는 같지 않음")
  func equatable_differentCoordinates_areNotEqual() {
    let coord1 = Coordinate(latitude: 37.5, longitude: 127.0)
    let coord2 = Coordinate(latitude: 37.6, longitude: 127.0)
    #expect(coord1 != coord2)
  }
}

// MARK: - Place 테스트

@Suite("Place 테스트")
struct PlaceTests {

  @Test("Place 기본 초기화")
  func init_setsProperties() {
    let coord = Coordinate(latitude: 37.5, longitude: 127.0)
    let place = Place(
      id: "place-1",
      name: "강남역",
      coordinate: coord,
      address: "서울 강남구 역삼동",
      roadAddress: "서울 강남구 강남대로 396",
      category: "교통",
      phone: "02-1234-5678"
    )
    #expect(place.id == "place-1")
    #expect(place.name == "강남역")
    #expect(place.coordinate == coord)
    #expect(place.address == "서울 강남구 역삼동")
    #expect(place.roadAddress == "서울 강남구 강남대로 396")
    #expect(place.category == "교통")
    #expect(place.phone == "02-1234-5678")
  }

  @Test("displayAddress: 도로명 주소가 있으면 도로명 우선")
  func displayAddress_withRoadAddress_returnsRoadAddress() {
    let coord = Coordinate(latitude: 37.5, longitude: 127.0)
    let place = Place(
      id: "p1",
      name: "장소",
      coordinate: coord,
      address: "지번 주소",
      roadAddress: "도로명 주소"
    )
    #expect(place.displayAddress == "도로명 주소")
  }

  @Test("displayAddress: 도로명 주소 없으면 지번 주소")
  func displayAddress_withoutRoadAddress_returnsAddress() {
    let coord = Coordinate(latitude: 37.5, longitude: 127.0)
    let place = Place(
      id: "p1",
      name: "장소",
      coordinate: coord,
      address: "지번 주소",
      roadAddress: nil
    )
    #expect(place.displayAddress == "지번 주소")
  }

  @Test("displayAddress: 둘 다 없으면 nil")
  func displayAddress_withNoAddress_returnsNil() {
    let coord = Coordinate(latitude: 37.5, longitude: 127.0)
    let place = Place(id: "p1", name: "장소", coordinate: coord)
    #expect(place.displayAddress == nil)
  }

  @Test("toLocationInfo: Place를 LocationInfoModel로 변환")
  func toLocationInfo_convertsCorrectly() {
    let coord = Coordinate(latitude: 37.5, longitude: 127.0)
    let place = Place(
      id: "p1",
      name: "카페",
      coordinate: coord,
      address: "지번",
      roadAddress: "도로명"
    )
    let locationInfo = place.toLocationInfo()

    #expect(locationInfo.name == "카페")
    #expect(locationInfo.address == "도로명")
    #expect(locationInfo.latitude == 37.5)
    #expect(locationInfo.longitude == 127.0)
  }
}

// MARK: - Proposal / ProposalStatus 테스트

@Suite("Proposal 및 ProposalStatus 테스트")
struct ProposalTests {

  @Test("Proposal 초기화 및 속성 확인")
  func init_setsProperties() {
    let proposal = Proposal(
      id: "prop-1",
      title: "점심 일정 제안",
      description: "같이 점심 먹을래요?",
      fromUserId: "from-user",
      toUserId: "to-user",
      scheduleId: "schedule-1",
      status: .pending
    )
    #expect(proposal.id == "prop-1")
    #expect(proposal.title == "점심 일정 제안")
    #expect(proposal.description == "같이 점심 먹을래요?")
    #expect(proposal.fromUserId == "from-user")
    #expect(proposal.toUserId == "to-user")
    #expect(proposal.scheduleId == "schedule-1")
    #expect(proposal.status == .pending)
  }

  @Test("ProposalStatus rawValue 올바름")
  func proposalStatus_rawValues() {
    #expect(ProposalStatus.pending.rawValue == "pending")
    #expect(ProposalStatus.accepted.rawValue == "accepted")
    #expect(ProposalStatus.declined.rawValue == "declined")
    #expect(ProposalStatus.expired.rawValue == "expired")
  }

  @Test("ProposalStatus allCases에 4개 포함")
  func proposalStatus_allCases() {
    #expect(ProposalStatus.allCases.count == 4)
  }
}
