import SwiftUI
import PromisoShared

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
            Text(LocalizedStrings.GroupComponents.activeCount(group.activeCount))
              .font(.system(size: 14))
              .foregroundColor(.secondary)

            Text("·")
              .foregroundColor(.secondary)

            Text(LocalizedStrings.GroupComponents.pendingCount(group.pendingCount))
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
      .adaptiveGlassCardBackground(tint: .blue)
    }
    .buttonStyle(PlainButtonStyle())
  }
}

// MARK: - Glass Effect Modifier

private extension View {
  /// iOS 26: thinMaterial glass effect with tint, 이전: gradient background
  func adaptiveGlassCardBackground(tint: Color) -> some View {
    if #available(iOS 26.0, *) {
      return AnyView(
        self
          .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
          .background(
            LinearGradient(
              colors: [tint.opacity(0.15), tint.opacity(0.25)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16)
              .strokeBorder(tint.opacity(0.3), lineWidth: 1.5)
          )
          .shadow(color: tint.opacity(0.2), radius: 12, x: 0, y: 6)
      )
    } else {
      return AnyView(
        self
          .background(
            LinearGradient(
              colors: [tint.opacity(0.1), tint.opacity(0.15)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .clipShape(RoundedRectangle(cornerRadius: 16))
      )
    }
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
