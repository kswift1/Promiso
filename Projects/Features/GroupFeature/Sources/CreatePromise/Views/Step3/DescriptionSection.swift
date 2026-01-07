import SwiftUI
import Clients
import ComposableArchitecture

struct DescriptionSection: View {
  let store: StoreOf<CreatePromise.Feature>
  @FocusState.Binding var isFocused: Bool

  var body: some View {
    SectionPlaceHolder(
      placeHolderTitle: "상세 설명",
      isRequired: false
    ) {
      VStack(alignment: .trailing, spacing: 8) {
        ZStack(alignment: .topLeading) {
          if store.promise.description?.isEmpty ?? true {
            Text("약속에 대한 추가 정보를 입력하세요\n예: 주차 정보, 복장, 준비물 등")
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
