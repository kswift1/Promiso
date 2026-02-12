// MARK: - AppLogger.swift
// 앱 전체에서 사용하는 범용 로거

import os.log

/// 앱 로깅을 위한 통합 로거
/// 카테고리별로 구분하여 디버그 필터링 가능
public enum AppLogger {

  // MARK: - Category Loggers

  /// 캘린더 관련 로그
  public static let calendar = Logger(subsystem: subsystem, category: "Calendar")

  /// 홈 화면 관련 로그
  public static let home = Logger(subsystem: subsystem, category: "Home")

  /// 그룹 관련 로그
  public static let group = Logger(subsystem: subsystem, category: "Group")

  /// 인증 관련 로그
  public static let auth = Logger(subsystem: subsystem, category: "Auth")

  /// 네트워크 관련 로그
  public static let network = Logger(subsystem: subsystem, category: "Network")

  /// 딥링크 관련 로그
  public static let deeplink = Logger(subsystem: subsystem, category: "Deeplink")

  /// 푸시 알림 관련 로그
  public static let notification = Logger(subsystem: subsystem, category: "Notification")

  /// LiveActivity 관련 로그
  public static let liveActivity = Logger(subsystem: subsystem, category: "LiveActivity")

  /// 이모지 생성 관련 로그
  public static let emoji = Logger(subsystem: subsystem, category: "Emoji")

  /// 개인 일정 관련 로그
  public static let personal = Logger(subsystem: subsystem, category: "Personal")

  /// 일반 로그
  public static let general = Logger(subsystem: subsystem, category: "General")

  // MARK: - Private

  private static let subsystem = "com.promiso"

  // MARK: - Debug Mode

  #if DEBUG
  public static let isDebugEnabled = true
  #else
  public static let isDebugEnabled = false
  #endif
}

// MARK: - Logger Extensions

extension Logger {

  /// 디버그 모드에서만 로그 출력
  /// - Parameters:
  ///   - message: 로그 메시지
  ///   - type: 로그 타입 (기본: .debug)
  public func debugLog(_ message: String, type: OSLogType = .debug) {
    guard AppLogger.isDebugEnabled else { return }
    self.log(level: type, "\(message)")
  }
}
