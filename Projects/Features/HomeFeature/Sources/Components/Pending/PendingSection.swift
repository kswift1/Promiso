import SwiftUI
import Clients
import PromisoShared

// MARK: - Pending Section

/// 응답 필요 섹션 - 투표가 필요한 일정들
struct PendingSection: View {
  let schedules: [ScheduleModel]
  let groupMembersCache: [String: [UserPublicModel]]
  let onScheduleTap: (ScheduleModel) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 헤더
      sectionHeader

      // 카드들 (가로 스크롤)
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 14) {
          ForEach(schedules) { schedule in
            PendingCard(
              schedule: schedule,
              totalMembers: groupMembersCache[schedule.groupId]?.count ?? schedule.minimumParticipants,
              onTap: { onScheduleTap(schedule) }
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
      Text(LocalizedStrings.Home.needResponse)
        .font(.headline)
        .foregroundStyle(.primary)

      // 배지
      if !schedules.isEmpty {
        Text("\(schedules.count)")
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
    schedules: [
      ScheduleModel.mock(id: "1", title: "저녁 모임"),
      ScheduleModel.mock(id: "2", title: "주말 일정")
    ],
    groupMembersCache: [:],
    onScheduleTap: { _ in }
  )
  .padding()
  .auroraBackground()
}
