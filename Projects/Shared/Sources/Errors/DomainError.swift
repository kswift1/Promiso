import Foundation

// MARK: - Shared Error

public enum DomainError: Error, LocalizedError {
  case scheduleNotFound
  case userNotFound
  case groupNotFound
  case insufficientParticipants
  case invalidOperation
  case networkError(String)
  case unknown(String)
  
  public var errorDescription: String? {
    switch self {
    case .scheduleNotFound:
      return LocalizedStrings.Error.notFoundError
    case .userNotFound:
      return LocalizedStrings.Error.userNotFound
    case .groupNotFound:
      return LocalizedStrings.Error.notFoundError
    case .insufficientParticipants:
      return LocalizedStrings.Error.validationError
    case .invalidOperation:
      return LocalizedStrings.Error.validationError
    case .networkError(let message):
      return message.isEmpty ? LocalizedStrings.Error.networkError : "\(LocalizedStrings.Error.networkError): \(message)"
    case .unknown(let message):
      return message.isEmpty ? LocalizedStrings.Error.unknownError : "\(LocalizedStrings.Error.unknownError): \(message)"
    }
  }
}
