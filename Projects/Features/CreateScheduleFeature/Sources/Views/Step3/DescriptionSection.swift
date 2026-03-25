import SwiftUI
import Clients
import ComposableArchitecture
import PromisoShared

struct DescriptionSection: View {
  let store: StoreOf<CreateSchedule.Feature>
  @FocusState.Binding var isFocused: Bool

  var body: some View {
    SectionPlaceHolder(
      placeHolderTitle: LocalizedStrings.CreateSchedule.descriptionSection,
    ) {
      DescriptionBlockEditor(
        blocks: Binding(
          get: { store.schedule.descriptionBlocks },
          set: { store.send(.view(.setDescriptionBlocks($0))) }
        )
      )
    }
  }
}
