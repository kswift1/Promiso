import SwiftUI
import PromisoShared

// MARK: - Pending Section

/// 응답 필요 섹션 - 투표가 필요한 약속들
struct PendingSection: View {
  let promises: [PromiseModel]
  let onPromiseTap: (PromiseModel) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 헤더
      sectionHeader

      // 카드들 (가로 스크롤)
      if promises.isEmpty {
        emptyState
      } else {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(promises) { promise in
              PendingCard(
                promise: promise,
                onTap: { onPromiseTap(promise) }
              )
            }
          }
          .padding(.horizontal, 16)
        }
        .padding(.horizontal, -16)
      }
    }
  }

  // MARK: - Header

  private var sectionHeader: some View {
    HStack(spacing: 8) {
      Text("응답 필요")
        .font(.headline)
        .foregroundStyle(.primary)

      // 배지
      if !promises.isEmpty {
        Text("\(promises.count)")
          .font(.caption)
          .fontWeight(.bold)
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 2)
          .background(Color.orange)
          .clipShape(Capsule())
      }

      Spacer()
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    HStack(spacing: 8) {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)

      Text("모든 약속에 응답했어요")
        .font(.subheadline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 12)
  }
}

// MARK: - Preview

#Preview("응답 필요 있음") {
  PendingSection(
    promises: [
      PromiseModel.mock(id: "1", title: "저녁 모임"),
      PromiseModel.mock(id: "2", title: "주말 약속")
    ],
    onPromiseTap: { _ in }
  )
  .padding()
  .auroraBackground()
}

#Preview("응답 완료") {
  PendingSection(
    promises: [],
    onPromiseTap: { _ in }
  )
  .padding()
  .auroraBackground()
}
