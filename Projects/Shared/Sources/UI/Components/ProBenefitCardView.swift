import SwiftUI
import ResourceKit

// MARK: - Pro Benefit Card View

/// 카드 하단 PRO 혜택 통합 뷰 — 날씨 + 일정 충돌을 하나의 컨테이너로 묶어 표시
///
/// - 날씨 행: `WeatherInfo.forecast(for:)`로 조회, 탭 시 WeatherTooltip 팝오버
/// - 충돌 행: 로딩 중 스피너 또는 충돌 요약 + ConflictTooltip 팝오버
/// - 표시할 내용이 없으면 EmptyView 렌더링
public struct ProBenefitCardView: View {
  let weather: WeatherInfo?
  let eventStartAt: Date
  let eventEndAt: Date?
  let conflicts: [ConflictInfo]
  let isCheckingConflicts: Bool
  let eventTitle: String
  let eventEmoji: String?

  public init(
    weather: WeatherInfo? = nil,
    eventStartAt: Date,
    eventEndAt: Date? = nil,
    conflicts: [ConflictInfo] = [],
    isCheckingConflicts: Bool = false,
    eventTitle: String = "",
    eventEmoji: String? = nil
  ) {
    self.weather = weather
    self.eventStartAt = eventStartAt
    self.eventEndAt = eventEndAt
    self.conflicts = conflicts
    self.isCheckingConflicts = isCheckingConflicts
    self.eventTitle = eventTitle
    self.eventEmoji = eventEmoji
  }

  private var weatherForecast: HourlyForecast? {
    weather?.forecast(for: eventStartAt)
  }

  private var hasContent: Bool {
    weatherForecast != nil
    || isCheckingConflicts
    || !conflicts.isEmpty
  }

  public var body: some View {
    if hasContent {
      VStack(alignment: .leading, spacing: 8) {
        Divider()

        VStack(alignment: .leading, spacing: 4) {
          // PRO 뱃지
          ProBadge()

          // 날씨 행
          if let forecast = weatherForecast {
            ProWeatherRow(
              forecast: forecast,
              rangeForecasts: weather?.forecasts(from: eventStartAt, to: eventEndAt) ?? [],
              forecastSource: weather?.forecastSource(for: eventStartAt) ?? .shortTerm,
              referenceTimeText: eventStartAt.formattedMonthDayTime
            )
          }

          // 충돌 행
          if isCheckingConflicts || !conflicts.isEmpty {
            ProConflictRow(
              conflicts: conflicts,
              isChecking: isCheckingConflicts,
              eventTitle: eventTitle,
              eventEmoji: eventEmoji,
              eventStartAt: eventStartAt,
              eventEndAt: eventEndAt
            )
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.pmindigo.n500.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .stroke(Color.pmindigo.n500.opacity(0.12), lineWidth: 1)
        )
      }
    }
  }

}

// MARK: - Previews

#Preview("날씨만") {
  ProBenefitCardView(
    weather: WeatherInfo(
      hourlyForecasts: [
        HourlyForecast(
          dateTime: Date(),
          temperature: 15,
          feelsLikeTemperature: 12,
          condition: .cloudy,
          precipitationProbability: 60,
          humidity: 70,
          windSpeed: 3.5
        )
      ]
    ),
    eventStartAt: Date(),
    eventTitle: "팀 점심 약속",
    eventEmoji: "🍱"
  )
  .padding()
}

#Preview("충돌만") {
  ProBenefitCardView(
    eventStartAt: Date(),
    conflicts: [
      ConflictInfo(title: "팀 회의", overlapMinutes: 30)
    ],
    eventTitle: "저녁 약속",
    eventEmoji: "🍽️"
  )
  .padding()
}

#Preview("날씨+충돌 전체") {
  ProBenefitCardView(
    weather: WeatherInfo(
      hourlyForecasts: [
        HourlyForecast(
          dateTime: Date(),
          temperature: 8,
          feelsLikeTemperature: 5,
          condition: .rain,
          precipitationProbability: 80,
          humidity: 85,
          windSpeed: 6.0
        )
      ]
    ),
    eventStartAt: Date(),
    conflicts: [
      ConflictInfo(title: "스터디 모임", overlapMinutes: 45)
    ],
    eventTitle: "저녁 약속",
    eventEmoji: "🍽️"
  )
  .padding()
}

#Preview("로딩 중") {
  ProBenefitCardView(
    eventStartAt: Date(),
    isCheckingConflicts: true,
    eventTitle: "저녁 약속",
    eventEmoji: "🍽️"
  )
  .padding()
}

#Preview("빈 상태 (EmptyView)") {
  VStack {
    Text("아래에 뷰가 없어야 합니다")
      .font(.caption)
      .foregroundStyle(.secondary)

    ProBenefitCardView(
      eventStartAt: Date(),
      eventTitle: "저녁 약속"
    )
  }
  .padding()
}
