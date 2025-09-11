import Foundation
import UIKit

// MARK: - Validation Helpers

/// 다양한 입력값 검증을 위한 헬퍼
public enum ValidationHelper {
  
  /// 이메일 검증
  public static func validateEmail(_ email: String) -> ValidationResult {
    guard !email.isEmpty else {
      return .failure("이메일을 입력해주세요")
    }
    
    guard email.isValidEmail else {
      return .failure("올바른 이메일 형식이 아닙니다")
    }
    
    return .success
  }
  
  /// 비밀번호 검증
  public static func validatePassword(_ password: String) -> ValidationResult {
    guard !password.isEmpty else {
      return .failure("비밀번호를 입력해주세요")
    }
    
    guard password.count >= 8 else {
      return .failure("비밀번호는 8자 이상이어야 합니다")
    }
    
    guard password.rangeOfCharacter(from: .letters) != nil else {
      return .failure("비밀번호에 문자가 포함되어야 합니다")
    }
    
    guard password.rangeOfCharacter(from: .decimalDigits) != nil else {
      return .failure("비밀번호에 숫자가 포함되어야 합니다")
    }
    
    return .success
  }
  
  /// 전화번호 검증
  public static func validatePhoneNumber(_ phoneNumber: String) -> ValidationResult {
    guard !phoneNumber.isEmpty else {
      return .failure("전화번호를 입력해주세요")
    }
    
    guard phoneNumber.isValidPhoneNumber else {
      return .failure("올바른 전화번호 형식이 아닙니다")
    }
    
    return .success
  }
  
  /// 이름 검증
  public static func validateName(_ name: String) -> ValidationResult {
    guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return .failure("이름을 입력해주세요")
    }
    
    guard name.count >= 2 else {
      return .failure("이름은 2자 이상이어야 합니다")
    }
    
    guard name.count <= 20 else {
      return .failure("이름은 20자 이하여야 합니다")
    }
    
    return .success
  }
}

/// 검증 결과
public enum ValidationResult: Equatable {
  case success
  case failure(String)
  
  public var isValid: Bool {
    switch self {
    case .success: return true
    case .failure: return false
    }
  }
  
  public var errorMessage: String? {
    switch self {
    case .success: return nil
    case .failure(let message): return message
    }
  }
}

// MARK: - Threading Helpers

/// 메인 스레드 실행 헬퍼
public enum ThreadHelper {
  
  /// 메인 스레드에서 실행
  public static func runOnMain(_ block: @escaping () -> Void) {
    if Thread.isMainThread {
      block()
    } else {
      DispatchQueue.main.async {
        block()
      }
    }
  }
  
  /// 백그라운드에서 실행 후 메인 스레드에서 완료 처리
  public static func runInBackground<T>(
    _ backgroundWork: @escaping () throws -> T,
    completion: @escaping (Result<T, Error>) -> Void
  ) {
    DispatchQueue.global(qos: .background).async {
      do {
        let result = try backgroundWork()
        DispatchQueue.main.async {
          completion(.success(result))
        }
      } catch {
        DispatchQueue.main.async {
          completion(.failure(error))
        }
      }
    }
  }
}

// MARK: - Device Helpers

/// 디바이스 정보 헬퍼
public enum DeviceHelper {
  
  /// 현재 디바이스가 iPhone인지 확인
  public static var isPhone: Bool {
    UIDevice.current.userInterfaceIdiom == .phone
  }
  
  /// 현재 디바이스가 iPad인지 확인
  public static var isPad: Bool {
    UIDevice.current.userInterfaceIdiom == .pad
  }
  
  /// 현재 화면이 작은 화면인지 확인 (iPhone SE 등)
  public static var isSmallScreen: Bool {
    guard isPhone else { return false }
    let screenHeight = UIScreen.main.bounds.height
    return screenHeight <= 667 // iPhone 6/6s/7/8 and smaller
  }
  
  /// 현재 화면이 큰 화면인지 확인 (iPhone Pro Max 등)
  public static var isLargeScreen: Bool {
    guard isPhone else { return false }
    let screenHeight = UIScreen.main.bounds.height
    return screenHeight >= 926 // iPhone 12 Pro Max and larger
  }
  
  /// Safe Area Top Inset
  public static var safeAreaTop: CGFloat {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first {
      return window.safeAreaInsets.top
    }
    return 0
  }
  
  /// Safe Area Bottom Inset
  public static var safeAreaBottom: CGFloat {
    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = windowScene.windows.first {
      return window.safeAreaInsets.bottom
    }
    return 0
  }
}

// MARK: - Debouncer

/// 연속된 호출을 방지하는 디바운서
public final class Debouncer {
  private let queue = DispatchQueue.main
  private var workItem: DispatchWorkItem?
  private let delay: TimeInterval
  
  public init(delay: TimeInterval) {
    self.delay = delay
  }
  
  public func call(_ action: @escaping () -> Void) {
    workItem?.cancel()
    workItem = DispatchWorkItem(block: action)
    if let workItem = workItem {
      queue.asyncAfter(deadline: .now() + delay, execute: workItem)
    }
  }
  
  public func cancel() {
    workItem?.cancel()
    workItem = nil
  }
}

// MARK: - Throttler

/// 지정된 시간 간격으로 호출을 제한하는 스로틀러
public final class Throttler {
  private var lastExecutionTime: Date = Date.distantPast
  private let delay: TimeInterval
  
  public init(delay: TimeInterval) {
    self.delay = delay
  }
  
  public func call(_ action: @escaping () -> Void) {
    let now = Date()
    if now.timeIntervalSince(lastExecutionTime) >= delay {
      lastExecutionTime = now
      action()
    }
  }
}

// MARK: - KeyPath Helpers

/// KeyPath를 사용한 정렬 헬퍼
public extension Sequence {
  func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>) -> [Element] {
    return sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
  }
  
  func sorted<T: Comparable>(by keyPath: KeyPath<Element, T>, descending: Bool) -> [Element] {
    return sorted { 
      if descending {
        return $0[keyPath: keyPath] > $1[keyPath: keyPath]
      } else {
        return $0[keyPath: keyPath] < $1[keyPath: keyPath]
      }
    }
  }
}

// MARK: - Error Helpers

/// 일반적인 앱 에러
public enum AppError: Error, LocalizedError, Equatable {
  case networkError(String)
  case validationError(String)
  case unknownError(String)
  case cancelled
  
  public var errorDescription: String? {
    switch self {
    case .networkError(let message):
      return "네트워크 오류: \(message)"
    case .validationError(let message):
      return "입력 오류: \(message)"
    case .unknownError(let message):
      return "알 수 없는 오류: \(message)"
    case .cancelled:
      return "작업이 취소되었습니다"
    }
  }
}