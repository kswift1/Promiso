import SwiftUI
import Clients
import PromisoShared

// MARK: - Conflict Warning Section

public struct ConflictWarningSection: View {
  let conflicts: [ScheduleConflict]
  let isChecking: Bool

  public init(conflicts: [ScheduleConflict], isChecking: Bool) {
    self.conflicts = conflicts
    self.isChecking = isChecking
  }

  public var body: some View {
    if isChecking {
      HStack(spacing: 8) {
        ProgressView()
          .scaleEffect(0.8)
        Text(LocalizedStrings.Shared.conflictChecking)
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }
      .padding(.vertical, 8)
    } else if !conflicts.isEmpty {
      VStack(alignment: .leading, spacing: 12) {
        // 헤더
        HStack(spacing: 6) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 14))
            .foregroundColor(headerColor)
          Text(headerText)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(headerColor)
        }

        // 충돌 목록
        VStack(spacing: 8) {
          ForEach(conflicts) { conflict in
            ConflictItemRow(conflict: conflict)
          }
        }
      }
      .padding(16)
      .background(backgroundColorForSeverity)
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }

  private var hasConfirmedConflict: Bool {
    conflicts.contains { $0.severity == .confirmed }
  }

  private var headerColor: Color {
    hasConfirmedConflict ? Color.pmwarning.n600 : Color.pmwarning.n500
  }

  private var headerText: String {
    if hasConfirmedConflict {
      return "겹치는 일정이 있어요"
    } else {
      return "아직 확정되지 않은 약속이 있어요"
    }
  }

  private var backgroundColorForSeverity: Color {
    hasConfirmedConflict ? Color.pmwarning.n50 : Color(.systemGray6)
  }
}

// MARK: - Conflict Item Row

private struct ConflictItemRow: View {
  let conflict: ScheduleConflict

  var body: some View {
    HStack(spacing: 10) {
      // 소스 아이콘
      Circle()
        .fill(severityColor.opacity(0.15))
        .frame(width: 32, height: 32)
        .overlay(
          Text(conflict.emoji ?? defaultEmoji)
            .font(.system(size: 14))
        )

      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          Text(conflict.title)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.primary)
            .lineLimit(1)

          if conflict.severity == .pending {
            Text(LocalizedStrings.Shared.undetermined)
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(Color.pmwarning.n500)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.pmwarning.n500.opacity(0.12))
              .clipShape(Capsule())
          }
        }

        Text(timeRangeText)
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }

      Spacer()

      // 겹침 시간
      Text(overlapText)
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(severityColor)
    }
    .padding(.vertical, 4)
  }

  private var severityColor: Color {
    switch conflict.severity {
    case .confirmed:
      return Color.pmwarning.n600
    case .pending:
      return Color.pmwarning.n500
    }
  }

  private var defaultEmoji: String {
    switch conflict.source {
    case .promise: return "📌"
    case .personalEvent: return "📅"
    }
  }

  private var timeRangeText: String {
    let startText = conflict.startAt.formattedTime
    if let endAt = conflict.endAt {
      return "\(startText) ~ \(endAt.formattedTime)"
    }
    return startText
  }

  private var overlapText: String {
    let minutes = conflict.overlapMinutes
    if minutes >= 60 {
      let hours = minutes / 60
      let remainingMinutes = minutes % 60
      if remainingMinutes > 0 {
        return "\(hours)시간 \(remainingMinutes)분 겹침"
      }
      return "\(hours)시간 겹침"
    }
    return "\(minutes)분 겹침"
  }
}
