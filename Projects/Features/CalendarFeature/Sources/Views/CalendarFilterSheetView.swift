// MARK: - CalendarFilterSheetView.swift
// 캘린더 필터 시트 View

import SwiftUI
import UIKit
import Clients
import PromisoShared
import ResourceKit

struct CalendarFilterSheetView: View {
  let groups: [UserGroupInfo]
  let groupColorMap: [String: Color]
  let selectedGroupIds: Set<String>
  let showPersonalEvents: Bool
  let selectedStatusFilters: Set<CalendarFeature.StatusFilter>
  let showCalendarEvents: Bool
  let canReadCalendarEvents: Bool
  let isFilterActive: Bool
  let onGroupToggled: (String) -> Void
  let onPersonalEventsToggled: () -> Void
  let onStatusFilterChanged: (CalendarFeature.StatusFilter) -> Void
  let onCalendarEventsToggled: () -> Void
  let onReset: () -> Void

  @State private var contentHeight: CGFloat = 200
  @State private var showStatusLegend: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      // 헤더: "필터" + 초기화 버튼
      headerSection

      // 그룹 섹션 (그룹 필터 + 약속 상태)
      groupFilterSection
      statusFilterSection

      Divider()

      // 개인 일정
      personalEventToggle

      Divider()

      // 시스템 캘린더
      calendarEventToggle
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
    Text(LocalizedStrings.Calendar.filterTitle)
      .font(.system(size: 20, weight: .bold))
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Group Filter Section

  private var groupFilterSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(LocalizedStrings.Calendar.filterGroup)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.secondary)
        Spacer()
        if selectedGroupIds.count < groups.count {
          Button(action: onReset) {
            Text(LocalizedStrings.Calendar.filterSelectAll)
              .font(.system(size: 13, weight: .medium))
              .foregroundColor(Color.pmbrand.primary)
          }
        }
      }

      FlowLayout(spacing: 8) {
        ForEach(groups) { group in
          groupChip(group)
        }
      }
      .padding(2)
    }
  }

  // MARK: - Group Chip

  private func groupChip(_ group: UserGroupInfo) -> some View {
    let isSelected = selectedGroupIds.contains(group.id)
    let groupColor = groupColorMap[group.id] ?? Color.pmindigo.n500

    return Button { onGroupToggled(group.id) } label: {
      HStack(spacing: 6) {
        Circle()
          .fill(isSelected ? groupColor : Color(.systemGray3))
          .frame(width: 8, height: 8)
        Text(group.name)
          .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
          .lineLimit(1)
      }
      .padding(.leading, 10)
      .padding(.trailing, 12)
      .padding(.vertical, 8)
      .background(Color(.systemGray6))
      .foregroundColor(isSelected ? .primary : .secondary)
      .cornerRadius(20)
      .overlay(
        RoundedRectangle(cornerRadius: 20)
          .stroke(isSelected ? groupColor : Color(.systemGray4), lineWidth: 1.5)
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Status Filter Section

  private var statusFilterSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(LocalizedStrings.Calendar.filterStatus)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.secondary)
        Spacer()
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            showStatusLegend.toggle()
          }
        } label: {
          HStack(spacing: 4) {
            Text("상태 설명")
              .font(.system(size: 13))
            Image(systemName: showStatusLegend ? "chevron.up" : "chevron.down")
              .font(.system(size: 11))
          }
          .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
      }

      FlowLayout(spacing: 8) {
        ForEach(CalendarFeature.StatusFilter.allCases, id: \.self) { filter in
          statusChip(filter)
        }
      }
      .padding(2)

      if showStatusLegend {
        statusLegendView
          .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
  }

  private func statusChip(_ filter: CalendarFeature.StatusFilter) -> some View {
    let isSelected = filter == .all
      ? selectedStatusFilters == CalendarFeature.StatusFilter.allIndividualFilters
      : selectedStatusFilters.contains(filter)

    return Button {
      onStatusFilterChanged(filter)
    } label: {
      HStack(spacing: 6) {
        Image(systemName: filter.icon)
          .font(.system(size: 12))
          .foregroundColor(isSelected ? filter.selectedColor : Color(.systemGray3))
        Text(filter.title)
          .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
          .foregroundColor(isSelected ? .primary : .secondary)
          .lineLimit(1)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color(.systemGray6))
      .cornerRadius(20)
      .overlay(
        RoundedRectangle(cornerRadius: 20)
          .stroke(isSelected ? filter.selectedColor : Color(.systemGray4), lineWidth: 1.5)
      )
    }
    .buttonStyle(.plain)
  }

  private var statusLegendView: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(CalendarFeature.StatusFilter.allCases.filter { $0 != .all }, id: \.self) { filter in
        HStack(spacing: 8) {
          Image(systemName: filter.icon)
            .font(.system(size: 12))
            .foregroundColor(filter.selectedColor)
            .frame(width: 16)
          Text(filter.title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
          Text(statusDescription(for: filter))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
      }
    }
  }

  private func statusDescription(for filter: CalendarFeature.StatusFilter) -> String {
    switch filter {
    case .all: return ""
    case .needResponse: return LocalizedStrings.Calendar.filterStatusNeedResponse
    case .waitingConfirmation: return LocalizedStrings.Calendar.filterStatusWaiting
    case .confirmed: return LocalizedStrings.Calendar.filterStatusConfirmed
    case .completed: return LocalizedStrings.Calendar.filterStatusCompleted
    case .failed: return LocalizedStrings.Calendar.filterStatusFailed
    }
  }

  // MARK: - Personal Event Toggle

  private var personalEventToggle: some View {
    HStack {
      Text(LocalizedStrings.Calendar.filterPersonal)
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.secondary)
      Spacer()
      Toggle("", isOn: Binding(
        get: { showPersonalEvents },
        set: { _ in onPersonalEventsToggled() }
      ))
      .labelsHidden()
      .tint(Color.pmbrand.primary)
    }
  }

  // MARK: - Calendar Event Toggle

  private var calendarEventToggle: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(LocalizedStrings.Calendar.filterCalendarEvents)
          .font(.system(size: 15, weight: .semibold))
          .foregroundColor(.secondary)
        Spacer()
        if canReadCalendarEvents {
          Toggle("", isOn: Binding(
            get: { showCalendarEvents },
            set: { _ in onCalendarEventsToggled() }
          ))
          .labelsHidden()
          .tint(Color.pmbrand.primary)
        }
      }

      if !canReadCalendarEvents {
        HStack(spacing: 4) {
          Text(LocalizedStrings.Calendar.calendarPermissionSubtitle)
            .font(.system(size: 13))
            .foregroundStyle(.tertiary)
          Button {
            if let url = URL(string: UIApplication.openSettingsURLString) {
              UIApplication.shared.open(url)
            }
          } label: {
            Text("설정으로 이동")
              .font(.system(size: 13, weight: .medium))
              .foregroundColor(Color.pmbrand.primary)
          }
          .buttonStyle(.plain)
        }
      }
    }
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
