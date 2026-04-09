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

  // MARK: - Guide

  /// 캘린더 기능 가이드를 본 적 있는지
  var hasSeenCalendarGuide: Bool {
    boolForKey(AppConstants.UserDefaults.hasSeenCalendarGuide)
  }

  /// 캘린더 기능 가이드를 봤다고 표시
  func markCalendarGuideSeen() {
    setBool(true, AppConstants.UserDefaults.hasSeenCalendarGuide)
  }

  /// 홈 기능 가이드를 본 적 있는지
  var hasSeenHomeGuide: Bool {
    boolForKey(AppConstants.UserDefaults.hasSeenHomeGuide)
  }

  /// 홈 기능 가이드를 봤다고 표시
  func markHomeGuideSeen() {
    setBool(true, AppConstants.UserDefaults.hasSeenHomeGuide)
  }

  /// 일정 기능 가이드를 본 적 있는지
  var hasSeenScheduleGuide: Bool {
    boolForKey(AppConstants.UserDefaults.hasSeenScheduleGuide)
  }

  /// 일정 기능 가이드를 봤다고 표시
  func markScheduleGuideSeen() {
    setBool(true, AppConstants.UserDefaults.hasSeenScheduleGuide)
  }

  /// 설정 기능 가이드를 본 적 있는지
  var hasSeenSettingsGuide: Bool {
    boolForKey(AppConstants.UserDefaults.hasSeenSettingsGuide)
  }

  /// 설정 기능 가이드를 봤다고 표시
  func markSettingsGuideSeen() {
    setBool(true, AppConstants.UserDefaults.hasSeenSettingsGuide)
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
