import SwiftUI

/// 약속 탭 모드 (그룹/개인)
public enum PromiseMode: String, CaseIterable, Sendable {
  case group = "그룹"
  case personal = "개인"
}

/// 약속 탭 공용 헤더 (타이틀 + 모드 Segment)
public struct PromiseTabHeader: View {
  let selectedMode: PromiseMode
  let defaultMode: PromiseMode
  let onModeChange: (PromiseMode) -> Void

  public init(
    selectedMode: PromiseMode,
    defaultMode: PromiseMode,
    onModeChange: @escaping (PromiseMode) -> Void
  ) {
    self.selectedMode = selectedMode
    self.defaultMode = defaultMode
    self.onModeChange = onModeChange
  }

  /// 디폴트 모드가 앞으로 오도록 정렬된 모드 배열
  private var orderedModes: [PromiseMode] {
    if defaultMode == .personal {
      return [.personal, .group]
    }
    return [.group, .personal]
  }

  public var body: some View {
    HStack {
      Text("약속")
        .font(.system(size: 28, weight: .bold))

      Spacer()

      Picker("모드", selection: Binding(
        get: { selectedMode },
        set: { onModeChange($0) }
      )) {
        ForEach(orderedModes, id: \.self) { mode in
          Text(mode.rawValue).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: 130)
    }
  }
}

#Preview {
  VStack(spacing: 20) {
    PromiseTabHeader(
      selectedMode: .group,
      defaultMode: .group,
      onModeChange: { _ in }
    )

    PromiseTabHeader(
      selectedMode: .personal,
      defaultMode: .personal,
      onModeChange: { _ in }
    )
  }
  .padding()
}
