//
//  View+GlassBackground.swift
//  PromisoShared
//

import SwiftUI

// MARK: - Glass Background Extension

extension View {
  /// iOS 26+에서는 glassEffect, 이전 버전에서는 ultraThinMaterial을 사용하는 적응형 배경
  @ViewBuilder
  public func adaptiveGlassBackground(cornerRadius: CGFloat = 12) -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
    } else {
      self
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
    }
  }

  /// 카드용 Glass Effect (shadow 포함)
  @ViewBuilder
  public func adaptiveGlassCard(cornerRadius: CGFloat = 16) -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
    } else {
      self
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
  }
}
