import Foundation

/// 약속 API 에러
public enum PromiseClientError: Error, Equatable {
  case networkError
  case unauthorized
  case notFound
  case serverError
  case invalidData
  case unknown

  public var localizedDescription: String {
    switch self {
    case .networkError:
      return "네트워크 연결을 확인해주세요"
    case .unauthorized:
      return "로그인이 필요합니다"
    case .notFound:
      return "약속을 찾을 수 없습니다"
    case .serverError:
      return "서버 오류가 발생했습니다"
    case .invalidData:
      return "잘못된 데이터입니다"
    case .unknown:
      return "알 수 없는 오류가 발생했습니다"
    }
  }
}
