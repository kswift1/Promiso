import SwiftUI
import Clients
import PromisoShared

struct TimelineSectionView: View {

  let section: HomeModels.TimelineSection
  let currentUserId: String
  let weatherCache: [String: WeatherInfo]
  let onScheduleTap: (ScheduleModel) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 날짜 헤더
      TimelineDateHeader(date: section.day)

      // 일정 카드들
      ForEach(section.schedules) { schedule in
        ScheduleGlassCard(
          schedule: schedule,
          currentUserId: currentUserId,
          weather: weatherCache[schedule.id],
          onTap: { onScheduleTap(schedule) }
        )
      }
    }
  }
}
