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
      return "일정을 찾을 수 없습니다."
    case .userNotFound:
      return "사용자를 찾을 수 없습니다."
    case .groupNotFound:
      return "그룹을 찾을 수 없습니다."
    case .insufficientParticipants:
      return "참가자 수가 부족합니다."
    case .invalidOperation:
      return "유효하지 않은 작업입니다."
    case .networkError(let message):
      return "네트워크 오류: \(message)"
    case .unknown(let message):
      return "알 수 없는 오류: \(message)"
    }
  }
}
