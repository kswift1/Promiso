//
//  ToastView.swift
//  PromisoShared
//

import SwiftUI
import UIKit
import ResourceKit

// MARK: - Models

/// 토스트가 표시될 위치
public enum ToastPosition: Sendable {
  case top
  case bottom
}

/// 토스트 타입 (아이콘, 색상, 자동 해제 시간 결정)
public enum ToastType: Sendable {
  case success
  case error
  case warning
  case info

  /// SF Symbol 아이콘 이름
  public var icon: String {
    switch self {
    case .success: "checkmark.circle.fill"
    case .error: "xmark.circle.fill"
    case .warning: "exclamationmark.triangle.fill"
    case .info: "info.circle.fill"
    }
  }

  /// 전경 강조 색상
  public var color: Color {
    switch self {
    case .success: Color.pmsuccess.n500
    case .error: Color.pmerror.n500
    case .warning: Color.pmwarning.n500
    case .info: Color.pminfo.n500
    }
  }

  /// Fallback 배경 틴트 색상
  public var backgroundColor: Color {
    switch self {
    case .success: Color.pmsuccess.n50
    case .error: Color.pmerror.n50
    case .warning: Color.pmwarning.n50
    case .info: Color.pminfo.n50
    }
  }

  /// 자동 해제까지의 시간 (초)
  public var autoDismissInterval: TimeInterval {
    switch self {
    case .success, .info: 3.0
    case .error, .warning: 4.0
    }
  }

  /// 타입에 맞는 Haptic 피드백 실행
  func triggerHaptic() {
    switch self {
    case .success: Haptic.success()
    case .error: Haptic.error()
    case .warning: Haptic.warning()
    case .info: Haptic.selection()
    }
  }
}

/// 토스트에 표시할 액션 버튼 정보
public struct ToastAction: Sendable {
  public let title: String
  public let handler: @Sendable () -> Void

  public init(title: String, handler: @escaping @Sendable () -> Void) {
    self.title = title
    self.handler = handler
  }
}

/// 토스트 메시지 모델
public struct ToastMessage: Equatable, Sendable {
  public let id: UUID
  public let type: ToastType
  public let title: String
  public let subtitle: String?
  public let action: ToastAction?
  public let position: ToastPosition

  public init(
    type: ToastType,
    title: String,
    subtitle: String? = nil,
    action: ToastAction? = nil,
    position: ToastPosition = .top
  ) {
    self.id = UUID()
    self.type = type
    self.title = title
    self.subtitle = subtitle
    self.action = action
    self.position = position
  }

  // Equatable: id로만 비교 (action 클로저는 비교 불가)
  public static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: - Toast View

/// 토스트 콘텐츠 뷰 (내부 전용)
struct ToastContentView: View {
  let message: ToastMessage

  var body: some View {
    HStack(spacing: 12) {
      // 아이콘
      Image(systemName: message.type.icon)
        .font(.body.weight(.semibold))
        .foregroundStyle(message.type.color)

      // 텍스트 영역
      VStack(alignment: .leading, spacing: 2) {
        Text(message.title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)

        if let subtitle = message.subtitle {
          Text(subtitle)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }

      Spacer(minLength: 0)

      // 액션 버튼
      if let action = message.action {
        Button {
          action.handler()
        } label: {
          Text(action.title)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.pmindigo.n500)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

// MARK: - Toast Modifier

/// 토스트 표시를 위한 ViewModifier
struct ToastModifier: ViewModifier {
  @Binding var message: ToastMessage?
  @State private var dragOffset: CGFloat = 0
  @State private var dismissTask: Task<Void, Never>?

  private var position: ToastPosition {
    message?.position ?? .top
  }

  func body(content: Content) -> some View {
    content
      .overlay(alignment: position == .top ? .top : .bottom) {
        if let message {
          toastView(for: message)
            .transition(
              .move(edge: position == .top ? .top : .bottom)
              .combined(with: .opacity)
            )
            .offset(y: dragOffset)
            .gesture(dismissGesture)
            .padding(.horizontal, 16)
            .padding(position == .top ? .top : .bottom, 8)
            .accessibilityElement(children: .combine)
        }
      }
      .animation(.spring(duration: 0.45, bounce: 0.2), value: message)
      .onChange(of: message) { _, newMessage in
        handleMessageChange(newMessage)
      }
      .onDisappear {
        dismissTask?.cancel()
      }
  }

  // MARK: - Toast View Builder

  @ViewBuilder
  private func toastView(for message: ToastMessage) -> some View {
    if #available(iOS 26.0, *) {
      glassToastView(for: message)
    } else {
      fallbackToastView(for: message)
    }
  }

  @available(iOS 26.0, *)
  private func glassToastView(for message: ToastMessage) -> some View {
    ToastContentView(message: message)
      .glassEffect(
        .regular.interactive(),
        in: .rect(cornerRadius: 14)
      )
      .shadow(
        color: .black.opacity(0.12),
        radius: 12,
        x: 0,
        y: position == .top ? 4 : -4
      )
  }

  private func fallbackToastView(for message: ToastMessage) -> some View {
    ToastContentView(message: message)
      .background {
        RoundedRectangle(cornerRadius: 14)
          .fill(.ultraThinMaterial)
          .overlay(
            RoundedRectangle(cornerRadius: 14)
              .fill(message.type.backgroundColor.opacity(0.15))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 14)
              .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
          )
      }
      .shadow(
        color: .black.opacity(0.12),
        radius: 12,
        x: 0,
        y: position == .top ? 4 : -4
      )
  }

  // MARK: - Dismiss Gesture

  private var dismissGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        let translation = value.translation.height
        if position == .top {
          // top 위치: 위로 드래그만 허용
          dragOffset = min(translation, 0)
        } else {
          // bottom 위치: 아래로 드래그만 허용
          dragOffset = max(translation, 0)
        }
      }
      .onEnded { value in
        let translation = value.translation.height
        let threshold: CGFloat = 40

        if position == .top, translation < -threshold {
          dismiss()
        } else if position == .bottom, translation > threshold {
          dismiss()
        } else {
          // threshold 미달: spring으로 복귀
          withAnimation(.spring(duration: 0.3, bounce: 0.2)) {
            dragOffset = 0
          }
        }
      }
  }

  // MARK: - Logic

  private func handleMessageChange(_ newMessage: ToastMessage?) {
    dismissTask?.cancel()
    dragOffset = 0

    guard let newMessage else { return }

    // Haptic 피드백
    newMessage.type.triggerHaptic()

    // 접근성 알림
    UIAccessibility.post(
      notification: .announcement,
      argument: newMessage.title
    )

    // 자동 해제 타이머
    let interval = newMessage.action != nil
      ? 5.0
      : newMessage.type.autoDismissInterval

    dismissTask = Task { @MainActor in
      try? await Task.sleep(for: .seconds(interval))
      guard !Task.isCancelled else { return }
      dismiss()
    }
  }

  private func dismiss() {
    dismissTask?.cancel()
    withAnimation(.spring(duration: 0.45, bounce: 0.2)) {
      message = nil
      dragOffset = 0
    }
  }
}

// MARK: - View Extension

public extension View {
  /// 토스트 메시지를 표시하는 modifier
  ///
  /// ```swift
  /// @State private var toast: ToastMessage?
  ///
  /// someView
  ///   .toast($toast)
  /// ```
  func toast(_ message: Binding<ToastMessage?>) -> some View {
    modifier(ToastModifier(message: message))
  }
}

// MARK: - Preview

#Preview("Toast Types") {
  ToastPreviewContainer()
}

/// 인터랙티브 프리뷰 컨테이너
private struct ToastPreviewContainer: View {
  @State private var toast: ToastMessage?
  @State private var position: ToastPosition = .top

  var body: some View {
    NavigationStack {
      VStack(spacing: 16) {
        Picker("위치", selection: $position) {
          Text("Top").tag(ToastPosition.top)
          Text("Bottom").tag(ToastPosition.bottom)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)

        Divider()

        VStack(spacing: 12) {
          Button {
            toast = ToastMessage(
              type: .success,
              title: "저장 완료",
              subtitle: "변경사항이 성공적으로 저장되었습니다.",
              position: position
            )
          } label: {
            HStack {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.pmsuccess.n500)
              Text("Success Toast")
              Spacer()
            }
            .contentShape(Rectangle())
          }

          Button {
            toast = ToastMessage(
              type: .error,
              title: "오류 발생",
              subtitle: "네트워크 연결을 확인해주세요.",
              position: position
            )
          } label: {
            HStack {
              Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color.pmerror.n500)
              Text("Error Toast")
              Spacer()
            }
            .contentShape(Rectangle())
          }

          Button {
            toast = ToastMessage(
              type: .warning,
              title: "주의",
              subtitle: "약속 시간이 30분 남았습니다.",
              position: position
            )
          } label: {
            HStack {
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.pmwarning.n500)
              Text("Warning Toast")
              Spacer()
            }
            .contentShape(Rectangle())
          }

          Button {
            toast = ToastMessage(
              type: .info,
              title: "새로운 멤버",
              subtitle: "김성원님이 그룹에 참여했습니다.",
              position: position
            )
          } label: {
            HStack {
              Image(systemName: "info.circle.fill")
                .foregroundStyle(Color.pminfo.n500)
              Text("Info Toast")
              Spacer()
            }
            .contentShape(Rectangle())
          }

          Divider()

          Button {
            toast = ToastMessage(
              type: .error,
              title: "삭제되었습니다",
              action: ToastAction(title: "실행 취소") {
                toast = ToastMessage(
                  type: .success,
                  title: "복원 완료",
                  position: position
                )
              },
              position: position
            )
          } label: {
            HStack {
              Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(Color.pmindigo.n500)
              Text("Snackbar (Action)")
              Spacer()
            }
            .contentShape(Rectangle())
          }
        }
        .padding(.horizontal)

        Spacer()
      }
      .padding(.top, 16)
      .navigationTitle("Toast Preview")
    }
    .toast($toast)
  }
}
