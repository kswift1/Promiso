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

  /// UserDefaults 영속화용 키
  public var persistKey: String {
    switch self {
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    case .denied: return "denied"
    case .fullAccess: return "fullAccess"
    case .writeOnly: return "writeOnly"
    case .authorized: return "authorized"
    }
  }

  /// persistKey로부터 복원
  public init?(persistKey: String) {
    switch persistKey {
    case "notDetermined": self = .notDetermined
    case "restricted": self = .restricted
    case "denied": self = .denied
    case "fullAccess": self = .fullAccess
    case "writeOnly": self = .writeOnly
    case "authorized": self = .authorized
    default: return nil
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

  /// 숫자·기호 이모지(#⃣, *⃣ 등)를 제외하고 그림 이모지만 필터링하기 위한 유니코드 스칼라 기준값
  private static let pictorialEmojiThreshold: UInt32 = 0x238C

  /// 제목에서 첫 번째 이모지를 추출, 없으면 nil
  public var displayEmoji: String? {
    for character in title {
      if character.unicodeScalars.first?.properties.isEmoji == true,
         character.unicodeScalars.first?.value ?? 0 > Self.pictorialEmojiThreshold {
        return String(character)
      }
    }
    return nil
  }

  /// 이모지를 제거한 제목 (첫 번째 이모지만 제거)
  public var displayTitle: String {
    guard let emoji = displayEmoji,
          let range = title.range(of: emoji) else { return title }
    return title
      .replacingCharacters(in: range, with: "")
      .trimmingCharacters(in: .whitespaces)
  }

  public var timeText: String {
    if isAllDay {
      return LocalizedStrings.Common.allDay
    }

    let calendar = Calendar.current
    if calendar.isDate(startDate, inSameDayAs: endDate) {
      let start = LocalizedDateFormatters.time.string(from: startDate)
      let end = LocalizedDateFormatters.time.string(from: endDate)
      return "\(start) ~ \(end)"
    } else {
      return "\(LocalizedDateFormatters.monthDayTimeString(from: startDate)) ~ \(LocalizedDateFormatters.monthDayTimeString(from: endDate))"
    }
  }
}

// MARK: - New Calendar Event (for adding)

/// 캘린더에 새로 추가할 이벤트 정보
public struct NewCalendarEvent: Equatable, Sendable {
  public let scheduleId: String
  public let title: String
  public let startDate: Date
  public let endDate: Date?
  public let location: String?
  /// Promiso 식별 URL (promiso://schedule/{id}?hash={hash})
  public let url: URL?

  public init(
    scheduleId: String,
    title: String,
    startDate: Date,
    endDate: Date? = nil,
    location: String? = nil,
    url: URL? = nil
  ) {
    self.scheduleId = scheduleId
    self.title = title
    self.startDate = startDate
    self.endDate = endDate
    self.location = location
    self.url = url
  }
}

// MARK: - Client Error

public enum EventKitClientError: Error, Equatable {
  case accessDenied
  case accessRestricted
  case writeNotAllowed
  case saveFailed(String)
  case eventStoreError(String)
  case unknown(String)
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

  /// 캘린더에 이벤트 추가 (일정 → 캘린더 동기화용)
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

  /// Promiso 태그가 있는 이벤트 조회 (오늘 시작~1년 후)
  public var getPromisoEvents: @Sendable () async throws -> [PromisoCalendarEvent]

  /// 과거 Promiso 이벤트 중복 정리 (마이그레이션용)
  /// - Returns: 삭제된 중복 이벤트 수
  public var cleanupPastDuplicates: @Sendable (_ daysBack: Int) async throws -> Int

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
          title: "점심 일정",
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
      return "preview-event-\(event.scheduleId)"
    },
    updateEvent: { _, _, _ in },
    deleteEvent: { _ in },
    getPromisoEvents: { [] },
    cleanupPastDuplicates: { _ in 0 },
    observeChanges: { AsyncStream { _ in } },
    openSettings: { }
  )

  public static let testValue: Self = Self(
    authorizationStatus: { .notDetermined },
    requestAccess: { false },
    fetchEvents: { _, _ in [] },
    addEvent: { _ in "" },
    updateEvent: { _, _, _ in },
    deleteEvent: { _ in },
    getPromisoEvents: { [] },
    cleanupPastDuplicates: { _ in 0 },
    observeChanges: { AsyncStream { _ in } },
    openSettings: { }
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
        // 공휴일 구독 캘린더 이벤트 제외 (Nager.Date API로 별도 표시)
        return events
          .filter { event in
            // Promiso 동기화 이벤트 제외 (모든 환경: promiso/promiso-dev/promiso-stage)
            guard !PromisoCalendarTag.isAnyPromisoURL(event.url) else { return false }
            // 공휴일 구독 캘린더 제외
            if event.calendar?.type == .subscription {
              let title = event.calendar?.title.lowercased() ?? ""
              if title.contains("holiday") || title.contains("공휴일") {
                return false
              }
            }
            return true
          }
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
          throw EventKitClientError.saveFailed(LocalizedStrings.Error.calendarSaveFailed)
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
          throw EventKitClientError.saveFailed(LocalizedStrings.Error.calendarSaveFailed)
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
          throw EventKitClientError.eventStoreError(LocalizedStrings.Error.calendarStoreError)
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

        // 2. 오늘 시작~1년 후 이벤트 조회
        // Firestore getActiveEvents(startAt >= startOfToday)와 동일 기준
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let oneYearLater = Calendar.current.date(byAdding: .year, value: 1, to: startOfToday) ?? startOfToday

        let predicate = eventStore.predicateForEvents(
          withStart: startOfToday,
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
            scheduleId: parsed.id,
            contentHash: parsed.contentHash,
            userNotes: event.notes,
            isPersonal: parsed.isPersonal
          )
        }
      },

      cleanupPastDuplicates: { daysBack in
        // 1. 읽기 권한 확인
        let status = EKEventStore.authorizationStatus(for: .event)
        guard status.toCalendarAuthorizationStatus().canReadEvents else {
          throw EventKitClientError.accessDenied
        }

        // 2. 과거 N일 ~ 오늘 시작 범위 검색
        let now = Date()
        let startOfToday = Calendar.current.startOfDay(for: now)
        guard let pastDate = Calendar.current.date(byAdding: .day, value: -daysBack, to: now) else {
          return 0
        }

        let predicate = eventStore.predicateForEvents(
          withStart: pastDate,
          end: startOfToday,
          calendars: nil
        )
        let events = eventStore.events(matching: predicate)

        // 3. Promiso URL이 있는 이벤트를 scheduleId별로 그룹핑
        var grouped: [String: [EKEvent]] = [:]
        for event in events {
          guard let parsed = PromisoCalendarTag.parse(from: event.url) else { continue }
          let key = "\(parsed.id)-\(parsed.isPersonal)"
          grouped[key, default: []].append(event)
        }

        // 4. 중복 삭제 (그룹별 첫 번째만 유지)
        var deletedCount = 0
        for (_, duplicateEvents) in grouped where duplicateEvents.count > 1 {
          for event in duplicateEvents.dropFirst() {
            guard event.calendar?.allowsContentModifications == true else { continue }
            do {
              try eventStore.remove(event, span: .thisEvent)
              deletedCount += 1
            } catch {
              AppLogger.calendar.error("🧹 [Cleanup] 중복 삭제 실패: \(error.localizedDescription)")
            }
          }
        }

        return deletedCount
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
  static let untitledEvent = LocalizedStrings.Common.untitled
  static let defaultCalendarName = LocalizedStrings.TabBar.calendar
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
