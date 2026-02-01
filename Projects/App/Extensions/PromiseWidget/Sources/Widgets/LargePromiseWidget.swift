import AppIntents
import PromisoShared
import ResourceKit
import SwiftUI
import WidgetKit

/// 큰 크기 위젯 (4x4) - 오늘 + 다가오는 약속 표시
struct LargePromiseWidget: Widget {
  let kind: String = "LargePromiseWidget"

  var body: some WidgetConfiguration {
    // TODO: iOS 26 SDK에서 .pushHandler(PromiseWidgetPushHandler.self) 추가
    StaticConfiguration(kind: kind, provider: PromiseTimelineProvider()) { entry in
      LargePromiseWidgetView(entry: entry)
        .containerBackground(for: .widget) {
          widgetBackground
        }
        .widgetAccentable()
    }
    .configurationDisplayName("약속 일정")
    .description("오늘과 다가오는 약속을 한눈에 확인하세요")
    .supportedFamilies([.systemLarge])
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

struct LargePromiseWidgetView: View {
  let entry: WidgetPromiseEntry

  var body: some View {
    switch entry.state {
    case .notLoggedIn:
      NotLoggedInView()
    case .empty:
      EmptyWidgetView(message: "예정된 약속이 없어요")
    case .loaded:
      contentView
    }
  }

  @ViewBuilder
  private var contentView: some View {
    let todayPromises = Array(entry.todayPromises.prefix(3))
    let upcomingPromises = Array(entry.upcomingPromises.prefix(4))

    if todayPromises.isEmpty && upcomingPromises.isEmpty {
      EmptyWidgetView(message: "예정된 약속이 없어요")
    } else {
      VStack(alignment: .leading, spacing: 12) {
        // 헤더 (기준 시간 + 새로고침)
        HStack {
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

        // 오늘 섹션
        if !todayPromises.isEmpty {
          sectionHeader("📅 오늘", count: todayPromises.count)
          Divider()
          ForEach(todayPromises) { promise in
            if let url = promise.deeplinkURL {
              Link(destination: url) {
                todayPromiseRow(promise)
              }
            }
          }
        }

        // 다가오는 약속 섹션
        if !upcomingPromises.isEmpty {
          if !todayPromises.isEmpty {
            Spacer().frame(height: 8)
          }
          sectionHeader("📅 다가오는 약속", count: upcomingPromises.count)
          Divider()
          ForEach(upcomingPromises) { promise in
            if let url = promise.deeplinkURL {
              Link(destination: url) {
                upcomingPromiseRow(promise)
              }
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
  }

  @ViewBuilder
  private func sectionHeader(_ title: String, count: Int) -> some View {
    HStack {
      Text(title)
        .font(.subheadline.bold())
      
      Text("(\(count))")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Spacer()
    }
  }

  @ViewBuilder
  private func todayPromiseRow(_ promise: WidgetPromiseData) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        Text(promise.emoji)
          .font(.body)
        Text(promise.title)
          .font(.subheadline.bold())
          .lineLimit(1)
        Spacer()
        Text(formatTime(promise.startAt))
          .font(.subheadline.bold())
          .foregroundStyle(Color.pmindigo.n500)
      }

      HStack(spacing: 4) {
        if let location = promise.location {
          Text(location)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        if promise.participantCount > 0 {
          Text("· \(promise.participantCount)명")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .padding(.leading, 28)
    }
    .contentShape(Rectangle())
  }

  @ViewBuilder
  private func upcomingPromiseRow(_ promise: WidgetPromiseData) -> some View {
    HStack(spacing: 8) {
      Text(promise.emoji)
        .font(.body)
      Text(promise.title)
        .font(.subheadline)
        .lineLimit(1)
      Spacer()
      Text(formatDateWithTime(promise.startAt))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .contentShape(Rectangle())
  }

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }

  private func formatDateWithTime(_ date: Date) -> String {
    let calendar = Calendar.current
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")

    if calendar.isDateInTomorrow(date) {
      formatter.dateFormat = "내일 a h:mm"
    } else {
      formatter.dateFormat = "M/d a h:mm"
    }
    return formatter.string(from: date)
  }

  private func formatUpdatedTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm 기준"
    return formatter.string(from: date)
  }
}

#if DEBUG
#Preview("전체 약속", as: .systemLarge) {
  LargePromiseWidget()
} timeline: {
  WidgetPromiseEntry.previewFull
}

#Preview("오늘만", as: .systemLarge) {
  LargePromiseWidget()
} timeline: {
  WidgetPromiseEntry.previewToday
}

#Preview("다가오는 약속만", as: .systemLarge) {
  LargePromiseWidget()
} timeline: {
  WidgetPromiseEntry.previewUpcoming
}

#Preview("약속 없음", as: .systemLarge) {
  LargePromiseWidget()
} timeline: {
  WidgetPromiseEntry(date: Date(), promises: [], state: .empty)
}
#endif
