import Foundation
import UIKit

// MARK: - String Extensions

public extension String {
  /// 문자열이 비어있지 않고 공백만 포함하지 않는지 확인
  var isNotEmpty: Bool {
    !trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  
  /// 안전한 substring 추출
  func safeSubstring(from index: Int, length: Int) -> String {
    let startIndex = max(0, min(index, count))
    let endIndex = min(startIndex + length, count)
    
    let start = self.index(self.startIndex, offsetBy: startIndex)
    let end = self.index(self.startIndex, offsetBy: endIndex)
    
    return String(self[start..<end])
  }
  
  /// 이메일 형식 검증
  var isValidEmail: Bool {
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
    let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegex)
    return emailTest.evaluate(with: self)
  }
  
  /// 전화번호 형식 검증 (한국)
  var isValidPhoneNumber: Bool {
    let phoneRegex = "^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$"
    let phoneTest = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
    return phoneTest.evaluate(with: self)
  }
}

// MARK: - Date Extensions

public extension Date {
  /// 사용자 친화적인 상대적 시간 표시
  var relativeTimeString: String {
    let now = Date()
    let interval = now.timeIntervalSince(self)
    
    switch interval {
    case 0..<60:
      return "방금 전"
    case 60..<3600:
      let minutes = Int(interval / 60)
      return "\(minutes)분 전"
    case 3600..<86400:
      let hours = Int(interval / 3600)
      return "\(hours)시간 전"
    case 86400..<2592000:
      let days = Int(interval / 86400)
      return "\(days)일 전"
    default:
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .none
      return formatter.string(from: self)
    }
  }
  
  /// 날짜를 yyyy-MM-dd 형식으로 포맷
  var dateString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: self)
  }
  
  /// 시간을 HH:mm 형식으로 포맷
  var timeString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter.string(from: self)
  }
  
  /// 날짜와 시간을 yyyy-MM-dd HH:mm 형식으로 포맷
  var dateTimeString: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm"
    return formatter.string(from: self)
  }
  
  /// 오늘인지 확인
  var isToday: Bool {
    Calendar.current.isDateInToday(self)
  }
  
  /// 어제인지 확인
  var isYesterday: Bool {
    Calendar.current.isDateInYesterday(self)
  }
  
  /// 내일인지 확인
  var isTomorrow: Bool {
    Calendar.current.isDateInTomorrow(self)
  }
}

// MARK: - Optional Extensions

public extension Optional {
  /// Optional이 nil이 아닌지 확인
  var isNotNil: Bool {
    self != nil
  }
  
  /// Optional이 nil인지 확인
  var isNil: Bool {
    self == nil
  }
}

public extension Optional where Wrapped == String {
  /// Optional String이 비어있지 않은지 확인
  var isNotEmpty: Bool {
    self?.isNotEmpty ?? false
  }
}

// MARK: - Collection Extensions

public extension Collection {
  /// 안전한 인덱스 접근
  subscript(safe index: Index) -> Element? {
    return indices.contains(index) ? self[index] : nil
  }
  
  /// 컬렉션이 비어있지 않은지 확인
  var isNotEmpty: Bool {
    !isEmpty
  }
}

// MARK: - Result Extensions

public extension Result {
  /// 성공 여부 확인
  var isSuccess: Bool {
    switch self {
    case .success: return true
    case .failure: return false
    }
  }
  
  /// 실패 여부 확인
  var isFailure: Bool {
    !isSuccess
  }
  
  /// 성공 값 추출 (nil 반환 가능)
  var successValue: Success? {
    switch self {
    case let .success(value): return value
    case .failure: return nil
    }
  }
  
  /// 실패 값 추출 (nil 반환 가능)
  var failureValue: Failure? {
    switch self {
    case .success: return nil
    case let .failure(error): return error
    }
  }
}

// MARK: - UIColor Extensions

public extension UIColor {
  /// Hex 문자열로부터 UIColor 생성
  convenience init?(hex: String) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int: UInt64 = 0
    Scanner(string: hex).scanHexInt64(&int)
    let a, r, g, b: UInt64
    switch hex.count {
    case 3: // RGB (12-bit)
      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
    case 6: // RGB (24-bit)
      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
    case 8: // ARGB (32-bit)
      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
    default:
      return nil
    }
    self.init(
      red: Double(r) / 255,
      green: Double(g) / 255,
      blue: Double(b) / 255,
      alpha: Double(a) / 255
    )
  }
  
  /// UIColor를 Hex 문자열로 변환
  var hexString: String {
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    getRed(&r, green: &g, blue: &b, alpha: &a)
    let rgb = Int(r * 255) << 16 | Int(g * 255) << 8 | Int(b * 255)
    return String(format: "#%06X", rgb)
  }
}