//
//  CalendarSyncClient.swift
//  Clients
//
//  캘린더 동기화 클라이언트
//

import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Sync Result

/// 캘린더 동기화 결과
public struct CalendarSyncResult: Equatable, Sendable {
  public let added: Int
  public let updated: Int
  public let deleted: Int

  public init(added: Int = 0, updated: Int = 0, deleted: Int = 0) {
    self.added = added
    self.updated = updated
    self.deleted = deleted
  }

  public var hasChanges: Bool {
    added > 0 || updated > 0 || deleted > 0
  }

  public var description: String {
    var parts: [String] = []
    if added > 0 { parts.append("추가 \(added)") }
    if updated > 0 { parts.append("업데이트 \(updated)") }
    if deleted > 0 { parts.append("삭제 \(deleted)") }
    return parts.isEmpty ? "변경 없음" : parts.joined(separator: ", ")
  }
}

// MARK: - Sync Error

public enum CalendarSyncError: Error, Equatable, LocalizedError {
  case noWritePermission
  case fetchFailed(String)
  case syncFailed(String)

  public var errorDescription: String? {
    switch self {
    case .noWritePermission:
      return "캘린더 쓰기 권한이 없습니다"
    case .fetchFailed(let message):
      return "약속 조회 실패: \(message)"
    case .syncFailed(let message):
      return "동기화 실패: \(message)"
    }
  }
}

// MARK: - Client

@DependencyClient
public struct CalendarSyncClient: Sendable {
  /// 그룹 약속 전체 동기화 실행
  public var sync: @Sendable (_ enabledGroupIds: Set<String>) async throws -> CalendarSyncResult

  /// 단일 약속 캘린더에 추가 (실시간 확정 시)
  public var addPromise: @Sendable (
    _ promise: CalendarSyncPromise,
    _ groupCalendarSyncEnabled: Bool
  ) async throws -> Void

  /// 단일 약속 캘린더에서 제거 (거절 시)
  public var removePromise: @Sendable (_ promiseId: String) async throws -> Void

  /// 개인 일정 전체 동기화 실행
  public var syncPersonalEvents: @Sendable (_ enabled: Bool) async throws -> CalendarSyncResult

  /// 단일 개인 일정 캘린더에 추가
  public var addPersonalEvent: @Sendable (
    _ event: PersonalEventModel,
    _ calendarSyncEnabled: Bool
  ) async throws -> Void

  /// 단일 개인 일정 캘린더에서 제거
  public var removePersonalEvent: @Sendable (_ eventId: String) async throws -> Void

  /// 단일 개인 일정 캘린더 업데이트
  public var updatePersonalEvent: @Sendable (
    _ event: PersonalEventModel,
    _ calendarSyncEnabled: Bool
  ) async throws -> Void
}

// MARK: - Test / Preview

extension CalendarSyncClient: TestDependencyKey {
  public static let previewValue = Self(
    sync: { _ in CalendarSyncResult(added: 2, updated: 1, deleted: 0) },
    addPromise: { _, _ in },
    removePromise: { _ in },
    syncPersonalEvents: { _ in CalendarSyncResult() },
    addPersonalEvent: { _, _ in },
    removePersonalEvent: { _ in },
    updatePersonalEvent: { _, _ in }
  )

  public static let testValue = Self(
    sync: unimplemented("\(Self.self).sync", placeholder: CalendarSyncResult()),
    addPromise: unimplemented("\(Self.self).addPromise"),
    removePromise: unimplemented("\(Self.self).removePromise"),
    syncPersonalEvents: unimplemented("\(Self.self).syncPersonalEvents", placeholder: CalendarSyncResult()),
    addPersonalEvent: unimplemented("\(Self.self).addPersonalEvent"),
    removePersonalEvent: unimplemented("\(Self.self).removePersonalEvent"),
    updatePersonalEvent: unimplemented("\(Self.self).updatePersonalEvent")
  )
}

// MARK: - Live

extension CalendarSyncClient: DependencyKey {
  public static let liveValue = Self(
    sync: { enabledGroupIds in
      @Dependency(\.eventKitClient) var eventKitClient
      @Dependency(\.promiseClient) var promiseClient

      AppLogger.calendar.debug("🔄 [Sync] 시작 - enabledGroupIds: \(enabledGroupIds)")

      // 1. 쓰기 권한 확인
      let status = eventKitClient.authorizationStatus()
      AppLogger.calendar.debug("🔄 [Sync] 권한 상태: \(String(describing: status))")
      guard status.canWriteEvents else {
        AppLogger.calendar.error("🔄 [Sync] 쓰기 권한 없음")
        throw CalendarSyncError.noWritePermission
      }

        // 2. 서버에서 확정된 약속 조회
        let serverPromises: [CalendarSyncPromise]
        do {
          serverPromises = try await promiseClient.getConfirmedPromisesForCalendar()
          AppLogger.calendar.debug("🔄 [Sync] 서버 약속 조회: \(serverPromises.count)개")
        } catch {
          AppLogger.calendar.error("🔄 [Sync] 서버 약속 조회 실패: \(error.localizedDescription)")
          throw CalendarSyncError.fetchFailed(error.localizedDescription)
        }

        // 3. calendarSync 활성화된 그룹의 약속만 필터
        let filteredPromises = serverPromises.filter { enabledGroupIds.contains($0.groupId) }
        AppLogger.calendar.debug("🔄 [Sync] 필터링 후: \(filteredPromises.count)개")

        // 4. EventKit에서 기존 Promiso 이벤트 조회 (그룹 약속만)
        let existingEvents: [PromisoCalendarEvent]
        do {
          existingEvents = try await eventKitClient.getPromisoEvents()
            .filter { !$0.isPersonal }
          AppLogger.calendar.debug("🔄 [Sync] 기존 캘린더 이벤트: \(existingEvents.count)개")
          for event in existingEvents {
            AppLogger.calendar.debug("  - \(event.promiseId): hash=\(event.contentHash)")
          }
        } catch {
          AppLogger.calendar.error("🔄 [Sync] 기존 이벤트 조회 실패: \(error.localizedDescription)")
          throw CalendarSyncError.fetchFailed(error.localizedDescription)
        }

        // 5. 매핑 생성
        let serverPromiseMap = Dictionary(uniqueKeysWithValues: filteredPromises.map { ($0.id, $0) })
        let existingEventMap = Dictionary(uniqueKeysWithValues: existingEvents.map { ($0.promiseId, $0) })

        var addedCount = 0
        var updatedCount = 0
        var deletedCount = 0

        // 6. 추가/업데이트 처리
        for promise in filteredPromises {
          let url = PromisoCalendarTag.createURL(
            promiseId: promise.id,
            contentHash: promise.contentHash
          )

          let newEvent = NewCalendarEvent(
            promiseId: promise.id,
            title: promise.calendarTitle,
            startDate: promise.startAt,
            endDate: promise.endAt,
            location: promise.location,
            url: url
          )

          if let existing = existingEventMap[promise.id] {
            // 이미 존재 → 해시 비교하여 업데이트 필요 여부 확인
            if existing.contentHash != promise.contentHash {
              do {
                try await eventKitClient.updateEvent(
                  existing.eventIdentifier,
                  newEvent,
                  existing.userNotes
                )
                updatedCount += 1
              } catch {
                // 개별 업데이트 실패는 무시하고 계속 진행
                AppLogger.calendar.error("Event update failed: \(error.localizedDescription)")
              }
            }
            // 해시 같으면 skip
          } else {
            // 존재하지 않음 → 추가
            do {
              _ = try await eventKitClient.addEvent(newEvent)
              addedCount += 1
            } catch {
              AppLogger.calendar.error("Event add failed: \(error.localizedDescription)")
            }
          }
        }

        // 7. 삭제 처리 (캘린더에 있지만 서버에 없는 것)
        for existingEvent in existingEvents {
          if serverPromiseMap[existingEvent.promiseId] == nil {
            do {
              try await eventKitClient.deleteEvent(existingEvent.eventIdentifier)
              deletedCount += 1
            } catch {
              AppLogger.calendar.error("Event delete failed: \(error.localizedDescription)")
            }
          }
        }

        let result = CalendarSyncResult(
          added: addedCount,
          updated: updatedCount,
          deleted: deletedCount
        )

        AppLogger.calendar.info("Calendar sync completed: \(result.description)")

        return result
      },

      addPromise: { promise, groupCalendarSyncEnabled in
        @Dependency(\.eventKitClient) var eventKitClient

        AppLogger.calendar.debug("➕ [AddPromise] 시작 - promiseId: \(promise.id), groupSync: \(groupCalendarSyncEnabled)")

        // 그룹의 캘린더 동기화가 비활성화면 무시
        guard groupCalendarSyncEnabled else {
          AppLogger.calendar.debug("➕ [AddPromise] 그룹 동기화 비활성화 - 스킵")
          return
        }

        // 쓰기 권한 확인
        let status = eventKitClient.authorizationStatus()
        AppLogger.calendar.debug("➕ [AddPromise] 권한 상태: \(String(describing: status))")
        guard status.canWriteEvents else {
          AppLogger.calendar.debug("➕ [AddPromise] 쓰기 권한 없음 - 스킵")
          return
        }

        // 이미 추가되어 있는지 확인
        let existingEvents = try await eventKitClient.getPromisoEvents()
        AppLogger.calendar.debug("➕ [AddPromise] 기존 이벤트 수: \(existingEvents.count)")
        if existingEvents.contains(where: { $0.promiseId == promise.id && !$0.isPersonal }) {
          AppLogger.calendar.debug("➕ [AddPromise] 이미 존재함 - 스킵")
          return
        }

        // 캘린더에 추가
        let url = PromisoCalendarTag.createURL(
          promiseId: promise.id,
          contentHash: promise.contentHash
        )
        AppLogger.calendar.debug("➕ [AddPromise] URL 생성: \(String(describing: url))")

        let newEvent = NewCalendarEvent(
          promiseId: promise.id,
          title: promise.calendarTitle,
          startDate: promise.startAt,
          endDate: promise.endAt,
          location: promise.location,
          url: url
        )
        AppLogger.calendar.debug("➕ [AddPromise] 이벤트 생성 - promiseId: \(newEvent.promiseId)")

        let eventId = try await eventKitClient.addEvent(newEvent)
        AppLogger.calendar.info("➕ [AddPromise] 완료 - eventId: \(eventId)")
      },

      removePromise: { promiseId in
        @Dependency(\.eventKitClient) var eventKitClient

        AppLogger.calendar.debug("➖ [RemovePromise] 시작 - promiseId: \(promiseId)")

        // 쓰기 권한 확인
        let status = eventKitClient.authorizationStatus()
        AppLogger.calendar.debug("➖ [RemovePromise] 권한 상태: \(String(describing: status))")
        guard status.canWriteEvents else {
          AppLogger.calendar.debug("➖ [RemovePromise] 쓰기 권한 없음 - 스킵")
          return
        }

        // 해당 promiseId의 이벤트 찾기
        let existingEvents = try await eventKitClient.getPromisoEvents()
        AppLogger.calendar.debug("➖ [RemovePromise] 기존 이벤트 수: \(existingEvents.count)")
        guard let event = existingEvents.first(where: { $0.promiseId == promiseId && !$0.isPersonal }) else {
          AppLogger.calendar.debug("➖ [RemovePromise] 이벤트 없음 - 스킵")
          return
        }

        // 삭제
        AppLogger.calendar.debug("➖ [RemovePromise] 삭제 중: \(event.eventIdentifier)")
        try await eventKitClient.deleteEvent(event.eventIdentifier)
        AppLogger.calendar.info("➖ [RemovePromise] 완료 - promiseId: \(promiseId)")
      },

      // MARK: - Personal Event Sync

      syncPersonalEvents: { enabled in
        @Dependency(\.eventKitClient) var eventKitClient
        @Dependency(\.personalEventClient) var personalEventClient

        AppLogger.calendar.debug("🔄 [PersonalSync] 시작 - enabled: \(enabled)")

        // 1. 쓰기 권한 확인
        let status = eventKitClient.authorizationStatus()
        guard status.canWriteEvents else {
          AppLogger.calendar.debug("🔄 [PersonalSync] 쓰기 권한 없음 - 스킵")
          return CalendarSyncResult()
        }

        // 2. EventKit에서 기존 개인 일정 이벤트 조회
        let existingEvents = try await eventKitClient.getPromisoEvents()
          .filter { $0.isPersonal }
        AppLogger.calendar.debug("🔄 [PersonalSync] 기존 캘린더 이벤트: \(existingEvents.count)개")

        // 3. 동기화 비활성화 시 기존 이벤트 전부 삭제
        guard enabled else {
          var deletedCount = 0
          for event in existingEvents {
            do {
              try await eventKitClient.deleteEvent(event.eventIdentifier)
              deletedCount += 1
            } catch {
              AppLogger.calendar.error("🔄 [PersonalSync] 삭제 실패: \(error.localizedDescription)")
            }
          }
          let result = CalendarSyncResult(deleted: deletedCount)
          AppLogger.calendar.info("🔄 [PersonalSync] 비활성화 정리 완료 - \(result.description)")
          return result
        }

        // 4. 서버에서 활성 개인 일정 조회
        let serverEvents: [PersonalEventModel]
        do {
          serverEvents = try await personalEventClient.getActiveEvents(100)
          AppLogger.calendar.debug("🔄 [PersonalSync] 서버 일정 조회: \(serverEvents.count)개")
        } catch {
          AppLogger.calendar.error("🔄 [PersonalSync] 서버 일정 조회 실패: \(error.localizedDescription)")
          throw CalendarSyncError.fetchFailed(error.localizedDescription)
        }

        // 5. 매핑 생성
        let serverEventMap = Dictionary(uniqueKeysWithValues: serverEvents.map { ($0.id, $0) })
        let existingEventMap = Dictionary(uniqueKeysWithValues: existingEvents.map { ($0.promiseId, $0) })

        var addedCount = 0
        var updatedCount = 0
        var deletedCount = 0

        // 6. 추가/업데이트 처리
        for personalEvent in serverEvents {
          let url = PromisoCalendarTag.createPersonalURL(
            eventId: personalEvent.id,
            contentHash: personalEvent.contentHash
          )

          let newEvent = NewCalendarEvent(
            promiseId: personalEvent.id,
            title: personalEvent.calendarTitle,
            startDate: personalEvent.startAt,
            endDate: personalEvent.endAt,
            location: personalEvent.location?.name,
            url: url
          )

          if let existing = existingEventMap[personalEvent.id] {
            if existing.contentHash != personalEvent.contentHash {
              do {
                try await eventKitClient.updateEvent(
                  existing.eventIdentifier,
                  newEvent,
                  existing.userNotes
                )
                updatedCount += 1
              } catch {
                AppLogger.calendar.error("🔄 [PersonalSync] 업데이트 실패: \(error.localizedDescription)")
              }
            }
          } else {
            do {
              _ = try await eventKitClient.addEvent(newEvent)
              addedCount += 1
            } catch {
              AppLogger.calendar.error("🔄 [PersonalSync] 추가 실패: \(error.localizedDescription)")
            }
          }
        }

        // 7. 삭제 처리 (캘린더에 있지만 서버에 없는 것)
        for existingEvent in existingEvents {
          if serverEventMap[existingEvent.promiseId] == nil {
            do {
              try await eventKitClient.deleteEvent(existingEvent.eventIdentifier)
              deletedCount += 1
            } catch {
              AppLogger.calendar.error("🔄 [PersonalSync] 삭제 실패: \(error.localizedDescription)")
            }
          }
        }

        let result = CalendarSyncResult(
          added: addedCount,
          updated: updatedCount,
          deleted: deletedCount
        )
        AppLogger.calendar.info("🔄 [PersonalSync] 완료 - \(result.description)")
        return result
      },

      addPersonalEvent: { event, calendarSyncEnabled in
        @Dependency(\.eventKitClient) var eventKitClient

        AppLogger.calendar.debug("➕ [AddPersonal] 시작 - eventId: \(event.id)")

        guard calendarSyncEnabled else {
          AppLogger.calendar.debug("➕ [AddPersonal] 동기화 비활성화 - 스킵")
          return
        }

        let status = eventKitClient.authorizationStatus()
        guard status.canWriteEvents else {
          AppLogger.calendar.debug("➕ [AddPersonal] 쓰기 권한 없음 - 스킵")
          return
        }

        // 중복 확인
        let existingEvents = try await eventKitClient.getPromisoEvents()
        if existingEvents.contains(where: { $0.promiseId == event.id && $0.isPersonal }) {
          AppLogger.calendar.debug("➕ [AddPersonal] 이미 존재함 - 스킵")
          return
        }

        let url = PromisoCalendarTag.createPersonalURL(
          eventId: event.id,
          contentHash: event.contentHash
        )

        let newEvent = NewCalendarEvent(
          promiseId: event.id,
          title: event.calendarTitle,
          startDate: event.startAt,
          endDate: event.endAt,
          location: event.location?.name,
          url: url
        )

        let eventId = try await eventKitClient.addEvent(newEvent)
        AppLogger.calendar.info("➕ [AddPersonal] 완료 - eventId: \(eventId)")
      },

      removePersonalEvent: { eventId in
        @Dependency(\.eventKitClient) var eventKitClient

        AppLogger.calendar.debug("➖ [RemovePersonal] 시작 - eventId: \(eventId)")

        let status = eventKitClient.authorizationStatus()
        guard status.canWriteEvents else {
          AppLogger.calendar.debug("➖ [RemovePersonal] 쓰기 권한 없음 - 스킵")
          return
        }

        let existingEvents = try await eventKitClient.getPromisoEvents()
        guard let event = existingEvents.first(where: { $0.promiseId == eventId && $0.isPersonal }) else {
          AppLogger.calendar.debug("➖ [RemovePersonal] 이벤트 없음 - 스킵")
          return
        }

        try await eventKitClient.deleteEvent(event.eventIdentifier)
        AppLogger.calendar.info("➖ [RemovePersonal] 완료 - eventId: \(eventId)")
      },

      updatePersonalEvent: { event, calendarSyncEnabled in
        @Dependency(\.eventKitClient) var eventKitClient

        AppLogger.calendar.debug("🔄 [UpdatePersonal] 시작 - eventId: \(event.id)")

        guard calendarSyncEnabled else {
          AppLogger.calendar.debug("🔄 [UpdatePersonal] 동기화 비활성화 - 스킵")
          return
        }

        let status = eventKitClient.authorizationStatus()
        guard status.canWriteEvents else {
          AppLogger.calendar.debug("🔄 [UpdatePersonal] 쓰기 권한 없음 - 스킵")
          return
        }

        let url = PromisoCalendarTag.createPersonalURL(
          eventId: event.id,
          contentHash: event.contentHash
        )

        let newEvent = NewCalendarEvent(
          promiseId: event.id,
          title: event.calendarTitle,
          startDate: event.startAt,
          endDate: event.endAt,
          location: event.location?.name,
          url: url
        )

        let existingEvents = try await eventKitClient.getPromisoEvents()
        if let existing = existingEvents.first(where: { $0.promiseId == event.id && $0.isPersonal }) {
          // 기존 이벤트 업데이트
          try await eventKitClient.updateEvent(
            existing.eventIdentifier,
            newEvent,
            existing.userNotes
          )
          AppLogger.calendar.info("🔄 [UpdatePersonal] 업데이트 완료 - eventId: \(event.id)")
        } else {
          // 없으면 새로 추가
          _ = try await eventKitClient.addEvent(newEvent)
          AppLogger.calendar.info("🔄 [UpdatePersonal] 새로 추가 완료 - eventId: \(event.id)")
        }
      }
    )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var calendarSyncClient: CalendarSyncClient {
    get { self[CalendarSyncClient.self] }
    set { self[CalendarSyncClient.self] = newValue }
  }
}
