// MARK: - GlassEffectModifiers.swift
// 캘린더 뷰용 Glass Effect 모디파이어

import SwiftUI
import ResourceKit

// MARK: - Adaptive Glass Background Modifiers

extension View {
  /// 카드 배경용 Glass Effect
  @ViewBuilder
  func adaptiveGlassBackground() -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    } else {
      self
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
  }

  /// 섹션 헤더 배경용 Glass Effect
  @ViewBuilder
  func adaptiveGlassSectionBackground() -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(.regular, in: .rect)
    } else {
      self
        .background(.ultraThinMaterial)
    }
  }

  /// 응답하기 버튼용 Glass Effect
  @ViewBuilder
  func adaptiveGlassRespondButton() -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(
          .regular.tint(Color.pmindigo.n500.opacity(0.8)).interactive(),
          in: .rect(cornerRadius: 10)
        )
        .shadow(color: Color.pmindigo.n500.opacity(0.3), radius: 8, y: 4)
    } else {
      self
        .background(
          LinearGradient(
            colors: [Color.pmindigo.n500, Color.pmindigo.n600],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          in: RoundedRectangle(cornerRadius: 10)
        )
        .shadow(color: Color.pmindigo.n500.opacity(0.3), radius: 8, y: 4)
    }
  }
}
