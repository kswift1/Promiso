//
//  TestFactories.swift
//  Clients
//
//  테스트용 도메인 모델 팩토리 함수 모음
//
//  ## 사용처
//  - CalendarSyncClientTests
//  - PromiseModelValidationTests
//  - GroupMainStateTests
//  - 기타 Clients/Features 테스트
//
//  ## 사용법
//  ```swift
//  let promise = TestFactories.makePromise(title: "점심 약속")
//  let group = TestFactories.makeGroup(memberIds: ["user1", "user2"])
//  ```
//

import Foundation
import Testing
import PromisoShared

@testable import Clients

// MARK: - TestFactories

enum TestFactories {

  // MARK: - PromiseModel

  /// 테스트용 PromiseModel 생성
  ///
  /// 모든 파라미터에 기본값이 있어 필요한 것만 오버라이드 가능
  /// - Parameters:
  ///   - id: 약속 ID (기본: "test-promise-id")
  ///   - title: 제목 (기본: "테스트 약속")
  ///   - emoji: 이모지 (기본: nil)
  ///   - description: 설명 (기본: nil)
  ///   - hostId: 호스트 ID (기본: "host-id")
  ///   - groupId: 그룹 ID (기본: "group-id")
  ///   - group: 연결된 그룹 모델 (기본: nil)
  ///   - minimumParticipants: 최소 참가 인원 (기본: 2)
  ///   - votes: 투표 정보 (기본: 빈 투표)
  ///   - startAt: 시작 시간 (기본: 1시간 후)
  ///   - endAt: 종료 시간 (기본: nil)
  ///   - location: 위치 정보 (기본: nil)
  ///   - trackingStartMinutesBefore: LiveActivity 시작 시간 (기본: nil)
  ///   - createdAt: 생성 시각 (기본: 현재)
  ///   - updatedAt: 수정 시각 (기본: 현재)
  static func makePromise(
    id: String = "test-promise-id",
    title: String = "테스트 약속",
    emoji: String? = nil,
    description: String? = nil,
    hostId: String = "host-id",
    groupId: String = "group-id",
    group: GroupModel? = nil,
    minimumParticipants: Int = 2,
    votes: PromiseVotesModel = PromiseVotesModel(),
    startAt: Date = Date().addingTimeInterval(3600),
    endAt: Date? = nil,
    location: LocationInfoModel? = nil,
    trackingStartMinutesBefore: Int? = nil,
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) -> PromiseModel {
    PromiseModel(
      id: id,
      title: title,
      emoji: emoji,
      description: description,
      hostId: hostId,
      groupId: groupId,
      group: group,
      minimumParticipants: minimumParticipants,
      votes: votes,
      startAt: startAt,
      endAt: endAt,
      location: location,
      trackingStartMinutesBefore: trackingStartMinutesBefore,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  // MARK: - GroupModel

  /// 테스트용 GroupModel 생성
  ///
  /// - Parameters:
  ///   - id: 그룹 ID (기본: "group-id")
  ///   - name: 그룹 이름 (기본: "테스트 그룹")
  ///   - description: 설명 (기본: nil)
  ///   - imageUrl: 이미지 URL (기본: nil)
  ///   - memberIds: 멤버 ID 목록 (기본: ["user1", "user2"])
  ///   - maxMembers: 최대 인원 (기본: 10)
  ///   - inviteCode: 초대 코드 (기본: "ABC123")
  ///   - createdBy: 생성자 ID (기본: "host-id")
  ///   - createdAt: 생성 시각 (기본: 현재)
  ///   - updatedAt: 수정 시각 (기본: 현재)
  static func makeGroup(
    id: String = "group-id",
    name: String = "테스트 그룹",
    description: String? = nil,
    imageUrl: String? = nil,
    memberIds: [String] = ["user1", "user2"],
    maxMembers: Int = 10,
    inviteCode: String = "ABC123",
    createdBy: String = "host-id",
    createdAt: Date = Date(),
    updatedAt: Date = Date()
  ) -> GroupModel {
    GroupModel(
      id: id,
      name: name,
      description: description,
      imageUrl: imageUrl,
      memberIds: memberIds,
      maxMembers: maxMembers,
      inviteCode: inviteCode,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt
    )
  }

  // MARK: - UserPrivateModel (현재 사용자)

  /// 테스트용 UserPrivateModel (현재 사용자) 생성
  ///
  /// - Parameters:
  ///   - userId: 사용자 ID (기본: "current-user")
  ///   - name: 이름 (기본: "테스트")
  ///   - nickname: 닉네임 (기본: "테스트")
  ///   - email: 이메일 (기본: "test@example.com")
  ///   - provider: 인증 제공자 (기본: "iOS")
  ///   - profile: 프로필 이미지 (기본: nil)
  ///   - metadata: 메타데이터 (기본: 빈 Metadata)
  ///   - groups: 그룹 목록 (기본: [])
  static func makeCurrentUser(
    userId: String = "current-user",
    name: String = "테스트",
    nickname: String = "테스트",
    email: String = "test@example.com",
    provider: String = "iOS",
    profile: ProfileImage? = nil,
    metadata: Metadata = .init(),
    groups: [UserGroupInfo] = []
  ) -> UserPrivateModel {
    UserPrivateModel(
      userId: userId,
      name: name,
      nickname: nickname,
      email: email,
      provider: provider,
      profile: profile,
      metadata: metadata,
      groups: groups
    )
  }

  // MARK: - NotificationModel

  /// 테스트용 NotificationModel 생성
  ///
  /// - Parameters:
  ///   - notificationId: 알림 ID (기본: "test-notification-id")
  ///   - userId: 수신자 ID (기본: "current-user")
  ///   - type: 알림 카테고리 (기본: .promiseInvitation)
  ///   - title: 제목 (기본: "테스트 알림")
  ///   - body: 본문 (기본: "알림 내용입니다")
  ///   - promiseId: 관련 약속 ID (기본: nil)
  ///   - groupId: 관련 그룹 ID (기본: nil)
  ///   - relatedUserId: 발신자 ID (기본: nil)
  ///   - isRead: 읽음 여부 (기본: false)
  ///   - createdAt: 생성 시각 (기본: 현재)
  ///   - readAt: 읽은 시각 (기본: nil)
  static func makeNotification(
    notificationId: String = "test-notification-id",
    userId: String = "current-user",
    type: NotificationCategory = .promiseInvitation,
    title: String = "테스트 알림",
    body: String = "알림 내용입니다",
    promiseId: String? = nil,
    groupId: String? = nil,
    relatedUserId: String? = nil,
    isRead: Bool = false,
    createdAt: Date = Date(),
    readAt: Date? = nil
  ) -> NotificationModel {
    NotificationModel(
      notificationId: notificationId,
      userId: userId,
      type: type,
      title: title,
      body: body,
      promiseId: promiseId,
      groupId: groupId,
      relatedUserId: relatedUserId,
      isRead: isRead,
      createdAt: createdAt,
      readAt: readAt
    )
  }

  // MARK: - PromiseVotesModel

  /// 테스트용 PromiseVotesModel 생성
  ///
  /// - Parameters:
  ///   - accepted: 수락한 유저 ID 목록 (기본: [])
  ///   - declined: 거절한 유저 ID 목록 (기본: [])
  ///   - until: 투표 마감 시각 (기본: 30분 후)
  static func makeVotes(
    accepted: [String] = [],
    declined: [String] = [],
    until: Date = Date().addingTimeInterval(1800)
  ) -> PromiseVotesModel {
    PromiseVotesModel(
      accepted: accepted,
      declined: declined,
      until: until
    )
  }

  // MARK: - UserPublicModel

  /// 테스트용 UserPublicModel (타인 사용자) 생성
  ///
  /// - Parameters:
  ///   - userId: 사용자 ID (기본: "user-id")
  ///   - name: 이름 (기본: "사용자")
  ///   - nickname: 닉네임 (기본: "닉네임")
  ///   - profile: 프로필 이미지 (기본: nil)
  ///   - metadata: 메타데이터 (기본: 빈 Metadata)
  static func makePublicUser(
    userId: String = "user-id",
    name: String = "사용자",
    nickname: String = "닉네임",
    profile: ProfileImage? = nil,
    metadata: Metadata = .init()
  ) -> UserPublicModel {
    UserPublicModel(
      userId: userId,
      name: name,
      nickname: nickname,
      profile: profile,
      metadata: metadata
    )
  }

  // MARK: - UserGroupInfo

  /// 테스트용 UserGroupInfo 생성
  ///
  /// - Parameters:
  ///   - id: 그룹 ID (기본: "group-id")
  ///   - name: 그룹 이름 (기본: "테스트 그룹")
  ///   - role: 역할 (기본: nil)
  ///   - joinedAt: 가입 시각 (기본: nil)
  ///   - notifications: 알림 설정 (기본: nil)
  ///   - hasNewActivity: 새 활동 여부 (기본: false)
  ///   - imageUrl: 이미지 URL (기본: nil)
  static func makeUserGroupInfo(
    id: String = "group-id",
    name: String = "테스트 그룹",
    role: GroupRole? = nil,
    joinedAt: Date? = nil,
    notifications: GroupNotificationSettings? = nil,
    hasNewActivity: Bool = false,
    imageUrl: String? = nil
  ) -> UserGroupInfo {
    UserGroupInfo(
      id: id,
      name: name,
      role: role,
      joinedAt: joinedAt,
      notifications: notifications,
      hasNewActivity: hasNewActivity,
      imageUrl: imageUrl
    )
  }

  // MARK: - LocationInfoModel

  /// 테스트용 LocationInfoModel 생성
  ///
  /// - Parameters:
  ///   - name: 장소 이름 (기본: "테스트 장소")
  ///   - address: 주소 (기본: nil)
  ///   - latitude: 위도 (기본: nil)
  ///   - longitude: 경도 (기본: nil)
  static func makeLocation(
    name: String = "테스트 장소",
    address: String? = nil,
    latitude: Double? = nil,
    longitude: Double? = nil
  ) -> LocationInfoModel {
    LocationInfoModel(
      name: name,
      address: address,
      latitude: latitude,
      longitude: longitude
    )
  }
}
