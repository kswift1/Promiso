//
//  PersonalEventClient.swift
//  Clients
//
//  TCA Dependency Client for PersonalEvent operations
//  Acts as an adapter between Feature layer and Shared layer
//

import ComposableArchitecture
import FirebaseAuth
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
      return LocalizedStrings.Error.networkError
    case .unauthorized:
      return LocalizedStrings.Error.userAuthRequired
    case .notFound:
      return LocalizedStrings.Error.notFoundError
    case .serverError:
      return LocalizedStrings.Error.serverError
    case .invalidData(let message):
      return message ?? LocalizedStrings.Error.validationError
    case .forbidden:
      return LocalizedStrings.Error.permissionError
    case .unknown(let message):
      return message ?? LocalizedStrings.Error.unknownError
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

  /// 진행 중인 일정 조회
  public var getOngoingEvents: @Sendable (_ limit: Int) async throws -> [PersonalEventModel]

  /// 과거 일정 조회 (커서 기반 페이징)
  public var getPastEvents: @Sendable (_ limit: Int, _ lastStartAt: Date?) async throws -> [PersonalEventModel]

  /// 활성 일정 실시간 구독
  public var subscribeToActiveEvents: @Sendable (_ limit: Int) async -> AsyncStream<[PersonalEventModel]> = { _ in AsyncStream { _ in } }

  /// 날짜 범위로 개인 일정 조회 (일정 충돌 감지용)
  public var getEventsByDateRange: @Sendable (_ startDate: Date, _ endDate: Date) async throws -> [PersonalEventModel]
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
    getOngoingEvents: { _ in
      try await Task.sleep(for: .seconds(0.3))
      return []
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
    },
    getEventsByDateRange: { _, _ in
      try await Task.sleep(for: .seconds(0.3))
      return []
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
    @Dependency(\.featureFlags) var featureFlags
    let dataSource: PersonalEventRemoteDataSourceProtocol = PersonalEventRemoteDataSource()
    let rustDataSource = PersonalEventRustDataSource(
      api: RustAPIClient(
        getAuthToken: {
          guard let firebaseUser = Auth.auth().currentUser else {
            throw PersonalEventClientError.unauthorized
          }
          return try await firebaseUser.getIDToken()
        }
      )
    )

    return PersonalEventClient(
      createEvent: { event in
        guard !event.title.isEmpty else {
          throw PersonalEventClientError.invalidData(LocalizedStrings.Error.validationError)
        }
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.createEvent(event)
        } else {
          do {
            return try await dataSource.createEvent(event)
          } catch {
            throw PersonalEventClientError(from: error)
          }
        }
      },
      updateEvent: { event in
        if featureFlags.useRustAPI(.promises) {
          try await rustDataSource.updateEvent(event)
        } else {
          do {
            try await dataSource.updateEvent(event)
          } catch {
            throw PersonalEventClientError(from: error)
          }
        }
      },
      deleteEvent: { eventId in
        if featureFlags.useRustAPI(.promises) {
          try await rustDataSource.deleteEvent(id: eventId)
        } else {
          do {
            try await dataSource.deleteEvent(id: eventId)
          } catch {
            throw PersonalEventClientError(from: error)
          }
        }
      },
      getEvent: { eventId in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.getEvent(id: eventId)
        } else {
          do {
            return try await dataSource.getEvent(id: eventId)
          } catch {
            throw PersonalEventClientError(from: error)
          }
        }
      },
      getActiveEvents: { limit in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.getActiveEvents(limit: limit)
        } else {
          do {
            return try await dataSource.getActiveEvents(limit: limit)
          } catch {
            throw PersonalEventClientError(from: error)
          }
        }
      },
      getOngoingEvents: { limit in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.getOngoingEvents(limit: limit)
        } else {
          do {
            return try await dataSource.getOngoingEvents(limit: limit)
          } catch {
            throw PersonalEventClientError(from: error)
          }
        }
      },
      getPastEvents: { limit, lastStartAt in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.getPastEvents(limit: limit, lastStartAt: lastStartAt)
        } else {
          do {
            return try await dataSource.getPastEvents(limit: limit, lastStartAt: lastStartAt)
          } catch {
            throw PersonalEventClientError(from: error)
          }
        }
      },
      subscribeToActiveEvents: { limit in
        // Real-time listener: Firebase only (no Rust equivalent)
        await dataSource.subscribeToActiveEvents(limit: limit)
      },
      getEventsByDateRange: { startDate, endDate in
        if featureFlags.useRustAPI(.promises) {
          return try await rustDataSource.getEventsByDateRange(startDate: startDate, endDate: endDate)
        } else {
          do {
            return try await dataSource.getEventsByDateRange(startDate: startDate, endDate: endDate)
          } catch {
            throw PersonalEventClientError(from: error)
          }
        }
      }
    )
  }()
}
