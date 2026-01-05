//
//  PromiseClient.swift
//  Clients
//
//  TCA Dependency Client for Promise operations
//  Acts as an adapter between Feature layer and Shared layer
//

import ComposableArchitecture
import Foundation
import Combine
import Shared

// MARK: - Error

/// 약속 API 에러
public enum PromiseClientError: Error, Equatable {
  case networkError
  case unauthorized
  case notFound
  case serverError
  case invalidData(String?)
  case groupNotFound
  case notGroupMember
  case unknown(String?)

  public var localizedDescription: String {
    switch self {
    case .networkError:
      return "네트워크 연결을 확인해주세요"
    case .unauthorized:
      return "로그인이 필요합니다"
    case .notFound:
      return "약속을 찾을 수 없습니다"
    case .serverError:
      return "서버 오류가 발생했습니다"
    case .invalidData(let message):
      return message ?? "잘못된 데이터입니다"
    case .groupNotFound:
      return "그룹을 찾을 수 없습니다"
    case .notGroupMember:
      return "그룹 멤버만 약속을 만들 수 있습니다"
    case .unknown(let message):
      return message ?? "알 수 없는 오류가 발생했습니다"
    }
  }
}

// MARK: - Client

/// TCA용 약속 클라이언트
/// Feature 레이어에 최적화된 API 제공
@DependencyClient
public struct PromiseClient: Sendable {
  /// 약속 생성
  public var createPromise: @Sendable (_ proposal: PromiseProposal, _ hostId: String) async throws -> String = { _, _ in "" }
  
  /// 약속 수정
  public var updatePromise: @Sendable (_ promiseId: String, _ proposal: PromiseProposal) async throws -> Void
  
  /// 약속 삭제
  public var deletePromise: @Sendable (_ promiseId: String) async throws -> Void
  
  /// 약속 조회
  public var getPromise: @Sendable (_ promiseId: String) async throws -> PromiseItem?
  
  /// 오늘의 약속 조회
  public var getTodayPromises: @Sendable (_ userId: String, _ groupId: String?) async throws -> [PromiseItem]
  
  /// 다가오는 약속 조회
  public var getUpcomingPromises: @Sendable (_ userId: String, _ limit: Int) async throws -> [PromiseItem]
  
  /// 그룹의 활성 약속 조회
  public var getActivePromises: @Sendable (_ groupId: String, _ limit: Int) async throws -> [PromiseItem]

  /// 약속 응답
  public var respondPromise: @Sendable (_ promiseId: String, _ status: PromiseAttendanceStatus) async throws -> Void
}

// MARK: - Test & Preview Values

extension PromiseClient: TestDependencyKey {
  public static let testValue = Self()
  
  public static let previewValue = Self(
    createPromise: { proposal, hostId in
      try await Task.sleep(for: .seconds(1))
      return UUID().uuidString
    },
    updatePromise: { promiseId, proposal in
      try await Task.sleep(for: .seconds(1))
    },
    deletePromise: { promiseId in
      try await Task.sleep(for: .seconds(0.5))
    },
    getPromise: { promiseId in
      try await Task.sleep(for: .seconds(0.5))
      return nil
    },
    getTodayPromises: { userId, groupId in
      try await Task.sleep(for: .seconds(1))
      return []
    },
    getUpcomingPromises: { userId, limit in
      try await Task.sleep(for: .seconds(1))
      return []
    },
    getActivePromises: {
      groupId,
      limit in
      try await Task.sleep(for: .seconds(1))
      return [
        .init(
          id: "",
          title: "",
          emoji: "",
          time: "",
          date: "",
          location: "",
          with: "",
          hostNickname: "",
          status: .needResponse,
          hostId: ""
        )
      ]
    },
    respondPromise: { _, _ in
      try await Task.sleep(for: .seconds(0.3))
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var promiseClient: PromiseClient {
    get { self[PromiseClient.self] }
    set { self[PromiseClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension PromiseClient: DependencyKey {
  public static let liveValue: PromiseClient = {
    let repository: PromiseRepositoryProtocol = PromiseRepository()

    return PromiseClient(
      createPromise: { proposal, hostId in
        guard let group = proposal.group else {
          throw PromiseClientError.invalidData(nil)
        }

        do {
          return try await repository.createPromise(
            proposal.toDomainModel(hostId: hostId, group: group),
            arrivalSharingTime: proposal.arrivalSharingTime
          )
        } catch let error as NSError {
          // Firebase Functions 에러 메시지 추출
          let errorMessage = error.localizedDescription
          print("error: \(errorMessage)")
          // Firebase Functions 에러를 PromiseClientError로 변환
          switch error.domain {
          case "FIRFunctionsErrorDomain":
            switch error.code {
            case 16: // unauthenticated
              throw PromiseClientError.unauthorized
            case 3, 9: // invalid-argument
              throw PromiseClientError.invalidData(errorMessage)
            case 5: // not-found
              throw PromiseClientError.groupNotFound
            case 7: // permission-denied
              throw PromiseClientError.notGroupMember
            case 13: // internal
              throw PromiseClientError.serverError
            default:
              throw PromiseClientError.unknown(errorMessage)
            }
          default:
            throw PromiseClientError.networkError
          }
        }
      },
      updatePromise: { _, _ in
        throw PromiseClientError.unknown(nil)
      },
      deletePromise: { promiseId in
        try await repository.deletePromise(id: promiseId)
      },
      getPromise: { _ in
        nil
      },
      getTodayPromises: { _, _ in
        []
      },
      getUpcomingPromises: { _, _ in
        []
      },
      getActivePromises: { groupId, limit in
        let promises = try await repository.getActivePromises(
          groupId: groupId,
          limit: limit
        )
        return promises.map { PromiseItem(domainModel: $0) }
      },
      respondPromise: { promiseId, status in
        try await repository.respondToPromise(
          promiseId: promiseId,
          status: status.rawValue
        )
      }
    )
  }()
}
