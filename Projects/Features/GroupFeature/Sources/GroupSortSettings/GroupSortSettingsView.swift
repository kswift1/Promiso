import SwiftUI
import ComposableArchitecture
import PromisoShared

extension GroupSortSettings {
  public struct RootView: View {
    @Bindable var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStack {
        VStack(spacing: 0) {
          // 프리뷰 리스트
          previewSection

          Divider()

          // 정렬 옵션
          sortOptionsSection
        }
        .navigationTitle("그룹 정렬")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("취소") {
              store.send(.view(.cancelTapped))
            }
          }

          ToolbarItem(placement: .confirmationAction) {
            Button("완료") {
              store.send(.view(.confirmTapped))
            }
            .fontWeight(.semibold)
          }
        }
      }
    }

    // MARK: - Preview Section

    @ViewBuilder
    private var previewSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("미리보기")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 16)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 12) {
            ForEach(store.sortedPreviewGroups.prefix(5)) { group in
              VStack(spacing: 6) {
                // 그룹 썸네일
                if let localImageName = group.localImageName {
                  Image(localImageName, bundle: .main)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
                } else {
                  GroupThumbnailView(
                    imageUrl: group.imageUrl,
                    name: group.name,
                    size: 48
                  )
                }

                Text(group.name)
                  .font(.system(size: 11))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .frame(width: 60)
              }
            }
          }
          .padding(.horizontal, 16)
        }
        .frame(height: 90)
      }
      .padding(.vertical, 16)
      .background(Color(.systemGroupedBackground))
    }

    // MARK: - Sort Options Section

    @ViewBuilder
    private var sortOptionsSection: some View {
      List {
        ForEach([GroupSortOption.SortType.joined, .name], id: \.self) { sortType in
          sortTypeRow(sortType)
        }
      }
      .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func sortTypeRow(_ sortType: GroupSortOption.SortType) -> some View {
      Button {
        store.send(.view(.sortTypeTapped(sortType)))
      } label: {
        HStack(spacing: 12) {
          // 아이콘
          Image(systemName: sortType.icon)
            .font(.system(size: 18))
            .foregroundStyle(isSelected(sortType) ? Color.pmindigo.n500 : .secondary)
            .frame(width: 24)

          // 타이틀
          Text(sortType.rawValue)
            .font(.system(size: 16))
            .foregroundStyle(.primary)

          Spacer()

          // 방향 화살표
          if isSelected(sortType) {
            Image(systemName: directionIcon(for: sortType))
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Color.pmindigo.n500)
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func isSelected(_ sortType: GroupSortOption.SortType) -> Bool {
      store.selectedOption.sortType == sortType
    }

    private func directionIcon(for sortType: GroupSortOption.SortType) -> String {
      guard store.selectedOption.sortType == sortType else {
        return ""
      }

      switch store.selectedOption {
      case .joinedRecent:
        return "arrow.down"  // 최신부터 (아래로)
      case .joinedOldest:
        return "arrow.up"    // 오래된부터 (위로)
      case .nameAscending:
        return "arrow.down"  // ㄱ→ㅎ (아래로)
      case .nameDescending:
        return "arrow.up"    // ㅎ→ㄱ (위로)
      }
    }
  }
}

// MARK: - Preview

#Preview {
  GroupSortSettings.RootView(
    store: Store(
      initialState: GroupSortSettings.Feature.State(
        selectedOption: .joinedRecent,
        previewGroups: [
          GroupBarItem(id: "g1", name: "지민과 나", hasNewActivity: true, isSelected: false),
          GroupBarItem(id: "g2", name: "대학 친구들", hasNewActivity: false, isSelected: false),
          GroupBarItem(id: "g3", name: "회사 동료", hasNewActivity: true, isSelected: false),
          GroupBarItem(id: "g4", name: "가족", hasNewActivity: false, isSelected: false)
        ]
      )
    ) {
      GroupSortSettings.Feature()
    }
  )
}
