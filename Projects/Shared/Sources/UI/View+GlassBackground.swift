//
//  View+GlassBackground.swift
//  PromisoShared
//

import SwiftUI

// MARK: - Glass Background Extension

extension View {
  /// iOS 26+에서는 glassEffect, 이전 버전에서는 ultraThinMaterial을 사용하는 적응형 배경
  @ViewBuilder
  public func adaptiveGlassBackground() -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    } else {
      self
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
  }
}
