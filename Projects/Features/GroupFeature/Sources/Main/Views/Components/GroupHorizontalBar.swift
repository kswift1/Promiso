import Clients
import PromisoShared
import SwiftUI

// MARK: - Data Model

/// 그룹 가로 바 아이템 데이터
public struct GroupBarItem: Identifiable, Equatable, Sendable {
  public let id: String
  public let name: String
  public let imageUrl: String?
  public let needResponseCount: Int
  public let isSelected: Bool

  public init(
    id: String,
    name: String,
    imageUrl: String? = nil,
    needResponseCount: Int = 0,
    isSelected: Bool = false
  ) {
    self.id = id
    self.name = name
    self.imageUrl = imageUrl
    self.needResponseCount = needResponseCount
    self.isSelected = isSelected
  }
}

// MARK: - GroupHorizontalBar

/// 유튜브 구독 탭 스타일의 가로 스크롤 그룹 바
struct GroupHorizontalBar: View {
  let groups: [GroupBarItem]
  let onGroupTap: (String) -> Void
  let onAddTap: () -> Void

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 16) {
          ForEach(groups) { group in
            GroupBarItemView(
              group: group,
              onTap: { onGroupTap(group.id) }
            )
            .id(group.id)
          }

          // + 추가 버튼
          AddGroupButton(onTap: onAddTap)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
    Button(action: onTap) {
      VStack(spacing: 6) {
        ZStack(alignment: .topTrailing) {
          // 그룹 아바타
          GroupAvatarView(imageUrl: group.imageUrl, name: group.name)
            .frame(width: 56, height: 56)
            .overlay(
              Circle()
                .stroke(
                  group.isSelected ? Color.pmindigo.n500 : Color.clear,
                  lineWidth: 3
                )
            )
            .scaleEffect(group.isSelected ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: group.isSelected)

          // 미응답 배지
          if group.needResponseCount > 0 {
            BadgeView(count: group.needResponseCount)
              .offset(x: 6, y: -6)
          }
        }

        Text(group.name)
          .font(.system(size: 11, weight: group.isSelected ? .semibold : .regular))
          .foregroundStyle(group.isSelected ? .primary : .secondary)
          .lineLimit(1)
          .frame(width: 60)
      }
    }
    .buttonStyle(.plain)
  }
}

// MARK: - BadgeView

private struct BadgeView: View {
  let count: Int

  var body: some View {
    Text("\(min(count, 99))\(count > 99 ? "+" : "")")
      .font(.system(size: 11, weight: .bold))
      .foregroundStyle(.white)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Color.red)
      .clipShape(Capsule())
  }
}

// MARK: - AddGroupButton

private struct AddGroupButton: View {
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(spacing: 6) {
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

        Text("추가")
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .frame(width: 60)
      }
    }
    .buttonStyle(.plain)
  }
}

// MARK: - GroupAvatarView

private struct GroupAvatarView: View {
  let imageUrl: String?
  let name: String

  var body: some View {
    if let url = imageUrl, let imageURL = URL(string: url) {
      AsyncImage(url: imageURL) { phase in
        switch phase {
        case .success(let image):
          image
            .resizable()
            .aspectRatio(contentMode: .fill)
        case .failure:
          defaultAvatar
        case .empty:
          ProgressView()
            .frame(width: 56, height: 56)
        @unknown default:
          defaultAvatar
        }
      }
      .clipShape(Circle())
    } else {
      defaultAvatar
    }
  }

  private var defaultAvatar: some View {
    Circle()
      .fill(
        LinearGradient(
          colors: [Color.pmindigo.n100, Color.pmindigo.n200],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        Text(String(name.prefix(1)))
          .font(.system(size: 22, weight: .bold))
          .foregroundStyle(Color.pmindigo.n500)
      )
  }
}

// MARK: - Preview

#Preview("GroupHorizontalBar") {
  VStack {
    GroupHorizontalBar(
      groups: [
        GroupBarItem(id: "g1", name: "지민과 나", needResponseCount: 2, isSelected: true),
        GroupBarItem(id: "g2", name: "회사 동료들", needResponseCount: 1, isSelected: false),
        GroupBarItem(id: "g3", name: "대학 친구들", needResponseCount: 0, isSelected: false),
        GroupBarItem(id: "g4", name: "가족", needResponseCount: 3, isSelected: false),
        GroupBarItem(id: "g5", name: "동호회", needResponseCount: 0, isSelected: false)
      ],
      onGroupTap: { id in print("Group tapped: \(id)") },
      onAddTap: { print("Add tapped") }
    )
    .background(Color(.systemGroupedBackground))

    Spacer()
  }
}

#Preview("GroupHorizontalBar - Empty") {
  GroupHorizontalBar(
    groups: [],
    onGroupTap: { _ in },
    onAddTap: { }
  )
  .background(Color(.systemGroupedBackground))
}
