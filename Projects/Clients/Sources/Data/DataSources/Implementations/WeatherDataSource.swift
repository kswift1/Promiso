import FirebaseFunctions
import Foundation
import PromisoShared

// MARK: - Firebase Functions Response Models

/// getWeather Functions 응답
private struct WeatherResponse: Decodable {
  let forecasts: [ForecastItem]
  let dailyForecasts: [DailyForecastItem]?
}

/// 예보 아이템
private struct ForecastItem: Decodable {
  let dateTime: String
  let temperature: Double
  let feelsLikeTemperature: Double
  let condition: String
  let precipitationProbability: Int
  let humidity: Int
  let windSpeed: Double
  let precipitationAmount: String?
}

/// 일별 예보 아이템 (중기예보)
/// Firebase SDK가 JS number를 Double로 변환하므로 Int 필드도 Double로 수신
private struct DailyForecastItem: Decodable {
  let date: String
  let minTemperature: Double
  let maxTemperature: Double
  let amCondition: String
  let pmCondition: String
  let amPrecipitationProbability: Double
  let pmPrecipitationProbability: Double
}

// MARK: - WeatherDataSource

/// 날씨 API 데이터소스 (Firebase Functions 프록시)
final class WeatherDataSource: Sendable {
  private let functions = DefaultFunctionsProvider().functions
  private let cache = WeatherCache()

  /// 날씨 정보 조회
  func getWeather(lat: Double, lng: Double, targetDate: Date) async throws -> WeatherInfo {
    // 1. 캐시 키 생성 (소수점 2자리 반올림 + 시간 단위)
    let cacheKey = Self.cacheKey(lat: lat, lng: lng, date: targetDate)


    // 2. 캐시 확인
    if let cached = await cache.get(key: cacheKey) {

      return cached
    }

    // 3. Firebase Functions 호출

    let callable = functions.httpsCallable("getWeather")

    let requestFormatter = ISO8601DateFormatter()
    let result = try await callable.call([
      "latitude": lat,
      "longitude": lng,
      "targetDate": requestFormatter.string(from: targetDate),
    ])

    // JS toISOString()은 밀리초 포함 ("...000Z")
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.formatOptions = [
      .withInternetDateTime, .withFractionalSeconds,
    ]

    guard let data = try? JSONSerialization.data(withJSONObject: result.data) else {
      throw WeatherDataSourceError.invalidResponse
    }

    let decoder = JSONDecoder()
    let response: WeatherResponse
    do {
      response = try decoder.decode(WeatherResponse.self, from: data)
    } catch {

      throw WeatherDataSourceError.invalidResponse
    }

    // 4. 변환 — 시간별 예보

    let forecasts = response.forecasts.compactMap { item -> HourlyForecast? in
      guard let dateTime = dateFormatter.date(from: item.dateTime) else {

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

    // 4-2. 변환 — 일별 예보 (중기예보)
    let dailyDateFormatter = DateFormatter()
    dailyDateFormatter.dateFormat = "yyyy-MM-dd"
    dailyDateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")

    let dailyForecasts: [DailyForecast] = (response.dailyForecasts ?? []).compactMap { item in
      guard let date = dailyDateFormatter.date(from: item.date) else {

        return nil
      }
      return DailyForecast(
        date: date,
        minTemperature: item.minTemperature,
        maxTemperature: item.maxTemperature,
        amCondition: WeatherCondition(rawValue: item.amCondition) ?? .unknown,
        pmCondition: WeatherCondition(rawValue: item.pmCondition) ?? .unknown,
        amPrecipitationProbability: Int(item.amPrecipitationProbability),
        pmPrecipitationProbability: Int(item.pmPrecipitationProbability)
      )
    }


    let weatherInfo = WeatherInfo(
      fetchedAt: Date(),
      current: forecasts.first(where: { abs($0.dateTime.timeIntervalSince(targetDate)) < 3600 }),
      hourlyForecasts: forecasts,
      dailyForecasts: dailyForecasts
    )

    // 5. 캐시 저장
    await cache.set(key: cacheKey, value: weatherInfo)

    return weatherInfo
  }

  /// 캐시 키 생성 (좌표 소수점 2자리 + 시간 단위 반올림)
  static func cacheKey(lat: Double, lng: Double, date: Date) -> String {
    let roundedLat = (lat * 100).rounded() / 100
    let roundedLng = (lng * 100).rounded() / 100
    let calendar = Calendar.current
    let hour = calendar.component(.hour, from: date)
    let day = calendar.startOfDay(for: date)
    return "\(roundedLat)_\(roundedLng)_\(day.timeIntervalSince1970)_\(hour)"
  }
}

// MARK: - Weather Cache (Actor)

private actor WeatherCache {
  private var entries: [String: (WeatherInfo, Date)] = [:]
  private let ttl: TimeInterval = 1800  // 30분
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
    // LRU: 최대 개수 초과 시 가장 오래된 항목 제거
    if entries.count >= maxEntries {
      let oldestKey = entries.min(by: { $0.value.1 < $1.value.1 })?.key
      if let oldestKey = oldestKey {
        entries.removeValue(forKey: oldestKey)
      }
    }
    entries[key] = (value, Date().addingTimeInterval(ttl))
  }
}

// MARK: - Error

enum WeatherDataSourceError: Error, LocalizedError {
  case invalidResponse

  var errorDescription: String? {
    switch self {
    case .invalidResponse:
      return "날씨 정보를 처리할 수 없습니다"
    }
  }
}
