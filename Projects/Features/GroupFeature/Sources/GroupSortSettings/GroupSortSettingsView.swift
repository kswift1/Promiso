import SwiftUI
import ComposableArchitecture
import PromisoShared

extension GroupSortSettings {
  public struct RootView: View {
    @Perception.Bindable public var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      WithPerceptionTracking {
        NavigationStack {
          contentView
            .navigationTitle("그룹 정렬")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .confirmationAction) {
                Button("완료") {
                  store.send(.view(.closeTapped))
                }
              }
            }
        }
      }
    }

    @ViewBuilder
    private var contentView: some View {
      List {
        Section {
          ForEach(GroupSortOption.allCases, id: \.self) { option in
            sortOptionRow(option)
          }
        } header: {
          Text("정렬 방식을 선택해주세요")
        }
      }
    }

    @ViewBuilder
    private func sortOptionRow(_ option: GroupSortOption) -> some View {
      Button {
        store.send(.view(.optionTapped(option)))
      } label: {
        HStack(spacing: 12) {
          // 아이콘
          Image(systemName: option.icon)
            .font(.system(size: 18))
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24)

          // 타이틀
          Text(option.title)
            .font(.system(size: 16))
            .foregroundStyle(.primary)

          Spacer()

          // 선택 표시
          if store.selectedOption == option {
            Image(systemName: "checkmark")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(Color.pmindigo.n500)
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }
}

// MARK: - Preview

#Preview {
  GroupSortSettings.RootView(
    store: Store(
      initialState: GroupSortSettings.Feature.State(
        selectedOption: .joinedRecent
      )
    ) {
      GroupSortSettings.Feature()
    }
  )
}
