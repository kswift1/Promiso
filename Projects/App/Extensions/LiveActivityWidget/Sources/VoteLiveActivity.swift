import ActivityKit
import AppIntents
import PromisoShared
import ResourceKit
import SwiftUI
import WidgetKit

// MARK: - Vote Live Activity Widget

struct VoteLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: VoteActivityAttributes.self) { context in
      // MARK: - Lock Screen UI
      VoteLockScreenView(context: context)
        .activityBackgroundTint(.black)
        .widgetURL(AppConstants.Deeplink.url(path: "vote/\(context.attributes.scheduleId)"))

    } dynamicIsland: { context in
      DynamicIsland {
        // MARK: - Expanded Center (이모지 + 제목 + 장소)
        DynamicIslandExpandedRegion(.center) {
          HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
              Text("\(context.attributes.emoji) \(context.attributes.title)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

              if let location = context.attributes.location {
                HStack(spacing: 4) {
                  Text("📍")
                    .font(.caption2)
                  Text(location)
                    .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
              }
            }

            Spacer()

            // 오른쪽: 일정 시간
            VStack(alignment: .trailing, spacing: 2) {
              Text(context.attributes.scheduledTime.amPmText)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))

              Text(context.attributes.scheduledTime.timeOnlyText)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
            }
          }
          .padding(.horizontal, 8)
        }

        // MARK: - Expanded Bottom (응답 현황)
        DynamicIslandExpandedRegion(.bottom) {
          VoteStatusBar(
            state: context.state,
            totalMemberCount: context.attributes.totalMemberCount
          )
          .padding(.horizontal, 8)
          .padding(.top, 8)
        }

      } compactLeading: {
        // MARK: - Compact Leading (이모지)
        Text(context.attributes.emoji)
          .font(.system(size: 16))

      } compactTrailing: {
        // MARK: - Compact Trailing (참여/전체 카운트)
        Text("\(context.state.acceptedMembers.count)/\(context.attributes.totalMemberCount)")
          .font(.system(size: 14, weight: .bold, design: .monospaced))
          .monospacedDigit()

      } minimal: {
        // MARK: - Minimal (이모지)
        Text(context.attributes.emoji)
          .font(.system(size: 16))
      }
      .widgetURL(AppConstants.Deeplink.url(path: "vote/\(context.attributes.scheduleId)"))
    }
  }
}

// MARK: - Lock Screen Banner View

private struct VoteLockScreenView: View {
  let context: ActivityViewContext<VoteActivityAttributes>

  /// 현재 유저가 이미 응답했는지 여부
  private var hasResponded: Bool {
    let userId = context.attributes.currentUserId
    let accepted = context.state.acceptedMembers.contains { $0.id == userId }
    let declined = context.state.declinedMembers.contains { $0.id == userId }
    return accepted || declined
  }

  /// 현재 유저의 응답이 참여인지 여부 (응답한 경우에만 의미 있음)
  private var isAccepted: Bool {
    context.state.acceptedMembers.contains { $0.id == context.attributes.currentUserId }
  }

  var body: some View {
    VStack(spacing: 12) {
      // 상단: 이모지 + 제목 + 일정 시간
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("\(context.attributes.emoji) \(context.attributes.title)")
            .font(.headline.weight(.bold))
            .foregroundStyle(.primary)
            .lineLimit(2)
            .minimumScaleFactor(0.8)

          if let location = context.attributes.location {
            Label(location, systemImage: "mappin.circle.fill")
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }

        Spacer()

        // 일정 시간 표시
        VStack(alignment: .trailing, spacing: 2) {
          Text(context.attributes.scheduledTime.amPmText)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)

          Text(context.attributes.scheduledTime.timeOnlyText)
            .font(.system(size: 17, weight: .bold, design: .monospaced))
            .foregroundStyle(.primary)
        }
      }

      // 중간: 응답 현황 바
      VoteStatusBar(
        state: context.state,
        totalMemberCount: context.attributes.totalMemberCount
      )

      // 하단: 버튼 또는 완료/마감 메시지
      Group {
        if context.state.isFinalized {
          // 투표 마감
          Label("투표 마감", systemImage: "lock.fill")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

        } else if hasResponded {
          // 이미 응답함 — 참여/불참 완료 텍스트
          let message = isAccepted ? "참여 완료" : "불참 완료"
          let icon = isAccepted ? "checkmark.circle.fill" : "xmark.circle.fill"
          let color: Color = isAccepted ? .green : .red

          Label(message, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))

        } else {
          // 미응답 — 참여/불참 버튼
          VoteActionButtons(
            channelId: context.attributes.channelId,
            scheduleId: context.attributes.scheduleId,
            userId: context.attributes.currentUserId,
            totalMemberCount: context.attributes.totalMemberCount,
            state: context.state
          )
        }
      }
    }
    .padding(16)
  }
}

// MARK: - Vote Action Buttons

private struct VoteActionButtons: View {
  let channelId: String
  let scheduleId: String
  let userId: String
  let totalMemberCount: Int
  let state: VoteActivityAttributes.ContentState

  /// ContentState를 JSON 문자열로 직렬화
  private var stateJSON: String {
    let encoder = JSONEncoder()
    guard let data = try? encoder.encode(state),
          let json = String(data: data, encoding: .utf8) else {
      return "{}"
    }
    return json
  }

  var body: some View {
    HStack(spacing: 12) {
      // 참여 버튼
      Button(intent: VoteResponseIntent(
        channelId: channelId,
        scheduleId: scheduleId,
        userId: userId,
        response: "accepted",
        totalMemberCount: totalMemberCount,
        currentStateJSON: stateJSON
      )) {
        Label("참여", systemImage: "checkmark.circle.fill")
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .tint(.green)
      .buttonStyle(.borderedProminent)
      .buttonBorderShape(.roundedRectangle(radius: 10))

      // 불참 버튼
      Button(intent: VoteResponseIntent(
        channelId: channelId,
        scheduleId: scheduleId,
        userId: userId,
        response: "declined",
        totalMemberCount: totalMemberCount,
        currentStateJSON: stateJSON
      )) {
        Label("불참", systemImage: "xmark.circle.fill")
          .font(.subheadline.weight(.semibold))
          .frame(maxWidth: .infinity)
      }
      .tint(.red)
      .buttonStyle(.borderedProminent)
      .buttonBorderShape(.roundedRectangle(radius: 10))
    }
  }
}

// MARK: - Vote Status Bar

private struct VoteStatusBar: View {
  let state: VoteActivityAttributes.ContentState
  let totalMemberCount: Int

  private var acceptedCount: Int { state.acceptedMembers.count }
  private var declinedCount: Int { state.declinedMembers.count }
  private var pendingCount: Int { state.pendingCount }
  private var total: Int { max(totalMemberCount, 1) }

  var body: some View {
    VStack(spacing: 6) {
      // 프로그레스 바 (그룹 일정 카드 스타일)
      GeometryReader { geometry in
        let barWidth = geometry.size.width
        let acceptedRatio = CGFloat(acceptedCount) / CGFloat(total)
        let declinedRatio = CGFloat(declinedCount) / CGFloat(total)

        ZStack(alignment: .leading) {
          // 배경
          Capsule()
            .fill(Color.gray.opacity(0.25))

          // 참여 + 불참 채움
          HStack(spacing: 0) {
            Rectangle()
              .fill(Color.green)
              .frame(width: max(0, barWidth * acceptedRatio))
            Rectangle()
              .fill(Color.red.opacity(0.6))
              .frame(width: max(0, barWidth * declinedRatio))
          }
          .clipShape(Capsule())

          // 인원별 마디
          if total > 1 {
            ForEach(1..<total, id: \.self) { i in
              let x = barWidth * CGFloat(i) / CGFloat(total)
              RoundedRectangle(cornerRadius: 0.5)
                .fill(Color.white.opacity(0.3))
                .frame(width: 1, height: 6)
                .offset(x: x - 0.5)
            }
          }
        }
      }
      .frame(height: 6)

      // 범례
      HStack(spacing: 0) {
        HStack(spacing: 3) {
          Circle()
            .fill(Color.green)
            .frame(width: 6, height: 6)
          Text("\(acceptedCount)명 참여")
            .foregroundStyle(.green)
        }

        Text(" · ")
          .foregroundStyle(.white.opacity(0.3))

        HStack(spacing: 3) {
          Circle()
            .fill(Color.red.opacity(0.7))
            .frame(width: 6, height: 6)
          Text("\(declinedCount)명 불참")
            .foregroundStyle(.red)
        }

        Text(" · ")
          .foregroundStyle(.white.opacity(0.3))

        HStack(spacing: 3) {
          Circle()
            .fill(Color.gray.opacity(0.4))
            .frame(width: 6, height: 6)
          Text("\(pendingCount)명 대기")
            .foregroundStyle(.secondary)
        }

        Spacer()
      }
      .font(.system(size: 11, weight: .medium))
    }
  }
}

// MARK: - Date Extension

private extension Date {
  var amPmText: String {
    LocalizedDateFormatters.amPm.string(from: self)
  }

  var timeOnlyText: String {
    LocalizedDateFormatters.time12Hour.string(from: self)
  }
}

// MARK: - Preview Attributes

private let previewAttributes = VoteActivityAttributes(
  scheduleId: "preview-vote-123",
  currentUserId: "user-1",
  emoji: "🍕",
  title: "금요일 피자 번개",
  location: "강남역 2번 출구",
  scheduledTime: Date().addingTimeInterval(3600 * 24),
  hostId: "user-1",
  hostName: "민수",
  channelId: "channel-abc",
  groupName: "친구들",
  totalMemberCount: 5
)

/// 긴 제목 테스트용
private let previewAttributesLong = VoteActivityAttributes(
  scheduleId: "preview-vote-long",
  currentUserId: "user-3",
  emoji: "🎉",
  title: "성원이 생일 파티 with 동아리 친구들",
  location: "서울특별시 마포구 홍익로 12길 21",
  scheduledTime: Date().addingTimeInterval(3600 * 48),
  hostId: "user-2",
  hostName: "지현",
  channelId: "channel-xyz",
  groupName: "대학교 동아리",
  totalMemberCount: 8
)

// MARK: - Preview States

/// 1. 초기 상태 — 모두 대기
private let stateInitial = VoteActivityAttributes.ContentState(
  acceptedMembers: [],
  declinedMembers: [],
  pendingCount: 5,
  isFinalized: false
)

/// 2. 진행 중 — 일부 응답
private let stateInProgress = VoteActivityAttributes.ContentState(
  acceptedMembers: [
    VoteMember(id: "user-1", name: "민수"),
    VoteMember(id: "user-2", name: "지현")
  ],
  declinedMembers: [
    VoteMember(id: "user-3", name: "서연")
  ],
  pendingCount: 2,
  isFinalized: false
)

/// 3. 현재 유저가 이미 참여 응답한 상태
private let stateCurrentUserAccepted = VoteActivityAttributes.ContentState(
  acceptedMembers: [
    VoteMember(id: "user-1", name: "나"),
    VoteMember(id: "user-2", name: "민수")
  ],
  declinedMembers: [
    VoteMember(id: "user-3", name: "서연")
  ],
  pendingCount: 2,
  isFinalized: false
)

/// 4. 투표 마감
private let stateFinalized = VoteActivityAttributes.ContentState(
  acceptedMembers: [
    VoteMember(id: "user-1", name: "민수"),
    VoteMember(id: "user-2", name: "지현"),
    VoteMember(id: "user-3", name: "서연")
  ],
  declinedMembers: [
    VoteMember(id: "user-4", name: "태양")
  ],
  pendingCount: 1,
  isFinalized: true
)

// MARK: - Previews

#Preview("1. 초기 상태 (Lock Screen)", as: .content, using: previewAttributes) {
  VoteLiveActivity()
} contentStates: {
  stateInitial
}

#Preview("2. 진행 중 (Lock Screen)", as: .content, using: previewAttributes) {
  VoteLiveActivity()
} contentStates: {
  stateInProgress
}

#Preview("3. 현재 유저 참여 완료 (Lock Screen)", as: .content, using: previewAttributes) {
  VoteLiveActivity()
} contentStates: {
  stateCurrentUserAccepted
}

#Preview("4. 투표 마감 (Lock Screen)", as: .content, using: previewAttributes) {
  VoteLiveActivity()
} contentStates: {
  stateFinalized
}

#Preview("5. 긴 제목 (Lock Screen)", as: .content, using: previewAttributesLong) {
  VoteLiveActivity()
} contentStates: {
  stateInProgress
}

// MARK: - Dynamic Island Previews

#Preview("DI - Compact", as: .dynamicIsland(.compact), using: previewAttributes) {
  VoteLiveActivity()
} contentStates: {
  stateInProgress
}

#Preview("DI - Expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
  VoteLiveActivity()
} contentStates: {
  stateInProgress
}

#Preview("DI - Minimal", as: .dynamicIsland(.minimal), using: previewAttributes) {
  VoteLiveActivity()
} contentStates: {
  stateInProgress
}
