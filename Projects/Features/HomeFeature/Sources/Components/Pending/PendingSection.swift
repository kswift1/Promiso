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
    HStack(spacing: 14) {
      // 체크 아이콘
      ZStack {
        Circle()
          .fill(Color.green.opacity(0.1))
          .frame(width: 48, height: 48)

        Image(systemName: "checkmark.circle.fill")
          .font(.title2)
          .foregroundStyle(.green)
      }

      // 텍스트
      VStack(alignment: .leading, spacing: 2) {
        Text("모두 응답 완료!")
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundStyle(.primary)

        Text("새로운 약속이 오면 알려드릴게요")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(14)
    .background(Color.green.opacity(0.05))
    .clipShape(RoundedRectangle(cornerRadius: 14))
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
