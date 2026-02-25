import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Day Timeline View

/// 00~24시 전체 시간을 수직 축으로 표시하는 타임라인 뷰
struct DayTimelineView: View {
  let scheduleItems: [HomeModels.ScheduleItem]
  let onScheduleItemTapped: (HomeModels.ScheduleItem) -> Void
  let currentUserId: String
  let weatherCache: [String: WeatherInfo]
  let groupColorMap: [String: Color]

  // MARK: - Constants

  private let hourHeight: CGFloat = 52
  private let timeLabelWidth: CGFloat = 44
  private let eventTimeLabelWidth: CGFloat = 40
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

        // Layer 2: 이벤트 시간 레이블
        ForEach(scheduleItems) { item in
          eventTimeLabel(item)
            .offset(y: yOffset(for: item.startAt))
        }

        // Layer 3: 일정 블록들
        ForEach(scheduleItems) { item in
          scheduleBlock(item)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, timeLabelWidth + eventTimeLabelWidth + 8)
            .padding(.trailing, 4)
            .offset(y: yOffset(for: item.startAt))
        }

      }
      .frame(width: nil, height: totalHeight)
      .padding(.top, 10)
      .padding(.bottom, 10)
      .padding(.leading, 8)
      .padding(.trailing, 20)
    }
  }

  // MARK: - Time Grid

  private var timeGrid: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(0..<totalHours, id: \.self) { hour in
        ZStack(alignment: .topLeading) {
          // 정각 행
          HStack(spacing: 8) {
            Text(String(format: "%02d:00", hour))
              .font(.system(size: 11, weight: .medium, design: .monospaced))
              .foregroundStyle(.tertiary)
              .frame(width: timeLabelWidth, alignment: .leading)

            // 정각 실선
            Rectangle()
              .fill(Color(.separator).opacity(0.5))
              .frame(height: 0.5)
          }
          .frame(height: 14, alignment: .center)
          .offset(y: -7)

          // 30분 점선
          HStack(alignment: .top, spacing: 8) {
            Color.clear
              .frame(width: timeLabelWidth)

            VStack(spacing: 0) {
              Spacer()
                .frame(height: hourHeight / 2)
              dashedLine
              Spacer()
            }
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
    let isCompact = blockHeight < 64

    return Button {
      onScheduleItemTapped(item)
    } label: {
      HStack(spacing: 0) {
        // 좌측 컬러 바
        RoundedRectangle(cornerRadius: 2)
          .fill(barColor(for: item))
          .frame(width: colorBarWidth)

        VStack(alignment: .leading, spacing: 2) {
          // Row 1: 이모지 + 제목 + 상태
          HStack(spacing: 5) {
            Text(item.displayEmoji)
              .font(.system(size: isCompact ? 14 : 16))

            Text(item.title)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.primary)
              .lineLimit(1)

            if case .promise(let p) = item {
              let status = promiseResponseStatus(p)
              Text(statusText(for: status))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(statusColor(for: status))
            }
          }

          if !isCompact {
            // Row 2: 그룹명 + 참여자수
            HStack(spacing: 5) {
              if let name = groupName(for: item) {
                Text(name)
                  .font(.system(size: 10))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }

              if case .promise(let p) = item, let group = p.group {
                Text("·")
                  .font(.system(size: 10))
                  .foregroundStyle(.tertiary)
                Text("👤 \(p.votes.acceptedCount)/\(group.memberIds.count)")
                  .font(.system(size: 10))
                  .foregroundStyle(.secondary)
              }
            }

            // Row 3: 장소 (있을 때만)
            if let location = itemLocation(for: item), !location.isEmpty {
              HStack(spacing: 4) {
                Image(systemName: "location.fill")
                  .font(.system(size: 9))
                  .foregroundStyle(Color.pmgray.n400)
                Text(location)
                  .font(.system(size: 10))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }

            // Row 4: 날씨 (약속에 날씨 데이터가 있을 때만)
            if case .promise(let p) = item,
               let weatherInfo = weatherCache[p.id],
               let forecast = weatherInfo.forecast(for: p.startAt) {
              HStack(spacing: 4) {
                Image(systemName: forecast.condition.sfSymbolName)
                  .symbolRenderingMode(.multicolor)
                  .font(.system(size: 10))
                Text("\(Int(forecast.temperature.rounded()))°")
                  .font(.system(size: 10, weight: .medium))
                  .foregroundStyle(.secondary)
              }
            }
          }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)

        Spacer(minLength: 0)
      }
      .frame(height: blockHeight)
      .background(blockBackground(for: item))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Event Time Label

  private func eventTimeLabel(_ item: HomeModels.ScheduleItem) -> some View {
    let blockHeight = blockHeight(for: item)
    let color = barColor(for: item)

    return VStack(spacing: 0) {
      Text(timeString(for: item.startAt))
        .font(.system(size: 9, weight: .medium, design: .monospaced))
        .foregroundStyle(color)

      Spacer(minLength: 0)

      if let endAt = item.endAt {
        Text(timeString(for: endAt))
          .font(.system(size: 9, weight: .medium, design: .monospaced))
          .foregroundStyle(color.opacity(0.6))
      }
    }
    .frame(width: eventTimeLabelWidth, height: blockHeight, alignment: .leading)
    .padding(.leading, timeLabelWidth)
  }

  // MARK: - Dashed Line

  private var dashedLine: some View {
    GeometryReader { geo in
      Path { path in
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: geo.size.width, y: 0))
      }
      .stroke(Color(.separator).opacity(0.45), style: StrokeStyle(lineWidth: 0.5, dash: [4, 3]))
    }
    .frame(height: 0.5)
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

  /// 블록 배경색 (그룹 컬러 기반 연한 배경)
  private func blockBackground(for item: HomeModels.ScheduleItem) -> Color {
    barColor(for: item).opacity(0.08)
  }

  private func barColor(for item: HomeModels.ScheduleItem) -> Color {
    switch item {
    case .promise(let p):
      return groupColorMap[p.groupId] ?? Color.pmindigo.n500
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

  private func timeString(for date: Date) -> String {
    Formatters.time.string(from: date)
  }

  private func promiseResponseStatus(_ promise: PromiseModel) -> PromiseResponseStatus {
    promise.responseStatus(currentUserId: currentUserId, totalGroupMembers: promise.group?.memberIds.count)
  }

  private func statusColor(for status: PromiseResponseStatus) -> Color {
    switch status {
    case .needResponse: return Color.pmwarning.n500
    case .responded:    return Color.pmwarning.n600
    case .confirmed:    return Color.pmsuccess.n500
    case .failed:       return Color.pmgray.n400
    }
  }

  private func statusText(for status: PromiseResponseStatus) -> String {
    switch status {
    case .needResponse: return "응답 필요"
    case .responded:    return "투표 완료"
    case .confirmed:    return "확정"
    case .failed:       return "미확정"
    }
  }

  private func itemLocation(for item: HomeModels.ScheduleItem) -> String? {
    switch item {
    case .promise(let p):
      return p.location?.name
    case .personalEvent(let e):
      return e.location?.name
    }
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
    onScheduleItemTapped: { _ in },
    currentUserId: "host1",
    weatherCache: [:],
    groupColorMap: ["g1": Color.pmindigo.n500, "g2": .orange]
  )
  .auroraBackground()
}

#Preview("일정 없음") {
  DayTimelineView(
    scheduleItems: [],
    onScheduleItemTapped: { _ in },
    currentUserId: "preview",
    weatherCache: [:],
    groupColorMap: [:]
  )
  .auroraBackground()
}
