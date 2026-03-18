//
//  GlassActionButton.swift
//  Shared
//
//  Created by 김성원 on 12/16/25.
//

import SwiftUI

/// 앱 전반에 사용하는 그라데이션 글래스 버튼입니다.
/// - Parameters:
///   - title: 버튼에 표시할 텍스트
///   - isPrimary: true면 채워진(프라이머리) 스타일, false면 아웃라인 느낌
///   - isVisible / isEnabled: 노출 및 활성화 여부(opacity/offset 애니메이션 포함)
///   - action: 탭 시 실행할 핸들러
public struct GlassActionButton: View {
  let title: String
  var leadingSystemImage: String?
  var isPrimary: Bool
  var isVisible: Bool
  var isEnabled: Bool
  let action: () -> Void
  
  public init(
    title: String,
    leadingSystemImage: String? = nil,
    isPrimary: Bool = true,
    isVisible: Bool = true,
    isEnabled: Bool = true,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.leadingSystemImage = leadingSystemImage
    self.isPrimary = isPrimary
    self.isVisible = isVisible
    self.isEnabled = isEnabled
    self.action = action
  }
  
  @ViewBuilder
  public var body: some View {
    if #available(iOS 26.0, *) {
      glassEffectBody
    } else {
      fallbackBody
    }
  }
  
  @available(iOS 26.0, *)
  private var glassEffectBody: some View {
    Button(action: action) {
      label
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .glassEffect(
          .regular
            .tint(
              isPrimary
              ? .pmindigo.n500.opacity(0.74)
              : .purple.opacity(0.14)
            )
            .interactive(),
          in: .rect(cornerRadius: 14)
        )
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.5)
    .opacity(isVisible ? 1 : 0)
    .offset(y: isVisible ? 0 : 20)
  }
  
  private var fallbackBody: some View {
    Button(action: action) {
      label
        .background(
          ZStack {
            if isPrimary {
              LinearGradient(
                colors: [
                  Color(red: 0.6, green: 0.4, blue: 0.9),
                  Color(red: 0.5, green: 0.3, blue: 0.8)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            } else {
              Color.clear
            }

            LinearGradient(
              colors: [
                Color.white.opacity(isPrimary ? 0.2 : 0.1),
                Color.white.opacity(0)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          }
        )
        .overlay(
          RoundedRectangle(cornerRadius: 14)
            .stroke(
              LinearGradient(
                colors: [
                  Color.white.opacity(isPrimary ? 0.3 : 0.2),
                  Color.white.opacity(0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(
          color: isPrimary
          ? Color(red: 0.6, green: 0.4, blue: 0.9).opacity(0.3)
          : Color.clear,
          radius: 12,
          y: 6
        )
    }
    .buttonStyle(.hapticBounce)
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1 : 0.5)
    .opacity(isVisible ? 1 : 0)
    .offset(y: isVisible ? 0 : 20)
  }
  
  private var label: some SwiftUI.View {
    HStack(spacing: 8) {
      if let leadingSystemImage {
        Image(systemName: leadingSystemImage)
          .font(.headline)
      }
      
      Text(title)
        .font(.body.weight(.semibold))
    }
    .foregroundStyle(isPrimary ? Color.white : Color.primary)
    .frame(maxWidth: .infinity)
    .frame(height: 52)
  }
}
