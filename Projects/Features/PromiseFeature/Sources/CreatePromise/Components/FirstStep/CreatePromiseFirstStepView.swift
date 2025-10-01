import SwiftUI
import ComposableArchitecture

// MARK: - Step 1 Content View
struct CreatePromiseFirstStepView: View {
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

struct SectionPlaceHolder<Content: View>: View {
  private let placeHolderTitle: String
  private let isRequired: Bool
  private let content: () -> Content
  
  init(placeHolderTitle: String, isRequired: Bool, @ViewBuilder content: @escaping () -> Content) {
    self.placeHolderTitle = placeHolderTitle
    self.isRequired = isRequired
    self.content = content
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 3) {
        
        Text(placeHolderTitle)
          .font(.system(size: 14))
        
        if isRequired {
          Text("*")
            .font(.system(size: 14))
            .foregroundStyle(.red)
        }
      }
      
      content()
    }
  }
}

// MARK: - CreatePromiseStep Extension
extension CreatePromiseStep {
  @ViewBuilder
  func contentView(store: StoreOf<CreatePromise.Feature>) -> some View {
    switch self {
    case .first:
      CreatePromiseFirstStepView(store: store)
      
    case .second:
      VStack {
        Text("Step 2 - 날짜/시간/장소")
          .font(.title2)
      }
      
    case .third:
      VStack {
        Text("Step 3 - 추가 옵션")
          .font(.title2)
      }
    }
  }
}

