import Foundation

// MARK: - Weather Hint Helper

/// 날씨 힌트 관련 공통 헬퍼
public enum WeatherHintHelper {

  /// 시간별 날씨 예보 추출 (시작~종료 2시간 이상이면 worst case)
  public static func forecast(
    from weatherInfo: WeatherInfo,
    startAt: Date,
    endAt: Date?
  ) -> HourlyForecast? {
    if let endAt, endAt.timeIntervalSince(startAt) >= 2 * 60 * 60 {
      return weatherInfo.worstCaseForecast(from: startAt, to: endAt)
    }
    return weatherInfo.forecast(for: startAt)
  }

  /// 최저 기온 (중기예보에서만)
  public static func minTemperature(
    from weatherInfo: WeatherInfo,
    startAt: Date
  ) -> Double? {
    guard weatherInfo.forecastSource(for: startAt) == .midTerm else { return nil }
    let calendar = Calendar.current
    return weatherInfo.dailyForecasts
      .first(where: { calendar.isDate($0.date, inSameDayAs: startAt) })?
      .minTemperature
  }

  /// 최고 기온 (중기예보에서만)
  public static func maxTemperature(
    from weatherInfo: WeatherInfo,
    startAt: Date
  ) -> Double? {
    guard weatherInfo.forecastSource(for: startAt) == .midTerm else { return nil }
    let calendar = Calendar.current
    return weatherInfo.dailyForecasts
      .first(where: { calendar.isDate($0.date, inSameDayAs: startAt) })?
      .maxTemperature
  }

  /// 약속 시간 구간 시간별 예보 목록 (팝오버 타임라인용)
  public static func rangeForecasts(
    from weatherInfo: WeatherInfo,
    startAt: Date,
    endAt: Date?
  ) -> [HourlyForecast] {
    guard let endAt else { return [] }
    return weatherInfo.forecasts(from: startAt, to: endAt)
  }

  /// 예보 출처 (단기/중기)
  public static func forecastSource(
    from weatherInfo: WeatherInfo,
    startAt: Date
  ) -> ForecastSource {
    weatherInfo.forecastSource(for: startAt)
  }
}
