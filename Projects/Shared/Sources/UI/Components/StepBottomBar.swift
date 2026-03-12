import SwiftUI
import ResourceKit

// MARK: - Configuration

/// StepBottomBar 버튼 구성
public enum StepBottomBarConfiguration {
  /// 단일 버튼 (저장 등)
  case single(
    title: String,
    systemImage: String = "checkmark.circle.fill",
    isLoading: Bool = false,
    isDisabled: Bool = false,
    action: () -> Void
  )
  /// 네비게이션 (이전/다음)
  case navigation(
    showPrevious: Bool,
    previousAction: () -> Void,
    nextTitle: String,
    nextSystemImage: String = "arrow.right.circle.fill",
    isNextDisabled: Bool = false,
    isNextLoading: Bool = false,
    nextAction: () -> Void
  )
}

// MARK: - Step Bottom Bar

/// 단계별 플로우의 하단 이전/다음/저장 버튼 바
public struct StepBottomBar: View {
  private let configuration: StepBottomBarConfiguration

  public init(configuration: StepBottomBarConfiguration) {
    self.configuration = configuration
  }

  public var body: some View {
    switch configuration {
    case let .single(title, systemImage, isLoading, isDisabled, action):
      singleButton(
        title: title,
        systemImage: systemImage,
        isLoading: isLoading,
        isDisabled: isDisabled,
        action: action
      )
    case let .navigation(showPrevious, previousAction, nextTitle, nextSystemImage, isNextDisabled, isNextLoading, nextAction):
      navigationButtons(
        showPrevious: showPrevious,
        previousAction: previousAction,
        nextTitle: nextTitle,
        nextSystemImage: nextSystemImage,
        isNextDisabled: isNextDisabled,
        isNextLoading: isNextLoading,
        nextAction: nextAction
      )
    }
  }
}

// MARK: - Layout Builders

extension StepBottomBar {
  @ViewBuilder
  private func singleButton(
    title: String,
    systemImage: String,
    isLoading: Bool,
    isDisabled: Bool,
    action: @escaping () -> Void
  ) -> some View {
    PrimaryStepButton(
      title: title,
      systemImage: systemImage,
      isLoading: isLoading,
      isDisabled: isDisabled,
      action: action
    )
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
  }

  @ViewBuilder
  private func navigationButtons(
    showPrevious: Bool,
    previousAction: @escaping () -> Void,
    nextTitle: String,
    nextSystemImage: String,
    isNextDisabled: Bool,
    isNextLoading: Bool,
    nextAction: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 12) {
      if showPrevious {
        PreviousStepButton(action: previousAction)
          .frame(width: 96)
      }

      PrimaryStepButton(
        title: nextTitle,
        systemImage: nextSystemImage,
        isLoading: isNextLoading,
        isDisabled: isNextDisabled,
        action: nextAction
      )
      .frame(maxWidth: .infinity)
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
  }
}

// MARK: - Previous Button

private struct PreviousStepButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        Image(systemName: "chevron.left")
          .font(.system(size: 13, weight: .semibold))
        Text(LocalizedStrings.Common.back)
          .font(.system(size: 15, weight: .semibold))
      }
      .foregroundStyle(Color(.label))
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(Color(.systemGray5))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.hapticBounce)
  }
}

// MARK: - Primary Step Button

private struct PrimaryStepButton: View {
  let title: String
  let systemImage: String
  let isLoading: Bool
  let isDisabled: Bool
  let action: () -> Void

  private var backgroundColor: Color {
    isDisabled ? Color(.systemGray4) : Color.pmindigo.n500
  }

  var body: some View {
    Button(action: action) {
      ZStack {
        if isLoading {
          ProgressView()
            .tint(.white)
            .scaleEffect(0.9)
        } else {
          HStack(spacing: 6) {
            Text(title)
              .font(.system(size: 15, weight: .semibold))
            Image(systemName: systemImage)
              .font(.system(size: 16, weight: .semibold))
          }
          .foregroundStyle(.white)
        }
      }
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(backgroundColor)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.hapticBounce)
    .disabled(isDisabled || isLoading)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDisabled)
  }
}

// MARK: - Previews

#Preview("단일 버튼 — 저장") {
  VStack {
    Spacer()
    StepBottomBar(configuration: .single(
      title: "저장",
      systemImage: "checkmark.circle.fill",
      action: {}
    ))
  }
}

#Preview("네비게이션 — 이전/다음") {
  VStack {
    Spacer()
    StepBottomBar(configuration: .navigation(
      showPrevious: true,
      previousAction: {},
      nextTitle: "다음",
      nextSystemImage: "arrow.right.circle.fill",
      nextAction: {}
    ))
  }
}

#Preview("네비게이션 — 첫 단계 (이전 없음)") {
  VStack {
    Spacer()
    StepBottomBar(configuration: .navigation(
      showPrevious: false,
      previousAction: {},
      nextTitle: "시작하기",
      nextSystemImage: "arrow.right.circle.fill",
      nextAction: {}
    ))
  }
}

#Preview("로딩 상태") {
  VStack {
    Spacer()
    StepBottomBar(configuration: .single(
      title: "저장 중...",
      systemImage: "checkmark.circle.fill",
      isLoading: true,
      action: {}
    ))
  }
}

#Preview("비활성화 상태") {
  VStack {
    Spacer()
    StepBottomBar(configuration: .navigation(
      showPrevious: true,
      previousAction: {},
      nextTitle: "다음",
      isNextDisabled: true,
      nextAction: {}
    ))
  }
}
