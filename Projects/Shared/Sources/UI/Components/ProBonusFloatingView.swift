import SwiftUI
import ResourceKit

// MARK: - Conflict Info

/// 일정 충돌 표시용 경량 모델 (PromisoShared 내부 전용)
/// Clients.ScheduleConflict 를 Feature에서 변환하여 전달합니다.
public struct ConflictInfo: Equatable, Sendable {
  public let title: String
  public let overlapMinutes: Int

  public init(title: String, overlapMinutes: Int) {
    self.title = title
    self.overlapMinutes = overlapMinutes
  }
}

// MARK: - Pro Bonus Floating View

/// Pro Plan 보너스 정보 플로팅 뷰
///
/// 날씨, 일정 충돌 힌트를 하단 버튼 위에 표시합니다.
/// 추후 Pro Plan 전용으로 변경될 수 있으므로 이름을 ProBonusFloatingView로 유지합니다.
public struct ProBonusFloatingView: View {
  let weatherForecast: HourlyForecast?
  let weatherAdvice: String?
  let conflicts: [ConflictInfo]
  let isCheckingConflicts: Bool

  public init(
    weatherForecast: HourlyForecast? = nil,
    weatherAdvice: String? = nil,
    conflicts: [ConflictInfo] = [],
    isCheckingConflicts: Bool = false
  ) {
    self.weatherForecast = weatherForecast
    self.weatherAdvice = weatherAdvice
    self.conflicts = conflicts
    self.isCheckingConflicts = isCheckingConflicts
  }

  private var hasContent: Bool {
    weatherForecast != nil
    || isCheckingConflicts
    || !conflicts.isEmpty
  }

  public var body: some View {
    if hasContent {
      VStack(alignment: .leading, spacing: 4) {
        // 날씨 행
        if let forecast = weatherForecast {
          weatherRow(forecast: forecast)
        }

        // 충돌 행
        if isCheckingConflicts || !conflicts.isEmpty {
          conflictRow
        }


      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .adaptiveGlassCard(cornerRadius: 12)
      .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
  }

  // MARK: - Weather Row

  @ViewBuilder
  private func weatherRow(forecast: HourlyForecast) -> some View {
    HStack(spacing: 6) {
      Image(systemName: forecast.condition.sfSymbolName)
        .symbolRenderingMode(.multicolor)
        .font(.system(size: 14))

      Text("\(Int(forecast.temperature.rounded()))°C")
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.primary)

      if let advice = weatherAdvice {
        Text("— \(advice)")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }

      Spacer(minLength: 0)
    }
  }

  // MARK: - Conflict Row

  @ViewBuilder
  private var conflictRow: some View {
    HStack(spacing: 6) {
      if isCheckingConflicts {
        ProgressView()
          .scaleEffect(0.7)
          .frame(width: 14, height: 14)

        Text("확인 중...")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
      } else if conflicts.count == 1, let first = conflicts.first {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 14))
          .foregroundStyle(Color.pmwarning.n500)

        Text("'\(first.title)'과(와) \(first.overlapMinutes)분 겹침")
          .font(.system(size: 13))
          .foregroundStyle(.primary)
          .lineLimit(1)
      } else if conflicts.count > 1 {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 14))
          .foregroundStyle(Color.pmwarning.n500)

        Text("\(conflicts.count)건의 일정 겹침")
          .font(.system(size: 13))
          .foregroundStyle(.primary)
      }

      Spacer(minLength: 0)
    }
  }

}

// MARK: - Previews

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
      ),
      weatherAdvice: "우산 챙기세요",
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
      weatherAdvice: "우산 필수",
      conflicts: [
        ConflictInfo(title: "스터디 모임", overlapMinutes: 45)
      ],
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
