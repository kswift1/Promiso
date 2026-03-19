import SwiftUI
import Clients
import ComposableArchitecture
import PromisoShared
import CreateGroupFeature

// MARK: - Step 1 Content View
struct CreateScheduleStep1View: View {
  private let store: StoreOf<CreateSchedule.Feature>
  @FocusState private var isTitleFocused: Bool
  @State private var isHourglassFlipped = false
  
  init(store: StoreOf<CreateSchedule.Feature>) {
    self.store = store
  }
  
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 32) {
        // 헤더
        HStack {
          CreateScheduleStep.first.headerView

          Spacer()

          if let emoji = store.schedule.emoji {
            Text(emoji)
              .font(.system(size: 48))
          } else if store.isEmojiLoading {
            Text(isHourglassFlipped ? "⌛️" : "⏳")
              .font(.system(size: 40))
          }
        }

        // 제목 입력
        SectionPlaceHolder(placeHolderTitle: LocalizedStrings.CreateSchedule.titleSection) {
            TitleInputTextField(
              title: store.schedule.title,
              emoji: store.schedule.emoji,
              isEmojiLoading: store.isEmojiLoading,
              isFocused: $isTitleFocused,
              onTitleChange: { store.send(.view(.setTitle($0))) }
            )
          }

        SectionPlaceHolder(placeHolderTitle: LocalizedStrings.CreateSchedule.groupSelection) {
            GroupListView(
              groupListState: store.groupListState,
              selectedGroupId: store.schedule.group?.id,
              groupScheduleCounts: store.groupScheduleCounts,
              maxActiveSchedules: CreateSchedule.Feature.State.maxActiveSchedulesPerGroup,
              onGroupSelected: { store.send(.view(.groupSelected($0))) },
              onRetry: { store.send(.view(.retryLoadGroups)) },
              onCreateGroup: { store.send(.view(.createGroupTapped)) },
              isFocused: $isTitleFocused
            )
          }
      }
      .padding(16)
    }
    .scrollDismissesKeyboard(.interactively)
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
    .onReceive(
      Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    ) { _ in
      if store.isEmojiLoading {
        isHourglassFlipped.toggle()
      }
    }
    .sheet(
      store: store.scope(state: \.$createGroup, action: \.createGroup)
    ) { childStore in
      NavigationStack {
        CreateGroup.RootView(store: childStore)
      }
    }
  }
}
