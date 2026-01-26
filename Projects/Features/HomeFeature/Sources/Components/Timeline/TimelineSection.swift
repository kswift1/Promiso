import SwiftUI
import PromisoShared

struct TimelineSectionView: View {
  let section: TimelineSection
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

// Preview는 PromiseModel.mock이 필요하므로 Example 타겟에서 테스트
