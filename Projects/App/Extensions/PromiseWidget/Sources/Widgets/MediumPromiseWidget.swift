import AppIntents
import PromisoShared
import ResourceKit
import SwiftUI
import WidgetKit

/// 중간 크기 위젯 (4x2) - 오늘 약속 2-3개 표시
struct MediumPromiseWidget: Widget {
  let kind: String = "MediumPromiseWidget"

  var body: some WidgetConfiguration {
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
    Group {
      switch entry.state {
      case .notLoggedIn:
        NotLoggedInView()
      case .empty:
        EmptyWidgetView(
          icon: "calendar.badge.clock",
          message: "오늘 예정된 약속이 없어요",
          hint: "새 약속을 만들어보세요"
        )
      case .error:
        ErrorWidgetView()
      case .loaded:
        contentView
      }
    }
  }

  @ViewBuilder
  private var contentView: some View {
    let promises = Array(entry.todayPromises.prefix(3))

    if promises.isEmpty {
      // 오늘 약속이 없으면 다가오는 약속 표시
      let upcoming = Array(entry.upcomingPromises.prefix(3))
      if upcoming.isEmpty {
        EmptyWidgetView(
          icon: "calendar.badge.clock",
          message: "예정된 약속이 없어요",
          hint: "새 약속을 만들어보세요"
        )
      } else {
        upcomingView(upcoming)
      }
    } else {
      todayView(promises)
    }
  }

  @ViewBuilder
  private func todayView(_ promises: [WidgetPromiseData]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      // 섹션 헤더
      sectionHeader(title: "오늘", icon: "sun.max.fill", count: promises.count)

      // 약속 목록
      ForEach(promises) { promise in
        if let url = promise.deeplinkURL {
          Link(destination: url) {
            todayRow(promise)
          }
        } else {
          todayRow(promise)
        }
      }

      Spacer(minLength: 0)
    }
    .padding()
    .overlay(alignment: .bottomTrailing) {
      WidgetFooterView(updatedAt: entry.date)
    }
  }

  @ViewBuilder
  private func upcomingView(_ promises: [WidgetPromiseData]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      // 섹션 헤더
      sectionHeader(title: "다가오는 약속", icon: "calendar", count: promises.count)

      // 약속 목록
      ForEach(promises) { promise in
        if let url = promise.deeplinkURL {
          Link(destination: url) {
            upcomingRow(promise)
          }
        } else {
          upcomingRow(promise)
        }
      }

      Spacer(minLength: 0)
    }
    .padding()
    .overlay(alignment: .bottomTrailing) {
      WidgetFooterView(updatedAt: entry.date)
    }
  }

  // MARK: - Section Header

  @ViewBuilder
  private func sectionHeader(title: String, icon: String, count: Int) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.pmindigo.n500)

      Text(title)
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.primary)

      Text("\(count)")
        .font(.caption.weight(.medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.pmindigo.n500, in: Capsule())

      Spacer()
    }
    .padding(.bottom, 4)
  }

  // MARK: - Row Views

  @ViewBuilder
  private func todayRow(_ promise: WidgetPromiseData) -> some View {
    HStack(spacing: 10) {
      // 이모지
      Text(promise.emoji)
        .font(.system(size: 22))
        .frame(width: 26)

      // 제목 + 장소
      VStack(alignment: .leading, spacing: 1) {
        Text(promise.title)
          .font(.subheadline.weight(.medium))
          .lineLimit(1)
          .foregroundStyle(.primary)

        if let location = promise.location {
          HStack(spacing: 2) {
            Image(systemName: "location.fill")
              .font(.system(size: 8))
            Text(location)
              .lineLimit(1)
          }
          .font(.caption2)
          .foregroundStyle(.secondary)
        }
      }

      Spacer(minLength: 4)

      // 시간 (강조)
      Text(formatTime(promise.startAt))
        .font(.subheadline.weight(.bold))
        .foregroundStyle(Color.pmindigo.n500)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel(for: promise, isToday: true))
  }

  @ViewBuilder
  private func upcomingRow(_ promise: WidgetPromiseData) -> some View {
    HStack(spacing: 10) {
      // 이모지
      Text(promise.emoji)
        .font(.system(size: 20))
        .frame(width: 24)

      // 제목
      Text(promise.title)
        .font(.subheadline)
        .lineLimit(1)
        .foregroundStyle(.primary)

      Spacer(minLength: 4)

      // 날짜 배지
      dateBadge(promise.startAt)
    }
    .contentShape(Rectangle())
    .accessibilityElement(children: .combine)
    .accessibilityLabel(accessibilityLabel(for: promise, isToday: false))
  }

  // MARK: - Date Badge

  @ViewBuilder
  private func dateBadge(_ date: Date) -> some View {
    let calendar = Calendar.current

    HStack(spacing: 3) {
      if calendar.isDateInTomorrow(date) {
        Text("내일")
          .font(.caption.weight(.medium))
          .foregroundStyle(Color.pmindigo.n500)
      } else {
        Text(formatShortDate(date))
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Text(formatTime(date))
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }

  // MARK: - Date Formatting

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }

  private func formatShortDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M/d"
    return formatter.string(from: date)
  }

  // MARK: - Accessibility

  private func accessibilityLabel(for promise: WidgetPromiseData, isToday: Bool) -> String {
    let calendar = Calendar.current
    var components: [String] = []

    // 날짜
    if isToday {
      components.append("오늘")
    } else if calendar.isDateInTomorrow(promise.startAt) {
      components.append("내일")
    } else {
      components.append(formatShortDate(promise.startAt))
    }

    // 시간
    components.append(formatTime(promise.startAt))

    // 제목
    components.append(promise.title)

    // 장소
    if let location = promise.location {
      components.append(location)
    }

    return components.joined(separator: ", ")
  }
}

#if DEBUG
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
#endif
