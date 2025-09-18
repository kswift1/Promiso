import SwiftUI
import Domain

// MARK: - App Theme

/// 앱 테마 시스템
public struct AppTheme {
  public let colors: ColorScheme
  public let typography: Typography
  public let spacing: Spacing
  public let cornerRadius: CornerRadius
  public let shadows: Shadows
  
  public init(
    colors: ColorScheme = .default,
    typography: Typography = .default,
    spacing: Spacing = .default,
    cornerRadius: CornerRadius = .default,
    shadows: Shadows = .default
  ) {
    self.colors = colors
    self.typography = typography
    self.spacing = spacing
    self.cornerRadius = cornerRadius
    self.shadows = shadows
  }
  
  public static let `default` = AppTheme()
}

// MARK: - Color Scheme

/// 앱 색상 체계
public struct ColorScheme {
  // Primary Colors
  public let primary: Color
  public let primaryVariant: Color
  public let onPrimary: Color
  
  // Secondary Colors
  public let secondary: Color
  public let secondaryVariant: Color
  public let onSecondary: Color
  
  // Surface Colors
  public let surface: Color
  public let onSurface: Color
  public let background: Color
  public let onBackground: Color
  
  // Status Colors
  public let success: Color
  public let warning: Color
  public let error: Color
  public let info: Color
  
  // Text Colors
  public let textPrimary: Color
  public let textSecondary: Color
  public let textTertiary: Color
  public let textDisabled: Color
  
  // Border Colors
  public let border: Color
  public let borderLight: Color
  public let separator: Color
  
  public init(
    primary: Color = Color.blue,
    primaryVariant: Color = Color.blue.opacity(0.8),
    onPrimary: Color = Color.white,
    secondary: Color = Color.gray,
    secondaryVariant: Color = Color.gray.opacity(0.8),
    onSecondary: Color = Color.white,
    surface: Color = Color(UIColor.systemBackground),
    onSurface: Color = Color(UIColor.label),
    background: Color = Color(UIColor.systemBackground),
    onBackground: Color = Color(UIColor.label),
    success: Color = Color.green,
    warning: Color = Color.orange,
    error: Color = Color.red,
    info: Color = Color.blue,
    textPrimary: Color = Color(UIColor.label),
    textSecondary: Color = Color(UIColor.secondaryLabel),
    textTertiary: Color = Color(UIColor.tertiaryLabel),
    textDisabled: Color = Color(UIColor.quaternaryLabel),
    border: Color = Color(UIColor.separator),
    borderLight: Color = Color(UIColor.separator).opacity(0.5),
    separator: Color = Color(UIColor.separator)
  ) {
    self.primary = primary
    self.primaryVariant = primaryVariant
    self.onPrimary = onPrimary
    self.secondary = secondary
    self.secondaryVariant = secondaryVariant
    self.onSecondary = onSecondary
    self.surface = surface
    self.onSurface = onSurface
    self.background = background
    self.onBackground = onBackground
    self.success = success
    self.warning = warning
    self.error = error
    self.info = info
    self.textPrimary = textPrimary
    self.textSecondary = textSecondary
    self.textTertiary = textTertiary
    self.textDisabled = textDisabled
    self.border = border
    self.borderLight = borderLight
    self.separator = separator
  }
  
  public static let `default` = ColorScheme()
}

// MARK: - Typography

/// 타이포그래피 시스템
public struct Typography {
  public let largeTitle: Font
  public let title1: Font
  public let title2: Font
  public let title3: Font
  public let headline: Font
  public let body: Font
  public let callout: Font
  public let subheadline: Font
  public let footnote: Font
  public let caption1: Font
  public let caption2: Font
  
  public init(
    largeTitle: Font = .largeTitle,
    title1: Font = .title,
    title2: Font = .title2,
    title3: Font = .title3,
    headline: Font = .headline,
    body: Font = .body,
    callout: Font = .callout,
    subheadline: Font = .subheadline,
    footnote: Font = .footnote,
    caption1: Font = .caption,
    caption2: Font = .caption2
  ) {
    self.largeTitle = largeTitle
    self.title1 = title1
    self.title2 = title2
    self.title3 = title3
    self.headline = headline
    self.body = body
    self.callout = callout
    self.subheadline = subheadline
    self.footnote = footnote
    self.caption1 = caption1
    self.caption2 = caption2
  }
  
  public static let `default` = Typography()
}

// MARK: - Spacing

/// 공간 체계
public struct Spacing {
  public let xs: CGFloat      // 4
  public let sm: CGFloat      // 8
  public let md: CGFloat      // 16
  public let lg: CGFloat      // 24
  public let xl: CGFloat      // 32
  public let xxl: CGFloat     // 48
  
  public init(
    xs: CGFloat = 4,
    sm: CGFloat = 8,
    md: CGFloat = 16,
    lg: CGFloat = 24,
    xl: CGFloat = 32,
    xxl: CGFloat = 48
  ) {
    self.xs = xs
    self.sm = sm
    self.md = md
    self.lg = lg
    self.xl = xl
    self.xxl = xxl
  }
  
  public static let `default` = Spacing()
}

// MARK: - Corner Radius

/// 모서리 둥글기 체계
public struct CornerRadius {
  public let xs: CGFloat      // 4
  public let sm: CGFloat      // 8
  public let md: CGFloat      // 12
  public let lg: CGFloat      // 16
  public let xl: CGFloat      // 20
  public let full: CGFloat    // 9999
  
  public init(
    xs: CGFloat = 4,
    sm: CGFloat = 8,
    md: CGFloat = 12,
    lg: CGFloat = 16,
    xl: CGFloat = 20,
    full: CGFloat = 9999
  ) {
    self.xs = xs
    self.sm = sm
    self.md = md
    self.lg = lg
    self.xl = xl
    self.full = full
  }
  
  public static let `default` = CornerRadius()
}

// MARK: - Shadows

/// 그림자 체계
public struct Shadows {
  public let small: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)
  public let medium: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)
  public let large: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat)
  
  public init(
    small: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (Color.black.opacity(0.1), 2, 0, 1),
    medium: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (Color.black.opacity(0.15), 4, 0, 2),
    large: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) = (Color.black.opacity(0.2), 8, 0, 4)
  ) {
    self.small = small
    self.medium = medium
    self.large = large
  }
  
  public static let `default` = Shadows()
}

// MARK: - Theme Environment

/// SwiftUI Environment를 통한 테마 접근
struct ThemeKey: EnvironmentKey {
  static let defaultValue = AppTheme.default
}

public extension EnvironmentValues {
  var theme: AppTheme {
    get { self[ThemeKey.self] }
    set { self[ThemeKey.self] = newValue }
  }
}

// MARK: - Theme Modifier

/// 테마를 적용하는 ViewModifier
public struct ThemeModifier: ViewModifier {
  let theme: AppTheme
  
  public func body(content: Content) -> some View {
    content
      .environment(\.theme, theme)
  }
}

public extension View {
  func theme(_ theme: AppTheme) -> some View {
    modifier(ThemeModifier(theme: theme))
  }
}