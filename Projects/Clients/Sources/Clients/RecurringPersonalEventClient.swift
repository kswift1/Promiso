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
    getAllEvents: { [.mock()] }
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
    let rustDataSource = RecurringPersonalEventRustDataSource(
      api: RustAPIClient()
    )

    return RecurringPersonalEventClient(
      createEvent: { event in
        guard !event.title.isEmpty else {
          throw RecurringPersonalEventClientError.invalidData(LocalizedStrings.Error.validationError)
        }
        return try await rustDataSource.createEvent(event)
      },
      updateEvent: { event in
        try await rustDataSource.updateEvent(event)
      },
      deleteEvent: { eventId in
        try await rustDataSource.deleteEvent(id: eventId)
      },
      getEvent: { eventId in
        return try await rustDataSource.getEvent(id: eventId)
      },
      getAllEvents: {
        return try await rustDataSource.getAllEvents()
      }
    )
  }()
}
