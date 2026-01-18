import ActivityKit
import PromisoShared
import SwiftUI

// MARK: - Live Activity Test Section

struct LiveActivityTestSection: View {
  @State private var isActive = false
  @State private var activityId: String?
  @State private var statusMessage = ""

  var body: some View {
    VStack(spacing: 12) {
      // 헤더
      HStack {
        Text("🧪 라이브액티비티 테스트")
          .font(.headline)
        Spacer()
        if isActive {
          Text("활성")
            .font(.caption)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.green)
            .clipShape(Capsule())
        }
      }

      // 상태 메시지
      if !statusMessage.isEmpty {
        Text(statusMessage)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      // 버튼
      if isActive {
        Button {
          endActivity()
        } label: {
          Label("종료", systemImage: "stop.circle.fill")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
      } else {
        Button {
          startActivity()
        } label: {
          Label("라이브액티비티 시작", systemImage: "play.circle.fill")
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.purple)
      }
    }
    .padding(16)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .onAppear {
      checkExisting()
    }
  }

  // MARK: - Actions

  private func startActivity() {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      statusMessage = "라이브액티비티 비활성화됨"
      return
    }

    let attributes = PromiseActivityAttributes(
      promiseId: "test-\(UUID().uuidString.prefix(8))",
      currentUserId: "user-1",
      emoji: "🍜",
      title: "점심 모임 테스트용 긴 제목입니다",
      location: "강남역 11번 출구 긴 위치 테스트",
      scheduledTime: Date().addingTimeInterval(1800)
    )

    let state = PromiseActivityAttributes.ContentState(
      trackingDurationMinutes: 30,
      participants: [
        ParticipantState(id: "user-1", name: "나", estimatedArrivalMinutes: nil),
        ParticipantState(id: "user-2", name: "민수", estimatedArrivalMinutes: nil),
        ParticipantState(id: "user-3", name: "지현", estimatedArrivalMinutes: nil),
        ParticipantState(id: "user-4", name: "서연", estimatedArrivalMinutes: nil)
      ]
    )

    do {
      let activity = try Activity.request(
        attributes: attributes,
        content: ActivityContent(state: state, staleDate: nil),
        pushType: nil
      )
      activityId = activity.id
      isActive = true
      statusMessage = "시작됨"
    } catch {
      statusMessage = "실패: \(error.localizedDescription)"
    }
  }

  private func endActivity() {
    Task {
      for activity in Activity<PromiseActivityAttributes>.activities {
        await activity.end(nil, dismissalPolicy: .immediate)
      }
      await MainActor.run {
        isActive = false
        activityId = nil
        statusMessage = "종료됨"
      }
    }
  }

  private func checkExisting() {
    isActive = !Activity<PromiseActivityAttributes>.activities.isEmpty
    if isActive {
      activityId = Activity<PromiseActivityAttributes>.activities.first?.id
    }
  }
}
