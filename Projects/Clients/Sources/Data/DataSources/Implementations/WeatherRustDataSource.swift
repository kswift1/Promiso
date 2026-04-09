import Foundation
import PromisoShared

// MARK: - Rust API DTOs

private struct RustWeatherResponse: Decodable {
  let forecasts: [RustHourlyForecast]
  let dailyForecasts: [RustDailyForecast]?
}

private struct RustHourlyForecast: Decodable {
  let dateTime: String
  let temperature: Double
  let feelsLikeTemperature: Double
  let condition: String
  let precipitationProbability: Int
  let humidity: Int
  let windSpeed: Double
  let precipitationAmount: String?
}

private struct RustDailyForecast: Decodable {
  let date: String
  let minTemperature: Double
  let maxTemperature: Double
  let amCondition: String
  let pmCondition: String
  let amPrecipitationProbability: Int
  let pmPrecipitationProbability: Int
}

private struct WeatherRequestBody: Encodable {
  let latitude: Double
  let longitude: Double
  let targetDate: Date
}

// MARK: - WeatherRustDataSource

public actor WeatherRustDataSource {
  private let api: RustAPIClient
  private let cache = WeatherCache()

  public init(api: RustAPIClient) {
    self.api = api
  }

  public func getWeather(lat: Double, lng: Double, targetDate: Date) async throws -> WeatherInfo {
    let cacheKey = Self.cacheKey(lat: lat, lng: lng, date: targetDate)

    if let cached = await cache.get(key: cacheKey) {
      return cached
    }

    let response: RustWeatherResponse = try await api.post(
      "/api/v1/weather",
      body: WeatherRequestBody(
        latitude: lat,
        longitude: lng,
        targetDate: targetDate
      )
    )

    let hourlyForecasts = response.forecasts.compactMap { item -> HourlyForecast? in
      guard let dateTime = parseFlexibleISO8601(item.dateTime) else {
        return nil
      }
      let condition = WeatherCondition(rawValue: item.condition) ?? .unknown

      return HourlyForecast(
        dateTime: dateTime,
        temperature: item.temperature,
        feelsLikeTemperature: item.feelsLikeTemperature,
        condition: condition,
        precipitationProbability: item.precipitationProbability,
        humidity: item.humidity,
        windSpeed: item.windSpeed,
        precipitationAmount: item.precipitationAmount ?? ""
      )
    }

    let dailyDateFormatter = DateFormatter()
    dailyDateFormatter.dateFormat = "yyyy-MM-dd"
    dailyDateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")

    let dailyForecasts = (response.dailyForecasts ?? []).compactMap { item -> DailyForecast? in
      guard let date = dailyDateFormatter.date(from: item.date) else {
        return nil
      }
      return DailyForecast(
        date: date,
        minTemperature: item.minTemperature,
        maxTemperature: item.maxTemperature,
        amCondition: WeatherCondition(rawValue: item.amCondition) ?? .unknown,
        pmCondition: WeatherCondition(rawValue: item.pmCondition) ?? .unknown,
        amPrecipitationProbability: item.amPrecipitationProbability,
        pmPrecipitationProbability: item.pmPrecipitationProbability
      )
    }

    let weatherInfo = WeatherInfo(
      fetchedAt: Date(),
      current: Self.selectCurrentForecast(from: hourlyForecasts, targetDate: targetDate),
      hourlyForecasts: hourlyForecasts,
      dailyForecasts: dailyForecasts
    )

    await cache.set(key: cacheKey, value: weatherInfo)
    return weatherInfo
  }

  static func cacheKey(lat: Double, lng: Double, date: Date) -> String {
    let roundedLat = (lat * 100).rounded() / 100
    let roundedLng = (lng * 100).rounded() / 100
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: date)
    let day = calendar.startOfDay(for: date)
    return "\(roundedLat)_\(roundedLng)_\(day.timeIntervalSince1970)_\(hour)"
  }

  static func selectCurrentForecast(
    from forecasts: [HourlyForecast],
    targetDate: Date
  ) -> HourlyForecast? {
    let threshold: TimeInterval = 3600
    let nearby = forecasts.filter { abs($0.dateTime.timeIntervalSince(targetDate)) <= threshold }

    if let preferredNearby = preferredForecast(in: nearby, targetDate: targetDate) {
      return preferredNearby
    }
    return preferredForecast(in: forecasts, targetDate: targetDate)
  }

  private static func preferredForecast(
    in forecasts: [HourlyForecast],
    targetDate: Date
  ) -> HourlyForecast? {
    forecasts.reduce(nil) { best, candidate in
      guard let best else { return candidate }
      return isPreferred(candidate, over: best, targetDate: targetDate) ? candidate : best
    }
  }

  private static func isPreferred(
    _ lhs: HourlyForecast,
    over rhs: HourlyForecast,
    targetDate: Date
  ) -> Bool {
    let lhsDelta = lhs.dateTime.timeIntervalSince(targetDate)
    let rhsDelta = rhs.dateTime.timeIntervalSince(targetDate)
    let lhsAbs = abs(lhsDelta)
    let rhsAbs = abs(rhsDelta)

    if lhsAbs != rhsAbs {
      return lhsAbs < rhsAbs
    }

    if lhsDelta >= 0, rhsDelta < 0 {
      return true
    }
    if lhsDelta < 0, rhsDelta >= 0 {
      return false
    }

    return lhsDelta > rhsDelta
  }
}

private actor WeatherCache {
  private var entries: [String: (WeatherInfo, Date)] = [:]
  private let ttl: TimeInterval = 1800
  private let maxEntries = 50

  func get(key: String) -> WeatherInfo? {
    guard let entry = entries[key] else { return nil }
    guard Date() < entry.1 else {
      entries.removeValue(forKey: key)
      return nil
    }
    return entry.0
  }

  func set(key: String, value: WeatherInfo) {
    if entries.count >= maxEntries {
      let oldestKey = entries.min(by: { $0.value.1 < $1.value.1 })?.key
      if let oldestKey {
        entries.removeValue(forKey: oldestKey)
      }
    }
    entries[key] = (value, Date().addingTimeInterval(ttl))
  }
}

private func parseFlexibleISO8601(_ string: String) -> Date? {
  if let date = WeatherRustDateParsers.fractional.date(from: string) {
    return date
  }
  if let date = WeatherRustDateParsers.standard.date(from: string) {
    return date
  }
  return nil
}

private enum WeatherRustDateParsers {
  static let fractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  static let standard: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime]
    return formatter
  }()
}
