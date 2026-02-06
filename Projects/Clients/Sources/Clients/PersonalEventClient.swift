//
//  PersonalEventClient.swift
//  Clients
//
//  TCA Dependency Client for PersonalEvent operations
//  Acts as an adapter between Feature layer and Shared layer
//

import ComposableArchitecture
import Foundation
import Combine
import PromisoShared

// MARK: - Error

/// 개인 일정 API 에러
public enum PersonalEventClientError: Error, Equatable {
  case networkError
  case unauthorized
  case notFound
  case serverError
  case invalidData(String?)
  case forbidden
  case unknown(String?)

  public var localizedDescription: String {
    switch self {
    case .networkError:
      return "네트워크 연결을 확인해주세요"
    case .unauthorized:
      return "로그인이 필요합니다"
    case .notFound:
      return "일정을 찾을 수 없습니다"
    case .serverError:
      return "서버 오류가 발생했습니다"
    case .invalidData(let message):
      return message ?? "잘못된 데이터입니다"
    case .forbidden:
      return "권한이 없습니다"
    case .unknown(let message):
      return message ?? "알 수 없는 오류가 발생했습니다"
    }
  }

  /// NSError를 PersonalEventClientError로 변환
  init(from error: Error) {
    let nsError = error as NSError
    let message = nsError.localizedDescription

    switch nsError.code {
    case 401: self = .unauthorized
    case 403: self = .forbidden
    case 404: self = .notFound
    case 500...599: self = .serverError
    default: self = .unknown(message)
    }
  }
}

// MARK: - Client

/// TCA용 개인 일정 클라이언트
/// Feature 레이어에 최적화된 API 제공
@DependencyClient
public struct PersonalEventClient: Sendable {
  /// 일정 생성
  public var createEvent: @Sendable (_ event: PersonalEventModel) async throws -> String = { _ in "" }

  /// 일정 수정
  public var updateEvent: @Sendable (_ event: PersonalEventModel) async throws -> Void

  /// 일정 삭제
  public var deleteEvent: @Sendable (_ eventId: String) async throws -> Void

  /// 일정 조회
  public var getEvent: @Sendable (_ eventId: String) async throws -> PersonalEventModel?

  /// 활성 일정 조회
  public var getActiveEvents: @Sendable (_ limit: Int) async throws -> [PersonalEventModel]

  /// 과거 일정 조회 (커서 기반 페이징)
  public var getPastEvents: @Sendable (_ limit: Int, _ lastStartAt: Date?) async throws -> [PersonalEventModel]

  /// 활성 일정 실시간 구독
  public var subscribeToActiveEvents: @Sendable (_ limit: Int) -> AsyncStream<[PersonalEventModel]> = { _ in AsyncStream { _ in } }
}

// MARK: - Test & Preview Values

extension PersonalEventClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    createEvent: { _ in
      try await Task.sleep(for: .seconds(1))
      return UUID().uuidString
    },
    updateEvent: { _ in
      try await Task.sleep(for: .seconds(1))
    },
    deleteEvent: { _ in
      try await Task.sleep(for: .seconds(0.5))
    },
    getEvent: { _ in
      try await Task.sleep(for: .seconds(0.5))
      return nil
    },
    getActiveEvents: { _ in
      try await Task.sleep(for: .seconds(1))
      return PersonalEventModel.activeExamples
    },
    getPastEvents: { _, _ in
      try await Task.sleep(for: .seconds(1))
      return PersonalEventModel.pastExamples
    },
    subscribeToActiveEvents: { _ in
      AsyncStream { continuation in
        Task {
          try? await Task.sleep(for: .seconds(0.5))
          continuation.yield(PersonalEventModel.activeExamples)
        }
      }
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var personalEventClient: PersonalEventClient {
    get { self[PersonalEventClient.self] }
    set { self[PersonalEventClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension PersonalEventClient: DependencyKey {
  public static let liveValue: PersonalEventClient = {
    let dataSource: PersonalEventRemoteDataSourceProtocol = PersonalEventRemoteDataSource()

    return PersonalEventClient(
      createEvent: { event in
        guard !event.title.isEmpty else {
          throw PersonalEventClientError.invalidData("제목이 비어있습니다")
        }

        do {
          return try await dataSource.createEvent(event)
        } catch {
          throw PersonalEventClientError(from: error)
        }
      },
      updateEvent: { event in
        do {
          try await dataSource.updateEvent(event)
        } catch {
          throw PersonalEventClientError(from: error)
        }
      },
      deleteEvent: { eventId in
        do {
          try await dataSource.deleteEvent(id: eventId)
        } catch {
          throw PersonalEventClientError(from: error)
        }
      },
      getEvent: { eventId in
        do {
          return try await dataSource.getEvent(id: eventId)
        } catch {
          throw PersonalEventClientError(from: error)
        }
      },
      getActiveEvents: { limit in
        do {
          return try await dataSource.getActiveEvents(limit: limit)
        } catch {
          throw PersonalEventClientError(from: error)
        }
      },
      getPastEvents: { limit, lastStartAt in
        do {
          return try await dataSource.getPastEvents(limit: limit, lastStartAt: lastStartAt)
        } catch {
          throw PersonalEventClientError(from: error)
        }
      },
      subscribeToActiveEvents: { limit in
        dataSource.subscribeToActiveEvents(limit: limit)
      }
    )
  }()
}
