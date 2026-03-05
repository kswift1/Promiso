import SwiftUI
import Clients
import ComposableArchitecture
import PromisoShared

struct DescriptionSection: View {
  let store: StoreOf<CreatePromise.Feature>
  @FocusState.Binding var isFocused: Bool

  var body: some View {
    SectionPlaceHolder(
      placeHolderTitle: LocalizedStrings.CreatePromise.descriptionSection,
    ) {
      VStack(alignment: .trailing, spacing: 8) {
        ZStack(alignment: .topLeading) {
          if store.promise.description?.isEmpty ?? true {
            Text(LocalizedStrings.CreatePromise.descriptionPlaceholder)
              .font(.system(size: 15))
              .foregroundColor(.secondary)
              .padding(.horizontal, 16)
              .padding(.vertical, 14)
          }

          TextEditor(text: Binding(
            get: { store.promise.description ?? "" },
            set: { store.send(.view(.setDescription($0))) }
          ))
          .font(.system(size: 15))
          .frame(height: 120)
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .scrollContentBackground(.hidden)
          .background(Color(.systemGray6))
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .focused($isFocused)
        }

        Text("\(store.promise.description?.count ?? 0)/500")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }
    }
  }
}
