import SwiftUI
import ResourceKit

// MARK: - Pro Conflict Row

/// Pro 혜택 충돌 행 — 로딩 스피너 또는 충돌 요약 텍스트 + 팝오버 버튼
///
/// ProBenefitCardView와 ProBonusFloatingView에서 공통으로 사용합니다.
public struct ProConflictRow: View {
  let conflicts: [ConflictInfo]
  let isChecking: Bool
  let eventTitle: String
  let eventEmoji: String?
  let eventStartAt: Date
  let eventEndAt: Date?

  @State private var showTooltip = false

  public init(
    conflicts: [ConflictInfo],
    isChecking: Bool,
    eventTitle: String = "",
    eventEmoji: String? = nil,
    eventStartAt: Date = .now,
    eventEndAt: Date? = nil
  ) {
    self.conflicts = conflicts
    self.isChecking = isChecking
    self.eventTitle = eventTitle
    self.eventEmoji = eventEmoji
    self.eventStartAt = eventStartAt
    self.eventEndAt = eventEndAt
  }

  public var body: some View {
    if isChecking {
      HStack(spacing: 6) {
        ProgressView()
          .scaleEffect(0.7)
          .frame(width: 14, height: 14)

        Text(LocalizedStrings.Shared.conflictCheckingEvents)
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
    }
  }

  // MARK: - Helpers

  private var conflictSummaryText: String {
    if conflicts.count == 1, let first = conflicts.first {
      if first.overlapMinutes > 0 {
        return "'\(first.title)'과(와) \(first.overlapMinutes)분 겹쳐요"
      } else if first.gapMinutes > 0 {
        return "'\(first.title)'과(와) 여유 \(first.gapMinutes)분이에요"
      } else {
        return "'\(first.title)'과(와) 일정이 겹쳐요"
      }
    }
    return "\(conflicts.count)건의 일정이 겹쳐요"
  }
}

// MARK: - Previews

#Preview("충돌 1건") {
  ProConflictRow(
    conflicts: [ConflictInfo(title: "팀 회의", overlapMinutes: 30)],
    isChecking: false,
    eventTitle: "저녁 약속",
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
