import SwiftUI
import ComposableArchitecture

// MARK: - Step 1 Content View
struct CreatePromiseStep1View: View {
  private let store: StoreOf<CreatePromise.Feature>
  
  init(store: StoreOf<CreatePromise.Feature>) {
    self.store = store
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 32) {
      // 헤더
      HStack {
        CreatePromiseStep.first.headerView
        
        Spacer()
        
        if let emoji = store.promiseProposal.emoji {
          Text(emoji)
            .font(.system(size: 48))
        }
      }
      
      // 제목 입력
      SectionPlaceHolder(
        placeHolderTitle: "제목",
        isRequired: true) {
          TitleInputTextField(store: store)
        }
      
      SectionPlaceHolder(
        placeHolderTitle: "그룹 선택",
        isRequired: true) {
          GroupListView(store: store)
        }
    }
  }
}
