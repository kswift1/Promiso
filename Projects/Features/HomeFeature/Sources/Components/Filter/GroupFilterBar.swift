import SwiftUI

struct GroupFilterBar: View {
  let groups: [GroupInfo]
  @Binding var selectedGroupId: String?  // nil = 전체

  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        // 전체 칩
        FilterChip(
          title: "전체",
          isSelected: selectedGroupId == nil,
          onTap: { selectedGroupId = nil }
        )

        // 그룹별 칩
        ForEach(groups) { group in
          FilterChip(
            title: group.name,
            isSelected: selectedGroupId == group.id,
            onTap: { selectedGroupId = group.id }
          )
        }
      }
      .padding(.horizontal, 16)
    }
  }
}

// MARK: - Filter Chip

struct FilterChip: View {
  let title: String
  let isSelected: Bool
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      Text(title)
        .font(.system(size: 14, weight: .medium))
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
          Capsule()
            .fill(isSelected ? Color.blue : Color(UIColor.systemGray6))
        )
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 16) {
    GroupFilterBar(
      groups: [
        GroupInfo(id: "1", name: "친구들"),
        GroupInfo(id: "2", name: "회사"),
        GroupInfo(id: "3", name: "가족"),
        GroupInfo(id: "4", name: "동아리")
      ],
      selectedGroupId: .constant(nil)
    )

    GroupFilterBar(
      groups: [
        GroupInfo(id: "1", name: "친구들"),
        GroupInfo(id: "2", name: "회사"),
        GroupInfo(id: "3", name: "가족")
      ],
      selectedGroupId: .constant("2")
    )
  }
  .padding(.vertical)
  .auroraBackground()
}
