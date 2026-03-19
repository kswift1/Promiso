import SwiftUI

/// 일정 탭 모드 (그룹/개인)
public enum ScheduleMode: String, CaseIterable, Sendable {
  case group
  case personal

  public var displayTitle: String {
    switch self {
    case .group: return LocalizedStrings.ScheduleModeSegment.group
    case .personal: return LocalizedStrings.ScheduleModeSegment.personal
    }
  }
}

/// 일정 탭 공용 헤더 (타이틀 + 모드 Segment)
public struct ScheduleTabHeader: View {
  let selectedMode: ScheduleMode
  let defaultMode: ScheduleMode
  let isShowingGuideTooltip: Bool
  let onGuideTapped: (() -> Void)?
  let onSettingsTapped: (() -> Void)?
  let onModeChange: (ScheduleMode) -> Void

  public init(
    selectedMode: ScheduleMode,
    defaultMode: ScheduleMode,
    isShowingGuideTooltip: Bool = false,
    onGuideTapped: (() -> Void)? = nil,
    onSettingsTapped: (() -> Void)? = nil,
    onModeChange: @escaping (ScheduleMode) -> Void
  ) {
    self.selectedMode = selectedMode
    self.defaultMode = defaultMode
    self.isShowingGuideTooltip = isShowingGuideTooltip
    self.onGuideTapped = onGuideTapped
    self.onSettingsTapped = onSettingsTapped
    self.onModeChange = onModeChange
  }

  /// 디폴트 모드가 앞으로 오도록 정렬된 모드 배열
  private var orderedModes: [ScheduleMode] {
    if defaultMode == .personal {
      return [.personal, .group]
    }
    return [.group, .personal]
  }

  public var body: some View {
    HStack {
      Text(LocalizedStrings.ScheduleModeSegment.scheduleTitle)
        .font(.system(size: 28, weight: .bold))

      if let onSettingsTapped {
        Button(action: onSettingsTapped) {
          Image(systemName: "gearshape.fill")
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .accessibilityLabel(LocalizedStrings.GroupMain.groupSettings)
        .padding(.leading, 4)
      }

      if let onGuideTapped {
        Button(action: onGuideTapped) {
          Image(systemName: "questionmark.circle")
            .font(.system(size: 18))
            .foregroundColor(.primary)
            .frame(width: 32, height: 36)
            .contentShape(Rectangle())
        }
        .overlay(alignment: .bottom) {
          if isShowingGuideTooltip {
            ScheduleGuideTooltip()
              .transition(.opacity.combined(with: .move(edge: .top)))
          }
        }
        .padding(.leading, 4)
      }

      Spacer()

      Picker(LocalizedStrings.ScheduleModeSegment.modePickerLabel, selection: Binding(
        get: { selectedMode },
        set: { onModeChange($0) }
      )) {
        ForEach(orderedModes, id: \.self) { mode in
          Text(mode.displayTitle).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .frame(minWidth: 150, idealWidth: 170, maxWidth: 190)
    }
  }
}

// MARK: - Schedule Guide Tooltip

private struct ScheduleGuideTooltip: View {
  var body: some View {
    Text(LocalizedStrings.Schedule.guideTooltip)
      .font(.caption)
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.pmindigo.n700, in: RoundedRectangle(cornerRadius: 8))
      .overlay(alignment: .top) {
        // 말풍선 꼬리
        ScheduleGuideTriangle()
          .fill(Color.pmindigo.n700)
          .frame(width: 12, height: 6)
          .offset(y: -6)
      }
      .offset(y: 42)
      .fixedSize()
  }
}

private struct ScheduleGuideTriangle: SwiftUI.Shape {
  func path(in rect: CGRect) -> SwiftUI.Path {
    var path = SwiftUI.Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}

#Preview {
  VStack(spacing: 20) {
    ScheduleTabHeader(
      selectedMode: .group,
      defaultMode: .group,
      onModeChange: { _ in }
    )

    ScheduleTabHeader(
      selectedMode: .personal,
      defaultMode: .personal,
      onModeChange: { _ in }
    )
  }
  .padding()
}
