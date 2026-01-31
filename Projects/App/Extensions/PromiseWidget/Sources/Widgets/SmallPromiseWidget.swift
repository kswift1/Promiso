import AppIntents
import PromisoShared
import ResourceKit
import SwiftUI
import WidgetKit

/// 작은 크기 위젯 (2x2) - 다음 약속 1개 표시
struct SmallPromiseWidget: Widget {
  let kind: String = "SmallPromiseWidget"

  var body: some WidgetConfiguration {
    // TODO: iOS 26 SDK에서 .pushHandler(PromiseWidgetPushHandler.self) 추가
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
    switch entry.state {
    case .notLoggedIn:
      NotLoggedInView()
    case .empty:
      EmptyWidgetView(message: "예정된 약속이 없어요")
    case .loaded:
      if let promise = entry.nextPromise {
        promiseView(promise)
      } else {
        EmptyWidgetView(message: "예정된 약속이 없어요")
      }
    }
  }

  @ViewBuilder
  private func promiseView(_ promise: WidgetPromiseData) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(promise.emoji)
        .font(.title2)

      Spacer()

      Text(promise.title)
        .font(.subheadline.bold())
        .lineLimit(2)

      Text(formatTime(promise.startAt))
        .font(.headline)
        .foregroundStyle(Color.pmindigo.n500)

      if let location = promise.location {
        Text(location)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding()
  }

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }
}

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
