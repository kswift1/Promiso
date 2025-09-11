import Foundation
import Security
import CoreDependencies
import ComposableArchitecture

// MARK: - Keychain Error

/// 키체인 관련 오류
public enum KeychainError: Error, LocalizedError {
  case noData
  case unexpectedData
  case unhandledError(status: OSStatus)
  case invalidData
  
  public var errorDescription: String? {
    switch self {
    case .noData:
      return "키체인에서 데이터를 찾을 수 없습니다"
    case .unexpectedData:
      return "예상하지 못한 데이터 형식입니다"
    case .unhandledError(let status):
      return "키체인 오류 (코드: \(status))"
    case .invalidData:
      return "잘못된 데이터입니다"
    }
  }
}

// MARK: - Keychain Storage

/// 키체인을 안전하게 사용하기 위한 래퍼
public struct KeychainStorage: Sendable {
  private let service: String
  
  public init(service: String = Bundle.main.bundleIdentifier ?? "com.promiso.app") {
    self.service = service
  }
  
  /// 키체인에 데이터 저장
  public func set(_ data: Data, for key: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    ]
    
    // 기존 항목 삭제
    SecItemDelete(query as CFDictionary)
    
    // 새 항목 추가
    let status = SecItemAdd(query as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw KeychainError.unhandledError(status: status)
    }
  }
  
  /// 키체인에서 데이터 조회
  public func get(_ key: String) throws -> Data {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne
    ]
    
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    guard status == errSecSuccess else {
      if status == errSecItemNotFound {
        throw KeychainError.noData
      } else {
        throw KeychainError.unhandledError(status: status)
      }
    }
    
    guard let data = result as? Data else {
      throw KeychainError.unexpectedData
    }
    
    return data
  }
  
  /// 키체인에서 데이터 삭제
  public func delete(_ key: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key
    ]
    
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.unhandledError(status: status)
    }
  }
  
  /// 키체인에 데이터가 존재하는지 확인
  public func exists(_ key: String) -> Bool {
    do {
      _ = try get(key)
      return true
    } catch {
      return false
    }
  }
  
  /// 모든 키체인 데이터 삭제
  public func deleteAll() throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service
    ]
    
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.unhandledError(status: status)
    }
  }
}

// MARK: - String Support

public extension KeychainStorage {
  /// 문자열 저장
  func setString(_ string: String, for key: String) throws {
    guard let data = string.data(using: .utf8) else {
      throw KeychainError.invalidData
    }
    try set(data, for: key)
  }
  
  /// 문자열 조회
  func getString(_ key: String) throws -> String {
    let data = try get(key)
    guard let string = String(data: data, encoding: .utf8) else {
      throw KeychainError.unexpectedData
    }
    return string
  }
}

// MARK: - Codable Support

public extension KeychainStorage {
  /// Codable 객체 저장
  func setCodable<T: Codable>(_ object: T, for key: String) throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(object)
    try set(data, for: key)
  }
  
  /// Codable 객체 조회
  func getCodable<T: Codable>(_ key: String, type: T.Type) throws -> T {
    let data = try get(key)
    let decoder = JSONDecoder()
    return try decoder.decode(type, from: data)
  }
}

// MARK: - Keychain Dependency

/// TCA Dependency로 Keychain 등록
public struct KeychainClient: Sendable {
  public var set: @Sendable (Data, String) async throws -> Void
  public var get: @Sendable (String) async throws -> Data
  public var delete: @Sendable (String) async throws -> Void
  public var exists: @Sendable (String) async -> Bool
  public var deleteAll: @Sendable () async throws -> Void
  
  // String 편의 메서드들
  public var setString: @Sendable (String, String) async throws -> Void
  public var getString: @Sendable (String) async throws -> String?
  
  public init(
    set: @escaping @Sendable (Data, String) async throws -> Void,
    get: @escaping @Sendable (String) async throws -> Data,
    delete: @escaping @Sendable (String) async throws -> Void,
    exists: @escaping @Sendable (String) async -> Bool,
    deleteAll: @escaping @Sendable () async throws -> Void,
    setString: @escaping @Sendable (String, String) async throws -> Void,
    getString: @escaping @Sendable (String) async throws -> String
  ) {
    self.set = set
    self.get = get
    self.delete = delete
    self.exists = exists
    self.deleteAll = deleteAll
    self.setString = setString
    self.getString = getString
  }
}

extension KeychainClient: DependencyKey {
  public static let liveValue: KeychainClient = {
    let storage = KeychainStorage()
    
    return KeychainClient(
      set: { data, key in
        try storage.set(data, for: key)
      },
      get: { key in
        try storage.get(key)
      },
      delete: { key in
        try storage.delete(key)
      },
      exists: { key in
        storage.exists(key)
      },
      deleteAll: {
        try storage.deleteAll()
      },
      setString: { string, key in
        try storage.setString(string, for: key)
      },
      getString: { key in
        try storage.getString(key)
      }
    )
  }()
  
  public static let testValue: KeychainClient = {
    actor MockStorage {
      private var storage: [String: Data] = [:]
      
      func set(_ data: Data, for key: String) {
        storage[key] = data
      }
      
      func get(_ key: String) throws -> Data {
        guard let data = storage[key] else {
          throw KeychainError.noData
        }
        return data
      }
      
      func delete(_ key: String) {
        storage.removeValue(forKey: key)
      }
      
      func exists(_ key: String) -> Bool {
        storage[key] != nil
      }
      
      func deleteAll() {
        storage.removeAll()
      }
    }
    
    let mockStorage = MockStorage()
    
    return KeychainClient(
      set: { data, key in
        await mockStorage.set(data, for: key)
      },
      get: { key in
        try await mockStorage.get(key)
      },
      delete: { key in
        await mockStorage.delete(key)
      },
      exists: { key in
        await mockStorage.exists(key)
      },
      deleteAll: {
        await mockStorage.deleteAll()
      },
      setString: { string, key in
        guard let data = string.data(using: .utf8) else {
          throw KeychainError.invalidData
        }
        await mockStorage.set(data, for: key)
      },
      getString: { key in
        let data = try await mockStorage.get(key)
        guard let string = String(data: data, encoding: .utf8) else {
          throw KeychainError.unexpectedData
        }
        return string
      }
    )
  }()
}

extension DependencyValues {
  public var keychain: KeychainClient {
    get { self[KeychainClient.self] }
    set { self[KeychainClient.self] = newValue }
  }
}

// MARK: - Common Keychain Keys

/// 앱에서 사용하는 공통 키체인 키들
public enum KeychainKeys {
  public static let accessToken = "auth.accessToken"
  public static let refreshToken = "auth.refreshToken"
  public static let userCredentials = "user.credentials"
  public static let deviceToken = "device.token"
  public static let encryptionKey = "encryption.key"
}
