import SwiftUI
import PromisoShared

struct OverviewSection: View {
  let overviewData: OverviewData
  let criticalZoneData: CriticalZoneData?
  let onNeedResponseTap: () -> Void
  let onCriticalZoneTap: () -> Void

  var body: some View {
    VStack(spacing: 12) {
      // Critical Zone (조건부)
      if let criticalData = criticalZoneData {
        CriticalZoneCard(
          data: criticalData,
          onTap: onCriticalZoneTap
        )
      }

      // Today Summary Card
      TodaySummaryCard(
        todayCount: overviewData.todayCount,
        nextPromise: overviewData.nextPromise
      )

      // Need Response Banner (조건부)
      if overviewData.needResponseCount > 0 {
        NeedResponseBanner(
          count: overviewData.needResponseCount,
          onTap: onNeedResponseTap
        )
      }
    }
    .padding(.horizontal, 16)
  }
}

// MARK: - Preview

#Preview("모든 섹션") {
  OverviewSection(
    overviewData: OverviewData(
      todayCount: 3,
      nextPromise: PromiseModel.mock(
        title: "점심 약속",
        emoji: "🍕",
        startAt: Date().addingTimeInterval(3600)
      ),
      needResponseCount: 5
    ),
    criticalZoneData: CriticalZoneData(
      reason: .liveActivity,
      promise: PromiseModel.mock(
        title: "저녁 약속",
        emoji: "🍽️",
        startAt: Date().addingTimeInterval(-1800)
      )
    ),
    onNeedResponseTap: {},
    onCriticalZoneTap: {}
  )
  .padding(.vertical)
  .auroraBackground()
}

#Preview("Critical Zone 없음") {
  OverviewSection(
    overviewData: OverviewData(
      todayCount: 2,
      nextPromise: PromiseModel.mock(
        title: "커피 타임",
        emoji: "☕",
        startAt: Date().addingTimeInterval(1800)
      ),
      needResponseCount: 3
    ),
    criticalZoneData: nil,
    onNeedResponseTap: {},
    onCriticalZoneTap: {}
  )
  .padding(.vertical)
  .auroraBackground()
}

#Preview("응답 필요 없음") {
  OverviewSection(
    overviewData: OverviewData(
      todayCount: 1,
      nextPromise: PromiseModel.mock(
        title: "팀 미팅",
        emoji: "💼",
        startAt: Date().addingTimeInterval(7200)
      ),
      needResponseCount: 0
    ),
    criticalZoneData: nil,
    onNeedResponseTap: {},
    onCriticalZoneTap: {}
  )
  .padding(.vertical)
  .auroraBackground()
}
