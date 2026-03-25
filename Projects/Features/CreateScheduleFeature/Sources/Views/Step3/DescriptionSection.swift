import SwiftUI
import Clients
import ComposableArchitecture
import PromisoShared

struct DescriptionSection: View {
  let store: StoreOf<CreateSchedule.Feature>
  @FocusState.Binding var isFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(LocalizedStrings.CreateSchedule.descriptionSection)
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.primary)

      DescriptionBlockEditor(
        blocks: Binding(
          get: { store.schedule.descriptionBlocks },
          set: { store.send(.view(.setDescriptionBlocks($0))) }
        )
      )
      .padding(16)
      .adaptiveGlassCard()
    }
  }
}
