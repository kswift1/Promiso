import ComposableArchitecture
import Foundation

// MARK: - Error

/// 그룹 API 에러
public enum GroupClientError: Error, Equatable {
  case networkError
  case unauthorized
  case notFound
  case serverError
  case unknown

  public var localizedDescription: String {
    switch self {
    case .networkError:
      return "네트워크 연결을 확인해주세요"
    case .unauthorized:
      return "로그인이 필요합니다"
    case .notFound:
      return "그룹을 찾을 수 없습니다"
    case .serverError:
      return "서버 오류가 발생했습니다"
    case .unknown:
      return "알 수 없는 오류가 발생했습니다"
    }
  }
}

// MARK: - Client

/// TCA용 그룹 클라이언트
@DependencyClient
public struct GroupClient: Sendable {
  /// 사용자의 그룹 목록 가져오기
  public var fetchGroups: @Sendable () async throws -> [GroupModel] = { [] }

  /// 네비게이션용 그룹 요약 목록 가져오기
  public var fetchGroupSummaries: @Sendable () async throws -> [UserGroupInfo] = { [] }

  /// 그룹 ID 목록으로 상세 그룹 가져오기
  public var fetchGroupsByIds: @Sendable (_ ids: [String]) async throws -> [GroupModel] = { _ in [] }

  /// 특정 그룹 상세 정보 가져오기
  public var fetchGroup: @Sendable (_ groupId: String) async throws -> GroupModel

  /// 그룹 멤버 목록 가져오기
  public var fetchGroupMembers: @Sendable (_ groupId: String) async throws -> [UserPublicModel]

  /// 새 그룹 생성
  public var createGroup: @Sendable (_ request: CreateGroupRequestModel) async throws -> GroupCreationResultModel

  /// 초대 코드로 그룹 미리보기
  public var previewGroup: @Sendable (_ inviteCode: String) async throws -> GroupPreviewModel

  /// 초대 코드로 그룹 참여
  public var joinGroup: @Sendable (_ inviteCode: String) async throws -> GroupModel

  /// 그룹 나가기
  public var leaveGroup: @Sendable (_ groupId: String) async throws -> Void

  /// 그룹 삭제 (호스트만 가능)
  public var deleteGroup: @Sendable (_ groupId: String) async throws -> Void
}

// MARK: - Test & Preview Values

extension GroupClient: TestDependencyKey {
  public static let testValue = Self(
    fetchGroups: unimplemented("\(Self.self).fetchGroups", placeholder: []),
    fetchGroupSummaries: unimplemented("\(Self.self).fetchGroupSummaries", placeholder: []),
    fetchGroupsByIds: unimplemented("\(Self.self).fetchGroupsByIds", placeholder: []),
    fetchGroup: unimplemented("\(Self.self).fetchGroup"),
    fetchGroupMembers: unimplemented("\(Self.self).fetchGroupMembers", placeholder: []),
    createGroup: unimplemented("\(Self.self).createGroup"),
    previewGroup: unimplemented("\(Self.self).previewGroup"),
    joinGroup: unimplemented("\(Self.self).joinGroup"),
    leaveGroup: unimplemented("\(Self.self).leaveGroup"),
    deleteGroup: unimplemented("\(Self.self).deleteGroup")
  )

  public static let previewValue = Self(
    fetchGroups: {
      try await Task.sleep(for: .seconds(0.3))
      return [
        .init(id: "g1", name: "지민과 나", maxMembers: 2, inviteCode: "ABC123", createdBy: "preview-user"),
        .init(id: "g2", name: "회사 동료들", maxMembers: 10, inviteCode: "DEF456", createdBy: "preview-user"),
        .init(id: "g3", name: "대학 친구들", maxMembers: 10, inviteCode: "GHI789", createdBy: "preview-user"),
        .init(id: "g4", name: "가족", maxMembers: 5, inviteCode: "JKL012", createdBy: "preview-user")
      ]
    },
    fetchGroupSummaries: {
      try await Task.sleep(for: .seconds(0.2))
      return [
        UserGroupInfo(id: "g1", name: "지민과 나", role: .admin, notifications: true, needResponseCount: 2, imageUrl: "https://picsum.photos/seed/g1/200"),
        UserGroupInfo(id: "g2", name: "회사 동료들", role: .member, notifications: true, needResponseCount: 1, imageUrl: "https://picsum.photos/seed/g2/200"),
        UserGroupInfo(id: "g3", name: "대학 친구들", role: .member, notifications: false, needResponseCount: 0, imageUrl: nil),
        UserGroupInfo(id: "g4", name: "가족", role: .member, notifications: true, needResponseCount: 3, imageUrl: "https://picsum.photos/seed/g4/200")
      ]
    },
    fetchGroupsByIds: { ids in
      try await Task.sleep(for: .seconds(0.2))
      return ids.map { id in
        GroupModel(id: id, name: "그룹 \(id)", maxMembers: 10, inviteCode: "PREVIEW", createdBy: "preview-user")
      }
    },
    fetchGroup: { id in
      try await Task.sleep(for: .seconds(0.5))
      return GroupModel(id: id, name: "구두", maxMembers: 5, inviteCode: "PREVIEW", createdBy: "preview-user")
    },
    fetchGroupMembers: { _ in
      try await Task.sleep(for: .seconds(0.3))
      return [
        UserPublicModel(
          userId: "u1",
          name: "김민수",
          nickname: "kms",
          profile: ProfileImage(url: "https://example.com/1.jpg", thumbUrl: nil, updatedAt: Date()),
          metadata: Metadata(createdAt: Date(), updatedAt: Date())
        ),
        UserPublicModel(
          userId: "u2",
          name: "이영희",
          nickname: "yhlee",
          profile: ProfileImage(url: "https://example.com/2.jpg", thumbUrl: nil, updatedAt: Date()),
          metadata: Metadata(createdAt: Date(), updatedAt: Date())
        ),
        UserPublicModel(
          userId: "u3",
          name: "박철수",
          nickname: "pcs",
          profile: ProfileImage(url: "https://example.com/3.jpg", thumbUrl: nil, updatedAt: Date()),
          metadata: Metadata(createdAt: Date(), updatedAt: Date())
        )
      ]
    },
    createGroup: { request in
      try await Task.sleep(for: .seconds(1))
      return GroupCreationResultModel(
        id: UUID().uuidString,
        name: request.name,
        inviteCode: "ABC123"
      )
    },
    previewGroup: { inviteCode in
      try await Task.sleep(for: .seconds(0.5))
      return GroupPreviewModel(
        group: GroupModel(
          id: UUID().uuidString,
          name: "주말 등산 모임",
          description: "매주 토요일마다 등산을 가는 모임입니다",
          maxMembers: 10,
          inviteCode: inviteCode,
          createdBy: "preview-user"
        ),
        members: [
          UserPublicModel(userId: "u1", name: "성원", nickname: "성원", metadata: Metadata(createdAt: Date(), updatedAt: Date())),
          UserPublicModel(userId: "u2", name: "지민", nickname: "지민", metadata: Metadata(createdAt: Date(), updatedAt: Date())),
          UserPublicModel(userId: "u3", name: "민수", nickname: "민수", metadata: Metadata(createdAt: Date(), updatedAt: Date())),
          UserPublicModel(userId: "u4", name: "서연", nickname: "서연", metadata: Metadata(createdAt: Date(), updatedAt: Date()))
        ]
      )
    },
    joinGroup: { inviteCode in
      try await Task.sleep(for: .seconds(1))
      return GroupModel(
        id: UUID().uuidString,
        name: "새 그룹",
        maxMembers: 10,
        inviteCode: inviteCode,
        createdBy: "preview-user"
      )
    },
    leaveGroup: { _ in
      try await Task.sleep(for: .seconds(0.5))
    },
    deleteGroup: { _ in
      try await Task.sleep(for: .seconds(0.5))
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var groupClient: GroupClient {
    get { self[GroupClient.self] }
    set { self[GroupClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension GroupClient: DependencyKey {
  public static let liveValue: GroupClient = {
    @Dependency(\.authClient) var authClient
    @Dependency(\.userProfileClient) var userProfileClient
    let dataSource = GroupRemoteDataSource()

    return Self(
      fetchGroups: {
        guard let currentUser = await authClient.currentUser() else {
          throw GroupClientError.unauthorized
        }

        return try await dataSource.fetchGroups(userId: currentUser.uid)
      },
      fetchGroupSummaries: {
        guard let currentUser = await authClient.currentUser() else {
          throw GroupClientError.unauthorized
        }

        return try await dataSource.fetchGroupSummaries(userId: currentUser.uid)
      },
      fetchGroupsByIds: { ids in
        return try await dataSource.fetchGroupsByIds(ids: ids)
      },
      fetchGroup: { groupId in
        return try await dataSource.fetchGroup(groupId: groupId)
      },
      fetchGroupMembers: { groupId in
        let group = try await dataSource.fetchGroup(groupId: groupId)
        return try await userProfileClient.getUsersByIds(group.memberIds)
      },
      createGroup: { request in
        return try await dataSource.createGroup(
          name: request.name,
          maxMembers: request.maxMembers,
          description: request.description,
          creatorId: request.creatorId,
          photoData: request.photoData
        )
      },
      previewGroup: { inviteCode in
        return try await dataSource.previewGroup(inviteCode: inviteCode)
      },
      joinGroup: { inviteCode in
        guard let currentUser = await authClient.currentUser() else {
          throw GroupClientError.unauthorized
        }

        return try await dataSource.joinGroup(inviteCode: inviteCode, userId: currentUser.uid)
      },
      leaveGroup: { groupId in
        try await dataSource.leaveGroup(groupId: groupId)
      },
      deleteGroup: { groupId in
        try await dataSource.deleteGroup(groupId: groupId)
      }
    )
  }()
}
