import SwiftUI
import Clients
import ComposableArchitecture
import PromisoShared

struct NotificationMethodSection: View {
  let store: StoreOf<CreateSchedule.Feature>

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // 섹션 제목
      Text(LocalizedStrings.CreateSchedule.notificationMethod)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.primary)

      // 설명
      Text(LocalizedStrings.CreateSchedule.notificationMethodDescription)
        .font(.system(size: 13))
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)

      // 3개 칩 (가로 배열)
      HStack(spacing: 8) {
        NotificationMethodChip(
          title: LocalizedStrings.CreateSchedule.notificationLiveActivity,
          systemImage: "person.wave.2",
          isSelected: store.notificationMethod == .liveActivity
        ) {
          store.send(.view(.setNotificationMethod(.liveActivity)), animation: .spring(response: 0.25, dampingFraction: 0.8))
        }

        NotificationMethodChip(
          title: LocalizedStrings.CreateSchedule.notificationPush,
          systemImage: "bell.fill",
          isSelected: store.notificationMethod == .pushNotification
        ) {
          store.send(.view(.setNotificationMethod(.pushNotification)), animation: .spring(response: 0.25, dampingFraction: 0.8))
        }

        NotificationMethodChip(
          title: LocalizedStrings.CreateSchedule.notificationNone,
          systemImage: "bell.slash",
          isSelected: store.notificationMethod == .none
        ) {
          store.send(.view(.setNotificationMethod(.none)), animation: .spring(response: 0.25, dampingFraction: 0.8))
        }
      }
    }
  }
}

// MARK: - Notification Method Chip

private struct NotificationMethodChip: View {
  let title: String
  let systemImage: String
  let isSelected: Bool
  let action: () -> Void

  @State private var isPressed = false

  var body: some View {
    Button {
      action()
    } label: {
      HStack(spacing: 4) {
        Image(systemName: systemImage)
          .font(.system(size: 12))

        Text(title)
          .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
      }
      .foregroundColor(isSelected ? .white : .primary)
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity)
      .background(
        Group {
          if isSelected {
            Color.pmindigo.n500
          } else {
            Color(.systemGray5)
          }
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(isSelected ? Color.pmindigo.n300 : Color.clear, lineWidth: 1)
      )
      .scaleEffect(isPressed ? 0.95 : 1.0)
      .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .simultaneousGesture(
      DragGesture(minimumDistance: 0)
        .onChanged { _ in isPressed = true }
        .onEnded { _ in isPressed = false }
    )
    .sensoryFeedback(.selection, trigger: isSelected)
  }
}
