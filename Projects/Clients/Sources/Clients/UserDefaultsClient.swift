import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Client

public struct UserDefaultsClient: Sendable {
  public var boolForKey: @Sendable (String) -> Bool
  public var setBool: @Sendable (Bool, String) -> Void
  public var stringForKey: @Sendable (String) -> String?
  public var setString: @Sendable (String?, String) -> Void
  public var intForKey: @Sendable (String) -> Int
  public var setInt: @Sendable (Int, String) -> Void
  public var remove: @Sendable (String) -> Void
}

// MARK: - Convenience Methods

public extension UserDefaultsClient {
  /// 실시간 공유 정보 팝오버를 본 적 있는지
  var hasSeenLiveActivityInfo: Bool {
    boolForKey(AppConstants.UserDefaults.hasSeenLiveActivityInfo)
  }

  /// 실시간 공유 정보 팝오버를 봤다고 표시
  func markLiveActivityInfoSeen() {
    setBool(true, AppConstants.UserDefaults.hasSeenLiveActivityInfo)
  }
}

// MARK: - Calendar Sync Convenience Methods

public extension UserDefaultsClient {
  /// 캘린더 이벤트 매핑 조회 (promiseId → eventIdentifier)
  func getCalendarEventMappings() -> [String: String] {
    guard let data = UserDefaults.standard.data(forKey: AppConstants.UserDefaults.calendarEventMappings),
          let mappings = try? JSONDecoder().decode([String: String].self, from: data) else {
      return [:]
    }
    return mappings
  }

  /// 캘린더 이벤트 매핑 저장
  func saveCalendarEventMapping(promiseId: String, eventIdentifier: String) {
    var mappings = getCalendarEventMappings()
    mappings[promiseId] = eventIdentifier
    if let data = try? JSONEncoder().encode(mappings) {
      UserDefaults.standard.set(data, forKey: AppConstants.UserDefaults.calendarEventMappings)
    }
  }

  /// 특정 약속이 캘린더에 추가되었는지 확인
  func isAddedToCalendar(promiseId: String) -> Bool {
    getCalendarEventMappings()[promiseId] != nil
  }

  /// 오늘 캘린더 동기화를 했는지 확인
  func hasCalendarSyncedToday() -> Bool {
    guard let lastSyncDate = UserDefaults.standard.object(
      forKey: AppConstants.UserDefaults.lastCalendarSyncDate
    ) as? Date else {
      return false
    }
    return Calendar.current.isDateInToday(lastSyncDate)
  }

  /// 캘린더 동기화 완료 표시
  func setCalendarSyncedToday() {
    UserDefaults.standard.set(Date(), forKey: AppConstants.UserDefaults.lastCalendarSyncDate)
  }
}

// MARK: - Test / Preview

extension UserDefaultsClient: TestDependencyKey {
  public static let previewValue = Self(
    boolForKey: { _ in false },
    setBool: { _, _ in },
    stringForKey: { _ in nil },
    setString: { _, _ in },
    intForKey: { _ in 0 },
    setInt: { _, _ in },
    remove: { _ in }
  )

  public static let testValue = Self(
    boolForKey: unimplemented("\(Self.self).boolForKey", placeholder: false),
    setBool: unimplemented("\(Self.self).setBool"),
    stringForKey: unimplemented("\(Self.self).stringForKey", placeholder: nil),
    setString: unimplemented("\(Self.self).setString"),
    intForKey: unimplemented("\(Self.self).intForKey", placeholder: 0),
    setInt: unimplemented("\(Self.self).setInt"),
    remove: unimplemented("\(Self.self).remove")
  )
}

// MARK: - Live

extension UserDefaultsClient: DependencyKey {
  public static let liveValue = Self(
    boolForKey: { key in
      UserDefaults.standard.bool(forKey: key)
    },
    setBool: { value, key in
      UserDefaults.standard.set(value, forKey: key)
    },
    stringForKey: { key in
      UserDefaults.standard.string(forKey: key)
    },
    setString: { value, key in
      if let value {
        UserDefaults.standard.set(value, forKey: key)
      } else {
        UserDefaults.standard.removeObject(forKey: key)
      }
    },
    intForKey: { key in
      UserDefaults.standard.integer(forKey: key)
    },
    setInt: { value, key in
      UserDefaults.standard.set(value, forKey: key)
    },
    remove: { key in
      UserDefaults.standard.removeObject(forKey: key)
    }
  )
}

// MARK: - Dependency Registration

public extension DependencyValues {
  var userDefaultsClient: UserDefaultsClient {
    get { self[UserDefaultsClient.self] }
    set { self[UserDefaultsClient.self] = newValue }
  }
}
