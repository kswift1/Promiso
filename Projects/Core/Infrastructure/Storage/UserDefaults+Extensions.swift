import Foundation

// MARK: - UserDefaults Key Protocol

/// UserDefaults 키를 안전하게 관리하기 위한 프로토콜
public protocol UserDefaultsKey {
  associatedtype Value
  var key: String { get }
  var defaultValue: Value { get }
}

// MARK: - UserDefaults Storage

/// UserDefaults를 안전하게 사용하기 위한 래퍼
public struct UserDefaultsStorage: Sendable {
  private let userDefaults: UserDefaults
  
  public init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }
  
  public func get<Key: UserDefaultsKey>(_ key: Key) -> Key.Value {
    let value = userDefaults.object(forKey: key.key) as? Key.Value
    return value ?? key.defaultValue
  }
  
  public func set<Key: UserDefaultsKey>(_ value: Key.Value, for key: Key) {
    userDefaults.set(value, forKey: key.key)
  }
  
  public func remove<Key: UserDefaultsKey>(_ key: Key) {
    userDefaults.removeObject(forKey: key.key)
  }
  
  public func has<Key: UserDefaultsKey>(_ key: Key) -> Bool {
    userDefaults.object(forKey: key.key) != nil
  }
}

// MARK: - Codable UserDefaults Support

public extension UserDefaultsStorage {
  func getCodable<Key: UserDefaultsKey, T: Codable>(_ key: Key, type: T.Type) -> T? where Key.Value == Data? {
    guard let data = get(key) else { return nil }
    return try? JSONDecoder().decode(T.self, from: data)
  }
  
  func setCodable<Key: UserDefaultsKey, T: Codable>(_ value: T, for key: Key) where Key.Value == Data? {
    guard let data = try? JSONEncoder().encode(value) else { return }
    set(data, for: key)
  }
}

// MARK: - Common UserDefaults Keys

/// 앱에서 사용하는 공통 UserDefaults 키들
public enum AppUserDefaultsKeys {
  
  public struct IsFirstLaunch: UserDefaultsKey {
    public let key = "app.isFirstLaunch"
    public let defaultValue = true
  }
  
  public struct AppVersion: UserDefaultsKey {
    public let key = "app.version"
    public let defaultValue = ""
  }
  
  public struct UserId: UserDefaultsKey {
    public let key = "user.id"
    public let defaultValue: String? = nil
  }
  
  public struct UserEmail: UserDefaultsKey {
    public let key = "user.email"
    public let defaultValue: String? = nil
  }
  
  public struct AccessToken: UserDefaultsKey {
    public let key = "auth.accessToken"
    public let defaultValue: String? = nil
  }
  
  public struct RefreshToken: UserDefaultsKey {
    public let key = "auth.refreshToken"
    public let defaultValue: String? = nil
  }
  
  public struct NotificationEnabled: UserDefaultsKey {
    public let key = "settings.notificationEnabled"
    public let defaultValue = true
  }
  
  public struct ThemeMode: UserDefaultsKey {
    public let key = "settings.themeMode"
    public let defaultValue = "system" // "light", "dark", "system"
  }
  
  public struct Language: UserDefaultsKey {
    public let key = "settings.language"
    public let defaultValue = "ko"
  }
}

// MARK: - UserDefaults Dependency

/// TCA Dependency로 UserDefaults 등록
public struct UserDefaultsClient: Sendable {
  public var get: @Sendable (String) -> Any?
  public var set: @Sendable (Any?, String) -> Void
  public var remove: @Sendable (String) -> Void
  public var has: @Sendable (String) -> Bool
  
  public init(
    get: @escaping @Sendable (String) -> Any?,
    set: @escaping @Sendable (Any?, String) -> Void,
    remove: @escaping @Sendable (String) -> Void,
    has: @escaping @Sendable (String) -> Bool
  ) {
    self.get = get
    self.set = set
    self.remove = remove
    self.has = has
  }
}

// TODO: TCA Dependencies 라이브러리 통합 후 활성화
// extension UserDefaultsClient: DependencyKey {
//   public static let liveValue: UserDefaultsClient = {
//     let storage = UserDefaultsStorage()
//     return UserDefaultsClient(
//       get: { key in UserDefaults.standard.object(forKey: key) },
//       set: { value, key in UserDefaults.standard.set(value, forKey: key) },
//       remove: { key in UserDefaults.standard.removeObject(forKey: key) },
//       has: { key in UserDefaults.standard.object(forKey: key) != nil }
//     )
//   }()
//   
//   public static let testValue: UserDefaultsClient = {
//     var storage: [String: Any] = [:]
//     return UserDefaultsClient(
//       get: { key in storage[key] },
//       set: { value, key in 
//         if let value = value {
//           storage[key] = value
//         } else {
//           storage.removeValue(forKey: key)
//         }
//       },
//       remove: { key in storage.removeValue(forKey: key) },
//       has: { key in storage[key] != nil }
//     )
//   }()
// }

// extension DependencyValues {
//   public var userDefaults: UserDefaultsClient {
//     get { self[UserDefaultsClient.self] }
//     set { self[UserDefaultsClient.self] = newValue }
//   }
// }

// MARK: - Convenience Extensions

public extension UserDefaultsClient {
  func getString(_ key: String) -> String? {
    get(key) as? String
  }
  
  func getInt(_ key: String) -> Int {
    get(key) as? Int ?? 0
  }
  
  func getBool(_ key: String) -> Bool {
    get(key) as? Bool ?? false
  }
  
  func getDouble(_ key: String) -> Double {
    get(key) as? Double ?? 0.0
  }
  
  func getDate(_ key: String) -> Date? {
    get(key) as? Date
  }
  
  func getData(_ key: String) -> Data? {
    get(key) as? Data
  }
  
  func setString(_ value: String?, for key: String) {
    set(value, key)
  }
  
  func setInt(_ value: Int, for key: String) {
    set(value, key)
  }
  
  func setBool(_ value: Bool, for key: String) {
    set(value, key)
  }
  
  func setDouble(_ value: Double, for key: String) {
    set(value, key)
  }
  
  func setDate(_ value: Date?, for key: String) {
    set(value, key)
  }
  
  func setData(_ value: Data?, for key: String) {
    set(value, key)
  }
}
