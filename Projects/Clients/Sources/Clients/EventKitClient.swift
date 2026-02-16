import ComposableArchitecture
import EventKit
import Foundation
import PromisoShared
import SwiftUI

// MARK: - Authorization Status

public enum CalendarAuthorizationStatus: Equatable, Sendable {
  case notDetermined
  case restricted
  case denied
  case fullAccess
  case writeOnly
  case authorized

  public var canReadEvents: Bool {
    switch self {
    case .fullAccess, .authorized:
      return true
    default:
      return false
    }
  }

  public var canWriteEvents: Bool {
    switch self {
    case .fullAccess, .writeOnly, .authorized:
      return true
    default:
      return false
    }
  }
}

// MARK: - Calendar Event Model

public struct CalendarEvent: Identifiable, Equatable, Sendable {
  public let id: String
  public let title: String
  public let startDate: Date
  public let endDate: Date
  public let location: String?
  public let isAllDay: Bool
  public let calendarName: String
  public let calendarColorHex: String

  public init(
    id: String,
    title: String,
    startDate: Date,
    endDate: Date,
    location: String?,
    isAllDay: Bool,
    calendarName: String,
    calendarColorHex: String
  ) {
    self.id = id
    self.title = title
    self.startDate = startDate
    self.endDate = endDate
    self.location = location
    self.isAllDay = isAllDay
    self.calendarName = calendarName
    self.calendarColorHex = calendarColorHex
  }

  // MARK: - Computed Properties

  public var calendarColor: Color {
    Color(hex: calendarColorHex) ?? .gray
  }

  public var timeText: String {
    if isAllDay {
      return "종일"
    }

    let start = LocalizedDateFormatters.time.string(from: startDate)
    let end = LocalizedDateFormatters.time.string(from: endDate)
    return "\(start) - \(end)"
  }
}

// MARK: - New Calendar Event (for adding)

/// 캘린더에 새로 추가할 이벤트 정보
public struct NewCalendarEvent: Equatable, Sendable {
  public let promiseId: String
  public let title: String
  public let startDate: Date
  public let endDate: Date?
  public let location: String?
  /// Promiso 식별 URL (promiso://promise/{id}?hash={hash})
  public let url: URL?

  public init(
    promiseId: String,
    title: String,
    startDate: Date,
    endDate: Date? = nil,
    location: String? = nil,
    url: URL? = nil
  ) {
    self.promiseId = promiseId
    self.title = title
    self.startDate = startDate
    self.endDate = endDate
    self.location = location
    self.url = url
  }
}

// MARK: - Client Error

public enum EventKitClientError: Error, Equatable, LocalizedError {
  case accessDenied
  case accessRestricted
  case writeNotAllowed
  case saveFailed(String)
  case eventStoreError(String)
  case unknown(String)

  public var errorDescription: String? {
    switch self {
    case .accessDenied:
      return "캘린더 접근이 거부되었습니다. 설정에서 권한을 허용해주세요."
    case .accessRestricted:
      return "캘린더 접근이 제한되어 있습니다."
    case .writeNotAllowed:
      return "캘린더 쓰기 권한이 없습니다."
    case .saveFailed(let message):
      return "캘린더 저장 실패: \(message)"
    case .eventStoreError(let message):
      return "캘린더 오류: \(message)"
    case .unknown(let message):
      return "알 수 없는 오류: \(message)"
    }
  }
}

// MARK: - Client

@DependencyClient
public struct EventKitClient: Sendable {
  /// 현재 권한 상태 확인
  public var authorizationStatus: @Sendable () -> CalendarAuthorizationStatus = { .notDetermined }

  /// 캘린더 접근 권한 요청 (읽기+쓰기)
  public var requestAccess: @Sendable () async throws -> Bool

  /// 특정 기간의 이벤트 가져오기
  public var fetchEvents: @Sendable (
    _ startDate: Date,
    _ endDate: Date
  ) async throws -> [CalendarEvent]

  /// 캘린더에 이벤트 추가 (약속 → 캘린더 동기화용)
  /// - Returns: 생성된 이벤트의 eventIdentifier
  public var addEvent: @Sendable (NewCalendarEvent) async throws -> String

  /// 캘린더 이벤트 업데이트
  public var updateEvent: @Sendable (
    _ eventIdentifier: String,
    _ newEvent: NewCalendarEvent,
    _ preserveUserNotes: String?
  ) async throws -> Void

  /// 캘린더 이벤트 삭제
  public var deleteEvent: @Sendable (_ eventIdentifier: String) async throws -> Void

  /// Promiso 태그가 있는 이벤트 조회 (미래 이벤트만)
  public var getPromisoEvents: @Sendable () async throws -> [PromisoCalendarEvent]

  /// 캘린더 변경 관찰 (이벤트 추가/수정/삭제 감지)
  public var observeChanges: @Sendable () -> AsyncStream<Void> = { AsyncStream { _ in } }

  /// 캘린더 설정 열기 (시스템 설정으로 이동)
  public var openSettings: @Sendable () async -> Void = { }
}

// MARK: - Test / Preview

extension EventKitClient: TestDependencyKey {
  public static let previewValue = Self(
    authorizationStatus: { .fullAccess },
    requestAccess: { true },
    fetchEvents: { startDate, _ in
      let calendar = Calendar.current
      return [
        CalendarEvent(
          id: "cal-1",
          title: "팀 미팅",
          startDate: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: startDate) ?? startDate,
          endDate: calendar.date(bySettingHour: 11, minute: 0, second: 0, of: startDate) ?? startDate,
          location: "회의실 A",
          isAllDay: false,
          calendarName: "업무",
          calendarColorHex: "#007AFF"
        ),
        CalendarEvent(
          id: "cal-2",
          title: "점심 약속",
          startDate: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: startDate) ?? startDate,
          endDate: calendar.date(bySettingHour: 13, minute: 30, second: 0, of: startDate) ?? startDate,
          location: nil,
          isAllDay: false,
          calendarName: "개인",
          calendarColorHex: "#34C759"
        )
      ]
    },
    addEvent: { event in
      return "preview-event-\(event.promiseId)"
    },
    updateEvent: { _, _, _ in },
    deleteEvent: { _ in },
    getPromisoEvents: { [] },
    observeChanges: { AsyncStream { _ in } },
    openSettings: { }
  )

  public static let testValue = Self(
    authorizationStatus: unimplemented("\(Self.self).authorizationStatus", placeholder: .notDetermined),
    requestAccess: unimplemented("\(Self.self).requestAccess", placeholder: false),
    fetchEvents: unimplemented("\(Self.self).fetchEvents", placeholder: []),
    addEvent: unimplemented("\(Self.self).addEvent", placeholder: ""),
    updateEvent: unimplemented("\(Self.self).updateEvent"),
    deleteEvent: unimplemented("\(Self.self).deleteEvent"),
    getPromisoEvents: unimplemented("\(Self.self).getPromisoEvents", placeholder: []),
    observeChanges: unimplemented("\(Self.self).observeChanges"),
    openSettings: unimplemented("\(Self.self).openSettings")
  )
}

// MARK: - Live

extension EventKitClient: DependencyKey {
  public static let liveValue: EventKitClient = {
    let eventStore = EKEventStore()

    return Self(
      authorizationStatus: {
        let status = EKEventStore.authorizationStatus(for: .event)
        return status.toCalendarAuthorizationStatus()
      },

      requestAccess: {
        if #available(iOS 17.0, *) {
          return try await eventStore.requestFullAccessToEvents()
        } else {
          return try await eventStore.requestAccess(to: .event)
        }
      },

      fetchEvents: { startDate, endDate in
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status.toCalendarAuthorizationStatus().canReadEvents else {
          throw EventKitClientError.accessDenied
        }

        let predicate = eventStore.predicateForEvents(
          withStart: startDate,
          end: endDate,
          calendars: nil
        )

        let events = eventStore.events(matching: predicate)

        // Promiso가 동기화한 이벤트 제외 (promiso:// URL 스킴)
        return events
          .filter { PromisoCalendarTag.parse(from: $0.url) == nil }
          .map { $0.toCalendarEvent() }
      },

      addEvent: { newEvent in
        // 1. 쓰기 권한 확인
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status.toCalendarAuthorizationStatus().canWriteEvents else {
          throw EventKitClientError.writeNotAllowed
        }

        // 2. 기본 캘린더 확인
        guard let defaultCalendar = eventStore.defaultCalendarForNewEvents else {
          throw EventKitClientError.saveFailed("기본 캘린더를 찾을 수 없습니다")
        }

        // 3. EKEvent 생성
        let event = EKEvent(eventStore: eventStore)
        event.title = newEvent.title
        event.startDate = newEvent.startDate
        event.endDate = newEvent.endDate ?? newEvent.startDate.addingTimeInterval(60 * 60)  // 1시간
        event.location = newEvent.location
        event.url = newEvent.url  // Promiso 식별 URL
        event.calendar = defaultCalendar

        // 4. 저장
        do {
          try eventStore.save(event, span: .thisEvent)
        } catch {
          throw EventKitClientError.saveFailed(error.localizedDescription)
        }

        // 6. eventIdentifier 반환
        guard let eventIdentifier = event.eventIdentifier else {
          throw EventKitClientError.saveFailed("이벤트 ID를 가져올 수 없습니다")
        }

        return eventIdentifier
      },

      updateEvent: { eventIdentifier, newEvent, preserveUserNotes in
        // 1. 쓰기 권한 확인
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status.toCalendarAuthorizationStatus().canWriteEvents else {
          throw EventKitClientError.writeNotAllowed
        }

        // 2. 기존 이벤트 조회
        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
          throw EventKitClientError.eventStoreError("이벤트를 찾을 수 없습니다")
        }

        // 3. 쓰기 가능한 캘린더인지 확인
        guard event.calendar?.allowsContentModifications == true else {
          throw EventKitClientError.writeNotAllowed
        }

        // 4. 이벤트 업데이트
        event.title = newEvent.title
        event.startDate = newEvent.startDate
        event.endDate = newEvent.endDate ?? newEvent.startDate.addingTimeInterval(60 * 60)  // 1시간
        event.location = newEvent.location
        event.url = newEvent.url  // Promiso 식별 URL 업데이트
        // notes는 사용자 메모이므로 건드리지 않음

        // 5. 저장
        do {
          try eventStore.save(event, span: .thisEvent)
        } catch {
          throw EventKitClientError.saveFailed(error.localizedDescription)
        }
      },

      deleteEvent: { eventIdentifier in
        // 1. 쓰기 권한 확인
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status.toCalendarAuthorizationStatus().canWriteEvents else {
          throw EventKitClientError.writeNotAllowed
        }

        // 2. 이벤트 조회
        guard let event = eventStore.event(withIdentifier: eventIdentifier) else {
          // 이미 삭제된 경우 성공으로 처리
          return
        }

        // 3. 쓰기 가능한 캘린더인지 확인
        guard event.calendar?.allowsContentModifications == true else {
          throw EventKitClientError.writeNotAllowed
        }

        // 4. 삭제
        do {
          try eventStore.remove(event, span: .thisEvent)
        } catch {
          throw EventKitClientError.saveFailed(error.localizedDescription)
        }
      },

      getPromisoEvents: {
        // 1. 읽기 권한 확인
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status.toCalendarAuthorizationStatus().canReadEvents else {
          throw EventKitClientError.accessDenied
        }

        // 2. 미래 1년간의 이벤트 조회
        let now = Date()
        let oneYearLater = Calendar.current.date(byAdding: .year, value: 1, to: now) ?? now

        let predicate = eventStore.predicateForEvents(
          withStart: now,
          end: oneYearLater,
          calendars: nil
        )

        let events = eventStore.events(matching: predicate)

        // 3. Promiso URL이 있는 이벤트만 필터링 및 파싱
        return events.compactMap { event -> PromisoCalendarEvent? in
          guard let eventId = event.eventIdentifier,
                let parsed = PromisoCalendarTag.parse(from: event.url) else {
            return nil
          }

          return PromisoCalendarEvent(
            eventIdentifier: eventId,
            promiseId: parsed.id,
            contentHash: parsed.contentHash,
            userNotes: event.notes,
            isPersonal: parsed.isPersonal
          )
        }
      },

      observeChanges: {
        AsyncStream { continuation in
          let observer = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
          ) { _ in
            continuation.yield(())
          }

          continuation.onTermination = { _ in
            NotificationCenter.default.removeObserver(observer)
          }
        }
      },

      openSettings: {
        await MainActor.run {
          if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
          }
        }
      }
    )
  }()
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var eventKitClient: EventKitClient {
    get { self[EventKitClient.self] }
    set { self[EventKitClient.self] = newValue }
  }
}

// MARK: - EKAuthorizationStatus Extension

private extension EKAuthorizationStatus {
  func toCalendarAuthorizationStatus() -> CalendarAuthorizationStatus {
    switch self {
    case .notDetermined:
      return .notDetermined
    case .restricted:
      return .restricted
    case .denied:
      return .denied
    case .fullAccess:
      return .fullAccess
    case .writeOnly:
      return .writeOnly
    case .authorized:
      return .authorized
    @unknown default:
      return .notDetermined
    }
  }
}

// MARK: - Constants

private enum EventKitConstants {
  static let untitledEvent = "제목 없음"
  static let defaultCalendarName = "캘린더"
  static let defaultColorHex = "#808080"
}

// MARK: - EKEvent Extension

private extension EKEvent {
  func toCalendarEvent() -> CalendarEvent {
    let colorHex: String
    if let cgColor = calendar?.cgColor {
      colorHex = UIColor(cgColor: cgColor).hexString
    } else {
      colorHex = EventKitConstants.defaultColorHex
    }

    return CalendarEvent(
      id: eventIdentifier ?? UUID().uuidString,
      title: title ?? EventKitConstants.untitledEvent,
      startDate: startDate,
      endDate: endDate,
      location: location,
      isAllDay: isAllDay,
      calendarName: calendar?.title ?? EventKitConstants.defaultCalendarName,
      calendarColorHex: colorHex
    )
  }
}

// MARK: - UIColor Hex Extension

private extension UIColor {
  var hexString: String {
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0

    getRed(&red, green: &green, blue: &blue, alpha: &alpha)

    return String(
      format: "#%02X%02X%02X",
      Int(red * 255),
      Int(green * 255),
      Int(blue * 255)
    )
  }
}

// MARK: - Color Hex Extension

private extension Color {
  init?(hex: String) {
    var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

    var rgb: UInt64 = 0
    guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

    let red = Double((rgb & 0xFF0000) >> 16) / 255.0
    let green = Double((rgb & 0x00FF00) >> 8) / 255.0
    let blue = Double(rgb & 0x0000FF) / 255.0

    self.init(red: red, green: green, blue: blue)
  }
}
