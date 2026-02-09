import SwiftUI
import PromisoShared

// MARK: - Personal Event Card

/// 개인 일정 카드 컴포넌트
/// - PromiseCard와 동일한 VStack 레이아웃 패턴
/// - Glass Effect 적용 (iOS 26 fallback 포함)
/// - 상태별 배지 표시 (진행 중/오늘/다가오는/지난)
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

  // MARK: - Body

  public var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 14) {
        // 메인 콘텐츠: 상태 배지 + 이모지 + 제목/설명/시간/장소
        mainContent

        // 하단: 알림 정보
        if event.reminderMinutesBefore != nil {
          bottomSection
        }
      }
      .padding(16)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .adaptiveGlassCard()
    .contextMenu {
      Button(action: onTap) {
        Label("상세 보기", systemImage: "info.circle")
      }

      Button(role: .destructive, action: onDelete) {
        Label("삭제", systemImage: "trash")
      }
    }
  }

  // MARK: - Main Content

  private var mainContent: some View {
    HStack(alignment: .top, spacing: 12) {
      Text(event.displayEmoji)
        .font(.system(size: 44))

      VStack(alignment: .leading, spacing: 10) {
        // 제목 + 상태 배지 (우측 상단)
        HStack(alignment: .top) {
          Text(event.title)
            .font(.system(size: 19, weight: .bold))
            .foregroundStyle(.primary)

          Spacer()

          PersonalEventStatusBadge(event: event)
        }

        // 설명
        if let description = event.description, !description.isEmpty {
          Text(description)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }

        VStack(alignment: .leading, spacing: 6) {
          // 날짜 & 시간
          HStack(spacing: 4) {
            Text("⏰")
              .font(.system(size: 14))
            Text("\(event.dateText) \(event.timeRangeText)")
              .font(.system(size: 14, weight: .medium))
          }
          .foregroundStyle(.primary)

          // 장소
          if let location = event.location {
            HStack(spacing: 4) {
              Text("📍")
                .font(.system(size: 14))
              Text(location.name)
                .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(.primary)
          }
        }
      }
    }
  }

  // MARK: - Bottom Section

  private var bottomSection: some View {
    HStack {
      if let minutes = event.reminderMinutesBefore {
        let isReminderSent = event.reminderDate.map { $0 <= Date() } ?? false

        HStack(spacing: 4) {
          Image(systemName: isReminderSent ? "checkmark.circle.fill" : "bell.fill")
            .font(.system(size: 12))
          Text(isReminderSent ? "알림 완료" : reminderText(minutes))
            .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(isReminderSent ? .green : .secondary)
      }

      Spacer()
    }
  }

  // MARK: - Helper

  private func reminderText(_ minutes: Int) -> String {
    if minutes >= 60 { return "\(minutes / 60)시간 전 알림" }
    return "\(minutes)분 전 알림"
  }
}

// MARK: - Personal Event Status Badge

private struct PersonalEventStatusBadge: View {
  let event: PersonalEventModel

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: iconName)
        .font(.system(size: 12, weight: .semibold))

      Text(statusText)
        .font(.system(size: 12, weight: .semibold))
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(statusColor.opacity(0.1))
    .foregroundStyle(statusColor)
    .clipShape(Capsule())
  }

  private var statusText: String {
    if event.isOngoing { return "진행 중" }
    if event.isPast { return "종료" }
    let calendar = Calendar.current
    if calendar.isDateInToday(event.startAt) { return "오늘" }
    return "예정"
  }

  private var iconName: String {
    if event.isOngoing { return "bolt.fill" }
    if event.isPast { return "checkmark.circle.fill" }
    let calendar = Calendar.current
    if calendar.isDateInToday(event.startAt) { return "sun.max.fill" }
    return "clock.fill"
  }

  private var statusColor: Color {
    if event.isOngoing { return .green }
    if event.isPast { return Color(UIColor.systemGray) }
    let calendar = Calendar.current
    if calendar.isDateInToday(event.startAt) { return .orange }
    return Color.pmindigo.n500
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
