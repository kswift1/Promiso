import ComposableArchitecture
import Foundation
import PromisoShared
import SwiftUI

// MARK: - WeatherClient

@DependencyClient
public struct WeatherClient: Sendable {
  /// 특정 위치/날짜의 날씨 정보 조회
  public var getWeather: @Sendable (
    _ latitude: Double,
    _ longitude: Double,
    _ targetDate: Date
  ) async throws -> WeatherInfo
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var weatherClient: WeatherClient {
    get { self[WeatherClient.self] }
    set { self[WeatherClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension WeatherClient: DependencyKey {
  public static let liveValue: WeatherClient = {
    let dataSource = WeatherDataSource()

    return Self(
      getWeather: { latitude, longitude, targetDate in
        try await dataSource.getWeather(lat: latitude, lng: longitude, targetDate: targetDate)
      }
    )
  }()
}

// MARK: - Test / Preview

extension WeatherClient: TestDependencyKey {
  public static let previewValue = Self(
    getWeather: { _, _, targetDate in
      // 미리보기용 샘플 데이터
      let calendar = Calendar.current
      let hour = calendar.component(.hour, from: targetDate)

      let forecasts = (0..<12).map { offset -> HourlyForecast in
        let forecastHour = hour + offset
        let date = calendar.date(byAdding: .hour, value: offset, to: targetDate) ?? targetDate

        let conditions: [WeatherCondition] = [.clear, .cloudy, .overcast, .rain, .clear, .cloudy]
        let condition = conditions[offset % conditions.count]
        let temp = 20.0 + Double(offset % 5) - 2.0

        return HourlyForecast(
          dateTime: date,
          temperature: temp,
          feelsLikeTemperature: temp - 2,
          condition: condition,
          precipitationProbability: condition == .rain ? 70 : 10,
          humidity: 60 + (offset * 2),
          windSpeed: 3.0 + Double(offset % 3)
        )
      }

      return WeatherInfo(
        fetchedAt: Date(),
        current: forecasts.first,
        hourlyForecasts: forecasts
      )
    }
  )

  public static let testValue = Self(
    getWeather: unimplemented("\(Self.self).getWeather")
  )
}
