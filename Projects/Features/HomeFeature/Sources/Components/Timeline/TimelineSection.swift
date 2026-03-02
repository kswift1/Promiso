import SwiftUI
import Clients
import PromisoShared

struct TimelineSectionView: View {

  let section: HomeModels.TimelineSection
  let currentUserId: String
  let weatherCache: [String: WeatherInfo]
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
          weather: weatherCache[promise.id],
          onTap: { onPromiseTap(promise) }
        )
      }
    }
  }
}
