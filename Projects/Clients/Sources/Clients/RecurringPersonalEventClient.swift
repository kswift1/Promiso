//
//  RecurringPersonalEventClient.swift
//  Clients
//
//  TCA Dependency Client for RecurringPersonalEvent operations
//

import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Error

/// 반복 개인 일정 API 에러
public enum RecurringPersonalEventClientError: Error, Equatable {
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
      return "반복 일정을 찾을 수 없습니다"
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

  /// NSError를 RecurringPersonalEventClientError로 변환
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

/// TCA용 반복 개인 일정 클라이언트
@DependencyClient
public struct RecurringPersonalEventClient: Sendable {
  /// 반복 일정 생성
  public var createEvent: @Sendable (_ event: RecurringPersonalEventModel) async throws -> String = { _ in "" }

  /// 반복 일정 수정
  public var updateEvent: @Sendable (_ event: RecurringPersonalEventModel) async throws -> Void

  /// 반복 일정 삭제
  public var deleteEvent: @Sendable (_ eventId: String) async throws -> Void

  /// 반복 일정 단건 조회
  public var getEvent: @Sendable (_ eventId: String) async throws -> RecurringPersonalEventModel?

  /// 반복 일정 전체 조회
  public var getAllEvents: @Sendable () async throws -> [RecurringPersonalEventModel]

  /// 반복 일정 전체 실시간 구독
  public var subscribeToAllEvents: @Sendable () async -> AsyncStream<[RecurringPersonalEventModel]> = { AsyncStream { _ in } }
}

// MARK: - Test & Preview Values

extension RecurringPersonalEventClient: TestDependencyKey {
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
    getEvent: { _ in nil },
    getAllEvents: { [.mock()] },
    subscribeToAllEvents: {
      AsyncStream { continuation in
        Task {
          try? await Task.sleep(for: .seconds(0.5))
          continuation.yield([.mock()])
        }
      }
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var recurringPersonalEventClient: RecurringPersonalEventClient {
    get { self[RecurringPersonalEventClient.self] }
    set { self[RecurringPersonalEventClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension RecurringPersonalEventClient: DependencyKey {
  public static let liveValue: RecurringPersonalEventClient = {
    let dataSource: RecurringPersonalEventRemoteDataSourceProtocol = RecurringPersonalEventRemoteDataSource()

    return RecurringPersonalEventClient(
      createEvent: { event in
        guard !event.title.isEmpty else {
          throw RecurringPersonalEventClientError.invalidData("제목이 비어있습니다")
        }
        do {
          return try await dataSource.createEvent(event)
        } catch {
          throw RecurringPersonalEventClientError(from: error)
        }
      },
      updateEvent: { event in
        do {
          try await dataSource.updateEvent(event)
        } catch {
          throw RecurringPersonalEventClientError(from: error)
        }
      },
      deleteEvent: { eventId in
        do {
          try await dataSource.deleteEvent(id: eventId)
        } catch {
          throw RecurringPersonalEventClientError(from: error)
        }
      },
      getEvent: { eventId in
        do {
          return try await dataSource.getEvent(id: eventId)
        } catch {
          throw RecurringPersonalEventClientError(from: error)
        }
      },
      getAllEvents: {
        do {
          return try await dataSource.getAllEvents()
        } catch {
          throw RecurringPersonalEventClientError(from: error)
        }
      },
      subscribeToAllEvents: {
        await dataSource.subscribeToAllEvents()
      }
    )
  }()
}
