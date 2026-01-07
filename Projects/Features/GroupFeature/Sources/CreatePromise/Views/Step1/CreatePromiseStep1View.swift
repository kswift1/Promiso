import SwiftUI
import Clients
import ComposableArchitecture

// MARK: - Step 1 Content View
struct CreatePromiseStep1View: View {
  private let store: StoreOf<CreatePromise.Feature>
  @FocusState private var isTitleFocused: Bool
  
  init(store: StoreOf<CreatePromise.Feature>) {
    self.store = store
  }
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 32) {
        // 헤더
        HStack {
          CreatePromiseStep.first.headerView

          Spacer()

          if let emoji = store.promise.emoji {
            Text(emoji)
              .font(.system(size: 48))
          }
        }

        // 제목 입력
        SectionPlaceHolder(
          placeHolderTitle: "제목",
          isRequired: true) {
            TitleInputTextField(
              title: store.promise.title,
              emoji: store.promise.emoji,
              isFocused: $isTitleFocused,
              onTitleChange: { store.send(.view(.setTitle($0))) }
            )
          }

        SectionPlaceHolder(
          placeHolderTitle: "그룹 선택",
          isRequired: true) {
            GroupListView(
              groupListState: store.groupListState,
              selectedGroupId: store.promise.group?.id,
              onGroupSelected: { store.send(.view(.groupSelected($0))) },
              onRetry: { store.send(.view(.retryLoadGroups)) },
              onCreateGroup: { store.send(.view(.createGroupTapped)) },
              isFocused: $isTitleFocused
            )
          }
      }
      .padding(16)
    }
    .simultaneousGesture(
      DragGesture().onChanged { _ in
        // 스크롤 시 키보드 내리기
        isTitleFocused = false
      }
    )
    .onTapGesture {
      // 빈 공간 탭 시 키보드 내리기
      isTitleFocused = false
    }
  }
}
