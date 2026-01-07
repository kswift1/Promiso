import Foundation

/// 앱 전역에서 사용하는 에러 래퍼
public struct AppError: Error, LocalizedError, Sendable, Equatable {
  public let message: String

  public init(_ error: Error) {
    self.message = error.localizedDescription
  }

  public init(message: String) {
    self.message = message
  }

  public var errorDescription: String? {
    message
  }
}
