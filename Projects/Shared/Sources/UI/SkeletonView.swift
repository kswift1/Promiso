//
//  SkeletonView.swift
//  Shared
//
//  로딩 중 스켈레톤 UI 컴포넌트
//

import SwiftUI

/// 스켈레톤 뷰 (로딩 중 표시)
public struct SkeletonView: View {
  let cornerRadius: CGFloat

  @State private var isAnimating = false

  public init(cornerRadius: CGFloat = 8) {
    self.cornerRadius = cornerRadius
  }

  public var body: some View {
    Rectangle()
      .fill(Color(.systemGray5))
      .cornerRadius(cornerRadius)
      .overlay(
        Rectangle()
          .fill(
            LinearGradient(
              colors: [
                .clear,
                Color.white.opacity(0.3),
                .clear
              ],
              startPoint: .leading,
              endPoint: .trailing
            )
          )
          .offset(x: isAnimating ? 400 : -400)
          .mask(
            Rectangle()
              .cornerRadius(cornerRadius)
          )
      )
      .onAppear {
        withAnimation(
          .linear(duration: 1.5)
            .repeatForever(autoreverses: false)
        ) {
          isAnimating = true
        }
      }
  }
}

/// 스켈레톤 수정자
public struct SkeletonModifier: ViewModifier {
  let isLoading: Bool
  let cornerRadius: CGFloat

  public func body(content: Content) -> some View {
    if isLoading {
      content
        .hidden()
        .overlay(
          SkeletonView(cornerRadius: cornerRadius)
        )
    } else {
      content
    }
  }
}

public extension View {
  /// 스켈레톤 효과 적용
  func skeleton(isLoading: Bool, cornerRadius: CGFloat = 8) -> some View {
    modifier(SkeletonModifier(isLoading: isLoading, cornerRadius: cornerRadius))
  }
}

// MARK: - Preview

#Preview("Skeleton View") {
  VStack(spacing: 16) {
    SkeletonView()
      .frame(height: 80)

    HStack(spacing: 12) {
      SkeletonView(cornerRadius: 40)
        .frame(width: 80, height: 80)

      VStack(alignment: .leading, spacing: 8) {
        SkeletonView()
          .frame(height: 20)

        SkeletonView()
          .frame(width: 200, height: 16)
      }
    }
  }
  .padding()
}