import SwiftUI
import ResourceKit

// MARK: - Conflict Tooltip

/// 일정 충돌 상세 팝오버 — 겹치는 시간대 미니 타임라인
public struct ConflictTooltip: View {
  let newEventTitle: String
  let newEventEmoji: String?
  let newEventStartAt: Date
  let newEventEndAt: Date?
  let conflicts: [ConflictInfo]

  public init(
    newEventTitle: String,
    newEventEmoji: String? = nil,
    newEventStartAt: Date,
    newEventEndAt: Date?,
    conflicts: [ConflictInfo]
  ) {
    self.newEventTitle = newEventTitle
    self.newEventEmoji = newEventEmoji
    self.newEventStartAt = newEventStartAt
    self.newEventEndAt = newEventEndAt
    self.conflicts = conflicts
  }

  // MARK: - Timeline Computation

  /// 타임라인 범위: 새 일정 기간에 따라 적응적으로 결정
  /// - 6시간 이하: ±30분 패딩
  /// - 6~48시간: 새 일정 범위 그대로 (모든 충돌 포함)
  /// - 48시간 초과: 가장 겹치는 충돌의 overlap 구간에 포커스 (±1시간, 최대 12시간)
  private var timelineRange: (start: Date, end: Date) {
    let calendar = Calendar.current
    let newEnd = newEventEndAt ?? newEventStartAt.addingTimeInterval(3600)

    // 충돌이 없으면 fallback
    if conflicts.isEmpty {
      let start = calendar.date(byAdding: .minute, value: -30, to: newEventStartAt) ?? newEventStartAt
      let end = calendar.date(byAdding: .minute, value: 30, to: newEnd) ?? newEnd
      return (start, end)
    }

    let durationHours = newEnd.timeIntervalSince(newEventStartAt) / 3600

    if durationHours <= 6 {
      // 짧은 일정: ±30분 패딩으로 기존 UX 유지
      let start = calendar.date(byAdding: .minute, value: -30, to: newEventStartAt) ?? newEventStartAt
      let end = calendar.date(byAdding: .minute, value: 30, to: newEnd) ?? newEnd
      return (start, end)
    }

    if durationHours <= 48 {
      // 중간 일정: 새 일정 범위 그대로 (모든 충돌 포함 보장)
      return (newEventStartAt, newEnd)
    }

    // 초장기 일정: 가장 겹치는 충돌의 overlap 구간에 포커스
    let topConflict = conflicts[0] // overlapMinutes 내림차순 정렬
    let conflictEnd = topConflict.endAt ?? topConflict.startAt.addingTimeInterval(3600)
    let overlapStart = max(newEventStartAt, topConflict.startAt)
    let overlapEnd = min(newEnd, conflictEnd)

    var start = calendar.date(byAdding: .hour, value: -1, to: overlapStart) ?? overlapStart
    var end = calendar.date(byAdding: .hour, value: 1, to: overlapEnd) ?? overlapEnd

    // 최대 12시간 윈도우
    let maxWindow: TimeInterval = 12 * 3600
    if end.timeIntervalSince(start) > maxWindow {
      end = start.addingTimeInterval(maxWindow)
    }

    return (start, end)
  }

  /// 48시간 초과 일정에서 가장 겹치는 구간에 포커스 중인지 여부
  private var isFocusedTimeline: Bool {
    let newEnd = newEventEndAt ?? newEventStartAt.addingTimeInterval(3600)
    return newEnd.timeIntervalSince(newEventStartAt) / 3600 > 48 && !conflicts.isEmpty
  }

  private var totalMinutes: CGFloat {
    CGFloat(timelineRange.end.timeIntervalSince(timelineRange.start) / 60)
  }

  private func yOffset(for date: Date, in height: CGFloat) -> CGFloat {
    let minutes = CGFloat(date.timeIntervalSince(timelineRange.start) / 60)
    return (minutes / totalMinutes) * height
  }

  /// 블록의 y / height를 타임라인 범위 내로 클램프
  private func clampedBlock(start: Date, end: Date) -> (y: CGFloat, h: CGFloat) {
    let range = timelineRange
    let cStart = max(start, range.start)
    let cEnd = min(end, range.end)

    var y = yOffset(for: cStart, in: timelineHeight)
    var h = CGFloat(cEnd.timeIntervalSince(cStart) / 60) / totalMinutes * timelineHeight
    h = max(h, 18) // 최소 높이

    // 타임라인 영역 밖으로 나가지 않도록
    if y + h > timelineHeight { h = timelineHeight - y }
    if y < 0 { h += y; y = 0 }

    return (y, max(h, 0))
  }

  // MARK: - Hour Labels

  /// 타임라인이 여러 날에 걸치는지 여부
  private var spansMultipleDays: Bool {
    !Calendar.current.isDate(timelineRange.start, inSameDayAs: timelineRange.end)
  }

  /// 타임라인 시간 범위에 따라 레이블 간격을 조정
  private var hourLabelInterval: Int {
    let hours = timelineRange.end.timeIntervalSince(timelineRange.start) / 3600
    if hours <= 6 { return 1 }
    if hours <= 12 { return 2 }
    if hours <= 24 { return 3 }
    return 6
  }

  private var hourLabels: [Date] {
    let calendar = Calendar.current
    var labels: [Date] = []
    var current = calendar.nextDate(
      after: timelineRange.start,
      matching: DateComponents(minute: 0),
      matchingPolicy: .nextTime
    ) ?? timelineRange.start

    while current <= timelineRange.end {
      labels.append(current)
      current = calendar.date(
        byAdding: .hour, value: hourLabelInterval, to: current
      ) ?? current.addingTimeInterval(TimeInterval(hourLabelInterval * 3600))
    }
    return labels
  }

  private func hourLabelText(for hour: Date) -> String {
    if spansMultipleDays {
      let hourComponent = Calendar.current.component(.hour, from: hour)
      if hourComponent == 0 || hour == hourLabels.first {
        return Self.dateTimeFormatter.string(from: hour)
      }
    }
    return Self.compactTimeFormatter.string(from: hour)
  }

  // MARK: - Body

  private var timelineHeight: CGFloat {
    let hours = timelineRange.end.timeIntervalSince(timelineRange.start) / 3600
    if hours <= 6 { return 180 }
    let calculated = CGFloat(hours) * 30
    return min(max(calculated, 180), 400)
  }

  public var body: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 12) {
        // 헤더
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 14))
            .foregroundStyle(Color.pmwarning.n500)

          Text("겹치는 일정")
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)

          Spacer()

          Text("\(conflicts.count)건")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
        }

        Divider()

        // 포커스 모드 안내
        if isFocusedTimeline, let topConflict = conflicts.first {
          Text("'\(topConflict.title)' 겹치는 구간 중심으로 표시")
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
        }

        // 타임라인
        timelineView

        Divider()

        // 충돌 목록 요약
        VStack(spacing: 6) {
          ForEach(Array(conflicts.enumerated()), id: \.offset) { index, conflict in
            conflictSummaryRow(conflict, index: index)
          }
        }
      }
      .padding(16)
    }
    .frame(width: 280)
    .frame(maxHeight: 520)
  }

  // MARK: - Compact Time Format

  private static let compactTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "H:mm"
    return f
  }()

  // MARK: - Timeline View

  private var timelineView: some View {
    VStack(spacing: 4) {
      // 컬럼 제목
      HStack(spacing: 0) {
        Color.clear
          .frame(width: spansMultipleDays ? 44 : 36)

        HStack(spacing: 2) {
          Text("새 일정")
            .frame(maxWidth: .infinity, alignment: .leading)

          Text("기존 일정")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
      }

      // 타임라인
      HStack(alignment: .top, spacing: 0) {
        // 시간 눈금 (클램프된 영역 내)
        ZStack(alignment: .topLeading) {
          ForEach(hourLabels, id: \.self) { hour in
            Text(hourLabelText(for: hour))
              .font(.system(size: spansMultipleDays ? 9 : 10, weight: .medium, design: .monospaced))
              .foregroundStyle(.tertiary)
              .offset(y: yOffset(for: hour, in: timelineHeight) - 6)
          }
        }
        .frame(width: spansMultipleDays ? 44 : 36)

        // 타임라인 콘텐츠 (그리드 + 2컬럼 블록)
        ZStack(alignment: .topLeading) {
          // 시간 구분선 (전체 너비)
          ForEach(hourLabels, id: \.self) { hour in
            Rectangle()
              .fill(Color.secondary.opacity(0.15))
              .frame(height: 0.5)
              .offset(y: yOffset(for: hour, in: timelineHeight))
          }

          // 2컬럼: 새 일정(좌) / 충돌 일정(우)
          HStack(spacing: 2) {
            ZStack(alignment: .topLeading) {
              Color.clear
              newEventBlock
            }

            ZStack(alignment: .topLeading) {
              Color.clear
              ForEach(Array(conflicts.enumerated()), id: \.offset) { index, conflict in
                conflictBlock(conflict, index: index)
              }
            }
          }
        }
        .frame(height: timelineHeight)
        .clipped()
      }
      .frame(height: timelineHeight)
    }
  }

  // MARK: - New Event Block

  private var newEventBlock: some View {
    let endAt = newEventEndAt ?? newEventStartAt.addingTimeInterval(3600)
    let (y, h) = clampedBlock(start: newEventStartAt, end: endAt)

    return HStack(spacing: 3) {
      if let emoji = newEventEmoji {
        Text(emoji)
          .font(.system(size: 9))
      }
      Text(newEventTitle.isEmpty ? "새 일정" : newEventTitle)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(Color.pmerror.n500)
        .lineLimit(1)
    }
    .padding(.horizontal, 6)
    .padding(.top, 4)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .frame(height: h)
    .background(Color.pmerror.n500.opacity(0.06))
    .overlay(
      RoundedRectangle(cornerRadius: 4)
        .strokeBorder(
          Color.pmerror.n500,
          style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
        )
    )
    .offset(y: y)
  }

  // MARK: - Conflict Block

  private func conflictBlock(_ conflict: ConflictInfo, index: Int) -> some View {
    let endAt = conflict.endAt ?? conflict.startAt.addingTimeInterval(3600)
    let (y, h) = clampedBlock(start: conflict.startAt, end: endAt)
    let color = blockColor(at: index)

    return HStack(spacing: 3) {
      if let emoji = conflict.emoji {
        Text(emoji)
          .font(.system(size: 9))
      }
      Text(conflict.title)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(color)
        .lineLimit(1)
    }
    .padding(.horizontal, 6)
    .padding(.top, 4)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .frame(height: h)
    .background(color.opacity(0.12))
    .clipShape(RoundedRectangle(cornerRadius: 4))
    .offset(y: y)
  }

  // MARK: - Conflict Summary Row

  private func conflictSummaryRow(_ conflict: ConflictInfo, index: Int) -> some View {
    let color = blockColor(at: index)

    return HStack(spacing: 8) {
      Circle()
        .fill(color.opacity(0.15))
        .frame(width: 24, height: 24)
        .overlay(
          Text(conflict.emoji ?? defaultEmoji(for: conflict))
            .font(.system(size: 11))
        )

      VStack(alignment: .leading, spacing: 1) {
        Text(conflict.title)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(color)
          .lineLimit(1)

        Text(timeRangeText(for: conflict))
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }

      Spacer()

      Text(overlapText(for: conflict))
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(color)
    }
  }

  // MARK: - Helpers

  /// 충돌 일정별 구분 색상 팔레트
  private static let conflictColors: [Color] = [
    Color.pmwarning.n500,
    Color.pmindigo.n500,
    Color.pmpurple.n500,
    Color.pmsuccess.n500,
    Color.pminfo.n500,
  ]

  private func blockColor(at index: Int) -> Color {
    Self.conflictColors[index % Self.conflictColors.count]
  }

  private func defaultEmoji(for conflict: ConflictInfo) -> String {
    "📅"
  }

  private static let dateTimeFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "M/d H:mm"
    return f
  }()

  private func timeRangeText(for conflict: ConflictInfo) -> String {
    let startText = Self.dateTimeFormatter.string(from: conflict.startAt)
    if let endAt = conflict.endAt {
      // 같은 날이면 종료 시간만, 다른 날이면 날짜 포함
      if Calendar.current.isDate(conflict.startAt, inSameDayAs: endAt) {
        return "\(startText) ~ \(Self.compactTimeFormatter.string(from: endAt))"
      }
      return "\(startText) ~ \(Self.dateTimeFormatter.string(from: endAt))"
    }
    return startText
  }

  private func overlapText(for conflict: ConflictInfo) -> String {
    let minutes = conflict.overlapMinutes
    if minutes >= 60 {
      let hours = minutes / 60
      let remaining = minutes % 60
      if remaining > 0 {
        return "\(hours)시간 \(remaining)분"
      }
      return "\(hours)시간"
    }
    return "\(minutes)분"
  }
}

// MARK: - Previews

/// 프리뷰용 래퍼 — 팝오버처럼 보여주기
private struct TooltipPreviewWrapper: View {
  let title: String
  let tooltip: ConflictTooltip

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(title)
        .font(.system(size: 13, weight: .bold))
        .foregroundStyle(.secondary)
      tooltip
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
    }
  }
}

#Preview("전체 겹침 케이스") {
  ScrollView {
    VStack(spacing: 20) {
      // 1) 뒷부분 겹침: 새 일정 끝 부분에 충돌 일정 시작
      TooltipPreviewWrapper(
        title: "뒷부분 겹침",
        tooltip: ConflictTooltip(
          newEventTitle: "저녁 약속",
          newEventEmoji: "🍽️",
          newEventStartAt: Date().addingTimeInterval(3600),
          newEventEndAt: Date().addingTimeInterval(3600 * 3),
          conflicts: [
            ConflictInfo(
              title: "팀 회의",
              overlapMinutes: 30,
              startAt: Date().addingTimeInterval(3600 * 2.5),
              endAt: Date().addingTimeInterval(3600 * 4),
              emoji: "📌",
              severity: .confirmed
            )
          ]
        )
      )

      // 2) 앞부분 겹침: 충돌 일정이 먼저 시작, 새 일정 시작 후 끝남
      TooltipPreviewWrapper(
        title: "앞부분 겹침",
        tooltip: ConflictTooltip(
          newEventTitle: "점심 약속",
          newEventEmoji: "🍜",
          newEventStartAt: Date().addingTimeInterval(3600 * 2),
          newEventEndAt: Date().addingTimeInterval(3600 * 4),
          conflicts: [
            ConflictInfo(
              title: "오전 미팅",
              overlapMinutes: 60,
              startAt: Date().addingTimeInterval(3600),
              endAt: Date().addingTimeInterval(3600 * 3),
              emoji: "💼",
              severity: .confirmed
            )
          ]
        )
      )

      // 3) 완전 포함: 충돌 일정이 새 일정 안에 완전히 들어감
      TooltipPreviewWrapper(
        title: "완전 포함",
        tooltip: ConflictTooltip(
          newEventTitle: "종일 워크숍",
          newEventEmoji: "📝",
          newEventStartAt: Date().addingTimeInterval(3600),
          newEventEndAt: Date().addingTimeInterval(3600 * 5),
          conflicts: [
            ConflictInfo(
              title: "1:1 미팅",
              overlapMinutes: 60,
              startAt: Date().addingTimeInterval(3600 * 2),
              endAt: Date().addingTimeInterval(3600 * 3),
              emoji: "🤝",
              severity: .confirmed
            )
          ]
        )
      )

      // 4) 장기 일정: 출장처럼 하루 넘는 일정
      TooltipPreviewWrapper(
        title: "장기 일정 (출장)",
        tooltip: ConflictTooltip(
          newEventTitle: "저녁 약속",
          newEventEmoji: "🍻",
          newEventStartAt: Date().addingTimeInterval(3600),
          newEventEndAt: Date().addingTimeInterval(3600 * 3),
          conflicts: [
            ConflictInfo(
              title: "출장",
              overlapMinutes: 120,
              startAt: Date().addingTimeInterval(-3600 * 12),
              endAt: Date().addingTimeInterval(3600 * 24),
              emoji: "✈️",
              severity: .confirmed
            )
          ]
        )
      )

      // 5) 동시 시작: 새 일정과 충돌 일정이 같은 시간에 시작
      TooltipPreviewWrapper(
        title: "동시 시작",
        tooltip: ConflictTooltip(
          newEventTitle: "스터디",
          newEventEmoji: "📚",
          newEventStartAt: Date().addingTimeInterval(3600),
          newEventEndAt: Date().addingTimeInterval(3600 * 3),
          conflicts: [
            ConflictInfo(
              title: "팀 회의",
              overlapMinutes: 60,
              startAt: Date().addingTimeInterval(3600),
              endAt: Date().addingTimeInterval(3600 * 2),
              emoji: "📌",
              severity: .confirmed
            )
          ]
        )
      )

      // 6) 여러 건 겹침
      TooltipPreviewWrapper(
        title: "여러 건 겹침 (3건)",
        tooltip: ConflictTooltip(
          newEventTitle: "저녁 약속",
          newEventEmoji: "🍽️",
          newEventStartAt: Date().addingTimeInterval(3600),
          newEventEndAt: Date().addingTimeInterval(3600 * 4),
          conflicts: [
            ConflictInfo(
              title: "팀 회의",
              overlapMinutes: 30,
              startAt: Date().addingTimeInterval(3600 * 0.5),
              endAt: Date().addingTimeInterval(3600 * 1.5),
              emoji: "📌",
              severity: .confirmed
            ),
            ConflictInfo(
              title: "점심 약속",
              overlapMinutes: 60,
              startAt: Date().addingTimeInterval(3600 * 2),
              endAt: Date().addingTimeInterval(3600 * 3),
              emoji: nil,
              severity: .pending
            ),
            ConflictInfo(
              title: "운동",
              overlapMinutes: 30,
              startAt: Date().addingTimeInterval(3600 * 3.5),
              endAt: Date().addingTimeInterval(3600 * 4.5),
              emoji: "🏃",
              severity: .confirmed
            )
          ]
        )
      )

      // 7) 미확정 약속
      TooltipPreviewWrapper(
        title: "미확정 약속",
        tooltip: ConflictTooltip(
          newEventTitle: "저녁 약속",
          newEventStartAt: Date().addingTimeInterval(3600),
          newEventEndAt: Date().addingTimeInterval(3600 * 3),
          conflicts: [
            ConflictInfo(
              title: "번개 모임",
              overlapMinutes: 90,
              startAt: Date().addingTimeInterval(3600 * 1.5),
              endAt: Date().addingTimeInterval(3600 * 3),
              emoji: "⚡",
              severity: .pending
            )
          ]
        )
      )

      // 8) 장기 일정 + 끝부분 1분 겹침
      TooltipPreviewWrapper(
        title: "장기 일정 + 끝부분 1분 겹침",
        tooltip: ConflictTooltip(
          newEventTitle: "주말 여행",
          newEventEmoji: "🏔️",
          newEventStartAt: Date().addingTimeInterval(3600),
          newEventEndAt: Date().addingTimeInterval(3600 * 26),
          conflicts: [
            ConflictInfo(
              title: "출장",
              overlapMinutes: 1528,
              startAt: Date().addingTimeInterval(-3600 * 5),
              endAt: Date().addingTimeInterval(3600 * 30),
              emoji: "✈️",
              severity: .confirmed
            ),
            ConflictInfo(
              title: "저녁 약속",
              overlapMinutes: 1,
              startAt: Date().addingTimeInterval(3600 * 25.83),
              endAt: Date().addingTimeInterval(3600 * 27.83),
              emoji: "🍽️",
              severity: .confirmed
            )
          ]
        )
      )
      // 9) 초장기 일정 (21일) — 타임라인 숨김, 요약만 표시
      TooltipPreviewWrapper(
        title: "초장기 일정 (21일, 타임라인 숨김)",
        tooltip: ConflictTooltip(
          newEventTitle: "해외 출장",
          newEventEmoji: "✈️",
          newEventStartAt: Date(),
          newEventEndAt: Date().addingTimeInterval(3600 * 24 * 21),
          conflicts: [
            ConflictInfo(
              title: "팀 회의",
              overlapMinutes: 60,
              startAt: Date().addingTimeInterval(3600 * 24 * 3),
              endAt: Date().addingTimeInterval(3600 * 24 * 3 + 3600),
              emoji: "📌",
              severity: .confirmed
            ),
            ConflictInfo(
              title: "저녁 약속",
              overlapMinutes: 120,
              startAt: Date().addingTimeInterval(3600 * 24 * 14),
              endAt: Date().addingTimeInterval(3600 * 24 * 14 + 7200),
              emoji: "🍽️",
              severity: .confirmed
            )
          ]
        )
      )
    }
    .padding(16)
  }
}
