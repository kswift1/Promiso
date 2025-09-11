import Foundation
import OSLog
import CoreDependencies
import CoreUtilities
import ComposableArchitecture

// MARK: - Log Level

/// 로그 레벨 정의
public enum LogLevel: String, CaseIterable, Comparable {
  case debug = "DEBUG"
  case info = "INFO"
  case warning = "WARNING"
  case error = "ERROR"
  
  public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
    let order: [LogLevel] = [.debug, .info, .warning, .error]
    guard let lhsIndex = order.firstIndex(of: lhs),
          let rhsIndex = order.firstIndex(of: rhs) else {
      return false
    }
    return lhsIndex < rhsIndex
  }
  
  /// OSLog 타입으로 변환
  var osLogType: OSLogType {
    switch self {
    case .debug: return .debug
    case .info: return .info
    case .warning: return .default
    case .error: return .error
    }
  }
  
  /// 이모지 표현
  var emoji: String {
    switch self {
    case .debug: return "🔍"
    case .info: return "ℹ️"
    case .warning: return "⚠️"
    case .error: return "❌"
    }
  }
}

// MARK: - Logger Protocol

/// 로거 프로토콜
public protocol LoggerProtocol: Sendable {
  func log(_ message: String, level: LogLevel, category: String, file: String, function: String, line: Int)
  func debug(_ message: String, category: String, file: String, function: String, line: Int)
  func info(_ message: String, category: String, file: String, function: String, line: Int)
  func warning(_ message: String, category: String, file: String, function: String, line: Int)
  func error(_ message: String, category: String, file: String, function: String, line: Int)
}

// MARK: - Logger Implementation

/// 메인 로거 구현
public struct Logger: LoggerProtocol {
  private let osLogger: OSLog
  private let minLevel: LogLevel
  private let dateFormatter: DateFormatter
  
  public init(subsystem: String = Bundle.main.bundleIdentifier ?? "com.promiso.app", 
              category: String = "Default",
              minLevel: LogLevel = .debug) {
    self.osLogger = OSLog(subsystem: subsystem, category: category)
    self.minLevel = minLevel
    
    self.dateFormatter = DateFormatter()
    self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
  }
  
  public func log(_ message: String, level: LogLevel, category: String = "Default", 
                  file: String = #file, function: String = #function, line: Int = #line) {
    guard level >= minLevel else { return }
    
    let fileName = (file as NSString).lastPathComponent
    let timestamp = dateFormatter.string(from: Date())
    let logMessage = "\(level.emoji) [\(timestamp)] [\(category)] \(fileName):\(line) \(function) - \(message)"
    
    os_log("%{public}@", log: osLogger, type: level.osLogType, logMessage)
    
    #if DEBUG
    print(logMessage)
    #endif
  }
  
  public func debug(_ message: String, category: String = "Default", 
                    file: String = #file, function: String = #function, line: Int = #line) {
    log(message, level: .debug, category: category, file: file, function: function, line: line)
  }
  
  public func info(_ message: String, category: String = "Default", 
                   file: String = #file, function: String = #function, line: Int = #line) {
    log(message, level: .info, category: category, file: file, function: function, line: line)
  }
  
  public func warning(_ message: String, category: String = "Default", 
                      file: String = #file, function: String = #function, line: Int = #line) {
    log(message, level: .warning, category: category, file: file, function: function, line: line)
  }
  
  public func error(_ message: String, category: String = "Default", 
                    file: String = #file, function: String = #function, line: Int = #line) {
    log(message, level: .error, category: category, file: file, function: function, line: line)
  }
}

// MARK: - Logger Dependency

/// TCA Dependency로 Logger 등록
public struct LoggerClient: Sendable {
  public var log: @Sendable (String, LogLevel, String, String, String, Int) -> Void
  public var debug: @Sendable (String, String, String, String, Int) -> Void
  public var info: @Sendable (String, String, String, String, Int) -> Void
  public var warning: @Sendable (String, String, String, String, Int) -> Void
  public var error: @Sendable (String, String, String, String, Int) -> Void
  
  public init(
    log: @escaping @Sendable (String, LogLevel, String, String, String, Int) -> Void,
    debug: @escaping @Sendable (String, String, String, String, Int) -> Void,
    info: @escaping @Sendable (String, String, String, String, Int) -> Void,
    warning: @escaping @Sendable (String, String, String, String, Int) -> Void,
    error: @escaping @Sendable (String, String, String, String, Int) -> Void
  ) {
    self.log = log
    self.debug = debug
    self.info = info
    self.warning = warning
    self.error = error
  }
}

extension LoggerClient: DependencyKey {
  public static let liveValue: LoggerClient = {
    let logger = Logger()
    return LoggerClient(
      log: logger.log,
      debug: logger.debug,
      info: logger.info,
      warning: logger.warning,
      error: logger.error
    )
  }()
  
  public static let testValue: LoggerClient = LoggerClient(
    log: { _, _, _, _, _, _ in },
    debug: { _, _, _, _, _ in },
    info: { _, _, _, _, _ in },
    warning: { _, _, _, _, _ in },
    error: { _, _, _, _, _ in }
  )
}

extension DependencyValues {
  public var logger: LoggerClient {
    get { self[LoggerClient.self] }
    set { self[LoggerClient.self] = newValue }
  }
}

// MARK: - Convenience Logger

/// 전역 로거 인스턴스
public let AppLogger = Logger()

/// 편의 함수들
public func logDebug(_ message: String, category: String = "App", 
                     file: String = #file, function: String = #function, line: Int = #line) {
  AppLogger.debug(message, category: category, file: file, function: function, line: line)
}

public func logInfo(_ message: String, category: String = "App", 
                    file: String = #file, function: String = #function, line: Int = #line) {
  AppLogger.info(message, category: category, file: file, function: function, line: line)
}

public func logWarning(_ message: String, category: String = "App", 
                       file: String = #file, function: String = #function, line: Int = #line) {
  AppLogger.warning(message, category: category, file: file, function: function, line: line)
}

public func logError(_ message: String, category: String = "App", 
                     file: String = #file, function: String = #function, line: Int = #line) {
  AppLogger.error(message, category: category, file: file, function: function, line: line)
}
