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

    let start = KoreanDateFormatters.time.string(from: startDate)
    let end = KoreanDateFormatters.time.string(from: endDate)
    return "\(start) - \(end)"
  }
}

// MARK: - Client Error

public enum EventKitClientError: Error, Equatable, LocalizedError {
  case accessDenied
  case accessRestricted
  case eventStoreError(String)
  case unknown(String)

  public var errorDescription: String? {
    switch self {
    case .accessDenied:
      return "캘린더 접근이 거부되었습니다. 설정에서 권한을 허용해주세요."
    case .accessRestricted:
      return "캘린더 접근이 제한되어 있습니다."
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

  /// 캘린더 접근 권한 요청
  public var requestAccess: @Sendable () async throws -> Bool

  /// 특정 기간의 이벤트 가져오기
  public var fetchEvents: @Sendable (
    _ startDate: Date,
    _ endDate: Date
  ) async throws -> [CalendarEvent]

  /// 캘린더 변경 관찰 (이벤트 추가/수정/삭제 감지)
  public var observeChanges: @Sendable () -> AsyncStream<Void> = { AsyncStream { _ in } }
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
    observeChanges: { AsyncStream { _ in } }
  )

  public static let testValue = Self(
    authorizationStatus: unimplemented("\(Self.self).authorizationStatus", placeholder: .notDetermined),
    requestAccess: unimplemented("\(Self.self).requestAccess", placeholder: false),
    fetchEvents: unimplemented("\(Self.self).fetchEvents", placeholder: []),
    observeChanges: unimplemented("\(Self.self).observeChanges")
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
        return events.map { $0.toCalendarEvent() }
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

// MARK: - EKEvent Extension

private extension EKEvent {
  func toCalendarEvent() -> CalendarEvent {
    let colorHex: String
    if let cgColor = calendar?.cgColor {
      colorHex = UIColor(cgColor: cgColor).hexString
    } else {
      colorHex = "#808080"
    }

    return CalendarEvent(
      id: eventIdentifier ?? UUID().uuidString,
      title: title ?? "제목 없음",
      startDate: startDate,
      endDate: endDate,
      location: location,
      isAllDay: isAllDay,
      calendarName: calendar?.title ?? "캘린더",
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
