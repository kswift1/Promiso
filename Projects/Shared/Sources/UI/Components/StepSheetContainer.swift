import SwiftUI
import ResourceKit
import UIKit

// MARK: - Step Sheet Container

/// 단계별 플로우를 위한 통합 Sheet 레이아웃 컨테이너
///
/// ```
/// ┌──────────────────────────────────┐
/// │  [제목 (중앙)]          [X 버튼] │  ← 상단 툴바
/// ├──────────────────────────────────┤
/// │  ████░░░░░░░░  (2/3)             │  ← StepProgressBar
/// ├──────────────────────────────────┤
/// │                                  │
/// │  Content (ScrollView 포함 가능)   │  ← content
/// │                                  │
/// │  ↕ 스크롤 영역                    │
/// │                                  │
/// ├─ 그라디언트 페이드 (24pt) ────────┤  ← 상단→투명 gradient overlay
/// │  ┌ FloatingContent ────────────┐ │  ← floatingContent (옵셔널)
/// │  └─────────────────────────────┘ │
/// │  [← 이전]        [다음 →]       │  ← bottomContent
/// └──────────────────────────────────┘
/// ```
public struct StepSheetContainer<
  Content: View,
  FloatingContent: View,
  BottomContent: View
>: View {
  let title: String
  let currentStep: Int
  let totalSteps: Int
  let onDismiss: () -> Void
  @ViewBuilder let content: () -> Content
  @ViewBuilder let floatingContent: () -> FloatingContent
  @ViewBuilder let bottomContent: () -> BottomContent

  @State private var isDismissPressed = false
  @State private var isKeyboardPresented = false

  public init(
    title: String,
    currentStep: Int,
    totalSteps: Int,
    onDismiss: @escaping () -> Void,
    @ViewBuilder content: @escaping () -> Content,
    @ViewBuilder floatingContent: @escaping () -> FloatingContent,
    @ViewBuilder bottomContent: @escaping () -> BottomContent
  ) {
    self.title = title
    self.currentStep = currentStep
    self.totalSteps = totalSteps
    self.onDismiss = onDismiss
    self.content = content
    self.floatingContent = floatingContent
    self.bottomContent = bottomContent
  }

  public var body: some View {
    GeometryReader { geometry in
      VStack(spacing: 0) {
        // 1. 상단 툴바
        sheetToolbar

        // 2. 진행바 (totalSteps > 1일 때만 표시)
        if totalSteps > 1 {
          StepProgressBar(currentStep: currentStep, totalSteps: totalSteps)
        }

        // 3. 콘텐츠 영역 + 하단 고정 영역
        content()
          .safeAreaInset(edge: .bottom) {
            bottomFixedArea
          }
      }
      .frame(height: geometry.size.height)
    }
    .ignoresSafeArea(.keyboard, edges: .bottom)
    .keyboardDismissToolbar(iconColor: .secondary)
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { notification in
      updateKeyboardPresentation(notification)
    }
    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
      updateKeyboardPresentation(notification, isHiddenOverride: true)
    }
  }

  // MARK: - Sheet Toolbar

  @ViewBuilder
  private var sheetToolbar: some View {
    HStack {
      // 레이아웃 균형을 위한 빈 공간
      Color.clear
        .frame(width: 36, height: 36)

      Spacer()

      Text(title)
        .font(.system(size: 18, weight: .bold))
        .foregroundStyle(.primary)

      Spacer()

      // X 닫기 버튼
      Button {
        onDismiss()
      } label: {
        ZStack {
          Circle()
            .fill(Color(.systemGray6))
            .frame(width: 36, height: 36)

          Image(systemName: "xmark")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.primary)
        }
        .contentShape(Circle())
      }
      .buttonStyle(.plain)
      .scaleEffect(isDismissPressed ? 0.9 : 1.0)
      .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isDismissPressed)
      .sensoryFeedback(.impact(flexibility: .soft), trigger: isDismissPressed)
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in isDismissPressed = true }
          .onEnded { _ in isDismissPressed = false }
      )
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  // MARK: - Bottom Fixed Area

  @ViewBuilder
  private var bottomFixedArea: some View {
    if !isKeyboardPresented {
      VStack(spacing: 12) {
        floatingContent()
          .padding(.horizontal, 16)

        bottomContent()
          .background(Color(.systemBackground))
          .overlay(alignment: .top) {
            // 그라디언트 페이드 (투명 → 배경색) — floatingContent 아래, 버튼 위
            LinearGradient(
              colors: [
                Color(.systemBackground).opacity(0),
                Color(.systemBackground)
              ],
              startPoint: .top,
              endPoint: .bottom
            )
            .frame(height: 24)
            .offset(y: -24)
            .allowsHitTesting(false)
          }
      }
      .padding(.top, 8)
      .transition(.move(edge: .bottom).combined(with: .opacity))
    }
  }

  private func updateKeyboardPresentation(
    _ notification: Notification,
    isHiddenOverride: Bool = false
  ) {
    let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25

    let isVisible: Bool
    if isHiddenOverride {
      isVisible = false
    } else if let endFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
      isVisible = endFrame.minY < UIScreen.main.bounds.height
    } else {
      isVisible = false
    }

    withAnimation(.easeInOut(duration: duration)) {
      isKeyboardPresented = isVisible
    }
  }
}

// MARK: - Convenience Initializer (FloatingContent = EmptyView)

extension StepSheetContainer where FloatingContent == EmptyView {
  /// floatingContent 없이 사용하는 편의 이니셜라이저
  public init(
    title: String,
    currentStep: Int,
    totalSteps: Int,
    onDismiss: @escaping () -> Void,
    @ViewBuilder content: @escaping () -> Content,
    @ViewBuilder bottomContent: @escaping () -> BottomContent
  ) {
    self.init(
      title: title,
      currentStep: currentStep,
      totalSteps: totalSteps,
      onDismiss: onDismiss,
      content: content,
      floatingContent: { EmptyView() },
      bottomContent: bottomContent
    )
  }
}

// MARK: - Previews

#Preview("1단계 — 기본") {
  StepSheetContainer(
    title: "약속 만들기",
    currentStep: 0,
    totalSteps: 3,
    onDismiss: {}
  ) {
    ScrollView {
      VStack(spacing: 16) {
        ForEach(0..<10) { index in
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.blue.opacity(0.1))
            .frame(height: 80)
            .overlay(Text("항목 \(index + 1)"))
        }
      }
      .padding()
    }
  } bottomContent: {
    StepBottomBar(configuration: .navigation(
      showPrevious: false,
      previousAction: {},
      nextTitle: "다음",
      nextAction: {}
    ))
  }
}

#Preview("2단계 — FloatingContent 포함") {
  StepSheetContainer(
    title: "날짜 선택",
    currentStep: 1,
    totalSteps: 3,
    onDismiss: {}
  ) {
    ScrollView {
      VStack(spacing: 16) {
        ForEach(0..<8) { index in
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.purple.opacity(0.1))
            .frame(height: 80)
            .overlay(Text("항목 \(index + 1)"))
        }
      }
      .padding()
    }
  } floatingContent: {
    RoundedRectangle(cornerRadius: 12)
      .fill(Color.orange.opacity(0.15))
      .frame(height: 48)
      .overlay(Text("날씨 정보 영역"))
  } bottomContent: {
    StepBottomBar(configuration: .navigation(
      showPrevious: true,
      previousAction: {},
      nextTitle: "다음",
      nextAction: {}
    ))
  }
}

#Preview("마지막 단계 — 저장 버튼") {
  StepSheetContainer(
    title: "약속 만들기",
    currentStep: 2,
    totalSteps: 3,
    onDismiss: {}
  ) {
    ScrollView {
      VStack(spacing: 16) {
        ForEach(0..<6) { index in
          RoundedRectangle(cornerRadius: 12)
            .fill(Color.green.opacity(0.1))
            .frame(height: 80)
            .overlay(Text("항목 \(index + 1)"))
        }
      }
      .padding()
    }
  } bottomContent: {
    StepBottomBar(configuration: .single(
      title: "저장하기",
      systemImage: "checkmark.circle.fill",
      action: {}
    ))
  }
}
