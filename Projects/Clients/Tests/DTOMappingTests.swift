//
//  DTOMappingTests.swift
//  Clients
//
//  DTO -> Model 변환 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Data/DTOs/Responses/PromiseDTO.swift`
//  - `Clients/Sources/Data/DTOs/Responses/GroupDTO.swift`
//  - `Clients/Sources/Data/DTOs/Responses/UserDTO.swift`
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

// MARK: - PromiseDTO -> PromiseModel 변환 테스트

@Suite("PromiseDTO -> PromiseModel 변환 테스트")
struct PromiseDTOToModelTests {

  @Test("모든 필드를 포함한 DTO에서 Model로 정확히 변환")
  func fullDTO_convertsToModelCorrectly() {
    let startDate = Date(timeIntervalSince1970: 1_700_000_000)
    let endDate = Date(timeIntervalSince1970: 1_700_003_600)
    let createdDate = Date(timeIntervalSince1970: 1_699_900_000)
    let updatedDate = Date(timeIntervalSince1970: 1_699_950_000)
    let votesUntil = Date(timeIntervalSince1970: 1_699_990_000)

    let dto = PromiseDTO(
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

    let model = PromiseModel(dto: dto, id: "promise-123")

    #expect(model.id == "promise-123")
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
    let dto = PromiseDTO(
      title: "간단 약속",
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

    let model = PromiseModel(dto: dto, id: "p-minimal")

    #expect(model.emoji == nil)
    #expect(model.description == nil)
    #expect(model.endAt == nil)
    #expect(model.location == nil)
    #expect(model.trackingStartMinutesBefore == nil)
  }
}

// MARK: - PromiseModel -> PromiseDTO 역변환 테스트

@Suite("PromiseModel -> PromiseDTO 역변환 테스트")
struct PromiseModelToDTOTests {

  @Test("Model에서 DTO로 변환 시 모든 필드가 정확히 매핑")
  func model_convertsToDTOCorrectly() {
    let location = LocationInfoModel(
      name: "서울역",
      address: "서울시 용산구",
      latitude: 37.5547,
      longitude: 126.9706
    )
    let votes = PromiseVotesModel(
      accepted: ["user-1", "user-2"],
      declined: ["user-3"],
      until: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let model = TestFactories.makePromise(
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

    let dto = PromiseDTO(model: model)

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
    let model = TestFactories.makePromise(
      emoji: nil,
      description: nil,
      location: nil,
      trackingStartMinutesBefore: nil
    )

    let dto = PromiseDTO(model: model)

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

  @Test("VotesDTO에서 PromiseVotesModel로 정확히 변환")
  func votesDTO_convertsToModel() {
    let until = Date(timeIntervalSince1970: 1_700_100_000)
    let dto = VotesDTO(
      accepted: ["a", "b", "c"],
      declined: ["d"],
      until: Timestamp(date: until)
    )

    let model = PromiseVotesModel(dto: dto)

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

  @Test("PromiseVotesModel에서 VotesDTO로 역변환")
  func votesModel_convertsToDTO() {
    let until = Date(timeIntervalSince1970: 1_700_200_000)
    let model = PromiseVotesModel(
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

// MARK: - UserDTO -> UserPrivateModel 변환 테스트

@Suite("UserDTO -> UserPrivateModel 변환 테스트")
struct UserDTOToModelTests {

  @Test("모든 필드를 포함한 UserDTO에서 UserPrivateModel로 변환")
  func fullUserDTO_convertsToModel() {
    let createdSeconds: TimeInterval = 1_700_000_000
    let updatedSeconds: TimeInterval = 1_700_100_000
    let joinedSeconds: TimeInterval = 1_700_050_000

    let dto = UserDTO(
      userId: "user-123",
      name: "김테스트",
      nickname: "테스트닉",
      email: "test@example.com",
      provider: "google",
      metaData: UserDTO.MetadataDTO(
        createdAt: UserDTO.FirebaseTimestampDTO(_seconds: createdSeconds, _nanoseconds: nil),
        updatedAt: UserDTO.FirebaseTimestampDTO(_seconds: updatedSeconds, _nanoseconds: nil)
      ),
      profile: UserDTO.ProfileImageDTO(
        url: "https://example.com/photo.jpg",
        thumbUrl: "https://example.com/thumb.jpg",
        updatedAt: UserDTO.FirebaseTimestampDTO(_seconds: updatedSeconds, _nanoseconds: nil)
      ),
      groups: [
        "g1": UserDTO.UserGroupInfoDTO(
          groupName: "친구들",
          role: .admin,
          joinedAt: UserDTO.FirebaseTimestampDTO(_seconds: joinedSeconds, _nanoseconds: nil),
          notifications: GroupNotificationSettings(enabled: true),
          hasNewActivity: true,
          imageUrl: "https://example.com/group.jpg"
        )
      ]
    )

    let model = dto.toModel()

    #expect(model.userId == "user-123")
    #expect(model.name == "김테스트")
    #expect(model.nickname == "테스트닉")
    #expect(model.email == "test@example.com")
    #expect(model.provider == "google")
    #expect(model.profile?.url == "https://example.com/photo.jpg")
    #expect(model.profile?.thumbUrl == "https://example.com/thumb.jpg")
    #expect(model.groups.count == 1)
    #expect(model.groups.first?.name == "친구들")
    #expect(model.groups.first?.role == .admin)
    #expect(model.groups.first?.hasNewActivity == true)
  }

  @Test("프로필이 nil이거나 <null>인 경우 profile이 nil로 변환")
  func userDTO_nullProfile_convertsToNilProfile() {
    let dto = UserDTO(
      userId: "user-no-profile",
      name: "프로필없음",
      nickname: "없음",
      email: nil,
      provider: nil,
      metaData: UserDTO.MetadataDTO(
        createdAt: UserDTO.FirebaseTimestampDTO(_seconds: 1_700_000_000, _nanoseconds: nil),
        updatedAt: UserDTO.FirebaseTimestampDTO(_seconds: 1_700_000_000, _nanoseconds: nil)
      ),
      profile: nil,
      groups: nil
    )

    let model = dto.toModel()

    #expect(model.profile == nil)
    #expect(model.email == "") // nil email -> 빈 문자열
    #expect(model.provider == "") // nil provider -> 빈 문자열
    #expect(model.groups.isEmpty)
  }

  @Test("ProfileImageDTO의 url이 '<null>'이면 profile nil로 변환")
  func userDTO_profileUrlNull_convertsToNilProfile() {
    let dto = UserDTO(
      userId: "user-null-url",
      name: "널URL",
      nickname: "널닉",
      email: "x@x.com",
      provider: "apple",
      metaData: UserDTO.MetadataDTO(
        createdAt: UserDTO.FirebaseTimestampDTO(_seconds: 1_700_000_000, _nanoseconds: nil),
        updatedAt: UserDTO.FirebaseTimestampDTO(_seconds: 1_700_000_000, _nanoseconds: nil)
      ),
      profile: UserDTO.ProfileImageDTO(
        url: "<null>",
        thumbUrl: nil,
        updatedAt: UserDTO.FirebaseTimestampDTO(_seconds: 1_700_000_000, _nanoseconds: nil)
      ),
      groups: nil
    )

    let model = dto.toModel()

    // ProfileImageDTO.isValid는 url != "<null>"을 체크
    #expect(model.profile == nil)
  }
}

// MARK: - FirebaseTimestampDTO 테스트

@Suite("FirebaseTimestampDTO date 변환 테스트")
struct FirebaseTimestampDTOTests {

  @Test("seconds만 있는 경우 정확한 Date 변환")
  func secondsOnly_convertsToCorrectDate() {
    let timestamp = UserDTO.FirebaseTimestampDTO(
      _seconds: 1_700_000_000,
      _nanoseconds: nil
    )
    let expected = Date(timeIntervalSince1970: 1_700_000_000)
    #expect(timestamp.date == expected)
  }

  @Test("seconds + nanoseconds가 있는 경우 정확한 Date 변환")
  func secondsAndNanoseconds_convertsToCorrectDate() {
    let timestamp = UserDTO.FirebaseTimestampDTO(
      _seconds: 1_700_000_000,
      _nanoseconds: 500_000_000 // 0.5초
    )
    let expected = Date(timeIntervalSince1970: 1_700_000_000.5)
    #expect(timestamp.date == expected)
  }
}
