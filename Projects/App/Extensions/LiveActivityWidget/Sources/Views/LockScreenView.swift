import PromisoShared
import SwiftUI
import WidgetKit

// MARK: - Lock Screen View

struct LockScreenView: View {
  let attributes: PromiseActivityAttributes
  let state: PromiseActivityAttributes.ContentState

  var body: some View {
    HStack(spacing: 16) {
      // MARK: - Left: Promise Info
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text(attributes.emoji)
            .font(.title2)
          Text(attributes.title)
            .font(.headline)
            .lineLimit(1)
        }

        if let location = attributes.locationName {
          Label(location, systemImage: "mappin")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Text(attributes.startAt, style: .time)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      // MARK: - Right: Arrival Status
      VStack(alignment: .trailing, spacing: 4) {
        ArrivalCountBadge(
          arrived: state.arrivedCount,
          total: attributes.totalParticipants
        )

        Text("도착")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
    .padding()
    .activityBackgroundTint(.black.opacity(0.7))
  }
}

// MARK: - Arrival Count Badge

struct ArrivalCountBadge: View {
  let arrived: Int
  let total: Int

  private var isComplete: Bool {
    arrived == total
  }

  var body: some View {
    Text("\(arrived)/\(total)")
      .font(.title2.bold().monospacedDigit())
      .foregroundStyle(isComplete ? .green : .primary)
  }
}

// MARK: - Member Status Row

struct MemberStatusRow: View {
  let members: [MemberArrivalStatus]

  private let maxDisplayCount = 5

  var body: some View {
    HStack(spacing: 8) {
      ForEach(members.prefix(maxDisplayCount)) { member in
        MemberAvatar(member: member)
      }

      if members.count > maxDisplayCount {
        Text("+\(members.count - maxDisplayCount)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }
}

// MARK: - Member Avatar

struct MemberAvatar: View {
  let member: MemberArrivalStatus

  private var initial: String {
    String(member.memberName.prefix(1))
  }

  var body: some View {
    VStack(spacing: 2) {
      ZStack {
        Circle()
          .fill(member.hasArrived ? .green : .gray.opacity(0.3))
          .frame(width: 32, height: 32)

        Text(initial)
          .font(.caption.bold())
          .foregroundStyle(.white)

        if member.hasArrived {
          Circle()
            .fill(.green)
            .frame(width: 12, height: 12)
            .overlay {
              Image(systemName: "checkmark")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
            }
            .offset(x: 10, y: 10)
        }
      }

      Text(member.memberName)
        .font(.caption2)
        .lineLimit(1)
        .frame(maxWidth: 40)
    }
  }
}

// MARK: - Preview

#Preview {
  LockScreenView(
    attributes: PromiseActivityAttributes(
      promiseId: "preview-123",
      title: "점심 약속",
      emoji: "🍽️",
      startAt: Date().addingTimeInterval(1800),
      locationName: "강남역 2번 출구",
      groupId: "group-123",
      totalParticipants: 4
    ),
    state: PromiseActivityAttributes.ContentState(
      memberStatuses: [
        MemberArrivalStatus(memberId: "1", memberName: "김철수", hasArrived: true, arrivedAt: Date()),
        MemberArrivalStatus(memberId: "2", memberName: "이영희", hasArrived: true, arrivedAt: Date()),
        MemberArrivalStatus(memberId: "3", memberName: "박민수", hasArrived: false),
        MemberArrivalStatus(memberId: "4", memberName: "최지원", hasArrived: false)
      ],
      lastUpdatedAt: Date(),
      isEnded: false
    )
  )
}
