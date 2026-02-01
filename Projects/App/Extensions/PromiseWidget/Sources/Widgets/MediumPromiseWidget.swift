import AppIntents
import PromisoShared
import ResourceKit
import SwiftUI
import WidgetKit

/// 중간 크기 위젯 (4x2) - 오늘 약속 2-3개 표시
struct MediumPromiseWidget: Widget {
  let kind: String = "MediumPromiseWidget"

  var body: some WidgetConfiguration {
    // TODO: iOS 26 SDK에서 .pushHandler(PromiseWidgetPushHandler.self) 추가
    StaticConfiguration(kind: kind, provider: PromiseTimelineProvider()) { entry in
      MediumPromiseWidgetView(entry: entry)
        .containerBackground(for: .widget) {
          widgetBackground
        }
        .widgetAccentable()
    }
    .configurationDisplayName("오늘의 약속")
    .description("오늘 예정된 약속을 확인하세요")
    .supportedFamilies([.systemMedium])
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

struct MediumPromiseWidgetView: View {
  let entry: WidgetPromiseEntry

  var body: some View {
    switch entry.state {
    case .notLoggedIn:
      NotLoggedInView()
    case .empty:
      EmptyWidgetView(message: "오늘 예정된 약속이 없어요")
    case .loaded:
      contentView
    }
  }

  @ViewBuilder
  private var contentView: some View {
    let promises = Array(entry.todayPromises.prefix(3))

    if promises.isEmpty {
      // 오늘 약속이 없으면 다가오는 약속 표시
      let upcoming = Array(entry.upcomingPromises.prefix(3))
      if upcoming.isEmpty {
        EmptyWidgetView(message: "예정된 약속이 없어요")
      } else {
        upcomingView(upcoming)
      }
    } else {
      todayView(promises)
    }
  }

  @ViewBuilder
  private func todayView(_ promises: [WidgetPromiseData]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("오늘의 약속")
          .font(.subheadline.bold())
        Text("(\(promises.count))")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
        
        if entry.hasStaleData {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.caption2)
            .foregroundStyle(.orange)
        }
        Text(formatUpdatedTime(entry.date))
          .font(.caption2)
          .foregroundStyle(.tertiary)
        Button(intent: RefreshWidgetIntent()) {
          Image(systemName: "arrow.clockwise")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }

      Divider()

      ForEach(promises) { promise in
        if let url = promise.deeplinkURL {
          Link(destination: url) {
            PromiseRowView(promise: promise)
          }
        }
      }

      Spacer(minLength: 0)
    }
    .padding()
    .overlay(alignment: .bottomTrailing) {
      HStack(spacing: 6) {
        if let lastUpdated = WidgetDataManager.lastUpdated() {
          Text(formatUpdatedTime(lastUpdated))
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        Button(intent: RefreshWidgetIntent()) {
          Image(systemName: "arrow.clockwise")
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(6)
            .background(Color.secondary.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
      }
    }
  }

  @ViewBuilder
  private func upcomingView(_ promises: [WidgetPromiseData]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("다가오는 약속")
          .font(.subheadline.bold())
        Text("(\(promises.count))")
          .font(.subheadline)
          .foregroundStyle(.secondary)
        Spacer()
        Text(formatUpdatedTime(entry.date))
          .font(.caption2)
          .foregroundStyle(.tertiary)
        Button(intent: RefreshWidgetIntent()) {
          Image(systemName: "arrow.clockwise")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }

      Divider()

      ForEach(promises) { promise in
        if let url = promise.deeplinkURL {
          Link(destination: url) {
            HStack(spacing: 8) {
              Text(promise.emoji)
                .font(.body)

              Text(promise.title)
                .font(.subheadline)
                .lineLimit(1)

              Spacer()

              Text(formatDate(promise.startAt))
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
          }
        }
      }

      Spacer(minLength: 0)
    }
    .padding()
    .overlay(alignment: .bottomTrailing) {
      HStack(spacing: 6) {
        if let lastUpdated = WidgetDataManager.lastUpdated() {
          Text(formatUpdatedTime(lastUpdated))
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        Button(intent: RefreshWidgetIntent()) {
          Image(systemName: "arrow.clockwise")
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
            .padding(6)
            .background(Color.secondary.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
      }
      .padding(8)
    }
  }

  private func formatDate(_ date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInTomorrow(date) {
      return "내일"
    }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M/d"
    return formatter.string(from: date)
  }

  private func formatUpdatedTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm 기준"
    return formatter.string(from: date)
  }
}

#Preview("오늘 약속", as: .systemMedium) {
  MediumPromiseWidget()
} timeline: {
  WidgetPromiseEntry.previewToday
}

#Preview("다가오는 약속", as: .systemMedium) {
  MediumPromiseWidget()
} timeline: {
  WidgetPromiseEntry.previewUpcoming
}

#Preview("약속 없음", as: .systemMedium) {
  MediumPromiseWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .empty)
}

#Preview("로그인 필요", as: .systemMedium) {
  MediumPromiseWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .notLoggedIn)
}
