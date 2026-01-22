import Clients
import PromisoShared
import SwiftUI

// MARK: - Data Model

/// 그룹 가로 바 아이템 데이터
public struct GroupBarItem: Identifiable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let imageUrl: String?
  public let hasNewActivity: Bool
  public let isSelected: Bool

  public init(
    id: String,
    name: String,
    imageUrl: String? = nil,
    hasNewActivity: Bool = false,
    isSelected: Bool = false
  ) {
    self.id = id
    self.name = name
    self.imageUrl = imageUrl
    self.hasNewActivity = hasNewActivity
    self.isSelected = isSelected
  }
}

// MARK: - GroupHorizontalBar

/// 유튜브 구독 탭 스타일의 가로 스크롤 그룹 바
struct GroupHorizontalBar: View {
  let groups: [GroupBarItem]
  let onGroupTap: (String) -> Void
  let onCreateGroup: () -> Void
  let onJoinGroup: () -> Void

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(alignment: .top, spacing: 16) {
          ForEach(groups) { group in
            GroupBarItemView(
              group: group,
              onTap: { onGroupTap(group.id) }
            )
            .id(group.id)
          }

          // + 추가 버튼 메뉴
          AddGroupMenuButton(
            onCreateGroup: onCreateGroup,
            onJoinGroup: onJoinGroup
          )
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
      }
      .onChange(of: groups.first(where: { $0.isSelected })?.id) { _, selectedId in
        if let selectedId {
          withAnimation(.easeInOut(duration: 0.3)) {
            proxy.scrollTo(selectedId, anchor: .center)
          }
        }
      }
    }
  }
}

// MARK: - GroupBarItemView

private struct GroupBarItemView: View {
  let group: GroupBarItem
  let onTap: () -> Void

  var body: some View {
    Button {
      UIImpactFeedbackGenerator(style: .light).impactOccurred()
      onTap()
    } label: {
      VStack(alignment: .center, spacing: 6) {
        ZStack(alignment: .topTrailing) {
          // 그룹 아바타 (PromisoShared 컴포넌트 사용)
          GroupThumbnailView(imageUrl: group.imageUrl, name: group.name, size: 56)
            .overlay(
              Circle()
                .stroke(
                  group.isSelected ? Color.pmindigo.n500 : Color.clear,
                  lineWidth: 3
                )
            )
            .scaleEffect(group.isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: group.isSelected)

          // 새 활동 표시 (border와 같은 톤)
          if group.hasNewActivity {
            ActivityIndicatorDot()
              .offset(x: 1, y: -1)
          }
        }

        Text(group.name)
          .font(.system(size: 11, weight: group.isSelected ? .semibold : .regular))
          .foregroundStyle(group.isSelected ? .primary : .secondary)
          .lineLimit(2)
          .multilineTextAlignment(.center)
          .frame(width: 72)
      }
    }
    .buttonStyle(.scale)
  }
}

// MARK: - ActivityIndicatorDot

private struct ActivityIndicatorDot: View {
  var body: some View {
    Circle()
      .fill(Color.pmerror.n500)
      .frame(width: 12, height: 12)
      .overlay(
        Circle()
          .stroke(Color.white, lineWidth: 2)
      )
  }
}

// MARK: - AddGroupMenuButton

private struct AddGroupMenuButton: View {
  let onCreateGroup: () -> Void
  let onJoinGroup: () -> Void

  var body: some View {
    Menu {
      Button {
        onCreateGroup()
      } label: {
        Label("그룹 생성", systemImage: "person.3.fill")
      }

      Button {
        onJoinGroup()
      } label: {
        Label("초대 코드로 참여", systemImage: "link")
      }
    } label: {
      Circle()
        .strokeBorder(
          Color.pmgray.n300,
          style: StrokeStyle(lineWidth: 2, dash: [5, 3])
        )
        .frame(width: 56, height: 56)
        .overlay(
          Image(systemName: "plus")
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Color.pmgray.n400)
        )
    }
  }
}

// MARK: - Preview

#Preview("GroupHorizontalBar") {
  VStack {
    GroupHorizontalBar(
      groups: [
        GroupBarItem(id: "g1", name: "지민과 나", hasNewActivity: true, isSelected: true),
        GroupBarItem(id: "g2", name: "일이삼사오육칠팔구십일이삼사오육칠팔구십일", hasNewActivity: true, isSelected: false),
        GroupBarItem(id: "g3", name: "대학 친구들", hasNewActivity: false, isSelected: false),
        GroupBarItem(id: "g4", name: "우리 가족 단톡방", hasNewActivity: true, isSelected: false),
        GroupBarItem(id: "g5", name: "주말 등산 동호회 멤버들", hasNewActivity: false, isSelected: false)
      ],
      onGroupTap: { id in print("Group tapped: \(id)") },
      onCreateGroup: { print("Create group") },
      onJoinGroup: { print("Join group") }
    )
    .background(Color(.systemGroupedBackground))

    Spacer()
  }
}

#Preview("GroupHorizontalBar - Empty") {
  GroupHorizontalBar(
    groups: [],
    onGroupTap: { _ in },
    onCreateGroup: { },
    onJoinGroup: { }
  )
  .background(Color(.systemGroupedBackground))
}
