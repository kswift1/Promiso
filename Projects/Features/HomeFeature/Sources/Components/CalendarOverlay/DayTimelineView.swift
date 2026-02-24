import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Day Timeline View

/// 00~24시 전체 시간을 수직 축으로 표시하는 타임라인 뷰
struct DayTimelineView: View {
  let scheduleItems: [HomeModels.ScheduleItem]
  let onScheduleItemTapped: (HomeModels.ScheduleItem) -> Void

  // MARK: - Constants

  private let hourHeight: CGFloat = 52
  private let timeLabelWidth: CGFloat = 44
  private let blockMinHeight: CGFloat = 48
  private let colorBarWidth: CGFloat = 4
  private let totalHours: Int = 24

  private var totalHeight: CGFloat {
    CGFloat(totalHours) * hourHeight
  }

  // MARK: - Body

  var body: some View {
    timelineContent
  }

  // MARK: - Timeline Content

  private var timelineContent: some View {
    ScrollView(.vertical, showsIndicators: false) {
      ZStack(alignment: .topLeading) {
        // Layer 1: 시간 눈금 + 구분선
        timeGrid

        // Layer 2: 일정 블록들
        ForEach(scheduleItems) { item in
          scheduleBlock(item)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, timeLabelWidth + 16)
            .padding(.trailing, 4)
            .offset(y: yOffset(for: item.startAt))
        }
      }
      .frame(width: nil, height: totalHeight)
      .padding(.horizontal, 20)
    }
  }

  // MARK: - Time Grid

  private var timeGrid: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(0..<totalHours, id: \.self) { hour in
        HStack(alignment: .top, spacing: 8) {
          // 시간 레이블
          Text(String(format: "%02d:00", hour))
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.tertiary)
            .frame(width: timeLabelWidth, alignment: .trailing)

          // 구분선
          VStack(spacing: 0) {
            Rectangle()
              .fill(Color(.separator).opacity(0.12))
              .frame(height: 0.5)
            Spacer()
          }
        }
        .frame(height: hourHeight)
      }
    }
    .frame(height: totalHeight)
  }

  // MARK: - Schedule Block

  private func scheduleBlock(_ item: HomeModels.ScheduleItem) -> some View {
    let blockHeight = blockHeight(for: item)

    return Button {
      onScheduleItemTapped(item)
    } label: {
      HStack(spacing: 0) {
        // 좌측 컬러 바
        RoundedRectangle(cornerRadius: 2)
          .fill(barColor(for: item))
          .frame(width: colorBarWidth)

        VStack(alignment: .leading, spacing: 3) {
          HStack(spacing: 6) {
            Text(item.displayEmoji)
              .font(.system(size: 16))

            Text(item.title)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.primary)
              .lineLimit(1)
          }

          HStack(spacing: 5) {
            Text(timeRangeString(for: item))
              .font(.system(size: 10, weight: .medium, design: .monospaced))
              .foregroundStyle(Color.pmgray.n600)

            if let name = groupName(for: item) {
              Text("·")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
              Text(name)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)

        Spacer(minLength: 0)
      }
      .frame(height: blockHeight)
      .background(blockBackground(for: item))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Helpers

  /// 시간 기반 y 좌표 계산
  private func yOffset(for date: Date) -> CGFloat {
    let calendar = Calendar.promiseDisplay
    let hour = calendar.component(.hour, from: date)
    let minute = calendar.component(.minute, from: date)
    return (CGFloat(hour) + CGFloat(minute) / 60.0) * hourHeight
  }

  /// 일정 블록 높이 (duration 기반, 최소 blockMinHeight)
  private func blockHeight(for item: HomeModels.ScheduleItem) -> CGFloat {
    guard let endAt = item.endAt else {
      return blockMinHeight
    }
    let duration = endAt.timeIntervalSince(item.startAt)
    let hours = duration / 3600.0
    let calculatedHeight = CGFloat(hours) * hourHeight
    return max(blockMinHeight, calculatedHeight)
  }

  /// 블록 배경색 (타입별 연한 색상)
  private func blockBackground(for item: HomeModels.ScheduleItem) -> Color {
    switch item {
    case .promise:
      return Color.pmindigo.n50
    case .personalEvent:
      return Color.pminfo.n50
    }
  }

  private func barColor(for item: HomeModels.ScheduleItem) -> Color {
    switch item {
    case .promise:
      return Color.pmindigo.n500
    case .personalEvent:
      return Color.pminfo.n500
    }
  }

  private func groupName(for item: HomeModels.ScheduleItem) -> String? {
    switch item {
    case .promise(let p):
      return p.group?.name
    case .personalEvent:
      return nil
    }
  }

  private func timeRangeString(for item: HomeModels.ScheduleItem) -> String {
    let start = timeString(for: item.startAt)
    if let end = item.endAt {
      return "\(start) - \(timeString(for: end))"
    }
    return start
  }

  private func timeString(for date: Date) -> String {
    Formatters.time.string(from: date)
  }

  // MARK: - Formatters

  private enum Formatters {
    static let displayTimeZone = Calendar.promiseDisplay.timeZone
    static let time: DateFormatter = {
      let f = DateFormatter()
      f.locale = Locale(identifier: "en_US_POSIX")
      f.timeZone = displayTimeZone
      f.dateFormat = "HH:mm"
      return f
    }()
  }
}

// MARK: - Preview

#Preview("일정 있음") {
  let calendar = Calendar.promiseDisplay
  let today = Date()

  let items: [HomeModels.ScheduleItem] = [
    .promise(PromiseModel.mock(
      id: "1",
      title: "팀 미팅",
      emoji: "🤝",
      hostId: "host1",
      groupId: "g1",
      group: GroupModel(
        id: "g1",
        name: "개발팀",
        maxMembers: 10,
        inviteCode: "code1",
        createdBy: "host1"
      ),
      startAt: calendar.date(bySettingHour: 8, minute: 0, second: 0, of: today)!,
      endAt: calendar.date(bySettingHour: 9, minute: 0, second: 0, of: today)
    )),
    .personalEvent(PersonalEventModel.mock(
      id: "2",
      title: "독서",
      emoji: "📚",
      startAt: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: today)!,
      endAt: calendar.date(bySettingHour: 11, minute: 30, second: 0, of: today)
    )),
    .promise(PromiseModel.mock(
      id: "3",
      title: "점심 약속",
      emoji: "🍽️",
      hostId: "host1",
      groupId: "g2",
      group: GroupModel(
        id: "g2",
        name: "친구들",
        maxMembers: 5,
        inviteCode: "code2",
        createdBy: "host1"
      ),
      startAt: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: today)!,
      endAt: nil
    )),
  ]

  DayTimelineView(
    scheduleItems: items,
    onScheduleItemTapped: { _ in }
  )
  .auroraBackground()
}

#Preview("일정 없음") {
  DayTimelineView(
    scheduleItems: [],
    onScheduleItemTapped: { _ in }
  )
  .auroraBackground()
}
