import PromisoShared
import SwiftUI
import WidgetKit

// MARK: - Circular Widget (원형 잠금화면 위젯)

/// 원형 잠금화면 위젯 - D-Day 표시
struct CircularPromiseWidget: Widget {
  let kind: String = "CircularPromiseWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PromiseTimelineProvider()) { entry in
      CircularPromiseWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("다음 약속")
    .description("다음 약속까지 남은 일수")
    .supportedFamilies([.accessoryCircular])
  }
}

struct CircularPromiseWidgetView: View {
  let entry: WidgetPromiseEntry

  var body: some View {
    switch entry.state {
    case .notLoggedIn, .empty, .error:
      ZStack {
        AccessoryWidgetBackground()
        Image(systemName: "calendar")
          .font(.title2)
      }
      .accessibilityLabel("약속 없음")
    case .loaded:
      if let promise = entry.nextPromise {
        ZStack {
          AccessoryWidgetBackground()
          VStack(spacing: 0) {
            Text(promise.emoji)
              .font(.system(size: 16))
            Text(dDayText(promise.startAt))
              .font(.system(size: 12, weight: .bold))
              .minimumScaleFactor(0.8)
          }
        }
        .accessibilityLabel(accessibilityLabel(for: promise))
      } else {
        ZStack {
          AccessoryWidgetBackground()
          Image(systemName: "calendar")
            .font(.title2)
        }
        .accessibilityLabel("약속 없음")
      }
    }
  }

  private func dDayText(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return "오늘"
    } else if calendar.isDateInTomorrow(date) {
      return "내일"
    } else {
      let days = calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: Date()),
        to: calendar.startOfDay(for: date)
      ).day ?? 0
      return "D-\(days)"
    }
  }

  private func accessibilityLabel(for promise: WidgetPromiseData) -> String {
    "\(dDayText(promise.startAt)), \(promise.title)"
  }
}

// MARK: - Rectangular Widget (직사각형 잠금화면 위젯)

/// 직사각형 잠금화면 위젯 - 다음 약속 정보
struct RectangularPromiseWidget: Widget {
  let kind: String = "RectangularPromiseWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PromiseTimelineProvider()) { entry in
      RectangularPromiseWidgetView(entry: entry)
        .containerBackground(.clear, for: .widget)
    }
    .configurationDisplayName("다음 약속")
    .description("다음 약속 정보를 확인하세요")
    .supportedFamilies([.accessoryRectangular])
  }
}

struct RectangularPromiseWidgetView: View {
  let entry: WidgetPromiseEntry

  var body: some View {
    switch entry.state {
    case .notLoggedIn:
      emptyView(message: "로그인 필요")
    case .empty:
      emptyView(message: "예정된 약속 없음")
    case .error:
      emptyView(message: "데이터 로드 실패")
    case .loaded:
      if let promise = entry.nextPromise {
        promiseView(promise)
      } else {
        emptyView(message: "예정된 약속 없음")
      }
    }
  }

  @ViewBuilder
  private func emptyView(message: String) -> some View {
    HStack {
      Image(systemName: "calendar")
        .font(.title3)
      Text(message)
        .font(.headline)
    }
    .accessibilityLabel(message)
  }

  @ViewBuilder
  private func promiseView(_ promise: WidgetPromiseData) -> some View {
    HStack(alignment: .center, spacing: 8) {
      // 이모지 + D-Day
      VStack(spacing: 2) {
        Text(promise.emoji)
          .font(.system(size: 20))
        Text(dDayText(promise.startAt))
          .font(.system(size: 10, weight: .bold))
      }
      .frame(width: 36)

      // 제목 + 시간
      VStack(alignment: .leading, spacing: 2) {
        Text(promise.title)
          .font(.headline)
          .lineLimit(1)

        Text(formatTime(promise.startAt))
          .font(.subheadline)
      }

      Spacer(minLength: 0)
    }
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel(for: promise))
  }

  private func dDayText(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return "오늘"
    } else if calendar.isDateInTomorrow(date) {
      return "내일"
    } else {
      let days = calendar.dateComponents(
        [.day],
        from: calendar.startOfDay(for: Date()),
        to: calendar.startOfDay(for: date)
      ).day ?? 0
      return "D-\(days)"
    }
  }

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }

  private func accessibilityLabel(for promise: WidgetPromiseData) -> String {
    var components = [dDayText(promise.startAt), formatTime(promise.startAt), promise.title]
    if let location = promise.location {
      components.append(location)
    }
    return components.joined(separator: ", ")
  }
}

// MARK: - Previews

#if DEBUG
#Preview("Circular - 약속 있음", as: .accessoryCircular) {
  CircularPromiseWidget()
} timeline: {
  WidgetPromiseEntry.previewToday
}

#Preview("Circular - 약속 없음", as: .accessoryCircular) {
  CircularPromiseWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .empty)
}

#Preview("Rectangular - 약속 있음", as: .accessoryRectangular) {
  RectangularPromiseWidget()
} timeline: {
  WidgetPromiseEntry.previewToday
}

#Preview("Rectangular - 약속 없음", as: .accessoryRectangular) {
  RectangularPromiseWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .empty)
}
#endif
