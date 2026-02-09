import SwiftUI
import PromisoShared

// MARK: - Personal Event Card

/// 개인 일정 카드 컴포넌트
/// - PromiseGlassCard 패턴 (시간 컬럼 | 콘텐츠)
/// - Glass Effect 적용 (iOS 26 fallback 포함)
/// - 상태별 색상 힌트 (진행 중=green, 다가오는=indigo, 과거=gray)
public struct PersonalEventCard: View {
  let event: PersonalEventModel
  let onTap: () -> Void
  let onDelete: () -> Void

  public init(
    event: PersonalEventModel,
    onTap: @escaping () -> Void,
    onDelete: @escaping () -> Void
  ) {
    self.event = event
    self.onTap = onTap
    self.onDelete = onDelete
  }

  // MARK: - Status

  private var statusColor: Color {
    if event.isOngoing { return .green }
    if event.isPast { return Color(UIColor.systemGray) }
    let calendar = Calendar.current
    if calendar.isDateInToday(event.startAt) { return .orange }
    return Color.pmindigo.n500
  }

  private var statusBackgroundTint: Color {
    if event.isOngoing { return .green.opacity(0.05) }
    return .clear
  }

  // MARK: - Body

  public var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // 좌측: 시간 + 상태
        timeColumn

        // 중앙: 콘텐츠
        contentColumn

        Spacer(minLength: 0)

        // 우측: 리마인더 배지 또는 chevron
        rightAccessory
      }
      .padding(14)
      .background(statusBackgroundTint)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .adaptiveGlassCard(cornerRadius: 14)
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      Button(role: .destructive) {
        onDelete()
      } label: {
        Label("삭제", systemImage: "trash.fill")
      }
    }
  }

  // MARK: - Time Column

  private var timeColumn: some View {
    VStack(spacing: 6) {
      Text(event.startAt.formattedTime)
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(.primary)

      // 상태 인디케이터
      Circle()
        .fill(statusColor)
        .frame(width: 7, height: 7)
        .overlay {
          if event.isOngoing {
            Circle()
              .stroke(statusColor.opacity(0.4), lineWidth: 2)
              .frame(width: 13, height: 13)
          }
        }
    }
    .frame(width: 50)
  }

  // MARK: - Content Column

  private var contentColumn: some View {
    VStack(alignment: .leading, spacing: 6) {
      // 이모지 + 제목
      HStack(spacing: 6) {
        Text(event.displayEmoji)
          .font(.title3)

        Text(event.title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)
      }

      // 시간 범위 (종료 시간이 있을 때)
      if event.endAt != nil {
        HStack(spacing: 4) {
          Image(systemName: "clock")
            .font(.system(size: 11))

          Text(event.timeRangeText)
            .font(.system(size: 13))
        }
        .foregroundStyle(.secondary)
      }

      // 장소
      if let location = event.location {
        HStack(spacing: 4) {
          Image(systemName: "location.fill")
            .font(.system(size: 11))

          Text(location.name)
            .font(.system(size: 13))
            .lineLimit(1)
        }
        .foregroundStyle(.secondary)
      }

      // 하단: 메모 프리뷰 (한 줄)
      if let description = event.description, !description.isEmpty {
        Text(description)
          .font(.system(size: 12))
          .foregroundStyle(.secondary.opacity(0.8))
          .lineLimit(1)
      }
    }
  }

  // MARK: - Right Accessory

  private var rightAccessory: some View {
    VStack(spacing: 8) {
      if event.reminderMinutesBefore != nil {
        reminderBadge
      }

      Spacer(minLength: 0)

      Image(systemName: "chevron.right")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.tertiary)
    }
    .frame(maxHeight: .infinity)
  }

  // MARK: - Reminder Badge

  private var reminderBadge: some View {
    HStack(spacing: 3) {
      Image(systemName: "bell.fill")
        .font(.system(size: 9))

      if let minutes = event.reminderMinutesBefore {
        Text(reminderText(minutes))
          .font(.system(size: 10, weight: .medium))
      }
    }
    .foregroundStyle(Color.pmindigo.n500)
    .padding(.horizontal, 7)
    .padding(.vertical, 3)
    .background(Color.pmindigo.n500.opacity(0.1))
    .clipShape(Capsule())
  }

  private func reminderText(_ minutes: Int) -> String {
    if minutes >= 60 { return "\(minutes / 60)시간 전" }
    return "\(minutes)분 전"
  }
}

// MARK: - Preview

#Preview("활성 일정") {
  ScrollView {
    LazyVStack(spacing: 12) {
      ForEach(PersonalEventModel.activeExamples) { event in
        PersonalEventCard(
          event: event,
          onTap: {},
          onDelete: {}
        )
      }
    }
    .padding(16)
  }
  .auroraBackground()
}

#Preview("전체 일정") {
  ScrollView {
    LazyVStack(spacing: 12) {
      ForEach(PersonalEventModel.examples) { event in
        PersonalEventCard(
          event: event,
          onTap: {},
          onDelete: {}
        )
      }
    }
    .padding(16)
  }
  .auroraBackground()
}

#Preview("다크 모드") {
  ScrollView {
    LazyVStack(spacing: 12) {
      ForEach(PersonalEventModel.examples) { event in
        PersonalEventCard(
          event: event,
          onTap: {},
          onDelete: {}
        )
      }
    }
    .padding(16)
  }
  .auroraBackground()
  .preferredColorScheme(.dark)
}
