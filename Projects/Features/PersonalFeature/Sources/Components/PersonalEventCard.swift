import SwiftUI

// MARK: - Personal Event Card

/// 개인 일정 카드 컴포넌트
/// - Glass Effect 적용 (iOS 26 fallback 포함)
/// - 스와이프 삭제 기능 지원
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

  public var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // 이모지
        Text(event.displayEmoji)
          .font(.system(size: 40))
          .frame(width: 50, height: 50)
          .background(
            Circle()
              .fill(Color(UIColor.systemGray6))
          )

        // 정보
        VStack(alignment: .leading, spacing: 6) {
          // 제목
          Text(event.title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(2)

          // 시간
          HStack(spacing: 4) {
            Image(systemName: "clock")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)

            Text(event.timeRangeText)
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
          }

          // 위치 (있으면)
          if let location = event.location {
            HStack(spacing: 4) {
              Image(systemName: "location.fill")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

              Text(location.name)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
          }
        }

        Spacer()

        // 화살표
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(16)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .adaptiveGlassCard()
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      Button(role: .destructive) {
        onDelete()
      } label: {
        Label("삭제", systemImage: "trash.fill")
      }
    }
  }
}

// MARK: - Preview

#Preview("기본") {
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

#Preview("다크 모드") {
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
  .preferredColorScheme(.dark)
}
