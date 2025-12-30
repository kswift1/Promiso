//
//  GroupClient.swift
//  Clients
//
//  TCA Dependency Client for Group operations
//

import ComposableArchitecture
import Foundation

import Shared
import FirebaseAuth

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

  /// 특정 그룹 상세 정보 가져오기
  public var fetchGroup: @Sendable (_ groupId: String) async throws -> GroupModel

  /// 새 그룹 생성
  public var createGroup: @Sendable (_ request: CreateGroupRequest) async throws -> GroupCreationResult

  /// 그룹 나가기
  public var leaveGroup: @Sendable (_ groupId: String) async throws -> Void
}

// MARK: - Test & Preview Values

extension GroupClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    fetchGroups: {
      try await Task.sleep(for: .seconds(0.3))
      return [
        .init(id: "g1", emoji: "👥", title: "지민과 나", memberCount: 2),
        .init(id: "g2", emoji: "🏢", title: "회사 동료들", memberCount: 8),
        .init(id: "g3", emoji: "🎓", title: "대학 친구들", memberCount: 12),
        .init(id: "g4", emoji: "👨‍👩‍👦", title: "가족", memberCount: 4)
      ]
    },
    fetchGroup: { id in
      try await Task.sleep(for: .seconds(0.5))
      return GroupModel(id: id, emoji: "👞", title: "구두", memberCount: 3)
    },
    createGroup: { request in
      try await Task.sleep(for: .seconds(1))
      return GroupCreationResult(
        id: UUID().uuidString,
        name: request.name,
        inviteCode: "ABC123"
      )
    },
    leaveGroup: { _ in
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
  public static let liveValue = Self(
    fetchGroups: {
      guard let userId = Auth.auth().currentUser?.uid else {
        throw GroupClientError.unauthorized
      }

      let dataSource = GroupRemoteDataSource()
      return try await dataSource.fetchGroups(userId: userId)
    },
    fetchGroup: unimplemented("\(Self.self).fetchGroup"),
    createGroup: { request in
      let dataSource = GroupRemoteDataSource()

      return try await dataSource.createGroup(
        name: request.name,
        maxMembers: request.maxMembers,
        description: request.description,
        creatorId: request.creatorId,
        photoData: request.photoData
      )
    },
    leaveGroup: unimplemented("\(Self.self).leaveGroup")
  )
}
