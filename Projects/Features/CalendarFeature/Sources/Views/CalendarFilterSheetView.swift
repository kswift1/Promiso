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
  let selectedStatus: CalendarFeature.StatusFilter
  let onGroupToggled: (String) -> Void
  let onStatusChanged: (CalendarFeature.StatusFilter) -> Void
  let onReset: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      // 헤더: "필터" + 초기화 버튼
      headerSection

      // 그룹 필터 섹션
      groupFilterSection

      // 상태 필터 섹션
      statusFilterSection

      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.top, 24)
  }

  // MARK: - Header Section

  private var headerSection: some View {
    HStack {
      Text("필터")
        .font(.system(size: 20, weight: .bold))
      Spacer()
      // 초기화 버튼 (필터가 활성화되어 있을 때만 표시)
      if !selectedGroupIds.isEmpty || selectedStatus != .all {
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

      // 가로 스크롤 그룹 칩
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(groups) { group in
            groupChip(group)
          }
        }
        .padding(.horizontal, 1) // shadow clipping 방지
      }
    }
  }

  // MARK: - Group Chip

  private func groupChip(_ group: UserGroupInfo) -> some View {
    let isSelected = selectedGroupIds.contains(group.id)
    let color = groupColorMap[group.id] ?? Color.pmindigo.n500

    return Button { onGroupToggled(group.id) } label: {
      HStack(spacing: 6) {
        Circle()
          .fill(color)
          .frame(width: 10, height: 10)
        Text(group.name)
          .font(.system(size: 14, weight: .medium))
          .lineLimit(1)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(isSelected ? color.opacity(0.15) : Color(.systemGray6))
      .foregroundColor(isSelected ? color : .primary)
      .cornerRadius(20)
      .overlay(
        RoundedRectangle(cornerRadius: 20)
          .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Status Filter Section

  private var statusFilterSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("상태")
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.secondary)

      CategoryFilterBar(
        selection: Binding(
          get: { selectedStatus },
          set: { onStatusChanged($0) }
        )
      )
    }
  }
}
