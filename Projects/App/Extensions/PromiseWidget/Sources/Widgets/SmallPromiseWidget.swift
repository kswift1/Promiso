import AppIntents
import PromisoShared
import ResourceKit
import SwiftUI
import WidgetKit

/// 작은 크기 위젯 (2x2) - 다음 약속 1개 표시
struct SmallPromiseWidget: Widget {
  let kind: String = "SmallPromiseWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: PromiseTimelineProvider()) { entry in
      SmallPromiseWidgetView(entry: entry)
        .containerBackground(for: .widget) {
          widgetBackground
        }
        .widgetAccentable()
    }
    .configurationDisplayName("다음 약속")
    .description("다음 약속을 확인하세요")
    .supportedFamilies([.systemSmall])
  }

  @ViewBuilder
  private var widgetBackground: some View {
    if #available(iOS 26.0, *) {
      Color.clear.glassEffect(.regular)
    } else {
      Color(.systemBackground).opacity(0.9)
    }
  }
}

struct SmallPromiseWidgetView: View {
  let entry: WidgetPromiseEntry

  var body: some View {
    Group {
      switch entry.state {
      case .notLoggedIn:
        NotLoggedInView()
      case .empty:
        EmptyWidgetView(
          icon: "calendar.badge.clock",
          message: "예정된 약속이 없어요",
          hint: "새 약속을 만들어보세요"
        )
      case .loaded:
        if let promise = entry.nextPromise {
          promiseView(promise)
        } else {
          EmptyWidgetView(
            icon: "calendar.badge.clock",
            message: "예정된 약속이 없어요",
            hint: "새 약속을 만들어보세요"
          )
        }
      }
    }
  }

  @ViewBuilder
  private func promiseView(_ promise: WidgetPromiseData) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      // 헤더: 이모지 + D-Day 배지
      HStack(alignment: .top) {
        Text(promise.emoji)
          .font(.system(size: 36))

        Spacer()

        dDayBadge(promise.startAt)
      }

      Spacer(minLength: 8)

      // 제목
      Text(promise.title)
        .font(.subheadline.weight(.semibold))
        .lineLimit(2)
        .foregroundStyle(.primary)

      Spacer().frame(height: 4)

      // 시간 (강조)
      Text(formatTime(promise.startAt))
        .font(.title3.weight(.bold))
        .foregroundStyle(accentColor)

      // 장소
      if let location = promise.location {
        HStack(spacing: 3) {
          Image(systemName: "location.fill")
            .font(.system(size: 9))
          Text(location)
            .lineLimit(1)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.top, 2)
      }
    }
    .padding()
  }

  // MARK: - D-Day Badge

  @ViewBuilder
  private func dDayBadge(_ date: Date) -> some View {
    let calendar = Calendar.current

    Group {
      if calendar.isDateInToday(date) {
        Text("오늘")
          .font(.caption.weight(.bold))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(accentColor, in: Capsule())
      } else if calendar.isDateInTomorrow(date) {
        Text("내일")
          .font(.caption.weight(.medium))
          .foregroundStyle(accentColor)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(accentColor.opacity(0.15), in: Capsule())
      } else {
        let days = calendar.dateComponents(
          [.day],
          from: calendar.startOfDay(for: Date()),
          to: calendar.startOfDay(for: date)
        ).day ?? 0
        Text("D-\(days)")
          .font(.caption.weight(.medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.secondary.opacity(0.15), in: Capsule())
      }
    }
  }

  // MARK: - Helpers

  private var accentColor: Color {
    Color.pmindigo.n500
  }

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }
}


#if DEBUG
#Preview("다음 약속", as: .systemSmall) {
  SmallPromiseWidget()
} timeline: {
  WidgetPromiseEntry.previewToday
}

#Preview("약속 없음", as: .systemSmall) {
  SmallPromiseWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .empty)
}

#Preview("로그인 필요", as: .systemSmall) {
  SmallPromiseWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .notLoggedIn)
}
#endif
