import SwiftUI

struct GroupDetailView: View {
  let group: CurrentGroup
  let onDismiss: () -> Void
  let onSettings: () -> Void
  let onToggleNotifications: () -> Void

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          // Group Header
          VStack(spacing: 12) {
            Text(group.emoji)
              .font(.system(size: 80))

            Text(group.name)
              .font(.system(size: 28, weight: .bold))

            HStack(spacing: 16) {
              StatItem(
                icon: "person.2.fill",
                value: "\(group.members.count)",
                label: "멤버"
              )

              StatItem(
                icon: "calendar.badge.clock",
                value: "\(group.activeCount)",
                label: "진행중"
              )

              StatItem(
                icon: "clock.fill",
                value: "\(group.pendingCount)",
                label: "대기"
              )
            }
          }
          .padding(.top, 20)

          Divider()
            .padding(.horizontal, 16)

          // Settings Section
          VStack(alignment: .leading, spacing: 16) {
            Text("설정")
              .font(.system(size: 18, weight: .bold))
              .padding(.horizontal, 16)

            VStack(spacing: 12) {
              SettingRow(
                icon: "bell.fill",
                title: "알림",
                isOn: group.notifications,
                onToggle: onToggleNotifications
              )

              SettingRow(
                icon: "gearshape.fill",
                title: "그룹 설정",
                action: onSettings
              )
            }
            .padding(.horizontal, 16)
          }

          Divider()
            .padding(.horizontal, 16)

          // Members Section
          VStack(alignment: .leading, spacing: 16) {
            Text("멤버 (\(group.members.count))")
              .font(.system(size: 18, weight: .bold))
              .padding(.horizontal, 16)

            VStack(spacing: 12) {
              ForEach(group.members) { member in
                MemberRow(member: member)
              }
            }
            .padding(.horizontal, 16)
          }

          Spacer(minLength: 40)
        }
        .padding(.bottom, 40)
      }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarLeading) {
          Button(action: onDismiss) {
            Image(systemName: "xmark")
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.primary)
          }
        }
      }
    }
  }
}

private struct StatItem: View {
  let icon: String
  let value: String
  let label: String

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: icon)
        .font(.system(size: 24))
        .foregroundColor(.blue)

      Text(value)
        .font(.system(size: 20, weight: .bold))

      Text(label)
        .font(.system(size: 14))
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
  }
}

private struct SettingRow: View {
  let icon: String
  let title: String
  var isOn: Bool?
  var onToggle: (() -> Void)?
  var action: (() -> Void)?

  var body: some View {
    HStack(spacing: 16) {
      Image(systemName: icon)
        .font(.system(size: 20))
        .foregroundColor(.blue)
        .frame(width: 28)

      Text(title)
        .font(.system(size: 16))

      Spacer()

      if let isOn = isOn, let onToggle = onToggle {
        Toggle("", isOn: .init(
          get: { isOn },
          set: { _ in onToggle() }
        ))
        .labelsHidden()
      } else if action != nil {
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(.secondary)
      }
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color(.systemGray5), lineWidth: 1)
    )
    .contentShape(Rectangle())
    .onTapGesture {
      if let action = action {
        action()
      }
    }
  }
}

private struct MemberRow: View {
  let member: GroupMember

  var body: some View {
    HStack(spacing: 16) {
      Text(member.emoji)
        .font(.system(size: 36))

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Text(member.name)
            .font(.system(size: 16, weight: .semibold))

          if member.isMe {
            Text("나")
              .font(.system(size: 12, weight: .semibold))
              .foregroundColor(.blue)
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.blue.opacity(0.1))
              .clipShape(Capsule())
          }
        }

        Text(member.role.displayText)
          .font(.system(size: 14))
          .foregroundColor(.secondary)
      }

      Spacer()
    }
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color(.systemGray5), lineWidth: 1)
    )
  }
}

// MARK: - Preview

#Preview {
  GroupDetailView(
    group: CurrentGroup(
      id: "1",
      name: "지민과 나",
      emoji: "👥",
      activeCount: 2,
      pendingCount: 1,
      role: .admin,
      notifications: true,
      members: [
        GroupMember(
          id: "1",
          name: "성원",
          emoji: "🧑‍💻",
          role: .admin,
          isMe: true
        ),
        GroupMember(
          id: "2",
          name: "지민",
          emoji: "👩‍🎨",
          role: .member,
          isMe: false
        ),
      ]
    ),
    onDismiss: {},
    onSettings: {},
    onToggleNotifications: {}
  )
}
