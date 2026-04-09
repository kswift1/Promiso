import Foundation

/// Firestore SDK 없이 유지하는 경량 timestamp 모델.
public struct Timestamp: Codable, Hashable, Sendable {
  public let seconds: Int64
  public let nanoseconds: Int32

  public init(seconds: Int64, nanoseconds: Int32 = 0) {
    self.seconds = seconds
    self.nanoseconds = nanoseconds
  }

  public init(date: Date = Date()) {
    let interval = date.timeIntervalSince1970
    let wholeSeconds = floor(interval)
    let fractional = interval - wholeSeconds

    self.seconds = Int64(wholeSeconds)
    self.nanoseconds = Int32((fractional * 1_000_000_000).rounded())
  }

  public func dateValue() -> Date {
    Date(timeIntervalSince1970: TimeInterval(seconds) + TimeInterval(nanoseconds) / 1_000_000_000)
  }

  private enum CodingKeys: String, CodingKey {
    case seconds
    case nanoseconds
    case legacySeconds = "_seconds"
    case legacyNanoseconds = "_nanoseconds"
  }

  public init(from decoder: Decoder) throws {
    if let singleValueContainer = try? decoder.singleValueContainer() {
      if let epochSeconds = try? singleValueContainer.decode(Double.self) {
        self.init(date: Date(timeIntervalSince1970: epochSeconds))
        return
      }

      if let iso8601String = try? singleValueContainer.decode(String.self),
         let date = Self.iso8601Date(from: iso8601String) {
        self.init(date: date)
        return
      }
    }

    let container = try decoder.container(keyedBy: CodingKeys.self)
    let seconds = try container.decodeIfPresent(Int64.self, forKey: .seconds)
      ?? container.decodeIfPresent(Int64.self, forKey: .legacySeconds)
      ?? 0
    let nanoseconds = try container.decodeIfPresent(Int32.self, forKey: .nanoseconds)
      ?? container.decodeIfPresent(Int32.self, forKey: .legacyNanoseconds)
      ?? 0

    self.init(seconds: seconds, nanoseconds: nanoseconds)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(seconds, forKey: .legacySeconds)
    try container.encode(nanoseconds, forKey: .legacyNanoseconds)
  }

  private static func iso8601Date(from value: String) -> Date? {
    if let date = Self.fractionalFormatter.date(from: value) {
      return date
    }
    return Self.standardFormatter.date(from: value)
  }

  private static let fractionalFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let standardFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
}
