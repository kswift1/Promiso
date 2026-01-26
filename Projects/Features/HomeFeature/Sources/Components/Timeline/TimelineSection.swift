import SwiftUI
import PromisoShared

struct TimelineSectionView: View {
  let section: HomeModels.TimelineSection
  let currentUserId: String
  let onPromiseTap: (PromiseModel) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 날짜 헤더
      TimelineDateHeader(date: section.day)

      // 약속 카드들
      ForEach(section.promises) { promise in
        PromiseGlassCard(
          promise: promise,
          currentUserId: currentUserId,
          onTap: { onPromiseTap(promise) }
        )
      }
    }
  }
}

// MARK: - Preview

#Preview {
  ScrollView {
    VStack(spacing: 20) {
      TimelineSectionView(
        section: HomeModels.TimelineSection(
          day: Date(),
          promises: [
            PromiseModel.mock(
              title: "점심 약속",
              emoji: "🍕",
              startAt: Date().addingTimeInterval(7200)
            ),
            PromiseModel.mock(
              title: "커피 타임",
              emoji: "☕",
              startAt: Date().addingTimeInterval(14400)
            )
          ]
        ),
        currentUserId: "user1",
        onPromiseTap: { _ in }
      )

      TimelineSectionView(
        section: HomeModels.TimelineSection(
          day: Date().addingTimeInterval(86400),
          promises: [
            PromiseModel.mock(
              title: "저녁 약속",
              emoji: "🍽️",
              startAt: Date().addingTimeInterval(93600)
            )
          ]
        ),
        currentUserId: "user1",
        onPromiseTap: { _ in }
      )
    }
    .padding(.horizontal, 16)
  }
  .auroraBackground()
}
