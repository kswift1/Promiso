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

      public init(selectedOption: GroupSortOption = .joinedRecent) {
        self.selectedOption = selectedOption
      }
    }

    public enum Action: ViewAction {
      case view(ViewAction)
      case delegate(DelegateAction)

      @CasePathable
      public enum ViewAction {
        /// 정렬 옵션 선택
        case optionTapped(GroupSortOption)
        /// 닫기 버튼
        case closeTapped
      }

      public enum DelegateAction {
        /// 정렬 옵션 변경됨
        case sortOptionChanged(GroupSortOption)
      }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.optionTapped(let option)):
          state.selectedOption = option
          return .send(.delegate(.sortOptionChanged(option)))

        case .view(.closeTapped):
          // 부모에서 dismiss 처리
          return .none

        case .delegate:
          return .none
        }
      }
    }
  }
}
