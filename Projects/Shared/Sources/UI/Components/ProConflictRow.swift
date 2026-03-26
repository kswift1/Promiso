import SwiftUI
import ResourceKit

// MARK: - Pro Conflict Row

/// Pro 혜택 충돌 행 — 로딩 스피너 또는 충돌 요약 텍스트 + 팝오버 버튼
///
/// ProBenefitCardView와 ProBonusFloatingView에서 공통으로 사용합니다.
public struct ProConflictRow: View {
  let conflicts: [ConflictInfo]
  let isChecking: Bool
  let checkTrigger: ConflictCheckTrigger
  let eventTitle: String
  let eventEmoji: String?
  let eventStartAt: Date
  let eventEndAt: Date?
  let conflictsChecked: Bool

  @State private var showTooltip = false

  public init(
    conflicts: [ConflictInfo],
    isChecking: Bool,
    checkTrigger: ConflictCheckTrigger = .initial,
    eventTitle: String = "",
    eventEmoji: String? = nil,
    eventStartAt: Date = .now,
    eventEndAt: Date? = nil,
    conflictsChecked: Bool = false
  ) {
    self.conflicts = conflicts
    self.isChecking = isChecking
    self.checkTrigger = checkTrigger
    self.eventTitle = eventTitle
    self.eventEmoji = eventEmoji
    self.eventStartAt = eventStartAt
    self.eventEndAt = eventEndAt
    self.conflictsChecked = conflictsChecked
  }

  public var body: some View {
    if isChecking {
      HStack(spacing: 6) {
        ProgressView()
          .scaleEffect(0.7)
          .frame(width: 14, height: 14)

        Text(checkingText)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)

        Spacer(minLength: 0)
      }
    } else if !conflicts.isEmpty {
      Button {
        showTooltip = true
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 14))
            .foregroundStyle(Color.pmwarning.n500)

          Text(conflictSummaryText)
            .font(.system(size: 12))
            .foregroundStyle(.primary)
            .lineLimit(1)

          Spacer(minLength: 0)

          Image(systemName: "info.circle")
            .font(.system(size: 12))
            .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .popover(isPresented: $showTooltip, arrowEdge: .bottom) {
        ConflictTooltip(
          newEventTitle: eventTitle,
          newEventEmoji: eventEmoji,
          newEventStartAt: eventStartAt,
          newEventEndAt: eventEndAt,
          conflicts: conflicts
        )
        .presentationCompactAdaptation(.popover)
      }
    } else if conflictsChecked {
      HStack(spacing: 6) {
        Image(systemName: "checkmark.circle")
          .font(.system(size: 14))
          .foregroundStyle(Color.pmsuccess.n500)

        Text(LocalizedStrings.ProPlan.noConflict)
          .font(.system(size: 12))
          .foregroundStyle(.secondary)

        Spacer(minLength: 0)
      }
    }
  }

  // MARK: - Helpers

  private var checkingText: String {
    LocalizedStrings.Shared.conflictCheckingEvents
  }

  private var conflictSummaryText: String {
    if conflicts.count == 1, let first = conflicts.first {
      if first.overlapMinutes > 0 {
        return "\(first.title) · \(formattedOverlapText(first.overlapMinutes))"
      } else if first.gapMinutes > 0 {
        return "\(first.title) · \(formattedMarginText(first.gapMinutes))"
      } else {
        return "\(first.title) · \(LocalizedStrings.Shared.conflictOverlap)"
      }
    }
    return "\(LocalizedStrings.Shared.conflictCount(conflicts.count)) \(LocalizedStrings.Shared.conflictOverlap)"
  }

  private func formattedOverlapText(_ minutes: Int) -> String {
    if minutes >= 60 {
      let hours = minutes / 60
      let remaining = minutes % 60
      if remaining > 0 {
        return LocalizedStrings.Shared.conflictOverlapHoursMinutes(hours, remaining)
      }
      return LocalizedStrings.Shared.conflictOverlapHours(hours)
    }
    return LocalizedStrings.Shared.conflictOverlapMinutes(minutes)
  }

  private func formattedMarginText(_ minutes: Int) -> String {
    if minutes >= 60 {
      let hours = minutes / 60
      let remaining = minutes % 60
      if remaining > 0 {
        return LocalizedStrings.Shared.conflictMarginHoursMinutes(hours, remaining)
      }
      return LocalizedStrings.Shared.conflictMarginHours(hours)
    }
    return LocalizedStrings.Shared.conflictMarginMinutes(minutes)
  }
}

// MARK: - Previews

#Preview("충돌 1건") {
  ProConflictRow(
    conflicts: [ConflictInfo(title: "팀 회의", overlapMinutes: 30)],
    isChecking: false,
    eventTitle: "저녁 일정",
    eventStartAt: Date()
  )
  .padding()
}

#Preview("충돌 확인 중") {
  ProConflictRow(
    conflicts: [],
    isChecking: true
  )
  .padding()
}
