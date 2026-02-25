import SwiftUI
import PromisoShared

// MARK: - Current Time Marker View

/// 일정 사이 빈 시간에 현재 위치를 표시하는 마커
struct CurrentTimeMarkerView: View {
  let nextPromiseStartAt: Date

  @State private var currentTime = Date()

  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      // 타임라인 인디케이터 (TimelineItemView와 동일 구조)
      timelineIndicator

      // 현재 시간 + 다음 일정까지 남은 시간
      VStack(spacing: 0) {
        HStack(alignment: .top, spacing: 0) {
          currentTimeLabel
            .frame(width: 80, alignment: .center)
            .padding(.leading, 8)

          nextScheduleInfo
            .padding(.leading, 8)

          Spacer(minLength: 0)
        }
        .padding(.vertical, 8)

        // Divider (TimelineItemView와 동일)
        Rectangle()
          .fill(Color.pmgray.n200)
          .frame(height: 0.5)
          .padding(.leading, 8)
          .padding(.trailing, 16)
      }
    }
    .onAppear {
      currentTime = Date()
    }
  }

  // MARK: - Timeline Indicator

  private var timelineIndicator: some View {
    VStack(spacing: 0) {
      // 상단 라인 (TimelineItemView와 동일)
      Rectangle()
        .fill(Color.pmindigo.n300.opacity(0.5))
        .frame(width: 2, height: 10)

      // 현재 위치 dot (강조)
      Circle()
        .fill(Color.pmindigo.n500)
        .frame(width: 10, height: 10)
        .overlay {
          Circle()
            .stroke(Color.pmindigo.n500.opacity(0.3), lineWidth: 3)
            .frame(width: 16, height: 16)
        }

      // 하단 라인 (TimelineItemView와 동일하게 남은 공간 채움)
      Rectangle()
        .fill(Color.pmindigo.n300.opacity(0.5))
        .frame(width: 2)
        .frame(maxHeight: .infinity)
    }
    .frame(width: 16)
  }

  // MARK: - Current Time Label

  private var currentTimeLabel: some View {
    Text(currentTime.formattedTime)
      .font(.pmSubheadlineSemibold)
      .foregroundStyle(Color.pmindigo.n500)
  }

  // MARK: - Next Schedule Info

  private var nextScheduleInfo: some View {
    VStack(alignment: .leading, spacing: 2) {
      let remaining = remainingTimeString(until: nextPromiseStartAt)
      Text(LocalizedStrings.Home.nextScheduleUntil)
        .font(.pmCaption)
        .foregroundStyle(.secondary)

      Text(remaining)
        .font(.pmBodySemibold)
        .foregroundStyle(Color.pmindigo.n500)
    }
  }

  // MARK: - Helper

  private func remainingTimeString(until date: Date) -> String {
    let interval = date.timeIntervalSince(currentTime)

    guard interval > 0 else { return LocalizedStrings.Home.startingSoon }

    let hours = Int(interval) / 3600
    let minutes = (Int(interval) % 3600) / 60

    if hours > 0 {
      return LocalizedStrings.Home.hoursMinutes(hours, minutes)
    } else {
      return LocalizedStrings.Home.minutesOnly(minutes)
    }
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 0) {
    CurrentTimeMarkerView(
      nextPromiseStartAt: Date().addingTimeInterval(4 * 3600)
    )
  }
  .padding()
  .auroraBackground()
}
