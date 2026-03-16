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
  let onSettingsTapped: (() -> Void)?
  let onModeChange: (ScheduleMode) -> Void

  public init(
    selectedMode: ScheduleMode,
    defaultMode: ScheduleMode,
    onSettingsTapped: (() -> Void)? = nil,
    onModeChange: @escaping (ScheduleMode) -> Void
  ) {
    self.selectedMode = selectedMode
    self.defaultMode = defaultMode
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
        .accessibilityLabel("그룹 설정")
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
