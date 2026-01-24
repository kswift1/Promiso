import SwiftUI
import ComposableArchitecture
import PromisoShared
import UIKit

extension GroupSortSettings {
  public struct RootView: View {
    @Bindable var store: StoreOf<Feature>

    // 드래그 상태
    @State private var draggingItem: GroupBarItem?
    @State private var dragOffsetX: CGFloat = 0
    @State private var sourceIndex: Int = 0
    @State private var proposedIndex: Int = 0  // 현재 드롭 예정 위치

    // 햅틱
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStack {
        VStack(spacing: 0) {
          previewSection

          Divider()

          sortOptionsSection
        }
        .navigationTitle("그룹 정렬")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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

    private let itemSize: CGFloat = 60
    private let itemSpacing: CGFloat = 12
    private var itemTotalWidth: CGFloat { itemSize + itemSpacing }

    /// 다른 아이템들의 밀림 오프셋 계산
    private func shiftOffset(for index: Int) -> CGFloat {
      guard draggingItem != nil else { return 0 }
      if index == sourceIndex { return 0 }

      // 오른쪽으로 드래그: 사이 아이템들 왼쪽으로 밀림
      if proposedIndex > sourceIndex {
        if index > sourceIndex && index <= proposedIndex {
          return -itemTotalWidth
        }
      }
      // 왼쪽으로 드래그: 사이 아이템들 오른쪽으로 밀림
      else if proposedIndex < sourceIndex {
        if index >= proposedIndex && index < sourceIndex {
          return itemTotalWidth
        }
      }
      return 0
    }

    @ViewBuilder
    private var previewSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text(store.selectedOption == .custom ? "길게 눌러서 순서를 변경하세요" : "미리보기")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)

          Spacer()
        }
        .padding(.horizontal, 16)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: itemSpacing) {
            ForEach(Array(store.sortedPreviewGroups.enumerated()), id: \.element.id) { index, group in
              groupPreviewItem(group, at: index)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
          .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.sortedPreviewGroups.map(\.id))
        }
        .frame(height: 90)
      }
      .padding(.vertical, 16)
      .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private func groupPreviewItem(_ group: GroupBarItem, at index: Int) -> some View {
      let isDragging = draggingItem?.id == group.id

      VStack(spacing: 6) {
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
          .frame(width: itemSize)
      }
      .opacity(isDragging ? 0.6 : 1.0)
      .scaleEffect(isDragging ? 1.05 : 1.0)
      .offset(x: isDragging ? dragOffsetX : shiftOffset(for: index))
      .zIndex(isDragging ? 1 : 0)
      .animation(.spring(response: 0.3, dampingFraction: 0.7), value: proposedIndex)
      .gesture(
        store.selectedOption == .custom
          ? LongPressGesture(minimumDuration: 0.2)
              .onEnded { _ in
                impactMedium.impactOccurred()
                draggingItem = group
                sourceIndex = index
                proposedIndex = index
              }
              .sequenced(before: DragGesture()
                .onChanged { value in
                  dragOffsetX = value.translation.width

                  // 드롭 위치 계산
                  let offset = Int(round(dragOffsetX / itemTotalWidth))
                  let newProposed = max(0, min(store.customOrderedGroups.count - 1, sourceIndex + offset))

                  // 위치 변경 시 햅틱
                  if newProposed != proposedIndex {
                    impactLight.impactOccurred()
                    proposedIndex = newProposed
                  }
                }
                .onEnded { _ in
                  // 실제 이동
                  if proposedIndex != sourceIndex {
                    store.send(.view(.moveGroup(
                      from: IndexSet(integer: sourceIndex),
                      to: proposedIndex > sourceIndex ? proposedIndex + 1 : proposedIndex
                    )))
                  }

                  withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                    dragOffsetX = 0
                    draggingItem = nil
                  }
                }
              )
          : nil
      )
    }

    // MARK: - Sort Options Section

    @ViewBuilder
    private var sortOptionsSection: some View {
      List {
        ForEach([GroupSortOption.SortType.joined, .name, .custom], id: \.self) { sortType in
          sortTypeRow(sortType)
        }
      }
      .listStyle(.insetGrouped)
      .safeAreaInset(edge: .bottom) {
        Color.clear.frame(height: 40)
      }
    }

    @ViewBuilder
    private func sortTypeRow(_ sortType: GroupSortOption.SortType) -> some View {
      Button {
        store.send(.view(.sortTypeTapped(sortType)))
      } label: {
        HStack(spacing: 12) {
          Image(systemName: sortType.icon)
            .font(.system(size: 18))
            .foregroundStyle(isSelected(sortType) ? Color.pmindigo.n500 : .secondary)
            .frame(width: 24)

          Text(sortType.rawValue)
            .font(.system(size: 16))
            .foregroundStyle(.primary)

          if isSelected(sortType) {
            Image(systemName: "checkmark")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(Color.pmindigo.n500)
          }

          Spacer()

          if isSelected(sortType) && sortType != .custom {
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
      switch store.selectedOption {
      case .joinedRecent:
        return "arrow.down"
      case .joinedOldest:
        return "arrow.up"
      case .nameAscending:
        return "arrow.down"
      case .nameDescending:
        return "arrow.up"
      case .custom:
        return ""
      }
    }
  }
}

// MARK: - Preview

#Preview {
  let groups = [
    "지민과 나", "대학 친구들", "회사 동료", "가족", "고등학교",
    "동네 친구", "헬스장", "독서 모임"
  ].enumerated().map { index, name in
    GroupBarItem(id: "g\(index)", name: name, hasNewActivity: index % 3 == 0, isSelected: false)
  }

  return GroupSortSettings.RootView(
    store: Store(
      initialState: GroupSortSettings.Feature.State(
        selectedOption: .custom,
        previewGroups: groups
      )
    ) {
      GroupSortSettings.Feature()
    }
  )
}
