import SwiftUI
import ResourceKit

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
  let weatherForecast: HourlyForecast?
  let rangeForecasts: [HourlyForecast]
  let forecastSource: ForecastSource
  let isLoadingWeather: Bool
  let weatherLocationName: String?
  let conflicts: [ConflictInfo]
  let isCheckingConflicts: Bool
  let newEventTitle: String
  let newEventEmoji: String?
  let newEventStartAt: Date
  let newEventEndAt: Date?

  @State private var showWeatherTooltip = false
  @State private var showConflictTooltip = false

  public init(
    weatherForecast: HourlyForecast? = nil,
    rangeForecasts: [HourlyForecast] = [],
    forecastSource: ForecastSource = .shortTerm,
    isLoadingWeather: Bool = false,
    weatherLocationName: String? = nil,
    conflicts: [ConflictInfo] = [],
    isCheckingConflicts: Bool = false,
    newEventTitle: String = "",
    newEventEmoji: String? = nil,
    newEventStartAt: Date = .now,
    newEventEndAt: Date? = nil
  ) {
    self.weatherForecast = weatherForecast
    self.rangeForecasts = rangeForecasts
    self.forecastSource = forecastSource
    self.isLoadingWeather = isLoadingWeather
    self.weatherLocationName = weatherLocationName
    self.conflicts = conflicts
    self.isCheckingConflicts = isCheckingConflicts
    self.newEventTitle = newEventTitle
    self.newEventEmoji = newEventEmoji
    self.newEventStartAt = newEventStartAt
    self.newEventEndAt = newEventEndAt
  }

  private var hasContent: Bool {
    weatherForecast != nil
    || isLoadingWeather
    || isCheckingConflicts
    || !conflicts.isEmpty
  }

  public var body: some View {
    if hasContent {
      VStack(alignment: .leading, spacing: 4) {
        // PRO 뱃지
        proBadge

        // 날씨 로딩 행
        if isLoadingWeather && weatherForecast == nil {
          weatherLoadingRow
        }

        // 날씨 행
        if let forecast = weatherForecast {
          weatherRow(forecast: forecast)
        }

        // 충돌 행
        if isCheckingConflicts || !conflicts.isEmpty {
          conflictRow
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .adaptiveGlassCard(cornerRadius: 12)
      .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
  }

  // MARK: - Pro Badge

  private var proBadge: some View {
    ProBadge()
  }

  // MARK: - Weather Loading Row

  @ViewBuilder
  private var weatherLoadingRow: some View {
    HStack(spacing: 6) {
      ProgressView()
        .scaleEffect(0.7)
        .frame(width: 14, height: 14)

      if let name = weatherLocationName {
        Text("\(name)의 약속시간대 날씨를 확인중이에요")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      } else {
        Text("약속시간대 날씨를 확인중이에요")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 0)
    }
  }

  // MARK: - Weather Row

  @ViewBuilder
  private func weatherRow(forecast: HourlyForecast) -> some View {
    Button {
      showWeatherTooltip = true
    } label: {
      HStack(spacing: 6) {
        Image(systemName: forecast.condition.sfSymbolName)
          .symbolRenderingMode(.multicolor)
          .font(.system(size: 12))
          .frame(width: 22, height: 22)
          .background(
            Circle()
              .fill(Color.cyan.opacity(0.12))
          )

        Text("\(Int(forecast.temperature.rounded()))°")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)

        Text(adviceMessage(for: forecast))
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(1)

        Spacer(minLength: 0)

        Image(systemName: "info.circle")
          .font(.system(size: 12))
          .foregroundStyle(.tertiary)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showWeatherTooltip, arrowEdge: .bottom) {
      WeatherTooltip(
        forecast: forecast,
        rangeForecasts: rangeForecasts,
        forecastSource: forecastSource
      )
      .presentationCompactAdaptation(.popover)
    }
  }

  // MARK: - Conflict Row

  @ViewBuilder
  private var conflictRow: some View {
    if isCheckingConflicts {
      HStack(spacing: 6) {
        ProgressView()
          .scaleEffect(0.7)
          .frame(width: 14, height: 14)

        Text("겹치는 일정이 있는지 확인중이에요")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)

        Spacer(minLength: 0)
      }
    } else if !conflicts.isEmpty {
      Button {
        showConflictTooltip = true
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 14))
            .foregroundStyle(Color.pmwarning.n500)

          if conflicts.count == 1, let first = conflicts.first {
            let text: String = {
              if first.overlapMinutes > 0 {
                return "'\(first.title)'과(와) \(first.overlapMinutes)분 겹쳐요"
              } else if first.gapMinutes > 0 {
                return "'\(first.title)'과(와) 여유 \(first.gapMinutes)분이에요"
              } else {
                return "'\(first.title)'과(와) 일정이 겹쳐요"
              }
            }()
            Text(text)
              .font(.system(size: 12))
              .foregroundStyle(.primary)
              .lineLimit(1)
          } else {
            Text("\(conflicts.count)건의 일정이 겹쳐요")
              .font(.system(size: 12))
              .foregroundStyle(.primary)
          }

          Spacer(minLength: 0)

          Image(systemName: "info.circle")
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .popover(isPresented: $showConflictTooltip, arrowEdge: .bottom) {
        ConflictTooltip(
          newEventTitle: newEventTitle,
          newEventEmoji: newEventEmoji,
          newEventStartAt: newEventStartAt,
          newEventEndAt: newEventEndAt,
          conflicts: conflicts
        )
        .presentationCompactAdaptation(.popover)
      }
    }
  }

  // MARK: - Helpers

  private func adviceMessage(for forecast: HourlyForecast) -> String {
    if let advice = WeatherAdvice.from(forecast: forecast).first {
      return advice.message
    }
    return forecast.condition.description
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

#Preview("정보 없음 (EmptyView)") {
  VStack {
    Spacer()
    ProBonusFloatingView()
      .padding(.horizontal, 16)
      .padding(.bottom, 8)
    Text("위에는 아무것도 렌더링되지 않아야 합니다")
      .font(.caption)
      .foregroundStyle(.secondary)
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
