// MARK: - CalendarFilterSheetView.swift
// 캘린더 필터 시트 View

import SwiftUI
import Clients
import PromisoShared
import ResourceKit

struct CalendarFilterSheetView: View {
  let groups: [UserGroupInfo]
  let groupColorMap: [String: Color]
  let selectedGroupIds: Set<String>
  let onGroupToggled: (String) -> Void
  let onReset: () -> Void

  @State private var contentHeight: CGFloat = 200

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      // 헤더: "필터" + 초기화 버튼
      headerSection

      // 그룹 필터 섹션
      groupFilterSection
    }
    .padding(.horizontal, 20)
    .padding(.top, 24)
    .padding(.bottom, 24)
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.height
    } action: { height in
      contentHeight = height
    }
    .presentationDetents([.height(contentHeight)])
  }

  // MARK: - Header Section

  private var headerSection: some View {
    HStack {
      Text("필터")
        .font(.system(size: 20, weight: .bold))
      Spacer()
      // 초기화 버튼 (전체 선택이 아닐 때만 표시)
      if selectedGroupIds.count < groups.count {
        Button(action: onReset) {
          Text("초기화")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color.pmindigo.n500)
        }
      }
    }
  }

  // MARK: - Group Filter Section

  private var groupFilterSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("그룹")
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.secondary)

      // Flow Layout (줄바꿈) 그룹 칩
      FlowLayout(spacing: 8) {
        ForEach(groups) { group in
          groupChip(group)
        }
      }
      .padding(2) // stroke clipping 방지
    }
  }

  // MARK: - Group Chip

  private func groupChip(_ group: UserGroupInfo) -> some View {
    let isSelected = selectedGroupIds.contains(group.id)
    let groupColor = groupColorMap[group.id] ?? Color.pmindigo.n500

    return Button { onGroupToggled(group.id) } label: {
      HStack(spacing: 6) {
        // 그룹 이미지 + groupColor 링
        GroupThumbnailView(imageUrl: group.imageUrl, name: group.name, size: 26)
          .overlay(
            Circle()
              .stroke(groupColor, lineWidth: 3.5)
              .frame(width: 29.5, height: 29.5)
          )
        Text(group.name)
          .font(.system(size: 14, weight: .medium))
          .lineLimit(1)
      }
      .padding(.leading, 6)
      .padding(.trailing, 12)
      .padding(.vertical, 6)
      .background(isSelected ? Color.pmindigo.n500.opacity(0.15) : Color(.systemGray6))
      .foregroundColor(isSelected ? Color.pmindigo.n500 : .primary)
      .cornerRadius(20)
      .overlay(
        RoundedRectangle(cornerRadius: 20)
          .stroke(isSelected ? Color.pmindigo.n500 : Color(.systemGray4), lineWidth: 1.5)
      )
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = computeRows(proposal: proposal, subviews: subviews)
    var height: CGFloat = 0
    for (index, row) in rows.enumerated() {
      let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
      height += rowHeight
      if index < rows.count - 1 { height += spacing }
    }
    return CGSize(width: proposal.width ?? 0, height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    let rows = computeRows(proposal: proposal, subviews: subviews)
    var y = bounds.minY
    for row in rows {
      let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
      var x = bounds.minX
      for subview in row {
        let size = subview.sizeThatFits(.unspecified)
        subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
        x += size.width + spacing
      }
      y += rowHeight + spacing
    }
  }

  private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubviews.Element]] {
    let maxWidth = proposal.width ?? .infinity
    var rows: [[LayoutSubviews.Element]] = [[]]
    var currentWidth: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
        rows.append([])
        currentWidth = 0
      }
      rows[rows.count - 1].append(subview)
      currentWidth += size.width + spacing
    }
    return rows
  }
}
