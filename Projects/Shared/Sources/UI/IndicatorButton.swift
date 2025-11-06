//
//  IndicatorButton.swift
//  Shared
//
//  Created by 김성원 on 11/6/25.
//

import SwiftUI

// MARK: - Indicator Button

public struct IndicatorButton: View {
  
  // MARK: - Enums
  
  public enum IndicatorPosition {
    /// 컨텐츠 왼쪽
    case leading
    /// 컨텐츠 오른쪽
    case trailing
    /// 인디케이터만 표시 (컨텐츠 숨김)
    case only
  }
  
  public enum Style {
    case primary
    case secondary
    case destructive
  }
  
  // MARK: - Properties
  
  private let title: String
  private let action: () -> Void
  private var isLoading: Bool
  private var isDisabled: Bool
  private var style: Style
  private var indicatorPosition: IndicatorPosition
  private var width: CGFloat?
  private var height: CGFloat
  private var fontSize: CGFloat
  private var fontWeight: Font.Weight
  private var indicatorScale: CGFloat
  private var fallbackBackground: Color?
  
  // MARK: - Initializer
  
  public init(
    _ title: String,
    isLoading: Bool = false,
    isDisabled: Bool = false,
    style: Style = .primary,
    indicatorPosition: IndicatorPosition = .trailing,
    width: CGFloat? = nil,
    height: CGFloat = 50,
    fontSize: CGFloat = 16,
    fontWeight: Font.Weight = .semibold,
    indicatorScale: CGFloat = 0.8,
    fallbackBackground: Color? = nil,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.isLoading = isLoading
    self.isDisabled = isDisabled
    self.style = style
    self.indicatorPosition = indicatorPosition
    self.width = width
    self.height = height
    self.fontSize = fontSize
    self.fontWeight = fontWeight
    self.indicatorScale = indicatorScale
    self.fallbackBackground = fallbackBackground
    self.action = action
  }
  
  // MARK: - Body
  
  public var body: some View {
    Button(action: action) {
      buttonContent
        .frame(maxWidth: width == nil ? .infinity : width)
        .frame(height: height)
    }
    .allowsHitTesting(!(isDisabled || isLoading))
    .applyIndicatorButtonStyle(style, fallbackBackground: fallbackBackground)
  }
  
  // MARK: - Private Views
  
  @ViewBuilder
  private var buttonContent: some View {
    switch indicatorPosition {
    case .leading:
      HStack(spacing: 8) {
        if isLoading {
          indicator
        }
        titleText
      }
      
    case .trailing:
      HStack(spacing: 8) {
        titleText
        if isLoading {
          indicator
        }
      }
      
    case .only:
      if isLoading {
        indicator
      } else {
        titleText
      }
    }
  }
  
  private var titleText: some View {
    Text(title)
      .font(.system(size: fontSize, weight: fontWeight))
      .foregroundStyle(foregroundColor)
  }
  
  private var indicator: some View {
    ProgressView()
      .progressViewStyle(CircularProgressViewStyle(tint: foregroundColor))
      .scaleEffect(indicatorScale)
  }
  
  private var foregroundColor: Color {
    switch style {
    case .primary, .destructive:
      return .white
    case .secondary:
      return .gray
    }
  }
}

// MARK: - Style Application

private extension View {
  @ViewBuilder
  func applyIndicatorButtonStyle(
    _ style: IndicatorButton.Style,
    fallbackBackground: Color?
  ) -> some View {
    switch style {
    case .primary:
      self.adaptivePrimaryButton()
    case .secondary:
      if let fallbackBackground = fallbackBackground {
        self.adaptiveSecondaryButton(fallBackBackground: fallbackBackground)
      } else {
        self.adaptiveSecondaryButton()
      }
    case .destructive:
      self.adaptiveDestructiveButton()
    }
  }
}

// MARK: - Presets for Common Use Cases

public extension IndicatorButton {
  /// 약속 카드용 작은 버튼 (높이 24)
  static func promiseAction(
    _ title: String,
    isLoading: Bool = false,
    isDisabled: Bool = false,
    style: Style = .primary,
    fallbackBackground: Color? = nil,
    action: @escaping () -> Void
  ) -> IndicatorButton {
    IndicatorButton(
      title,
      isLoading: isLoading,
      isDisabled: isDisabled,
      style: style,
      indicatorPosition: .only,
      height: 24,
      fontSize: 14,
      fontWeight: .semibold,
      indicatorScale: 0.7,
      fallbackBackground: fallbackBackground,
      action: action
    )
  }
  
  /// 일반 버튼 (높이 50)
  static func standard(
    _ title: String,
    isLoading: Bool = false,
    isDisabled: Bool = false,
    style: Style = .primary,
    action: @escaping () -> Void
  ) -> IndicatorButton {
    IndicatorButton(
      title,
      isLoading: isLoading,
      isDisabled: isDisabled,
      style: style,
      indicatorPosition: .trailing,
      height: 50,
      fontSize: 16,
      fontWeight: .semibold,
      action: action
    )
  }
  
  /// 큰 버튼 (높이 60)
  static func large(
    _ title: String,
    isLoading: Bool = false,
    isDisabled: Bool = false,
    style: Style = .primary,
    action: @escaping () -> Void
  ) -> IndicatorButton {
    IndicatorButton(
      title,
      isLoading: isLoading,
      isDisabled: isDisabled,
      style: style,
      indicatorPosition: .trailing,
      height: 60,
      fontSize: 18,
      fontWeight: .bold,
      indicatorScale: 1.0,
      action: action
    )
  }
  
  /// 작은 버튼 (높이 40)
  static func compact(
    _ title: String,
    isLoading: Bool = false,
    isDisabled: Bool = false,
    style: Style = .primary,
    action: @escaping () -> Void
  ) -> IndicatorButton {
    IndicatorButton(
      title,
      isLoading: isLoading,
      isDisabled: isDisabled,
      style: style,
      indicatorPosition: .trailing,
      height: 40,
      fontSize: 14,
      fontWeight: .semibold,
      indicatorScale: 0.7,
      action: action
    )
  }
}

// MARK: - Preview

#Preview("Indicator Button Showcase") {
  ScrollView {
    VStack(spacing: 32) {
      // Standard Buttons
      VStack(alignment: .leading, spacing: 16) {
        Text("Standard Buttons")
          .font(.headline)
        
        IndicatorButton.standard(
          "약속 생성하기",
          isLoading: false,
          action: {}
        )
        
        IndicatorButton.standard(
          "로딩 중...",
          isLoading: true,
          action: {}
        )
        
        IndicatorButton.standard(
          "비활성화",
          isDisabled: true,
          action: {}
        )
      }
      
      // Promise Action Buttons
      VStack(alignment: .leading, spacing: 16) {
        Text("Promise Action Buttons")
          .font(.headline)
        
        HStack(spacing: 12) {
          IndicatorButton.promiseAction(
            "수락",
            isLoading: false,
            style: .primary,
            action: {}
          )
          
          IndicatorButton.promiseAction(
            "거절",
            isLoading: false,
            style: .secondary,
            fallbackBackground: Color(.systemGroupedBackground),
            action: {}
          )
        }
        
        HStack(spacing: 12) {
          IndicatorButton.promiseAction(
            "수락",
            isLoading: true,
            style: .primary,
            action: {}
          )
          
          IndicatorButton.promiseAction(
            "거절",
            isLoading: false,
            isDisabled: true,
            style: .secondary,
            fallbackBackground: Color(.systemGroupedBackground),
            action: {}
          )
        }
      }
      
      // Indicator Positions
      VStack(alignment: .leading, spacing: 16) {
        Text("Indicator Positions")
          .font(.headline)
        
        IndicatorButton(
          "Leading",
          isLoading: true,
          indicatorPosition: .leading,
          action: {}
        )
        
        IndicatorButton(
          "Trailing",
          isLoading: true,
          indicatorPosition: .trailing,
          action: {}
        )
        
        IndicatorButton(
          "Only",
          isLoading: true,
          indicatorPosition: .only,
          action: {}
        )
      }
      
      // Sizes
      VStack(alignment: .leading, spacing: 16) {
        Text("Sizes")
          .font(.headline)
        
        IndicatorButton.large(
          "Large Button",
          isLoading: true,
          action: {}
        )
        
        IndicatorButton.standard(
          "Standard Button",
          isLoading: true,
          action: {}
        )
        
        IndicatorButton.compact(
          "Compact Button",
          isLoading: true,
          action: {}
        )
        
        IndicatorButton.promiseAction(
          "Promise Action",
          isLoading: true,
          action: {}
        )
      }
      
      // Styles
      VStack(alignment: .leading, spacing: 16) {
        Text("Styles")
          .font(.headline)
        
        IndicatorButton.standard(
          "Primary",
          isLoading: true,
          style: .primary,
          action: {}
        )
        
        IndicatorButton.standard(
          "Secondary",
          isLoading: true,
          style: .secondary,
          action: {}
        )
        
        IndicatorButton.standard(
          "Destructive",
          isLoading: true,
          style: .destructive,
          action: {}
        )
      }
    }
    .padding()
  }
  .background(Color(.systemGroupedBackground))
}
