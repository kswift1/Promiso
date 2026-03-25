//
//  View+GlassBackground.swift
//  PromisoShared
//

import ResourceKit
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

  /// iOS 26+에서는 glassEffect(.regular), 이전 버전에서는 ultraThinMaterial (interactive 없음)
  @ViewBuilder
  public func staticGlassBackground(cornerRadius: CGFloat = 12) -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
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

  /// 정적 카드용 Glass Effect (shadow 포함, interactive 없음)
  @ViewBuilder
  public func staticGlassCard(cornerRadius: CGFloat = 16) -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
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

  /// Pro Plan 전용 보라색 tinted Glass Card
  @ViewBuilder
  public func proGlassCard(cornerRadius: CGFloat = 16) -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(
          .regular.tint(Color.pmpurple.n500.opacity(0.15)).interactive(),
          in: .rect(cornerRadius: cornerRadius)
        )
        .shadow(color: Color.pmpurple.n500.opacity(0.1), radius: 10, x: 0, y: 4)
    } else {
      self
        .background(
          LinearGradient(
            colors: [
              Color.pmpurple.n500.opacity(0.08),
              Color.pmindigo.n500.opacity(0.06)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          ),
          in: RoundedRectangle(cornerRadius: cornerRadius)
        )
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        .overlay(
          RoundedRectangle(cornerRadius: cornerRadius)
            .strokeBorder(
              LinearGradient(
                colors: [Color.pmpurple.n500.opacity(0.2), Color.pmindigo.n500.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1
            )
        )
        .shadow(color: Color.pmpurple.n500.opacity(0.08), radius: 8, x: 0, y: 4)
    }
  }
}
