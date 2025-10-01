import SwiftUI
import ComposableArchitecture

struct TitleInputTextField: View {
  private let store: StoreOf<CreatePromise.Feature>
  private let titlePrefix: Int
  
  init(store: StoreOf<CreatePromise.Feature>, titlePrefix: Int = 30) {
    self.store = store
    self.titlePrefix = titlePrefix
  }
  
  var body: some View {
    VStack(alignment: .trailing, spacing: 2) {
      TextField("예: 영화 관람, 카페 미팅", text: Binding(
        get: { store.promiseProposal.title },
        set: { store.send(.setTitle($0)) }
      ))
      .onChange(of: store.promiseProposal.title, { _, newValue in
        if newValue.count > 30 {
          let trimmed = String(newValue.prefix(30))
          store.send(.setTitle(trimmed))
        }
      })
      .font(.system(size: 17))
      .padding(18)
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .frame(maxWidth: .infinity, minHeight: 80)
      
      Text("\(store.promiseProposal.title.count)/\(titlePrefix)")
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }
  }
}
