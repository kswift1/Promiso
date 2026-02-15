import Foundation

// MARK: - Localized Strings

/// 앱에서 사용하는 모든 문자열을 관리하는 구조체
public enum LocalizedStrings {

  public static let bundle = Bundle.module

  // MARK: - Common
  public enum Common {
    public static let ok = String(localized: "common.ok", bundle: LocalizedStrings.bundle)
    public static let cancel = String(localized: "common.cancel", bundle: LocalizedStrings.bundle)
    public static let save = String(localized: "common.save", bundle: LocalizedStrings.bundle)
    public static let delete = String(localized: "common.delete", bundle: LocalizedStrings.bundle)
    public static let edit = String(localized: "common.edit", bundle: LocalizedStrings.bundle)
    public static let done = String(localized: "common.done", bundle: LocalizedStrings.bundle)
    public static let next = String(localized: "common.next", bundle: LocalizedStrings.bundle)
    public static let back = String(localized: "common.back", bundle: LocalizedStrings.bundle)
    public static let confirm = String(localized: "common.confirm", bundle: LocalizedStrings.bundle)
    public static let retry = String(localized: "common.retry", bundle: LocalizedStrings.bundle)
    public static let loading = String(localized: "common.loading", bundle: LocalizedStrings.bundle)
    public static let error = String(localized: "common.error", bundle: LocalizedStrings.bundle)
    public static let success = String(localized: "common.success", bundle: LocalizedStrings.bundle)
    public static let warning = String(localized: "common.warning", bundle: LocalizedStrings.bundle)
    public static let info = String(localized: "common.info", bundle: LocalizedStrings.bundle)
  }

  // MARK: - Authentication
  public enum Auth {
    public static let login = String(localized: "auth.login", bundle: LocalizedStrings.bundle)
    public static let logout = String(localized: "auth.logout", bundle: LocalizedStrings.bundle)
    public static let signup = String(localized: "auth.signup", bundle: LocalizedStrings.bundle)
    public static let email = String(localized: "auth.email", bundle: LocalizedStrings.bundle)
    public static let password = String(localized: "auth.password", bundle: LocalizedStrings.bundle)
    public static let confirmPassword = String(localized: "auth.confirmPassword", bundle: LocalizedStrings.bundle)
    public static let name = String(localized: "auth.name", bundle: LocalizedStrings.bundle)
    public static let phoneNumber = String(localized: "auth.phoneNumber", bundle: LocalizedStrings.bundle)
    public static let forgotPassword = String(localized: "auth.forgotPassword", bundle: LocalizedStrings.bundle)

    // Error Messages
    public static let invalidEmail = String(localized: "auth.error.invalidEmail", bundle: LocalizedStrings.bundle)
    public static let invalidPassword = String(localized: "auth.error.invalidPassword", bundle: LocalizedStrings.bundle)
    public static let passwordMismatch = String(localized: "auth.error.passwordMismatch", bundle: LocalizedStrings.bundle)
    public static let loginFailed = String(localized: "auth.error.loginFailed", bundle: LocalizedStrings.bundle)
    public static let signupFailed = String(localized: "auth.error.signupFailed", bundle: LocalizedStrings.bundle)

    // Success Messages
    public static let loginSuccess = String(localized: "auth.success.login", bundle: LocalizedStrings.bundle)
    public static let signupSuccess = String(localized: "auth.success.signup", bundle: LocalizedStrings.bundle)
    public static let logoutSuccess = String(localized: "auth.success.logout", bundle: LocalizedStrings.bundle)
  }

  // MARK: - Promises
  public enum Promise {
    public static let promise = String(localized: "promise.promise", bundle: LocalizedStrings.bundle)
    public static let promises = String(localized: "promise.promises", bundle: LocalizedStrings.bundle)
    public static let createPromise = String(localized: "promise.create", bundle: LocalizedStrings.bundle)
    public static let editPromise = String(localized: "promise.edit", bundle: LocalizedStrings.bundle)
    public static let deletePromise = String(localized: "promise.delete", bundle: LocalizedStrings.bundle)
    public static let joinPromise = String(localized: "promise.join", bundle: LocalizedStrings.bundle)
    public static let leavePromise = String(localized: "promise.leave", bundle: LocalizedStrings.bundle)
    public static let completePromise = String(localized: "promise.complete", bundle: LocalizedStrings.bundle)
    public static let cancelPromise = String(localized: "promise.cancel", bundle: LocalizedStrings.bundle)

    public static let title = String(localized: "promise.title", bundle: LocalizedStrings.bundle)
    public static let description = String(localized: "promise.description", bundle: LocalizedStrings.bundle)
    public static let location = String(localized: "promise.location", bundle: LocalizedStrings.bundle)
    public static let dateTime = String(localized: "promise.dateTime", bundle: LocalizedStrings.bundle)
    public static let participants = String(localized: "promise.participants", bundle: LocalizedStrings.bundle)

    // Status
    public static let scheduled = String(localized: "promise.status.scheduled", bundle: LocalizedStrings.bundle)
    public static let ongoing = String(localized: "promise.status.ongoing", bundle: LocalizedStrings.bundle)
    public static let completed = String(localized: "promise.status.completed", bundle: LocalizedStrings.bundle)
    public static let missed = String(localized: "promise.status.missed", bundle: LocalizedStrings.bundle)
    public static let cancelled = String(localized: "promise.status.cancelled", bundle: LocalizedStrings.bundle)

    // Priority
    public static let priorityLow = String(localized: "promise.priority.low", bundle: LocalizedStrings.bundle)
    public static let priorityNormal = String(localized: "promise.priority.normal", bundle: LocalizedStrings.bundle)
    public static let priorityHigh = String(localized: "promise.priority.high", bundle: LocalizedStrings.bundle)
    public static let priorityUrgent = String(localized: "promise.priority.urgent", bundle: LocalizedStrings.bundle)

    // Messages
    public static let noPromises = String(localized: "promise.empty.title", bundle: LocalizedStrings.bundle)
    public static let noPromisesSubtitle = String(localized: "promise.empty.subtitle", bundle: LocalizedStrings.bundle)
    public static let createFirstPromise = String(localized: "promise.empty.action", bundle: LocalizedStrings.bundle)

    // Success Messages
    public static let createSuccess = String(localized: "promise.success.create", bundle: LocalizedStrings.bundle)
    public static let updateSuccess = String(localized: "promise.success.update", bundle: LocalizedStrings.bundle)
    public static let deleteSuccess = String(localized: "promise.success.delete", bundle: LocalizedStrings.bundle)
    public static let joinSuccess = String(localized: "promise.success.join", bundle: LocalizedStrings.bundle)
    public static let leaveSuccess = String(localized: "promise.success.leave", bundle: LocalizedStrings.bundle)
    public static let completeSuccess = String(localized: "promise.success.complete", bundle: LocalizedStrings.bundle)
  }

  // MARK: - Groups
  public enum Group {
    public static let group = String(localized: "group.group", bundle: LocalizedStrings.bundle)
    public static let groups = String(localized: "group.groups", bundle: LocalizedStrings.bundle)
    public static let createGroup = String(localized: "group.create", bundle: LocalizedStrings.bundle)
    public static let editGroup = String(localized: "group.edit", bundle: LocalizedStrings.bundle)
    public static let deleteGroup = String(localized: "group.delete", bundle: LocalizedStrings.bundle)
    public static let joinGroup = String(localized: "group.join", bundle: LocalizedStrings.bundle)
    public static let leaveGroup = String(localized: "group.leave", bundle: LocalizedStrings.bundle)

    public static let groupName = String(localized: "group.name", bundle: LocalizedStrings.bundle)
    public static let groupDescription = String(localized: "group.description", bundle: LocalizedStrings.bundle)
    public static let members = String(localized: "group.members", bundle: LocalizedStrings.bundle)
    public static let inviteCode = String(localized: "group.inviteCode", bundle: LocalizedStrings.bundle)
    public static let inviteMembers = String(localized: "group.inviteMembers", bundle: LocalizedStrings.bundle)

    // Roles
    public static let owner = String(localized: "group.role.owner", bundle: LocalizedStrings.bundle)
    public static let admin = String(localized: "group.role.admin", bundle: LocalizedStrings.bundle)
    public static let moderator = String(localized: "group.role.moderator", bundle: LocalizedStrings.bundle)
    public static let member = String(localized: "group.role.member", bundle: LocalizedStrings.bundle)

    // Messages
    public static let noGroups = String(localized: "group.empty.title", bundle: LocalizedStrings.bundle)
    public static let noGroupsSubtitle = String(localized: "group.empty.subtitle", bundle: LocalizedStrings.bundle)
    public static let createFirstGroup = String(localized: "group.empty.action", bundle: LocalizedStrings.bundle)

    // Success Messages
    public static let createSuccess = String(localized: "group.success.create", bundle: LocalizedStrings.bundle)
    public static let joinSuccess = String(localized: "group.success.join", bundle: LocalizedStrings.bundle)
    public static let leaveSuccess = String(localized: "group.success.leave", bundle: LocalizedStrings.bundle)
  }

  // MARK: - Settings
  public enum Settings {
    public static let settings = String(localized: "settings.settings", bundle: LocalizedStrings.bundle)
    public static let profile = String(localized: "settings.profile", bundle: LocalizedStrings.bundle)
    public static let notifications = String(localized: "settings.notifications", bundle: LocalizedStrings.bundle)
    public static let privacy = String(localized: "settings.privacy", bundle: LocalizedStrings.bundle)
    public static let about = String(localized: "settings.about", bundle: LocalizedStrings.bundle)
    public static let help = String(localized: "settings.help", bundle: LocalizedStrings.bundle)
    public static let contactUs = String(localized: "settings.contact", bundle: LocalizedStrings.bundle)

    // Theme
    public static let theme = String(localized: "settings.theme", bundle: LocalizedStrings.bundle)
    public static let lightMode = String(localized: "settings.theme.light", bundle: LocalizedStrings.bundle)
    public static let darkMode = String(localized: "settings.theme.dark", bundle: LocalizedStrings.bundle)
    public static let systemMode = String(localized: "settings.theme.system", bundle: LocalizedStrings.bundle)

    // Language
    public static let language = String(localized: "settings.language", bundle: LocalizedStrings.bundle)

    // Notifications
    public static let pushNotifications = String(localized: "settings.notifications.push", bundle: LocalizedStrings.bundle)
    public static let emailNotifications = String(localized: "settings.notifications.email", bundle: LocalizedStrings.bundle)

    // Success Messages
    public static let saveSuccess = String(localized: "settings.success.save", bundle: LocalizedStrings.bundle)
    public static let updateSuccess = String(localized: "settings.success.update", bundle: LocalizedStrings.bundle)
  }

  // MARK: - Errors
  public enum Error {
    public static let networkError = String(localized: "error.network", bundle: LocalizedStrings.bundle)
    public static let unknownError = String(localized: "error.unknown", bundle: LocalizedStrings.bundle)
    public static let serverError = String(localized: "error.server", bundle: LocalizedStrings.bundle)
    public static let timeoutError = String(localized: "error.timeout", bundle: LocalizedStrings.bundle)
    public static let validationError = String(localized: "error.validation", bundle: LocalizedStrings.bundle)
    public static let permissionError = String(localized: "error.permission", bundle: LocalizedStrings.bundle)
    public static let notFoundError = String(localized: "error.notFound", bundle: LocalizedStrings.bundle)
  }

  // MARK: - Tab Bar
  public enum TabBar {
    public static let home = String(localized: "tab.home", bundle: LocalizedStrings.bundle)
    public static let promise = String(localized: "tab.promise", bundle: LocalizedStrings.bundle)
    public static let calendar = String(localized: "tab.calendar", bundle: LocalizedStrings.bundle)
    public static let group = String(localized: "tab.group", bundle: LocalizedStrings.bundle)
  }
}

// MARK: - String Extension for Localization

public extension String {
  /// 현재 문자열을 키로 사용하여 지역화된 문자열을 반환
  var localized: String {
    return String(localized: String.LocalizationValue(self), bundle: LocalizedStrings.bundle)
  }

  /// 현재 문자열을 키로 사용하여 지역화된 문자열을 반환 (인자 포함)
  func localized(with arguments: CVarArg...) -> String {
    return String(format: String(localized: String.LocalizationValue(self), bundle: LocalizedStrings.bundle), arguments: arguments)
  }
}

// MARK: - Localization Helpers

public enum LocalizationHelper {
  /// 현재 앱의 언어 설정을 반환
  public static var currentLanguage: String {
    return Locale.current.identifier
  }

  /// 지원하는 언어 목록
  public static let supportedLanguages = ["ko", "en"]

  /// 특정 언어로 지역화된 문자열을 가져옴
  public static func localizedString(for key: String, language: String) -> String {
    guard let path = LocalizedStrings.bundle.path(forResource: language, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
      return String(localized: String.LocalizationValue(key), bundle: LocalizedStrings.bundle)
    }
    return NSLocalizedString(key, bundle: bundle, comment: "")
  }

  /// 복수형 처리를 위한 헬퍼
  public static func pluralizedString(for count: Int, singular: String, plural: String) -> String {
    return count == 1 ? singular : plural
  }

  /// 숫자와 함께 복수형 문자열 생성
  public static func countString(count: Int, singular: String, plural: String) -> String {
    let pluralized = pluralizedString(for: count, singular: singular, plural: plural)
    return "\(count) \(pluralized)"
  }
}
