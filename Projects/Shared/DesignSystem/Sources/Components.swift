import SwiftUI
import SharedModels
import CoreUtilities

// MARK: - Primary Button

/// 기본 버튼 컴포넌트
public struct PrimaryButton: View {
  private let title: String
  private let action: () -> Void
  private let isEnabled: Bool
  private let isLoading: Bool
  
  @Environment(\.theme) private var theme
  
  public init(
    _ title: String,
    isEnabled: Bool = true,
    isLoading: Bool = false,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.isEnabled = isEnabled
    self.isLoading = isLoading
    self.action = action
  }
  
  public var body: some View {
    Button(action: action) {
      HStack {
        if isLoading {
          ProgressView()
            .scaleEffect(0.8)
            .foregroundColor(theme.colors.onPrimary)
        }
        
        Text(title)
          .font(theme.typography.headline)
          .foregroundColor(theme.colors.onPrimary)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 48)
      .background(
        RoundedRectangle(cornerRadius: theme.cornerRadius.md)
          .fill(isEnabled ? theme.colors.primary : theme.colors.textDisabled)
      )
      .shadow(
        color: theme.shadows.small.color,
        radius: theme.shadows.small.radius,
        x: theme.shadows.small.x,
        y: theme.shadows.small.y
      )
    }
    .disabled(!isEnabled || isLoading)
    .animation(.easeInOut(duration: 0.2), value: isLoading)
  }
}

// MARK: - Secondary Button

/// 보조 버튼 컴포넌트
public struct SecondaryButton: View {
  private let title: String
  private let action: () -> Void
  private let isEnabled: Bool
  
  @Environment(\.theme) private var theme
  
  public init(
    _ title: String,
    isEnabled: Bool = true,
    action: @escaping () -> Void
  ) {
    self.title = title
    self.isEnabled = isEnabled
    self.action = action
  }
  
  public var body: some View {
    Button(action: action) {
      Text(title)
        .font(theme.typography.headline)
        .foregroundColor(theme.colors.primary)
        .frame(maxWidth: .infinity)
        .frame(height: 48)
        .background(
          RoundedRectangle(cornerRadius: theme.cornerRadius.md)
            .stroke(theme.colors.primary, lineWidth: 1)
        )
    }
    .disabled(!isEnabled)
    .opacity(isEnabled ? 1.0 : 0.6)
  }
}

// MARK: - Input Field

/// 입력 필드 컴포넌트
public struct InputField: View {
  private let title: String
  private let placeholder: String
  @Binding private var text: String
  private let isSecure: Bool
  private let errorMessage: String?
  
  @Environment(\.theme) private var theme
  @FocusState private var isFocused: Bool
  
  public init(
    title: String,
    placeholder: String = "",
    text: Binding<String>,
    isSecure: Bool = false,
    errorMessage: String? = nil
  ) {
    self.title = title
    self.placeholder = placeholder
    self._text = text
    self.isSecure = isSecure
    self.errorMessage = errorMessage
  }
  
  public var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      Text(title)
        .font(theme.typography.subheadline)
        .foregroundColor(theme.colors.textSecondary)
      
      Group {
        if isSecure {
          SecureField(placeholder, text: $text)
        } else {
          TextField(placeholder, text: $text)
        }
      }
      .font(theme.typography.body)
      .padding(.horizontal, theme.spacing.md)
      .frame(height: 48)
      .background(
        RoundedRectangle(cornerRadius: theme.cornerRadius.md)
          .stroke(
            errorMessage != nil ? theme.colors.error :
            isFocused ? theme.colors.primary : theme.colors.border,
            lineWidth: 1
          )
      )
      .focused($isFocused)
      
      if let errorMessage = errorMessage {
        Text(errorMessage)
          .font(theme.typography.caption1)
          .foregroundColor(theme.colors.error)
      }
    }
  }
}

// MARK: - Card

/// 카드 컴포넌트
public struct Card<Content: View>: View {
  private let content: () -> Content
  private let padding: CGFloat
  
  @Environment(\.theme) private var theme
  
  public init(
    padding: CGFloat? = nil,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.content = content
    self.padding = padding ?? 0
  }
  
  public var body: some View {
    content()
      .padding(padding)
      .background(
        RoundedRectangle(cornerRadius: theme.cornerRadius.md)
          .fill(theme.colors.surface)
          .shadow(
            color: theme.shadows.small.color,
            radius: theme.shadows.small.radius,
            x: theme.shadows.small.x,
            y: theme.shadows.small.y
          )
      )
  }
}

// MARK: - Loading View

/// 로딩 뷰 컴포넌트
public struct LoadingView: View {
  private let message: String?
  
  @Environment(\.theme) private var theme
  
  public init(message: String? = nil) {
    self.message = message
  }
  
  public var body: some View {
    VStack(spacing: theme.spacing.md) {
      ProgressView()
        .scaleEffect(1.2)
      
      if let message = message {
        Text(message)
          .font(theme.typography.subheadline)
          .foregroundColor(theme.colors.textSecondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(theme.colors.background)
  }
}

// MARK: - Empty State View

/// 빈 상태 뷰 컴포넌트
public struct EmptyStateView: View {
  private let image: String
  private let title: String
  private let subtitle: String?
  private let actionTitle: String?
  private let action: (() -> Void)?
  
  @Environment(\.theme) private var theme
  
  public init(
    image: String,
    title: String,
    subtitle: String? = nil,
    actionTitle: String? = nil,
    action: (() -> Void)? = nil
  ) {
    self.image = image
    self.title = title
    self.subtitle = subtitle
    self.actionTitle = actionTitle
    self.action = action
  }
  
  public var body: some View {
    VStack(spacing: theme.spacing.lg) {
      Image(systemName: image)
        .font(.system(size: 60))
        .foregroundColor(theme.colors.textTertiary)
      
      VStack(spacing: theme.spacing.sm) {
        Text(title)
          .font(theme.typography.title3)
          .foregroundColor(theme.colors.textPrimary)
          .multilineTextAlignment(.center)
        
        if let subtitle = subtitle {
          Text(subtitle)
            .font(theme.typography.body)
            .foregroundColor(theme.colors.textSecondary)
            .multilineTextAlignment(.center)
        }
      }
      
      if let actionTitle = actionTitle, let action = action {
        PrimaryButton(actionTitle, action: action)
          .padding(.horizontal, theme.spacing.xl)
      }
    }
    .padding(theme.spacing.xl)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(theme.colors.background)
  }
}

// MARK: - Alert Toast

/// 토스트 알림 컴포넌트
public struct AlertToast: View {
  private let message: String
  private let type: AlertType
  
  @Environment(\.theme) private var theme
  
  public enum AlertType {
    case success
    case warning
    case error
    case info
    
    var color: Color {
      switch self {
      case .success: return .green
      case .warning: return .orange
      case .error: return .red
      case .info: return .blue
      }
    }
    
    var icon: String {
      switch self {
      case .success: return "checkmark.circle.fill"
      case .warning: return "exclamationmark.triangle.fill"
      case .error: return "xmark.circle.fill"
      case .info: return "info.circle.fill"
      }
    }
  }
  
  public init(message: String, type: AlertType) {
    self.message = message
    self.type = type
  }
  
  public var body: some View {
    HStack(spacing: theme.spacing.sm) {
      Image(systemName: type.icon)
        .foregroundColor(type.color)
      
      Text(message)
        .font(theme.typography.body)
        .foregroundColor(theme.colors.textPrimary)
      
      Spacer()
    }
    .padding(theme.spacing.md)
    .background(
      RoundedRectangle(cornerRadius: theme.cornerRadius.md)
        .fill(theme.colors.surface)
        .shadow(
          color: theme.shadows.medium.color,
          radius: theme.shadows.medium.radius,
          x: theme.shadows.medium.x,
          y: theme.shadows.medium.y
        )
    )
  }
}

// MARK: - Promise Status Badge

/// 약속 상태 배지 컴포넌트
public struct PromiseStatusBadge: View {
  private let status: PromiseStatus
  
  @Environment(\.theme) private var theme
  
  public init(status: PromiseStatus) {
    self.status = status
  }
  
  private var statusColor: Color {
    switch status {
    case .scheduled: return theme.colors.info
    case .ongoing: return theme.colors.warning
    case .completed: return theme.colors.success
    case .missed: return theme.colors.error
    case .cancelled: return theme.colors.textTertiary
    }
  }
  
  public var body: some View {
    HStack(spacing: theme.spacing.xs) {
      Text(status.emoji)
        .font(theme.typography.caption1)
      
      Text(status.displayName)
        .font(theme.typography.caption1)
        .fontWeight(.medium)
    }
    .padding(.horizontal, theme.spacing.sm)
    .padding(.vertical, theme.spacing.xs)
    .background(
      Capsule()
        .fill(statusColor.opacity(0.2))
    )
    .foregroundColor(statusColor)
  }
}

// MARK: - Priority Badge

/// 우선순위 배지 컴포넌트
public struct PriorityBadge: View {
  private let priority: PromisePriority
  
  @Environment(\.theme) private var theme
  
  public init(priority: PromisePriority) {
    self.priority = priority
  }
  
  public var body: some View {
    HStack(spacing: theme.spacing.xs) {
      Text(priority.emoji)
        .font(theme.typography.caption2)
      
      Text(priority.displayName)
        .font(theme.typography.caption2)
        .fontWeight(.medium)
    }
    .padding(.horizontal, theme.spacing.xs)
    .padding(.vertical, 2)
    .background(
      Capsule()
        .fill(theme.colors.textTertiary.opacity(0.2))
    )
    .foregroundColor(theme.colors.textSecondary)
  }
}
