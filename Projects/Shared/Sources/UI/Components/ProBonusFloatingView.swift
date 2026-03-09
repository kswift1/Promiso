import SwiftUI
import ResourceKit

// MARK: - Conflict Check Trigger

public enum ConflictCheckTrigger: Equatable, Sendable {
  case initial
  case startTimeChanged
  case endTimeChanged
}

// MARK: - Conflict Severity

public enum ConflictSeverity: Equatable, Sendable {
  case confirmed
  case pending
}

// MARK: - Conflict Info

/// 일정 충돌 표시용 모델 (PromisoShared 내부 전용)
/// Clients.ScheduleConflict 를 Feature에서 변환하여 전달합니다.
public struct ConflictInfo: Equatable, Sendable {
  public let title: String
  public let overlapMinutes: Int
  public let gapMinutes: Int
  public let startAt: Date
  public let endAt: Date?
  public let emoji: String?
  public let severity: ConflictSeverity

  public init(
    title: String,
    overlapMinutes: Int,
    gapMinutes: Int = 0,
    startAt: Date = .now,
    endAt: Date? = nil,
    emoji: String? = nil,
    severity: ConflictSeverity = .confirmed
  ) {
    self.title = title
    self.overlapMinutes = overlapMinutes
    self.gapMinutes = gapMinutes
    self.startAt = startAt
    self.endAt = endAt
    self.emoji = emoji
    self.severity = severity
  }
}

// MARK: - Pro Bonus Floating View

/// Pro Plan 보너스 정보 플로팅 뷰
///
/// 날씨, 일정 충돌 힌트를 하단 버튼 위에 표시합니다.
/// 추후 Pro Plan 전용으로 변경될 수 있으므로 이름을 ProBonusFloatingView로 유지합니다.
public struct ProBonusFloatingView: View {
  let isPro: Bool
  let hasCheckedConflicts: Bool
  let weatherForecast: HourlyForecast?
  let rangeForecasts: [HourlyForecast]
  let forecastSource: ForecastSource
  let isLoadingWeather: Bool
  let weatherLocationName: String?
  let conflicts: [ConflictInfo]
  let isCheckingConflicts: Bool
  let conflictCheckTrigger: ConflictCheckTrigger
  let conflictThresholdMinutes: Int
  let newEventTitle: String
  let newEventEmoji: String?
  let newEventStartAt: Date
  let newEventEndAt: Date?

  public init(
    isPro: Bool = false,
    hasCheckedConflicts: Bool = false,
    weatherForecast: HourlyForecast? = nil,
    rangeForecasts: [HourlyForecast] = [],
    forecastSource: ForecastSource = .shortTerm,
    isLoadingWeather: Bool = false,
    weatherLocationName: String? = nil,
    conflicts: [ConflictInfo] = [],
    isCheckingConflicts: Bool = false,
    conflictCheckTrigger: ConflictCheckTrigger = .initial,
    conflictThresholdMinutes: Int = 0,
    newEventTitle: String = "",
    newEventEmoji: String? = nil,
    newEventStartAt: Date = .now,
    newEventEndAt: Date? = nil
  ) {
    self.isPro = isPro
    self.hasCheckedConflicts = hasCheckedConflicts
    self.weatherForecast = weatherForecast
    self.rangeForecasts = rangeForecasts
    self.forecastSource = forecastSource
    self.isLoadingWeather = isLoadingWeather
    self.weatherLocationName = weatherLocationName
    self.conflicts = conflicts
    self.isCheckingConflicts = isCheckingConflicts
    self.conflictCheckTrigger = conflictCheckTrigger
    self.conflictThresholdMinutes = conflictThresholdMinutes
    self.newEventTitle = newEventTitle
    self.newEventEmoji = newEventEmoji
    self.newEventStartAt = newEventStartAt
    self.newEventEndAt = newEventEndAt
  }

  private var hasContent: Bool {
    isPro
    || weatherForecast != nil
    || isLoadingWeather
    || isCheckingConflicts
    || !conflicts.isEmpty
  }

  public var body: some View {
    if hasContent {
      VStack(alignment: .leading, spacing: 4) {
        // PRO 뱃지
        proBadge

        // 날씨 (로딩 / 결과 / 불가 — 상호 배타)
        if let forecast = weatherForecast {
          ProWeatherRow(
            forecast: forecast,
            rangeForecasts: rangeForecasts,
            forecastSource: forecastSource
          )
        } else if isLoadingWeather {
          weatherLoadingRow
        } else if isPro {
          weatherUnavailableRow
        }

        // 충돌 (확인중 / 결과 / 없음 — 상호 배타)
        if isCheckingConflicts || !conflicts.isEmpty {
          ProConflictRow(
            conflicts: conflicts,
            isChecking: isCheckingConflicts,
            checkTrigger: conflictCheckTrigger,
            eventTitle: newEventTitle,
            eventEmoji: newEventEmoji,
            eventStartAt: newEventStartAt,
            eventEndAt: newEventEndAt
          )
        } else if isPro && hasCheckedConflicts {
          noConflictRow
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .proGlassCard(cornerRadius: 12)
      .padding(.bottom, 4)
    }
  }

  // MARK: - Pro Badge

  private var proBadge: some View {
    ProBadge()
  }

  // MARK: - Weather Unavailable Row

  private var weatherUnavailableRow: some View {
    HStack(spacing: 6) {
      Image(systemName: weatherLocationName == nil ? "cloud.sun" : "cloud.slash")
        .symbolRenderingMode(.multicolor)
        .font(.system(size: 12))
        .foregroundStyle(.tertiary)
        .frame(width: 22, height: 22)

      if weatherLocationName == nil {
        Text("장소를 설정하면 날씨를 확인해드릴 수 있어요!")
          .font(.system(size: 12))
          .foregroundStyle(.tertiary)
      } else {
        Text("10일 이내 약속만 날씨를 확인할 수 있어요")
          .font(.system(size: 12))
          .foregroundStyle(.tertiary)
      }

      Spacer(minLength: 0)
    }
  }

  // MARK: - No Conflict Row

  private var noConflictRow: some View {
    HStack(spacing: 6) {
      Image(systemName: "checkmark.circle.fill")
        .font(.system(size: 14))
        .foregroundStyle(Color.pmsuccess.n500)

      Text(noConflictText)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)

      Spacer(minLength: 0)
    }
  }

  private var noConflictText: String {
    if conflictThresholdMinutes > 0 {
      return "전후 \(conflictThresholdMinutes)분 내 겹치는 일정이 없어요"
    }
    return "겹치는 일정이 없어요"
  }

  // MARK: - Weather Loading Row

  @ViewBuilder
  private var weatherLoadingRow: some View {
    HStack(spacing: 6) {
      ProgressView()
        .scaleEffect(0.7)
        .frame(width: 14, height: 14)

      if let name = weatherLocationName {
        Text(LocalizedStrings.Shared.weatherCheckingWithLocation(name))
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      } else {
        Text(LocalizedStrings.Shared.weatherChecking)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 0)
    }
  }

}

// MARK: - Previews

#Preview("날씨 로딩") {
  VStack {
    Spacer()
    ProBonusFloatingView(
      isLoadingWeather: true,
      weatherLocationName: "강남역"
    )
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
  }
}

#Preview("날씨") {
  VStack {
    Spacer()
    ProBonusFloatingView(
      weatherForecast: HourlyForecast(
        dateTime: Date(),
        temperature: 15,
        feelsLikeTemperature: 12,
        condition: .cloudy,
        precipitationProbability: 60,
        humidity: 70,
        windSpeed: 3.5
      )
    )
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
  }
}

#Preview("충돌 1건") {
  VStack {
    Spacer()
    ProBonusFloatingView(
      conflicts: [
        ConflictInfo(title: "팀 회의", overlapMinutes: 30)
      ]
    )
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
  }
}

#Preview("충돌 여러 건") {
  VStack {
    Spacer()
    ProBonusFloatingView(
      conflicts: [
        ConflictInfo(title: "팀 회의", overlapMinutes: 30),
        ConflictInfo(title: "점심 약속", overlapMinutes: 60)
      ]
    )
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
  }
}

#Preview("충돌 확인 중") {
  VStack {
    Spacer()
    ProBonusFloatingView(
      isCheckingConflicts: true
    )
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
  }
}

#Preview("전체 정보") {
  VStack {
    Spacer()
    ProBonusFloatingView(
      weatherForecast: HourlyForecast(
        dateTime: Date(),
        temperature: 8,
        feelsLikeTemperature: 5,
        condition: .rain,
        precipitationProbability: 80,
        humidity: 85,
        windSpeed: 6.0
      ),
      conflicts: [
        ConflictInfo(title: "스터디 모임", overlapMinutes: 45)
      ]
    )
    .padding(.horizontal, 16)
    .padding(.bottom, 8)
  }
}

#Preview("Pro 빈 상태") {
  VStack {
    Spacer()
    ProBonusFloatingView(isPro: true, hasCheckedConflicts: true)
      .padding(.horizontal, 16)
      .padding(.bottom, 8)
  }
}

#Preview("날씨 아이콘 전체") {
  ScrollView {
    VStack(spacing: 8) {
      ForEach(WeatherCondition.allCases, id: \.self) { condition in
        ProBonusFloatingView(
          weatherForecast: HourlyForecast(
            dateTime: Date(),
            temperature: 15,
            feelsLikeTemperature: 12,
            condition: condition,
            precipitationProbability: 50,
            humidity: 60,
            windSpeed: 3.0
          )
        )
      }
    }
    .padding(.horizontal, 16)
  }
}
