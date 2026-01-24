import ComposableArchitecture
import PromisoShared

// MARK: - GroupSortSettings

public enum GroupSortSettings {}

extension GroupSortSettings {
  @Reducer
  public struct Feature {
    @ObservableState
    public struct State: Equatable {
      /// 현재 선택된 정렬 옵션
      var selectedOption: GroupSortOption
      /// 미리보기용 그룹 목록
      var previewGroups: [GroupBarItem]
      /// 초기 옵션 (취소 시 복원용)
      let initialOption: GroupSortOption

      public init(
        selectedOption: GroupSortOption,
        previewGroups: [GroupBarItem]
      ) {
        self.selectedOption = selectedOption
        self.previewGroups = previewGroups
        self.initialOption = selectedOption
      }

      /// 현재 옵션에 따라 정렬된 프리뷰 그룹
      var sortedPreviewGroups: [GroupBarItem] {
        switch selectedOption {
        case .joinedRecent, .joinedOldest:
          // 가입순: 초기 옵션과 다르면 역순으로
          if initialOption.sortType == .joined && selectedOption != initialOption {
            return Array(previewGroups.reversed())
          } else {
            return previewGroups
          }
        case .nameAscending:
          return previewGroups.sorted { $0.name < $1.name }
        case .nameDescending:
          return previewGroups.sorted { $0.name > $1.name }
        }
      }
    }

    public enum Action: ViewAction {
      case view(ViewAction)
      case delegate(DelegateAction)

      @CasePathable
      public enum ViewAction {
        /// 정렬 타입 탭 (토글)
        case sortTypeTapped(GroupSortOption.SortType)
        /// 완료 버튼
        case confirmTapped
        /// 취소 버튼
        case cancelTapped
      }

      public enum DelegateAction {
        /// 정렬 옵션 변경 확정
        case sortOptionChanged(GroupSortOption)
      }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.sortTypeTapped(let sortType)):
          // 같은 타입이면 토글, 다른 타입이면 해당 타입의 기본값
          if state.selectedOption.sortType == sortType {
            state.selectedOption = state.selectedOption.toggled
          } else {
            // 다른 타입으로 전환
            switch sortType {
            case .joined:
              state.selectedOption = .joinedRecent
            case .name:
              state.selectedOption = .nameAscending
            }
          }
          return .none

        case .view(.confirmTapped):
          return .send(.delegate(.sortOptionChanged(state.selectedOption)))

        case .view(.cancelTapped):
          state.selectedOption = state.initialOption
          return .none

        case .delegate:
          return .none
        }
      }
    }
  }
}
