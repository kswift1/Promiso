import SwiftUI

// MARK: - Weather Card Strip (Level 1)

/// 카드 내 날씨 전용 영역 - 아이콘 + 온도 + 제안 순환
/// 탭하면 WeatherTooltip 팝오버 표시
public struct WeatherCardStrip: View {
  private let forecast: HourlyForecast
  private let rangeForecasts: [HourlyForecast]
  private let referenceTimeText: String?
  private let forecastSource: ForecastSource
  private let suggestions: [WeatherSuggestion]
  @State private var showTooltip = false
  @State private var currentIndex = 0

  public init(
    forecast: HourlyForecast,
    rangeForecasts: [HourlyForecast] = [],
    referenceTimeText: String? = nil,
    forecastSource: ForecastSource = .shortTerm
  ) {
    self.forecast = forecast
    self.rangeForecasts = rangeForecasts
    self.referenceTimeText = referenceTimeText
    self.forecastSource = forecastSource
    self.suggestions = WeatherSuggestion.from(forecast: forecast)
  }

  public var body: some View {
    Button {
      showTooltip = true
    } label: {
      HStack(spacing: 8) {
        Image(systemName: forecast.condition.sfSymbolName)
          .symbolRenderingMode(.multicolor)
          .font(.system(size: 16))

        Text("\(Int(forecast.temperature.rounded()))°")
          .font(.system(size: 14, weight: .bold))
          .foregroundStyle(.primary)
          .fixedSize()

        if !suggestions.isEmpty {
          MarqueeText(
            text: suggestions[currentIndex].message,
            font: .system(size: 12),
            color: .secondary
          )
          .id(currentIndex)
          .transition(.asymmetric(
            insertion: .opacity.combined(with: .move(edge: .bottom)),
            removal: .opacity.combined(with: .move(edge: .top))
          ))
        }

        Spacer(minLength: 0)

        Image(systemName: "info.circle")
          .font(.system(size: 14))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(stripBackground)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(forecast.condition.iconColor.opacity(0.15), lineWidth: 1)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .popover(isPresented: $showTooltip, arrowEdge: .bottom) {
      WeatherTooltip(
        forecast: forecast,
        rangeForecasts: rangeForecasts,
        referenceTimeText: referenceTimeText,
        forecastSource: forecastSource
      )
      .presentationCompactAdaptation(.popover)
    }
    .onAppear { startRotation() }
  }

  private var stripBackground: some ShapeStyle {
    forecast.condition.iconColor.opacity(0.1)
  }

  private func startRotation() {
    guard suggestions.count > 1 else { return }
    Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
      withAnimation(.easeInOut(duration: 0.4)) {
        currentIndex = (currentIndex + 1) % suggestions.count
      }
    }
  }
}

// MARK: - Marquee Text

/// 텍스트가 잘릴 때 자동으로 좌우 스크롤하는 컴포넌트
private struct MarqueeText: View {
  let text: String
  let font: Font
  let color: Color

  @State private var textWidth: CGFloat = 0
  @State private var containerWidth: CGFloat = 0
  @State private var offset: CGFloat = 0
  @State private var animating = false

  private var isOverflowing: Bool {
    textWidth > containerWidth
  }

  var body: some View {
    GeometryReader { geo in
      Text(text)
        .font(font)
        .foregroundStyle(color)
        .lineLimit(1)
        .fixedSize()
        .background(
          GeometryReader { textGeo in
            Color.clear
              .onAppear {
                textWidth = textGeo.size.width
                containerWidth = geo.size.width
                startMarqueeIfNeeded()
              }
          }
        )
        .offset(x: offset)
    }
    .clipped()
    .frame(height: 16)
    .onChange(of: text) {
      offset = 0
      animating = false
      textWidth = 0
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        startMarqueeIfNeeded()
      }
    }
  }

  private func startMarqueeIfNeeded() {
    guard isOverflowing, !animating else { return }
    animating = true
    let overflow = textWidth - containerWidth
    let scrollDuration = Double(overflow) / 30.0

    // 1초 대기 → 스크롤 → 1.5초 대기 → 복귀 → 반복
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      withAnimation(.easeInOut(duration: scrollDuration)) {
        offset = -overflow
      }

      DispatchQueue.main.asyncAfter(deadline: .now() + scrollDuration + 1.5) {
        withAnimation(.easeInOut(duration: 0.3)) {
          offset = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + 1.0) {
          animating = false
          startMarqueeIfNeeded()
        }
      }
    }
  }
}

// MARK: - Preview

#Preview("비 오는 날") {
  VStack(spacing: 12) {
    WeatherCardStrip(
      forecast: HourlyForecast(
        dateTime: Date(),
        temperature: 14,
        feelsLikeTemperature: 10,
        condition: .rain,
        precipitationProbability: 80,
        humidity: 75,
        windSpeed: 6.0,
        precipitationAmount: "3mm"
      ),
      referenceTimeText: "2월 18일 14:30"
    )

    WeatherCardStrip(
      forecast: HourlyForecast(
        dateTime: Date(),
        temperature: 22,
        feelsLikeTemperature: 21,
        condition: .clear,
        precipitationProbability: 5,
        humidity: 50,
        windSpeed: 2.0
      ),
      referenceTimeText: "3월 5일 13:00"
    )

    WeatherCardStrip(
      forecast: HourlyForecast(
        dateTime: Date(),
        temperature: -5,
        feelsLikeTemperature: -12,
        condition: .snow,
        precipitationProbability: 90,
        humidity: 70,
        windSpeed: 8.5,
        precipitationAmount: "5cm"
      ),
      referenceTimeText: "1월 10일 09:00"
    )
  }
  .padding()
}
