import Foundation

// MARK: - App Constants

/// 앱 전반에서 사용되는 상수들
public enum AppConstants {
  
  // MARK: - App Info
  public enum App {
    public static let name = "Promiso"
    public static let displayName = "Promiso - 약속을 지키는 습관"
    public static let bundleId = "com.promiso.app"
    public static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    public static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    public static let appStoreURL = URL(string: "https://apps.apple.com/app/promiso/id123456789")!
    public static let privacyPolicyURL = URL(string: "https://promiso.com/privacy")!
    public static let termsOfServiceURL = URL(string: "https://promiso.com/terms")!
    public static let supportURL = URL(string: "https://promiso.com/support")!
  }
  
  // MARK: - API Configuration
  public enum API {
    public static let baseURL = URL(string: "https://api.promiso.com")!
    public static let version = "v1"
    public static let timeout: TimeInterval = 30
    public static let retryCount = 3
    
    // API Endpoints
    public enum Endpoints {
      public static let auth = "/auth"
      public static let users = "/users"
      public static let groups = "/groups"
      public static let promises = "/promises"
      public static let notifications = "/notifications"
      public static let analytics = "/analytics"
    }
    
    // API Keys (실제로는 환경변수나 키체인에서 로드)
    public enum Keys {
      public static let apiKey = "your-api-key"
      public static let clientId = "your-client-id"
      public static let clientSecret = "your-client-secret"
    }
  }
  
  // MARK: - UI Constants
  public enum UI {
    // Spacing
    public static let spacing: CGFloat = 16
    public static let smallSpacing: CGFloat = 8
    public static let largeSpacing: CGFloat = 24
    public static let extraLargeSpacing: CGFloat = 32
    
    // Corner Radius
    public static let cornerRadius: CGFloat = 12
    public static let smallCornerRadius: CGFloat = 8
    public static let largeCornerRadius: CGFloat = 16
    public static let buttonCornerRadius: CGFloat = 8
    
    // Animation Duration
    public static let animationDuration: Double = 0.3
    public static let fastAnimationDuration: Double = 0.2
    public static let slowAnimationDuration: Double = 0.5
    
    // Shadow
    public static let shadowRadius: CGFloat = 4
    public static let shadowOpacity: Float = 0.1
    public static let shadowOffset = CGSize(width: 0, height: 2)
    
    // Safe Margins
    public static let safeMargin: CGFloat = 16
    public static let minimumTouchSize: CGFloat = 44
  }
  
  // MARK: - User Defaults Keys
  public enum UserDefaults {
    public static let isFirstLaunch = "app.isFirstLaunch"
    public static let appVersion = "app.version"
    public static let userId = "user.id"
    public static let userEmail = "user.email"
    public static let accessToken = "auth.accessToken"
    public static let refreshToken = "auth.refreshToken"
    public static let notificationEnabled = "settings.notificationEnabled"
    public static let themeMode = "settings.themeMode"
    public static let language = "settings.language"
    public static let lastSyncDate = "sync.lastDate"
  }
  
  // MARK: - Keychain Keys
  public enum Keychain {
    public static let accessToken = "auth.accessToken"
    public static let refreshToken = "auth.refreshToken"
    public static let userCredentials = "user.credentials"
    public static let deviceToken = "device.token"
    public static let encryptionKey = "encryption.key"
    public static let biometricCredentials = "biometric.credentials"
  }
  
  // MARK: - Notification Names
  public enum Notifications {
    public static let userDidLogin = NSNotification.Name("UserDidLogin")
    public static let userDidLogout = NSNotification.Name("UserDidLogout")
    public static let userProfileDidUpdate = NSNotification.Name("UserProfileDidUpdate")
    public static let promiseDidCreate = NSNotification.Name("PromiseDidCreate")
    public static let promiseDidUpdate = NSNotification.Name("PromiseDidUpdate")
    public static let promiseDidComplete = NSNotification.Name("PromiseDidComplete")
    public static let groupDidJoin = NSNotification.Name("GroupDidJoin")
    public static let groupDidLeave = NSNotification.Name("GroupDidLeave")
    public static let networkStatusDidChange = NSNotification.Name("NetworkStatusDidChange")
    public static let themeDidChange = NSNotification.Name("ThemeDidChange")
  }
  
  // MARK: - Analytics Events
  public enum Analytics {
    // User Events
    public static let userRegistered = "user_registered"
    public static let userLoggedIn = "user_logged_in"
    public static let userLoggedOut = "user_logged_out"
    public static let userProfileUpdated = "user_profile_updated"
    
    // Promise Events
    public static let promiseCreated = "promise_created"
    public static let promiseJoined = "promise_joined"
    public static let promiseCompleted = "promise_completed"
    public static let promiseMissed = "promise_missed"
    public static let promiseCancelled = "promise_cancelled"
    
    // Group Events
    public static let groupCreated = "group_created"
    public static let groupJoined = "group_joined"
    public static let groupLeft = "group_left"
    public static let groupInviteSent = "group_invite_sent"
    
    // Screen Events
    public static let screenViewed = "screen_viewed"
    public static let buttonTapped = "button_tapped"
    public static let featureUsed = "feature_used"
    
    // Error Events
    public static let errorOccurred = "error_occurred"
    public static let apiErrorOccurred = "api_error_occurred"
  }
  
  // MARK: - Feature Flags
  public enum FeatureFlags {
    public static let biometricAuthEnabled = true
    public static let locationTrackingEnabled = true
    public static let pushNotificationsEnabled = true
    public static let analyticsEnabled = true
    public static let betaFeaturesEnabled = false
    public static let debugModeEnabled = false
  }
  
  // MARK: - Limits
  public enum Limits {
    public static let maxGroupNameLength = 50
    public static let maxPromiseTitleLength = 100
    public static let maxPromiseDescriptionLength = 500
    public static let maxGroupDescriptionLength = 200
    public static let maxUsernameLength = 30
    public static let maxGroupMembers = 50
    public static let maxPromiseParticipants = 20
    public static let maxFileSize = 10 * 1024 * 1024 // 10MB
    public static let maxImageSize = 5 * 1024 * 1024 // 5MB
    public static let minPasswordLength = 8
    public static let maxPasswordLength = 128
  }
  
  // MARK: - Time Intervals
  public enum TimeIntervals {
    public static let networkTimeout: TimeInterval = 30
    public static let refreshTokenExpiry: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    public static let accessTokenExpiry: TimeInterval = 60 * 60 // 1 hour
    public static let locationUpdateInterval: TimeInterval = 30 // 30 seconds
    public static let analyticsFlushInterval: TimeInterval = 5 * 60 // 5 minutes
    public static let cacheExpiry: TimeInterval = 24 * 60 * 60 // 24 hours
    public static let invitationExpiry: TimeInterval = 7 * 24 * 60 * 60 // 7 days
  }
  
  // MARK: - Validation Patterns
  public enum Validation {
    public static let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
    public static let phonePattern = "^01[0-9]-?[0-9]{3,4}-?[0-9]{4}$"
    public static let usernamePattern = "^[a-zA-Z0-9_]{3,30}$"
    public static let passwordPattern = "^(?=.*[A-Za-z])(?=.*\\d)[A-Za-z\\d@$!%*#?&]{8,}$"
  }
  
  // MARK: - Error Messages
  public enum ErrorMessages {
    public static let networkError = "네트워크 연결을 확인해주세요"
    public static let unknownError = "알 수 없는 오류가 발생했습니다"
    public static let validationError = "입력 정보를 확인해주세요"
    public static let authenticationError = "로그인이 필요합니다"
    public static let permissionError = "권한이 없습니다"
    public static let notFoundError = "요청한 정보를 찾을 수 없습니다"
    public static let serverError = "서버 오류가 발생했습니다"
    public static let timeoutError = "요청 시간이 초과되었습니다"
  }
  
  // MARK: - Success Messages
  public enum SuccessMessages {
    public static let loginSuccess = "로그인되었습니다"
    public static let logoutSuccess = "로그아웃되었습니다"
    public static let signupSuccess = "회원가입이 완료되었습니다"
    public static let promiseCreated = "약속이 생성되었습니다"
    public static let promiseJoined = "약속에 참가했습니다"
    public static let promiseCompleted = "약속을 완료했습니다"
    public static let groupCreated = "그룹이 생성되었습니다"
    public static let groupJoined = "그룹에 가입했습니다"
    public static let profileUpdated = "프로필이 업데이트되었습니다"
    public static let settingsSaved = "설정이 저장되었습니다"
  }
}

// MARK: - Environment Configuration

/// 환경별 설정
public enum Environment {
  case development
  case staging
  case production
  
  public static var current: Environment {
    #if DEBUG
    return .development
    #elseif STAGING
    return .staging
    #else
    return .production
    #endif
  }
  
  public var baseURL: URL {
    switch self {
    case .development:
      return URL(string: "https://dev-api.promiso.com")!
    case .staging:
      return URL(string: "https://staging-api.promiso.com")!
    case .production:
      return URL(string: "https://api.promiso.com")!
    }
  }
  
  public var isDebug: Bool {
    switch self {
    case .development, .staging:
      return true
    case .production:
      return false
    }
  }
  
  public var analyticsEnabled: Bool {
    switch self {
    case .development:
      return false
    case .staging, .production:
      return true
    }
  }

  /// Firebase Functions env 파라미터
  public var firebaseEnv: String {
    switch self {
    case .development, .staging:
      return "stage"
    case .production:
      return "prod"
    }
  }

  /// Firebase Storage 경로 prefix
  public var storagePrefix: String {
    switch self {
    case .development, .staging:
      return "stage"
    case .production:
      return "prod"
    }
  }
}

// MARK: - Build Configuration

/// 빌드별 설정
public enum BuildConfiguration {
  public static let isDebug: Bool = {
    #if DEBUG
    return true
    #else
    return false
    #endif
  }()
  
  public static let isSimulator: Bool = {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
  }()
  
  public static let isTestFlight: Bool = {
    guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
      return false
    }
    return appStoreReceiptURL.lastPathComponent == "sandboxReceipt"
  }()
  
  public static let isAppStore: Bool = {
    guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
      return false
    }
    return appStoreReceiptURL.lastPathComponent == "receipt"
  }()
}
