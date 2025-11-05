import SwiftUI

struct CurrentGroupCard: View {
  let group: CurrentGroup
  let onTap: () -> Void
  let onSettings: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // Group Emoji
        Text(group.emoji)
          .font(.system(size: 36))

        // Group Info
        VStack(alignment: .leading, spacing: 4) {
          Text(group.name)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.primary)

          HStack(spacing: 8) {
            Text("\(group.activeCount)개 진행중")
              .font(.system(size: 14))
              .foregroundColor(.secondary)

            Text("·")
              .foregroundColor(.secondary)

            Text("\(group.pendingCount)개 대기")
              .font(.system(size: 14))
              .foregroundColor(.secondary)
          }
        }

        Spacer()

        // Settings Button
        Button(action: {
          onSettings()
        }) {
          Image(systemName: "gearshape.fill")
            .font(.system(size: 20))
            .foregroundColor(.secondary)
            .padding(8)
            .background(Color.blue.opacity(0.1))
            .clipShape(Circle())
        }
        .buttonStyle(PlainButtonStyle())

        // Chevron
        Image(systemName: "chevron.right")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.secondary)
      }
      .padding(16)
      .background(
        LinearGradient(
          colors: [Color.blue.opacity(0.1), Color.blue.opacity(0.15)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    .buttonStyle(PlainButtonStyle())
  }
}

// MARK: - Preview

#Preview {
  CurrentGroupCard(
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
    onTap: {},
    onSettings: {}
  )
  .padding()
}
