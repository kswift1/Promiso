//
//  DTOMappingTests.swift
//  Clients
//
//  DTO -> Model 변환 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Data/DTOs/Responses/ScheduleDTO.swift`
//  - `Clients/Sources/Data/DTOs/Responses/NotificationDTO.swift`
//  - `Clients/Sources/Domain/Models/SupportingTypes.swift`
//
//  ## 테스트 목적
//  - DTO에서 도메인 모델로의 정확한 변환 검증
//  - 선택적 필드 nil 처리 검증
//  - Model -> DTO 역변환 검증
//

import Foundation
import Testing
@testable import Clients
import PromisoShared

// MARK: - ScheduleDTO -> ScheduleModel 변환 테스트

@Suite("ScheduleDTO -> ScheduleModel 변환 테스트")
struct ScheduleDTOToModelTests {

  @Test("모든 필드를 포함한 DTO에서 Model로 정확히 변환")
  func fullDTO_convertsToModelCorrectly() {
    let startDate = Date(timeIntervalSince1970: 1_700_000_000)
    let endDate = Date(timeIntervalSince1970: 1_700_003_600)
    let createdDate = Date(timeIntervalSince1970: 1_699_900_000)
    let updatedDate = Date(timeIntervalSince1970: 1_699_950_000)
    let votesUntil = Date(timeIntervalSince1970: 1_699_990_000)

    let dto = ScheduleDTO(
      title: "팀 회식",
      emoji: "🍻",
      description: "분기 회식입니다",
      hostId: "host-user",
      groupId: "group-1",
      minimumParticipants: 3,
      votes: VotesDTO(
        accepted: ["host-user", "user-2"],
        declined: ["user-3"],
        until: Timestamp(date: votesUntil)
      ),
      startAt: Timestamp(date: startDate),
      endAt: Timestamp(date: endDate),
      location: LocationDTO(
        name: "강남역 맛집",
        address: "서울시 강남구",
        latitude: 37.4979,
        longitude: 127.0276
      ),
      trackingStartMinutesBefore: 30,
      createdAt: Timestamp(date: createdDate),
      updatedAt: Timestamp(date: updatedDate)
    )

    let model = ScheduleModel(dto: dto, id: "schedule-123")

    #expect(model.id == "schedule-123")
    #expect(model.title == "팀 회식")
    #expect(model.emoji == "🍻")
    #expect(model.description == "분기 회식입니다")
    #expect(model.hostId == "host-user")
    #expect(model.groupId == "group-1")
    #expect(model.minimumParticipants == 3)
    #expect(model.votes.accepted == ["host-user", "user-2"])
    #expect(model.votes.declined == ["user-3"])
    #expect(model.location?.name == "강남역 맛집")
    #expect(model.location?.address == "서울시 강남구")
    #expect(model.location?.latitude == 37.4979)
    #expect(model.location?.longitude == 127.0276)
    #expect(model.trackingStartMinutesBefore == 30)
    #expect(model.group == nil) // DTO에서 변환 시 group은 항상 nil
  }

  @Test("선택적 필드가 nil인 DTO에서 Model로 변환")
  func minimalDTO_convertsWithNilOptionals() {
    let now = Date()
    let dto = ScheduleDTO(
      title: "간단 일정",
      emoji: nil,
      description: nil,
      hostId: "host-1",
      groupId: "g1",
      minimumParticipants: 2,
      votes: VotesDTO(until: Timestamp(date: now)),
      startAt: Timestamp(date: now),
      endAt: nil,
      location: nil,
      trackingStartMinutesBefore: nil,
      createdAt: Timestamp(date: now),
      updatedAt: Timestamp(date: now)
    )

    let model = ScheduleModel(dto: dto, id: "p-minimal")

    #expect(model.emoji == nil)
    #expect(model.description == nil)
    #expect(model.endAt == nil)
    #expect(model.location == nil)
    #expect(model.trackingStartMinutesBefore == nil)
  }
}

// MARK: - ScheduleModel -> ScheduleDTO 역변환 테스트

@Suite("ScheduleModel -> ScheduleDTO 역변환 테스트")
struct ScheduleModelToDTOTests {

  @Test("Model에서 DTO로 변환 시 모든 필드가 정확히 매핑")
  func model_convertsToDTOCorrectly() {
    let location = LocationInfoModel(
      name: "서울역",
      address: "서울시 용산구",
      latitude: 37.5547,
      longitude: 126.9706
    )
    let votes = ScheduleVotesModel(
      accepted: ["user-1", "user-2"],
      declined: ["user-3"],
      until: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let model = TestFactories.makeSchedule(
      title: "역변환 테스트",
      emoji: "🚂",
      description: "DTO 변환 검증용",
      hostId: "host-1",
      groupId: "g-1",
      minimumParticipants: 4,
      votes: votes,
      location: location,
      trackingStartMinutesBefore: 15
    )

    let dto = ScheduleDTO(model: model)

    #expect(dto.title == "역변환 테스트")
    #expect(dto.emoji == "🚂")
    #expect(dto.description == "DTO 변환 검증용")
    #expect(dto.hostId == "host-1")
    #expect(dto.groupId == "g-1")
    #expect(dto.minimumParticipants == 4)
    #expect(dto.votes.accepted == ["user-1", "user-2"])
    #expect(dto.votes.declined == ["user-3"])
    #expect(dto.location?.name == "서울역")
    #expect(dto.location?.address == "서울시 용산구")
    #expect(dto.location?.latitude == 37.5547)
    #expect(dto.location?.longitude == 126.9706)
    #expect(dto.trackingStartMinutesBefore == 15)
  }

  @Test("선택적 필드가 nil인 Model에서 DTO 변환")
  func model_nilOptionals_convertsToDTOWithNils() {
    let model = TestFactories.makeSchedule(
      emoji: nil,
      description: nil,
      location: nil,
      trackingStartMinutesBefore: nil
    )

    let dto = ScheduleDTO(model: model)

    #expect(dto.emoji == nil)
    #expect(dto.description == nil)
    #expect(dto.endAt == nil)
    #expect(dto.location == nil)
    #expect(dto.trackingStartMinutesBefore == nil)
  }
}

// MARK: - VotesDTO / LocationDTO 변환 테스트

@Suite("VotesDTO 및 LocationDTO 변환 테스트")
struct SupportingDTOConversionTests {

  @Test("VotesDTO에서 ScheduleVotesModel로 정확히 변환")
  func votesDTO_convertsToModel() {
    let until = Date(timeIntervalSince1970: 1_700_100_000)
    let dto = VotesDTO(
      accepted: ["a", "b", "c"],
      declined: ["d"],
      until: Timestamp(date: until)
    )

    let model = ScheduleVotesModel(dto: dto)

    #expect(model.accepted == ["a", "b", "c"])
    #expect(model.declined == ["d"])
    #expect(model.acceptedCount == 3)
    #expect(model.declinedCount == 1)
  }

  @Test("LocationDTO에서 LocationInfoModel로 정확히 변환")
  func locationDTO_convertsToModel() {
    let dto = LocationDTO(
      name: "카페",
      address: "서울시 마포구 연남동",
      latitude: 37.5665,
      longitude: 126.9780
    )

    let model = LocationInfoModel(dto: dto)

    #expect(model.name == "카페")
    #expect(model.address == "서울시 마포구 연남동")
    #expect(model.latitude == 37.5665)
    #expect(model.longitude == 126.9780)
  }

  @Test("LocationDTO 선택적 필드 nil 변환")
  func locationDTO_nilOptionals_convertsCorrectly() {
    let dto = LocationDTO(
      name: "미정 장소",
      address: nil,
      latitude: nil,
      longitude: nil
    )

    let model = LocationInfoModel(dto: dto)

    #expect(model.name == "미정 장소")
    #expect(model.address == nil)
    #expect(model.latitude == nil)
    #expect(model.longitude == nil)
  }

  @Test("LocationInfoModel에서 LocationDTO로 역변환")
  func locationModel_convertsToDTO() {
    let model = LocationInfoModel(
      name: "회의실",
      address: "강남구 테헤란로 427",
      latitude: 37.5046,
      longitude: 127.0495
    )

    let dto = LocationDTO(model: model)

    #expect(dto.name == "회의실")
    #expect(dto.address == "강남구 테헤란로 427")
    #expect(dto.latitude == 37.5046)
    #expect(dto.longitude == 127.0495)
  }

  @Test("ScheduleVotesModel에서 VotesDTO로 역변환")
  func votesModel_convertsToDTO() {
    let until = Date(timeIntervalSince1970: 1_700_200_000)
    let model = ScheduleVotesModel(
      accepted: ["x", "y"],
      declined: ["z"],
      until: until
    )

    let dto = VotesDTO(model: model)

    #expect(dto.accepted == ["x", "y"])
    #expect(dto.declined == ["z"])
    #expect(dto.until.dateValue().timeIntervalSince1970 == until.timeIntervalSince1970)
  }
}
