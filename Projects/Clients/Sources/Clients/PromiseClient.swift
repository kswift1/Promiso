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
import PromisoShared

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

  /// NSError를 PromiseClientError로 변환
  init(from error: Error) {
    let nsError = error as NSError
    let message = nsError.localizedDescription

    guard nsError.domain == "FIRFunctionsErrorDomain" else {
      self = .networkError
      return
    }

    switch nsError.code {
    case 16: self = .unauthorized
    case 3, 9: self = .invalidData(message)
    case 5: self = .groupNotFound
    case 7: self = .notGroupMember
    case 13: self = .serverError
    default: self = .unknown(message)
    }
  }
}

// MARK: - Client

/// TCA용 약속 클라이언트
/// Feature 레이어에 최적화된 API 제공
@DependencyClient
public struct PromiseClient: Sendable {
  /// 약속 생성
  public var createPromise: @Sendable (_ promise: PromiseModel) async throws -> String = { _ in "" }

  /// 약속 수정
  public var updatePromise: @Sendable (_ promise: PromiseModel) async throws -> Void

  /// 약속 삭제
  public var deletePromise: @Sendable (_ promiseId: String) async throws -> Void

  /// 약속 조회
  public var getPromise: @Sendable (_ promiseId: String) async throws -> PromiseModel?

  /// 오늘의 약속 조회 (사용자가 속한 그룹들의 약속)
  public var getTodayPromises: @Sendable (_ groupIds: [String]) async throws -> [PromiseModel]

  /// 다가오는 약속 조회 (사용자가 속한 그룹들의 약속)
  public var getUpcomingPromises: @Sendable (_ groupIds: [String], _ limit: Int) async throws -> [PromiseModel]

  /// 그룹의 활성 약속 조회
  public var getActivePromises: @Sendable (_ groupId: String, _ limit: Int) async throws -> [PromiseModel]

  /// 그룹의 과거 약속 조회 (커서 기반 페이징)
  public var getPastPromises: @Sendable (_ groupId: String, _ limit: Int, _ lastStartAt: Date?) async throws -> [PromiseModel]

  /// 그룹의 활성 약속 개수 조회
  public var getActivePromiseCount: @Sendable (_ groupId: String) async throws -> Int

  /// 날짜 범위로 약속 조회 (캘린더용, 사용자가 속한 그룹들의 약속)
  public var getPromisesByDateRange: @Sendable (
    _ groupIds: [String],
    _ startDate: Date,
    _ endDate: Date
  ) async throws -> [PromiseModel]

  /// 그룹의 활성 약속 실시간 구독
  public var subscribeToPromises: @Sendable (_ groupId: String, _ limit: Int) -> AsyncStream<[PromiseModel]> = { _, _ in AsyncStream { _ in } }

  /// 약속 응답
  public var respondPromise: @Sendable (_ promiseId: String, _ status: PromiseAttendanceStatus) async throws -> Void

  // MARK: - Live Activity

  /// LiveActivity 시작 요청 (백엔드에서 Push to Start APNs 전송)
  public var startLiveActivity: @Sendable (_ promiseId: String) async throws -> Void

  /// ETA 업데이트 요청 (백엔드에서 APNs 브로드캐스트)
  public var updateETA: @Sendable (_ promiseId: String, _ estimatedMinutes: Int) async throws -> Void

  /// LiveActivity 종료 요청
  public var endLiveActivity: @Sendable (_ promiseId: String) async throws -> Void
}

// MARK: - Test & Preview Values

extension PromiseClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    createPromise: { _ in
      try await Task.sleep(for: .seconds(1))
      return UUID().uuidString
    },
    updatePromise: { _ in
      try await Task.sleep(for: .seconds(1))
    },
    deletePromise: { _ in
      try await Task.sleep(for: .seconds(0.5))
    },
    getPromise: { _ in
      try await Task.sleep(for: .seconds(0.5))
      return nil
    },
    getTodayPromises: { _ in
      try await Task.sleep(for: .seconds(1))
      return []
    },
    getUpcomingPromises: { _, _ in
      try await Task.sleep(for: .seconds(1))
      return []
    },
    getActivePromises: { _, _ in
      try await Task.sleep(for: .seconds(1))
      return PromiseModel.examples
    },
    getPastPromises: { _, _, _ in
      try await Task.sleep(for: .seconds(1))
      return []
    },
    getActivePromiseCount: { _ in
      try await Task.sleep(for: .seconds(0.3))
      return 3
    },
    getPromisesByDateRange: { _, _, _ in
      try await Task.sleep(for: .seconds(0.5))
      return PromiseModel.examples
    },
    subscribeToPromises: { _, _ in
      AsyncStream { continuation in
        Task {
          try? await Task.sleep(for: .seconds(0.5))
          continuation.yield(PromiseModel.examples)
        }
      }
    },
    respondPromise: { _, _ in
      try await Task.sleep(for: .seconds(0.3))
    },
    startLiveActivity: { _ in
      try await Task.sleep(for: .seconds(0.5))
    },
    updateETA: { _, _ in
      try await Task.sleep(for: .seconds(0.3))
    },
    endLiveActivity: { _ in
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
    let dataSource: PromiseRemoteDataSourceProtocol = PromiseRemoteDataSource()

    return PromiseClient(
      createPromise: { promise in
        guard !promise.groupId.isEmpty else {
          throw PromiseClientError.invalidData(nil)
        }

        do {
          return try await dataSource.createPromise(promise)
        } catch {
          throw PromiseClientError(from: error)
        }
      },
      updatePromise: { promise in
        try await dataSource.updatePromise(promise)
      },
      deletePromise: { promiseId in
        try await dataSource.deletePromise(id: promiseId)
      },
      getPromise: { promiseId in
        try await dataSource.getPromise(id: promiseId)
      },
      getTodayPromises: { groupIds in
        try await dataSource.getTodayPromises(groupIds: groupIds)
      },
      getUpcomingPromises: { groupIds, limit in
        try await dataSource.getUpcomingPromises(groupIds: groupIds, limit: limit)
      },
      getActivePromises: { groupId, limit in
        try await dataSource.getActivePromises(groupId: groupId, limit: limit)
      },
      getPastPromises: { groupId, limit, lastStartAt in
        try await dataSource.getPastPromises(groupId: groupId, limit: limit, lastStartAt: lastStartAt)
      },
      getActivePromiseCount: { groupId in
        try await dataSource.getActivePromiseCount(groupId: groupId)
      },
      getPromisesByDateRange: { groupIds, startDate, endDate in
        try await dataSource.getPromisesByDateRange(groupIds: groupIds, startDate: startDate, endDate: endDate)
      },
      subscribeToPromises: { groupId, limit in
        dataSource.subscribeToActivePromises(groupId: groupId, limit: limit)
      },
      respondPromise: { promiseId, status in
        try await dataSource.respondToPromise(
          promiseId: promiseId,
          status: status.rawValue
        )
      },
      startLiveActivity: { promiseId in
        try await dataSource.startLiveActivity(promiseId: promiseId)
      },
      updateETA: { promiseId, estimatedMinutes in
        try await dataSource.updateETA(promiseId: promiseId, visibleMinutes: estimatedMinutes)
      },
      endLiveActivity: { promiseId in
        try await dataSource.endLiveActivity(promiseId: promiseId)
      }
    )
  }()
}

// MARK: - Example Data

extension PromiseModel {
  public static let examples: [PromiseModel] = [
    PromiseModel(
      id: "1",
      title: "카페 데이트",
      emoji: "☕",
      description: "오랜만에 만나서 수다 떨어요!",
      hostId: "user123",
      groupId: "group1",
      minimumParticipants: 2,
      votes: PromiseVotesModel(
        accepted: [],
        declined: [],
        until: Date().addingTimeInterval(10800)
      ),
      startAt: Date().addingTimeInterval(7200),
      location: LocationInfoModel(name: "스타벅스 강남점")
    ),
    PromiseModel(
      id: "2",
      title: "저녁 식사",
      emoji: "🍽️",
      description: "맛있는 파스타 먹으러 가요",
      hostId: "user456",
      groupId: "group1",
      minimumParticipants: 2,
      votes: PromiseVotesModel(
        accepted: ["user123", "user456"],
        declined: [],
        until: Date()
      ),
      startAt: Date().addingTimeInterval(18000),
      location: LocationInfoModel(name: "이탈리안 레스토랑")
    )
  ]
}
