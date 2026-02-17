import SwiftUI
import Clients
import PromisoShared

// MARK: - Pending Section

/// 응답 필요 섹션 - 투표가 필요한 약속들
struct PendingSection: View {
  let promises: [PromiseModel]
  let weatherCache: [String: WeatherInfo]
  let onPromiseTap: (PromiseModel) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 헤더
      sectionHeader

      // 카드들 (가로 스크롤)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 14) {
          ForEach(promises) { promise in
            PendingCard(
              promise: promise,
              weather: weatherCache[promise.id],
              onTap: { onPromiseTap(promise) }
            )
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
      }
      .padding(.horizontal, -16)
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

}

// MARK: - Preview

#Preview {
  PendingSection(
    promises: [
      PromiseModel.mock(id: "1", title: "저녁 모임"),
      PromiseModel.mock(id: "2", title: "주말 약속")
    ],
    weatherCache: [:],
    onPromiseTap: { _ in }
  )
  .padding()
  .auroraBackground()
}
