import SwiftUI
import PromisoShared

/// Quick Insights 섹션 - 가로 스크롤 인사이트 카드들
struct QuickInsightsSection: View {
  let data: QuickInsightsData
  let onInsightTap: (InsightType) -> Void

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        InsightCard(
          type: .today,
          count: data.todayCount,
          onTap: { onInsightTap(.today) }
        )

        InsightCard(
          type: .needResponse,
          count: data.needResponseCount,
          onTap: { onInsightTap(.needResponse) }
        )

        InsightCard(
          type: .thisWeek,
          count: data.thisWeekCount,
          onTap: { onInsightTap(.thisWeek) }
        )
      }
      .padding(.horizontal, 16)
    }
    .scrollTargetBehavior(.viewAligned)
  }
}

/// 개별 인사이트 카드
struct InsightCard: View {
  let type: InsightType
  let count: Int
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 12) {
        // 아이콘 + 라벨
        HStack(spacing: 8) {
          Image(systemName: type.iconName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(accentColor)

          Text(type.rawValue)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.secondary)
        }

        // 숫자
        HStack(alignment: .lastTextBaseline, spacing: 4) {
          Text("\(count)")
            .font(.system(size: 32, weight: .bold, design: .rounded))
            .foregroundStyle(.primary)

          Text("개")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
      .frame(width: 120, alignment: .leading)
      .padding(16)
      .adaptiveGlassCard(cornerRadius: 16)
    }
    .buttonStyle(.plain)
  }

  private var accentColor: Color {
    switch type {
    case .today: return Color.pmindigo.n500
    case .needResponse: return Color.pmaurora.purple
    case .thisWeek: return Color.green
    }
  }
}

// MARK: - Preview

#Preview("Quick Insights") {
  VStack {
    QuickInsightsSection(
      data: QuickInsightsData(
        todayCount: 3,
        needResponseCount: 2,
        thisWeekCount: 7
      ),
      onInsightTap: { type in
        print("Tapped: \(type)")
      }
    )
  }
  .padding(.vertical)
  .auroraBackground()
}

#Preview("빈 상태") {
  VStack {
    QuickInsightsSection(
      data: QuickInsightsData(
        todayCount: 0,
        needResponseCount: 0,
        thisWeekCount: 0
      ),
      onInsightTap: { _ in }
    )
  }
  .padding(.vertical)
  .auroraBackground()
}
