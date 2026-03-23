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
        .widgetURL(AppConstants.Deeplink.url(path: "vote/\(context.attributes.scheduleId)"))

    } dynamicIsland: { context in
      DynamicIsland {
        // MARK: - Expanded Center
        DynamicIslandExpandedRegion(.center) {
          VStack(alignment: .leading, spacing: 3) {
            // 1행: 제목 + 일정
            HStack(alignment: .firstTextBaseline) {
              Text("\(context.attributes.emoji) \(context.attributes.title)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
              Spacer()
              Text(context.attributes.scheduledTime.dateTimeText)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
            }
            // 2행: 그룹 · 위치 · 카운트다운
            HStack(spacing: 4) {
              if let groupName = context.attributes.groupName {
                Image(systemName: "person.2.fill")
                  .font(.system(size: 7))
                  .foregroundStyle(Color.pmindigo.n300)
                Text(groupName)
                  .font(.system(size: 10))
                  .foregroundStyle(.white.opacity(0.5))
              }
              if context.attributes.groupName != nil, context.attributes.location != nil {
                Text("·")
                  .font(.system(size: 10))
                  .foregroundStyle(.white.opacity(0.3))
              }
              if let location = context.attributes.location {
                Image(systemName: "location.fill")
                  .font(.system(size: 7))
                  .foregroundStyle(Color.pmindigo.n300)
                Text(location)
                  .font(.system(size: 10))
                  .foregroundStyle(.white.opacity(0.5))
              }
              Spacer()
              Image(systemName: "timer")
                .font(.system(size: 7))
                .foregroundStyle(Color.pmindigo.n300)
              Text(context.attributes.voteDeadline, style: .timer)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            }
            .lineLimit(1)
          }
          .padding(.horizontal, 8)
        }

        // MARK: - Expanded Bottom (응답 현황)
        DynamicIslandExpandedRegion(.bottom) {
          VoteStatusBar(
            state: context.state,
            totalMemberCount: context.attributes.totalMemberCount, minimumParticipants: context.attributes.minimumParticipants
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
    VStack(spacing: 10) {
      // 1행: 이모지 + 제목 (좌) / 약속 시간 (우)
      HStack(alignment: .firstTextBaseline) {
        Text("\(context.attributes.emoji) \(context.attributes.title)")
          .font(.system(size: 19, weight: .bold))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)

        Spacer()

        Text(context.attributes.scheduledTime.dateTimeText)
          .font(.system(size: 13, weight: .semibold, design: .monospaced))
          .foregroundStyle(.white.opacity(0.7))
      }

      // 2행: 그룹 · 위치
      HStack(spacing: 4) {
        if let groupName = context.attributes.groupName {
          Image(systemName: "person.2.fill")
            .font(.system(size: 8))
            .foregroundStyle(Color.pmindigo.n300)
          Text(groupName)
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.5))
        }

        if context.attributes.groupName != nil, context.attributes.location != nil {
          Text("·")
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.3))
        }

        if let location = context.attributes.location {
          Image(systemName: "location.fill")
            .font(.system(size: 8))
            .foregroundStyle(Color.pmindigo.n300)
          Text(location)
            .font(.system(size: 10))
            .foregroundStyle(.white.opacity(0.5))
        }

        Spacer()
      }
      .lineLimit(1)

      // 3행: 남은 시간
      HStack(spacing: 4) {
        Image(systemName: "timer")
          .font(.system(size: 8))
          .foregroundStyle(Color.pmindigo.n300)
        Text("투표 종료까지")
          .font(.system(size: 10))
          .foregroundStyle(.white.opacity(0.4))
        Text(context.attributes.voteDeadline, style: .timer)
          .font(.system(size: 10, weight: .medium, design: .monospaced))
          .foregroundStyle(.white.opacity(0.6))
        Spacer()
      }

      // 중간: 응답 현황 (썸네일 포함)
      VoteStatusBar(
        state: context.state,
        totalMemberCount: context.attributes.totalMemberCount,
        minimumParticipants: context.attributes.minimumParticipants
      )

      // 하단: 마감 시 텍스트, 아니면 항상 버튼 표시
      if context.state.isFinalized {
        Label("투표 마감", systemImage: "lock.fill")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.white.opacity(0.6))
          .frame(maxWidth: .infinity)
          .padding(.vertical, 8)
          .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
      } else {
        VoteActionButtons(
          channelId: context.attributes.channelId,
          scheduleId: context.attributes.scheduleId,
          userId: context.attributes.currentUserId,
          totalMemberCount: context.attributes.totalMemberCount,
          state: context.state,
          currentResponse: hasResponded ? (isAccepted ? "accepted" : "declined") : nil
        )
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .foregroundStyle(.white)
    .activityBackgroundTint(.black)
  }
}

// MARK: - Vote Action Buttons

private struct VoteActionButtons: View {
  let channelId: String
  let scheduleId: String
  let userId: String
  let totalMemberCount: Int
  let state: VoteActivityAttributes.ContentState
  /// 현재 응답 상태: "accepted", "declined", nil(미응답)
  let currentResponse: String?

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
      .tint(currentResponse == "accepted" ? .green : .gray)
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
      .tint(currentResponse == "declined" ? .red : .gray)
      .buttonStyle(.borderedProminent)
      .buttonBorderShape(.roundedRectangle(radius: 10))
    }
  }
}

// MARK: - Vote Status Bar

private struct VoteStatusBar: View {
  let state: VoteActivityAttributes.ContentState
  let totalMemberCount: Int
  let minimumParticipants: Int

  private var acceptedCount: Int { state.acceptedMembers.count }
  private var declinedCount: Int { state.declinedMembers.count }
  private var pendingCount: Int { state.pendingCount }
  private var total: Int { max(totalMemberCount, 1) }
  private var isConfirmed: Bool { acceptedCount >= minimumParticipants }

  var body: some View {
    VStack(spacing: 6) {
      // 프로그레스 바 (그룹 일정 카드 스타일)
      GeometryReader { geometry in
        let barWidth = geometry.size.width
        let acceptedRatio = min(1.0, CGFloat(acceptedCount) / CGFloat(total))
        let declinedRatio = min(1.0 - acceptedRatio, CGFloat(declinedCount) / CGFloat(total))
        let confirmRatio = min(1.0, CGFloat(minimumParticipants) / CGFloat(total))

        ZStack(alignment: .leading) {
          // 배경
          Capsule()
            .fill(Color.white.opacity(0.15))

          // 참여 + 불참 채움
          HStack(spacing: 0) {
            Rectangle()
              .fill(isConfirmed ? Color.green : Color.green.opacity(0.7))
              .frame(width: max(0, barWidth * acceptedRatio))
            Rectangle()
              .fill(Color.red.opacity(0.5))
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

          // 확정 기준선 (보라색)
          if minimumParticipants < total {
            RoundedRectangle(cornerRadius: 1)
              .fill(Color.pmindigo.n500)
              .frame(width: 2, height: 10)
              .offset(x: barWidth * confirmRatio - 1)
          }
        }
      }
      .frame(height: 6)

      // 범례 (아바타 포함)
      HStack(spacing: 0) {
        // 참여
        HStack(spacing: 2) {
          Circle().fill(Color.green).frame(width: 6, height: 6)
          Text("참여 \(acceptedCount)")
            .foregroundStyle(.green)
          MiniAvatarStack(
            members: state.acceptedMembers,
            color: .green
          )
        }
        Text("·").foregroundStyle(.white.opacity(0.3))
        // 불참
        HStack(spacing: 2) {
          Circle().fill(Color.red.opacity(0.7)).frame(width: 6, height: 6)
          Text("불참 \(declinedCount)")
            .foregroundStyle(.red)
          MiniAvatarStack(
            members: state.declinedMembers,
            color: .red
          )
        }
        Text("·").foregroundStyle(.white.opacity(0.3))
        // 미응답
        HStack(spacing: 2) {
          Circle()
            .fill(Color.white.opacity(0.3))
            .frame(width: 6, height: 6)
          Text("미응답 \(pendingCount)")
            .foregroundStyle(.white.opacity(0.4))
        }
        Text("·").foregroundStyle(.white.opacity(0.3))
        // 최소확정 기준
        HStack(spacing: 2) {
          RoundedRectangle(cornerRadius: 0.5)
            .fill(Color.pmindigo.n500)
            .frame(width: 2, height: 8)
          Text("최소확정 \(minimumParticipants)")
            .foregroundStyle(Color.pmindigo.n500)
        }
        Spacer()
      }
      .font(.system(size: 11, weight: .medium))
    }
  }
}

// MARK: - Mini Avatar Stack

/// 범례 옆 아바타 (최대 3개 + 초과 뱃지)
/// 기존 CompactParticipantMarker 패턴: 캐시 이미지 → 이모지 폴백
private struct MiniAvatarStack: View {
  let members: [VoteMember]
  let color: Color

  private let size: CGFloat = 16
  private let overlap: CGFloat = 4
  private let maxVisible: Int = 3

  private static let defaultEmojis = [
    "😀", "😊", "🙂", "😎", "🤗",
    "😇", "🥳", "🤩", "😺", "🐻"
  ]

  var body: some View {
    let visible = Array(members.prefix(maxVisible))
    let extra = members.count - visible.count

    HStack(spacing: -overlap) {
      ForEach(visible) { member in
        MiniAvatar(member: member, color: color, size: size)
      }

      if extra > 0 {
        Text("+\(extra)")
          .font(.system(size: 7, weight: .bold))
          .foregroundStyle(.white)
          .frame(width: size, height: size)
          .background(Color.white.opacity(0.2), in: Circle())
          .overlay(
            Circle().strokeBorder(.black, lineWidth: 0.5)
          )
      }
    }
  }
}

/// 단일 미니 아바타: 캐시 프로필 이미지 → 이니셜 폴백
private struct MiniAvatar: View {
  let member: VoteMember
  let color: Color
  let size: CGFloat

  private var cachedImage: UIImage? {
    LiveActivityImageStore.loadImage(userId: member.id)
  }

  var body: some View {
    Group {
      if let image = cachedImage {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: size, height: size)
          .clipShape(Circle())
      } else {
        ZStack {
          Circle().fill(color.opacity(0.6))
          Text(String(member.name.prefix(1)))
            .font(.system(size: size * 0.5, weight: .bold))
            .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
      }
    }
    .overlay(Circle().strokeBorder(color, lineWidth: 1))
    .overlay(Circle().strokeBorder(.black, lineWidth: 0.5))
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

  /// "3/24(월) 오후 7:42" 형태
  var dateTimeText: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M/d(E) a h:mm"
    return formatter.string(from: self)
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
  totalMemberCount: 5,
  voteDeadline: Date().addingTimeInterval(3600 * 23)
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
  totalMemberCount: 8,
  voteDeadline: Date().addingTimeInterval(3600 * 47)
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
