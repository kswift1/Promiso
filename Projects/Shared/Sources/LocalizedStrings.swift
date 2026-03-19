import Foundation

// MARK: - Localized Strings

/// 앱에서 사용하는 모든 문자열을 관리하는 구조체
public enum LocalizedStrings {

  /// 현재 활성 번들 (언어 전환 시 변경됨)
  private static var _bundle: Bundle = Bundle.module

  /// 현재 활성 번들
  public static var bundle: Bundle { _bundle }

  /// 선호 언어로 번들 설정
  /// - AppMain.init()에서 호출
  public static func configure() {
    let lang = AppLanguage.resolved.rawValue

    guard let path = Bundle.module.path(forResource: lang, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
      _bundle = Bundle.module  // 시스템 기본
      return
    }
    _bundle = bundle
  }

  // MARK: - Common
  public enum Common {
    public static var ok: String { String(localized: "common.ok", bundle: bundle) }
    public static var cancel: String { String(localized: "common.cancel", bundle: bundle) }
    public static var save: String { String(localized: "common.save", bundle: bundle) }
    public static var delete: String { String(localized: "common.delete", bundle: bundle) }
    public static var edit: String { String(localized: "common.edit", bundle: bundle) }
    public static var done: String { String(localized: "common.done", bundle: bundle) }
    public static var next: String { String(localized: "common.next", bundle: bundle) }
    public static var back: String { String(localized: "common.back", bundle: bundle) }
    public static var confirm: String { String(localized: "common.confirm", bundle: bundle) }
    public static var retry: String { String(localized: "common.retry", bundle: bundle) }
    public static var loading: String { String(localized: "common.loading", bundle: bundle) }
    public static var error: String { String(localized: "common.error", bundle: bundle) }
    public static var success: String { String(localized: "common.success", bundle: bundle) }
    public static var warning: String { String(localized: "common.warning", bundle: bundle) }
    public static var info: String { String(localized: "common.info", bundle: bundle) }
    public static var live: String { String(localized: "common.live", bundle: bundle) }
    public static var modify: String { String(localized: "common.modify", bundle: bundle) }
    public static var change: String { String(localized: "common.change", bundle: bundle) }
    public static var laterAction: String { String(localized: "common.later", bundle: bundle) }
    public static var all: String { String(localized: "common.all", bundle: bundle) }
    public static var add: String { String(localized: "common.add", bundle: bundle) }
    public static var today: String { String(localized: "common.today", bundle: bundle) }
    public static var photo: String { String(localized: "common.photo", bundle: bundle) }
    public static var settings: String { String(localized: "common.settings", bundle: bundle) }
    public static var start: String { String(localized: "common.start", bundle: bundle) }
    public static var endTime: String { String(localized: "common.endTime", bundle: bundle) }
    public static var date: String { String(localized: "common.date", bundle: bundle) }
    public static var time: String { String(localized: "common.time", bundle: bundle) }
    public static var location: String { String(localized: "common.location", bundle: bundle) }
    public static var noLocation: String { String(localized: "common.noLocation", bundle: bundle) }
    public static var reminder: String { String(localized: "common.reminder", bundle: bundle) }
    public static var directions: String { String(localized: "common.directions", bundle: bundle) }
    public static var schedule: String { String(localized: "common.schedule", bundle: bundle) }
    public static var personalEvent: String { String(localized: "common.personalEvent", bundle: bundle) }
    public static var allDay: String { String(localized: "common.allDay", bundle: bundle) }
    public static var untitled: String { String(localized: "common.untitled", bundle: bundle) }
    public static var me: String { String(localized: "common.me", bundle: bundle) }
    public static var expired: String { String(localized: "common.expired", bundle: bundle) }
    public static var seeMore: String { String(localized: "common.seeMore", bundle: bundle) }
    public static var collapse: String { String(localized: "common.collapse", bundle: bundle) }
    public static var deleteAction: String { String(localized: "common.deleteAction", bundle: bundle) }
  }

  // MARK: - Authentication
  public enum Auth {
    public static var login: String { String(localized: "auth.login", bundle: bundle) }
    public static var logout: String { String(localized: "auth.logout", bundle: bundle) }
    public static var signup: String { String(localized: "auth.signup", bundle: bundle) }
    public static var email: String { String(localized: "auth.email", bundle: bundle) }
    public static var password: String { String(localized: "auth.password", bundle: bundle) }
    public static var confirmPassword: String { String(localized: "auth.confirmPassword", bundle: bundle) }
    public static var name: String { String(localized: "auth.name", bundle: bundle) }
    public static var phoneNumber: String { String(localized: "auth.phoneNumber", bundle: bundle) }
    public static var forgotPassword: String { String(localized: "auth.forgotPassword", bundle: bundle) }

    // Error Messages
    public static var invalidEmail: String { String(localized: "auth.error.invalidEmail", bundle: bundle) }
    public static var invalidPassword: String { String(localized: "auth.error.invalidPassword", bundle: bundle) }
    public static var passwordMismatch: String { String(localized: "auth.error.passwordMismatch", bundle: bundle) }
    public static var loginFailed: String { String(localized: "auth.error.loginFailed", bundle: bundle) }
    public static var signupFailed: String { String(localized: "auth.error.signupFailed", bundle: bundle) }

    // Success Messages
    public static var loginSuccess: String { String(localized: "auth.success.login", bundle: bundle) }
    public static var signupSuccess: String { String(localized: "auth.success.signup", bundle: bundle) }
    public static var logoutSuccess: String { String(localized: "auth.success.logout", bundle: bundle) }

    // Login Request
    public static var loginRequestFailed: String { String(localized: "auth.error.loginRequestFailed", bundle: bundle) }

    // Hero Text
    public static var heroSchedulesWord: String { String(localized: "auth.hero.schedulesWord", bundle: bundle) }
    public static var heroMoreSpecial: String { String(localized: "auth.hero.moreSpecial", bundle: bundle) }
    public static var heroPreciousMoments: String { String(localized: "auth.hero.preciousMoments", bundle: bundle) }
    public static var heroWithPromiso: String { String(localized: "auth.hero.withPromiso", bundle: bundle) }

    // Social Login
    public static var continueWith: String { String(localized: "auth.continueWith", bundle: bundle) }
    public static var continueWithApple: String { String(localized: "auth.continueWithApple", bundle: bundle) }
    public static var continueWithGoogle: String { String(localized: "auth.continueWithGoogle", bundle: bundle) }
  }

  // MARK: - Schedules
  public enum Schedule {
    public static var schedule: String { String(localized: "schedule.schedule", bundle: bundle) }
    public static var schedules: String { String(localized: "schedule.schedules", bundle: bundle) }
    public static var createSchedule: String { String(localized: "schedule.create", bundle: bundle) }
    public static var editSchedule: String { String(localized: "schedule.edit", bundle: bundle) }
    public static var deleteSchedule: String { String(localized: "schedule.delete", bundle: bundle) }
    public static var joinSchedule: String { String(localized: "schedule.join", bundle: bundle) }
    public static var leaveSchedule: String { String(localized: "schedule.leave", bundle: bundle) }
    public static var completeSchedule: String { String(localized: "schedule.complete", bundle: bundle) }
    public static var cancelSchedule: String { String(localized: "schedule.cancel", bundle: bundle) }

    public static var title: String { String(localized: "schedule.title", bundle: bundle) }
    public static var description: String { String(localized: "schedule.description", bundle: bundle) }
    public static var location: String { String(localized: "schedule.location", bundle: bundle) }
    public static var dateTime: String { String(localized: "schedule.dateTime", bundle: bundle) }
    public static var participants: String { String(localized: "schedule.participants", bundle: bundle) }

    // Status
    public static var scheduled: String { String(localized: "schedule.status.scheduled", bundle: bundle) }
    public static var ongoing: String { String(localized: "schedule.status.ongoing", bundle: bundle) }
    public static var completed: String { String(localized: "schedule.status.completed", bundle: bundle) }
    public static var missed: String { String(localized: "schedule.status.missed", bundle: bundle) }
    public static var cancelled: String { String(localized: "schedule.status.cancelled", bundle: bundle) }

    // Priority
    public static var priorityLow: String { String(localized: "schedule.priority.low", bundle: bundle) }
    public static var priorityNormal: String { String(localized: "schedule.priority.normal", bundle: bundle) }
    public static var priorityHigh: String { String(localized: "schedule.priority.high", bundle: bundle) }
    public static var priorityUrgent: String { String(localized: "schedule.priority.urgent", bundle: bundle) }

    // Messages
    public static var noSchedules: String { String(localized: "schedule.empty.title", bundle: bundle) }
    public static var noSchedulesSubtitle: String { String(localized: "schedule.empty.subtitle", bundle: bundle) }
    public static var createFirstSchedule: String { String(localized: "schedule.empty.action", bundle: bundle) }

    // Success Messages
    public static var createSuccess: String { String(localized: "schedule.success.create", bundle: bundle) }
    public static var updateSuccess: String { String(localized: "schedule.success.update", bundle: bundle) }
    public static var deleteSuccess: String { String(localized: "schedule.success.delete", bundle: bundle) }
    public static var joinSuccess: String { String(localized: "schedule.success.join", bundle: bundle) }
    public static var leaveSuccess: String { String(localized: "schedule.success.leave", bundle: bundle) }
    public static var completeSuccess: String { String(localized: "schedule.success.complete", bundle: bundle) }
  }

  // MARK: - Groups
  public enum Group {
    public static var group: String { String(localized: "group.group", bundle: bundle) }
    public static var groups: String { String(localized: "group.groups", bundle: bundle) }
    public static var createGroup: String { String(localized: "group.create", bundle: bundle) }
    public static var editGroup: String { String(localized: "group.edit", bundle: bundle) }
    public static var deleteGroup: String { String(localized: "group.delete", bundle: bundle) }
    public static var joinGroup: String { String(localized: "group.join", bundle: bundle) }
    public static var leaveGroup: String { String(localized: "group.leave", bundle: bundle) }

    public static var groupName: String { String(localized: "group.name", bundle: bundle) }
    public static var groupDescription: String { String(localized: "group.description", bundle: bundle) }
    public static var members: String { String(localized: "group.members", bundle: bundle) }
    public static var inviteCode: String { String(localized: "group.inviteCode", bundle: bundle) }
    public static var inviteMembers: String { String(localized: "group.inviteMembers", bundle: bundle) }

    // Roles
    public static var owner: String { String(localized: "group.role.owner", bundle: bundle) }
    public static var admin: String { String(localized: "group.role.admin", bundle: bundle) }
    public static var moderator: String { String(localized: "group.role.moderator", bundle: bundle) }
    public static var member: String { String(localized: "group.role.member", bundle: bundle) }

    // Messages
    public static var noGroups: String { String(localized: "group.empty.title", bundle: bundle) }
    public static var noGroupsSubtitle: String { String(localized: "group.empty.subtitle", bundle: bundle) }
    public static var createFirstGroup: String { String(localized: "group.empty.action", bundle: bundle) }

    // Success Messages
    public static var createSuccess: String { String(localized: "group.success.create", bundle: bundle) }
    public static var joinSuccess: String { String(localized: "group.success.join", bundle: bundle) }
    public static var leaveSuccess: String { String(localized: "group.success.leave", bundle: bundle) }
  }

  // MARK: - Settings
  public enum SettingsStrings {
    public static var settings: String { String(localized: "settings.settings", bundle: bundle) }
    public static var profile: String { String(localized: "settings.profile", bundle: bundle) }
    public static var notifications: String { String(localized: "settings.notifications", bundle: bundle) }
    public static var privacy: String { String(localized: "settings.privacy", bundle: bundle) }
    public static var about: String { String(localized: "settings.about", bundle: bundle) }
    public static var help: String { String(localized: "settings.help", bundle: bundle) }
    public static var contactUs: String { String(localized: "settings.contact", bundle: bundle) }

    // Theme
    public static var theme: String { String(localized: "settings.theme", bundle: bundle) }
    public static var lightMode: String { String(localized: "settings.theme.light", bundle: bundle) }
    public static var darkMode: String { String(localized: "settings.theme.dark", bundle: bundle) }
    public static var systemMode: String { String(localized: "settings.theme.system", bundle: bundle) }

    // Theme Mode Screen
    public static var themeModeNavigationTitle: String { String(localized: "settings.themeMode.navigationTitle", bundle: bundle) }
    public static var themeModeSectionTitle: String { String(localized: "settings.themeMode.sectionTitle", bundle: bundle) }
    public static var themeModeSectionHint: String { String(localized: "settings.themeMode.sectionHint", bundle: bundle) }
    public static var themeModeSystemDescription: String { String(localized: "settings.themeMode.system.description", bundle: bundle) }
    public static var themeModeLightDescription: String { String(localized: "settings.themeMode.light.description", bundle: bundle) }
    public static var themeModeDarkDescription: String { String(localized: "settings.themeMode.dark.description", bundle: bundle) }

    // Language
    public static var language: String { String(localized: "settings.language", bundle: bundle) }
    // Language Settings
    public static var languageSectionTitle: String { String(localized: "settings.language.sectionTitle", bundle: bundle) }
    public static var languageHint: String { String(localized: "settings.language.hint", bundle: bundle) }
    public static var languageRestartTitle: String { String(localized: "settings.language.restartTitle", bundle: bundle) }
    public static var languageRestartMessage: String { String(localized: "settings.language.restartMessage", bundle: bundle) }
    public static var languageRestartAction: String { String(localized: "settings.language.restartAction", bundle: bundle) }

    // Notifications
    public static var pushNotifications: String { String(localized: "settings.notifications.push", bundle: bundle) }
    public static var emailNotifications: String { String(localized: "settings.notifications.email", bundle: bundle) }

    // Success Messages
    public static var saveSuccess: String { String(localized: "settings.success.save", bundle: bundle) }
    public static var updateSuccess: String { String(localized: "settings.success.update", bundle: bundle) }

    // MARK: - Batch 4 Settings Group 1 Localization
    // Main
    public static var title: String { String(localized: "settings.title", bundle: bundle) }
    public static var appSettings: String { String(localized: "settings.appSettings", bundle: bundle) }
    public static var support: String { String(localized: "settings.support", bundle: bundle) }
    public static var info: String { String(localized: "settings.info", bundle: bundle) }
    public static var developer: String { String(localized: "settings.developer", bundle: bundle) }

    // Menu Items
    public static var dateTimeDisplay: String { String(localized: "settings.dateTimeDisplay", bundle: bundle) }
    public static var themeMode: String { String(localized: "settings.themeMode", bundle: bundle) }
    public static var calendarSettings: String { String(localized: "settings.calendarSettings", bundle: bundle) }
    public static var scheduleTabDefaultMode: String { String(localized: "settings.scheduleTabDefaultMode", bundle: bundle) }
    public static var tabSettingsMenu: String { String(localized: "settings.tabSettings", bundle: bundle) }
    public static var termsAndPolicies: String { String(localized: "settings.termsAndPolicies", bundle: bundle) }
    public static var appInfo: String { String(localized: "settings.appInfo", bundle: bundle) }
    public static var developerSettings: String { String(localized: "settings.developerSettings", bundle: bundle) }

    // Profile
    public static var profileEdit: String { String(localized: "settings.profileEdit", bundle: bundle) }
    public static var profileEditCancel: String { String(localized: "settings.profileEditCancel", bundle: bundle) }
    public static var profileEditSave: String { String(localized: "settings.profileEditSave", bundle: bundle) }
    public static var nickname: String { String(localized: "settings.nickname", bundle: bundle) }
    public static var nicknamePlaceholder: String { String(localized: "settings.nicknamePlaceholder", bundle: bundle) }
    public static var nicknameRequired: String { String(localized: "settings.nicknameRequired", bundle: bundle) }
    public static var nicknameTooShort: String { String(localized: "settings.nicknameTooShort", bundle: bundle) }
    public static var nicknameTooLong: String { String(localized: "settings.nicknameTooLong", bundle: bundle) }
    public static var nicknameValidationHint: String { String(localized: "settings.nicknameValidationHint", bundle: bundle) }
    public static var nicknameAvailable: String { String(localized: "settings.nicknameAvailable", bundle: bundle) }
    public static var nicknameUnavailable: String { String(localized: "settings.nicknameUnavailable", bundle: bundle) }
    public static var nicknameCheckFailed: String { String(localized: "settings.nicknameCheckFailed", bundle: bundle) }

    // Account Info
    public static var accountInfo: String { String(localized: "settings.accountInfo", bundle: bundle) }
    public static var email: String { String(localized: "settings.email", bundle: bundle) }
    public static var loginMethod: String { String(localized: "settings.loginMethod", bundle: bundle) }
    public static var joinDate: String { String(localized: "settings.joinDate", bundle: bundle) }
    public static var logout: String { String(localized: "settings.logout", bundle: bundle) }
    public static var logoutConfirm: String { String(localized: "settings.logoutConfirm", bundle: bundle) }
    public static var loggingOut: String { String(localized: "settings.loggingOut", bundle: bundle) }
    public static var deleteAccount: String { String(localized: "settings.deleteAccount", bundle: bundle) }
    public static var deleteAccountTitle: String { String(localized: "settings.deleteAccountTitle", bundle: bundle) }
    public static var deleteAccountConfirm: String { String(localized: "settings.deleteAccountConfirm", bundle: bundle) }
    public static var deleteAccountFailed: String { String(localized: "settings.deleteAccountFailed", bundle: bundle) }

    // Pro Subscription Warning (Account Deletion)
    public static var proSubscriptionWarningTitle: String { String(localized: "settings.proSubscriptionWarningTitle", bundle: bundle) }
    public static var proSubscriptionWarningMessage: String { String(localized: "settings.proSubscriptionWarningMessage", bundle: bundle) }
    public static var manageSubscription: String { String(localized: "settings.manageSubscription", bundle: bundle) }
    public static var proceedDeleteAccount: String { String(localized: "settings.proceedDeleteAccount", bundle: bundle) }

    // Errors
    public static var errorTitle: String { String(localized: "settings.errorTitle", bundle: bundle) }
    public static var logoutFailed: String { String(localized: "settings.logoutFailed", bundle: bundle) }
    public static var userNotFound: String { String(localized: "settings.userNotFound", bundle: bundle) }
    public static var imageLoadFailed: String { String(localized: "settings.imageLoadFailed", bundle: bundle) }
    public static var unknownError: String { String(localized: "settings.unknownError", bundle: bundle) }

    // Date Time Settings
    public static var timeFormatSection: String { String(localized: "settings.timeFormatSection", bundle: bundle) }
    public static var timeFormat12Hour: String { String(localized: "settings.timeFormat12Hour", bundle: bundle) }
    public static var timeFormat12HourExample: String { String(localized: "settings.timeFormat12HourExample", bundle: bundle) }
    public static var timeFormat24Hour: String { String(localized: "settings.timeFormat24Hour", bundle: bundle) }
    public static var timeFormat24HourExample: String { String(localized: "settings.timeFormat24HourExample", bundle: bundle) }
    public static var timeFormatHint: String { String(localized: "settings.timeFormatHint", bundle: bundle) }

    // Calendar Start Day
    public static var calendarStartDaySection: String { String(localized: "settings.calendarStartDaySection", bundle: bundle) }
    public static var calendarStartSunday: String { String(localized: "settings.calendarStartSunday", bundle: bundle) }
    public static var calendarStartMonday: String { String(localized: "settings.calendarStartMonday", bundle: bundle) }
    public static var calendarStartDayHint: String { String(localized: "settings.calendarStartDayHint", bundle: bundle) }

    public static var preview: String { String(localized: "settings.preview", bundle: bundle) }
    public static var previewHint: String { String(localized: "settings.previewHint", bundle: bundle) }
    public static var restartTitle: String { String(localized: "settings.restartTitle", bundle: bundle) }
    public static var restartMessage: String { String(localized: "settings.restartMessage", bundle: bundle) }
    public static var restart: String { String(localized: "settings.restart", bundle: bundle) }

    // Theme Settings
    public static var themeModeSection: String { String(localized: "settings.themeModeSection", bundle: bundle) }
    public static var themeModeHint: String { String(localized: "settings.themeModeHint", bundle: bundle) }
    public static var themeModeSystem: String { String(localized: "settings.themeModeSystem", bundle: bundle) }
    public static var themeModeLight: String { String(localized: "settings.themeModeLight", bundle: bundle) }
    public static var themeModeDark: String { String(localized: "settings.themeModeDark", bundle: bundle) }
    public static var themeModeRestartMessage: String { String(localized: "settings.themeModeRestartMessage", bundle: bundle) }

    // Schedule Tab Mode Settings
    public static var scheduleTabModeDefault: String { String(localized: "settings.scheduleTabModeDefault", bundle: bundle) }
    public static var scheduleTabModeGroup: String { String(localized: "settings.scheduleTabModeGroup", bundle: bundle) }
    public static var scheduleTabModeGroupDescription: String { String(localized: "settings.scheduleTabModeGroupDescription", bundle: bundle) }
    public static var scheduleTabModeOwn: String { String(localized: "settings.scheduleTabModeOwn", bundle: bundle) }
    public static var scheduleTabModeOwnDescription: String { String(localized: "settings.scheduleTabModeOwnDescription", bundle: bundle) }
    public static var scheduleTabModeHint: String { String(localized: "settings.scheduleTabModeHint", bundle: bundle) }
    public static var scheduleTabModePreviewHint: String { String(localized: "settings.scheduleTabModePreviewHint", bundle: bundle) }

    // Calendar Display Mode Settings
    public static var calendarDisplayModeDefault: String { String(localized: "settings.calendarDisplayModeDefault", bundle: bundle) }
    public static var calendarDisplayModeHint: String { String(localized: "settings.calendarDisplayModeHint", bundle: bundle) }

    // Tab Bar Labels
    public static var tabHome: String { String(localized: "settings.tab.home", bundle: bundle) }
    public static var tabGroup: String { String(localized: "settings.tab.group", bundle: bundle) }
    public static var tabOwn: String { String(localized: "settings.tab.own", bundle: bundle) }
    public static var tabCalendar: String { String(localized: "settings.tab.calendar", bundle: bundle) }
    public static var tabSettings: String { String(localized: "settings.tab.settings", bundle: bundle) }

    // MARK: - Batch 4 Settings Group 2 Localization
    // Notification Settings
    public static var notificationSettingsTitle: String { String(localized: "settings.notificationSettings.title", bundle: bundle) }
    public static var appPushNotifications: String { String(localized: "settings.notificationSettings.appPush", bundle: bundle) }
    public static var allowNotifications: String { String(localized: "settings.notificationSettings.allow", bundle: bundle) }
    public static var enableNotificationsInSettings: String { String(localized: "settings.notificationSettings.enableInSettings", bundle: bundle) }
    public static var groupNotifications: String { String(localized: "settings.notificationSettings.groupNotifications", bundle: bundle) }
    public static var noGroupsJoined: String { String(localized: "settings.notificationSettings.noGroups", bundle: bundle) }
    public static var groupNotificationToggle: String { String(localized: "settings.notificationSettings.groupToggle", bundle: bundle) }
    public static var receiveNotifications: String { String(localized: "settings.notificationSettings.receive", bundle: bundle) }
    public static var thisGroupNotificationsOn: String { String(localized: "settings.notificationSettings.thisGroupOn", bundle: bundle) }
    public static var thisGroupNotificationsOff: String { String(localized: "settings.notificationSettings.thisGroupOff", bundle: bundle) }
    public static var notificationTypes: String { String(localized: "settings.notificationSettings.types", bundle: bundle) }
    public static var groupNotificationMustBeOn: String { String(localized: "settings.notificationSettings.mustBeOn", bundle: bundle) }
    public static var notificationCanToggle: String { String(localized: "settings.notificationSettings.canToggle", bundle: bundle) }
    public static var newScheduleArrived: String { String(localized: "settings.notificationSettings.newSchedule", bundle: bundle) }
    public static var scheduleConfirmedTitle: String { String(localized: "settings.notificationSettings.confirmed", bundle: bundle) }
    public static var scheduleCancelledTitle: String { String(localized: "settings.notificationSettings.cancelled", bundle: bundle) }
    public static var scheduleUpdatedTitle: String { String(localized: "settings.notificationSettings.updated", bundle: bundle) }
    public static var newMemberJoinedTitle: String { String(localized: "settings.notificationSettings.newMember", bundle: bundle) }
    public static var groupUpdateTitle: String { String(localized: "settings.notificationSettings.groupUpdate", bundle: bundle) }
    public static var scheduleInvitationBody: String { String(localized: "settings.notificationSettings.invitationBody", bundle: bundle) }
    public static var scheduleConfirmedBody: String { String(localized: "settings.notificationSettings.confirmedBody", bundle: bundle) }
    public static var scheduleCancelledBody: String { String(localized: "settings.notificationSettings.cancelledBody", bundle: bundle) }
    public static var scheduleUpdatedBody: String { String(localized: "settings.notificationSettings.updatedBody", bundle: bundle) }
    public static var newMemberJoinedBody: String { String(localized: "settings.notificationSettings.newMemberBody", bundle: bundle) }
    public static var groupUpdateSubtitle: String { String(localized: "settings.notificationSettings.groupUpdateSubtitle", bundle: bundle) }
    public static var now: String { String(localized: "settings.notificationSettings.now", bundle: bundle) }

    // Calendar Settings
    public static var calendarSettingsTitle: String { String(localized: "settings.calendarSettings.title", bundle: bundle) }
    public static var calendarAccess: String { String(localized: "settings.calendarSettings.access", bundle: bundle) }
    public static var calendarSync: String { String(localized: "settings.calendarSettings.sync", bundle: bundle) }
    public static var enableCalendarInSettings: String { String(localized: "settings.calendarSettings.enableInSettings", bundle: bundle) }
    public static var calendarAccessRestricted: String { String(localized: "settings.calendarSettings.restricted", bundle: bundle) }
    public static var permissionDetails: String { String(localized: "settings.calendarSettings.permissionDetails", bundle: bundle) }
    public static var readPermission: String { String(localized: "settings.calendarSettings.read", bundle: bundle) }
    public static var readPermissionDescription: String { String(localized: "settings.calendarSettings.readDescription", bundle: bundle) }
    public static var writePermission: String { String(localized: "settings.calendarSettings.write", bundle: bundle) }
    public static var writePermissionDescription: String { String(localized: "settings.calendarSettings.writeDescription", bundle: bundle) }
    public static var calendarPermissionHint: String { String(localized: "settings.calendarSettings.permissionHint", bundle: bundle) }
    public static var personalSchedule: String { String(localized: "settings.calendarSettings.personalSchedule", bundle: bundle) }
    public static var personalScheduleSync: String { String(localized: "settings.calendarSettings.personalSync", bundle: bundle) }
    public static var personalScheduleSyncHint: String { String(localized: "settings.calendarSettings.personalSyncHint", bundle: bundle) }
    public static var groupWritePermissions: String { String(localized: "settings.calendarSettings.groupWritePermissions", bundle: bundle) }
    public static var groupWritePermissionsHint: String { String(localized: "settings.calendarSettings.groupWriteHint", bundle: bundle) }

    // App Info
    public static var appInfoTitle: String { String(localized: "settings.appInfo.title", bundle: bundle) }
    public static var appVersion: String { String(localized: "settings.appInfo.version", bundle: bundle) }
    public static var environment: String { String(localized: "settings.appInfo.environment", bundle: bundle) }

    // Legal Info
    public static var legalInfoTitle: String { String(localized: "settings.legalInfo.title", bundle: bundle) }
    public static var privacyPolicy: String { String(localized: "settings.legalInfo.privacyPolicy", bundle: bundle) }
    public static var termsOfService: String { String(localized: "settings.legalInfo.termsOfService", bundle: bundle) }

    // Support
    public static var supportTitle: String { String(localized: "settings.support.title", bundle: bundle) }
    public static var faq: String { String(localized: "settings.support.faq", bundle: bundle) }
    public static var bugReport: String { String(localized: "settings.support.bugReport", bundle: bundle) }

    // FAQ
    public static var faqTitle: String { String(localized: "settings.faq.title", bundle: bundle) }
    public static var faqLoading: String { String(localized: "settings.faq.loading", bundle: bundle) }
    public static var faqRetry: String { String(localized: "settings.faq.retry", bundle: bundle) }
    public static var faqEmpty: String { String(localized: "settings.faq.empty", bundle: bundle) }
    public static var faqAll: String { String(localized: "settings.faq.all", bundle: bundle) }

    // MARK: - Batch 4 Settings Group 3 Localization
    // Developer Settings
    public static var uiTest: String { String(localized: "settings.developer.uiTest", bundle: bundle) }
    public static var liveActivityTest: String { String(localized: "settings.developer.liveActivityTest", bundle: bundle) }
    public static var liveScheduleSettings: String { String(localized: "settings.developer.liveScheduleSettings", bundle: bundle) }
    public static var statusOn: String { String(localized: "settings.developer.statusOn", bundle: bundle) }
    public static var statusOff: String { String(localized: "settings.developer.statusOff", bundle: bundle) }
    public static var crashlyticsTest: String { String(localized: "settings.developer.crashlyticsTest", bundle: bundle) }
    public static var crashWillOccur: String { String(localized: "settings.developer.crashWillOccur", bundle: bundle) }
    public static var deviceInfo: String { String(localized: "settings.developer.deviceInfo", bundle: bundle) }
    public static var iosVersion: String { String(localized: "settings.developer.iosVersion", bundle: bundle) }
    public static var appVersionLabel: String { String(localized: "settings.developer.appVersion", bundle: bundle) }

    // LiveActivity Test
    public static var existingActivity: String { String(localized: "settings.liveActivityTest.existingActivity", bundle: bundle) }
    public static var liveActivityDisabled: String { String(localized: "settings.liveActivityTest.disabled", bundle: bundle) }
    public static var cachedFiles: String { String(localized: "settings.liveActivityTest.cachedFiles", bundle: bundle) }
    public static var mockMeeting: String { String(localized: "settings.liveActivityTest.mockMeeting", bundle: bundle) }
    public static var mockLocation: String { String(localized: "settings.liveActivityTest.mockLocation", bundle: bundle) }
    public static var arrived: String { String(localized: "settings.liveActivityTest.arrived", bundle: bundle) }
    public static var waiting: String { String(localized: "settings.liveActivityTest.waiting", bundle: bundle) }
    public static var groupingTest: String { String(localized: "settings.liveActivityTest.groupingTest", bundle: bundle) }
    public static var sequentialArrivalStarting: String { String(localized: "settings.liveActivityTest.sequentialArrivalStarting", bundle: bundle) }
    public static var mixedStatus: String { String(localized: "settings.liveActivityTest.mixedStatus", bundle: bundle) }
    public static var started: String { String(localized: "settings.liveActivityTest.started", bundle: bundle) }
    public static var ended: String { String(localized: "settings.liveActivityTest.ended", bundle: bundle) }
    public static var failed: String { String(localized: "settings.liveActivityTest.failed", bundle: bundle) }
    public static var allToWaiting: String { String(localized: "settings.liveActivityTest.allToWaiting", bundle: bundle) }
    public static var allTo15Min: String { String(localized: "settings.liveActivityTest.allTo15Min", bundle: bundle) }
    public static var allToArrived: String { String(localized: "settings.liveActivityTest.allToArrived", bundle: bundle) }
    public static var liveActivityTestTitle: String { String(localized: "settings.liveActivityTest.title", bundle: bundle) }
    public static var liveActivityTestHeader: String { String(localized: "settings.liveActivityTest.header", bundle: bundle) }
    public static var active: String { String(localized: "settings.liveActivityTest.active", bundle: bundle) }
    public static var individualETASettings: String { String(localized: "settings.liveActivityTest.individualETA", bundle: bundle) }
    public static var me: String { String(localized: "settings.liveActivityTest.me", bundle: bundle) }
    public static var mockNameMinsu: String { String(localized: "settings.liveActivityTest.mockNameMinsu", bundle: bundle) }
    public static var mockNameJihyun: String { String(localized: "settings.liveActivityTest.mockNameJihyun", bundle: bundle) }
    public static var mockNameSeoyeon: String { String(localized: "settings.liveActivityTest.mockNameSeoyeon", bundle: bundle) }
    public static var scenarioTest: String { String(localized: "settings.liveActivityTest.scenarioTest", bundle: bundle) }
    public static var allWaiting: String { String(localized: "settings.liveActivityTest.allWaiting", bundle: bundle) }
    public static var allDeparted15Min: String { String(localized: "settings.liveActivityTest.allDeparted15Min", bundle: bundle) }
    public static var allArrived: String { String(localized: "settings.liveActivityTest.allArrived", bundle: bundle) }
    public static var sequentialArrival: String { String(localized: "settings.liveActivityTest.sequentialArrival", bundle: bundle) }
    public static var endLiveActivity: String { String(localized: "settings.liveActivityTest.endLiveActivity", bundle: bundle) }
    public static var startMockLiveActivity: String { String(localized: "settings.liveActivityTest.startMockLiveActivity", bundle: bundle) }
    public static var mockDescription: String { String(localized: "settings.liveActivityTest.mockDescription", bundle: bundle) }
    public static var debugInfo: String { String(localized: "settings.liveActivityTest.debugInfo", bundle: bundle) }
    public static var activityId: String { String(localized: "settings.liveActivityTest.activityId", bundle: bundle) }
    public static var activeActivityCount: String { String(localized: "settings.liveActivityTest.activeActivityCount", bundle: bundle) }
    public static var location: String { String(localized: "settings.liveActivityTest.location", bundle: bundle) }
    public static var coordinates: String { String(localized: "settings.liveActivityTest.coordinates", bundle: bundle) }
    public static var trackingTime: String { String(localized: "settings.liveActivityTest.trackingTime", bundle: bundle) }
    public static var participantCount: String { String(localized: "settings.liveActivityTest.participantCount", bundle: bundle) }
    public static var minutes: String { String(localized: "settings.liveActivityTest.minutes", bundle: bundle) }
    public static var eta30Min: String { String(localized: "settings.liveActivityTest.eta30Min", bundle: bundle) }
    public static var eta15Min: String { String(localized: "settings.liveActivityTest.eta15Min", bundle: bundle) }
    public static var eta10Min: String { String(localized: "settings.liveActivityTest.eta10Min", bundle: bundle) }
    public static var eta5Min: String { String(localized: "settings.liveActivityTest.eta5Min", bundle: bundle) }

    // Bottom Accessory Info
    public static var liveScheduleDisplay: String { String(localized: "settings.bottomAccessory.liveScheduleDisplay", bundle: bundle) }
    public static var liveScheduleDescription: String { String(localized: "settings.bottomAccessory.description", bundle: bundle) }
    public static var currentAPIMode: String { String(localized: "settings.bottomAccessory.currentAPIMode", bundle: bundle) }

    // Policy View
    public static var privacyPolicyTitle: String { String(localized: "settings.policy.privacyPolicy", bundle: bundle) }
    public static var termsOfServiceTitle: String { String(localized: "settings.policy.termsOfService", bundle: bundle) }

    // Time Format Example (Preview Card)
    public static var exampleTime12: String { String(localized: "settings.timeFormat.example.time12", bundle: bundle) }
    public static var exampleTime24: String { String(localized: "settings.timeFormat.example.time24", bundle: bundle) }
    public static var exampleDate: String { String(localized: "settings.timeFormat.example.date", bundle: bundle) }
    public static var exampleTitle: String { String(localized: "settings.timeFormat.example.title", bundle: bundle) }
    public static var exampleLocation: String { String(localized: "settings.timeFormat.example.location", bundle: bundle) }

    // MARK: - Conflict Detection Settings
    public static var conflictDetectionTitle: String { String(localized: "settings.conflictDetection.title", bundle: bundle) }
    public static var conflictDetectionAdditionalFeature: String { String(localized: "settings.conflictDetection.additionalFeature", bundle: bundle) }
    public static var conflictDetectionDescription: String { String(localized: "settings.conflictDetection.description", bundle: bundle) }
    public static var conflictDetectionThresholdSection: String { String(localized: "settings.conflictDetection.thresholdSection", bundle: bundle) }
    public static var conflictDetectionMinThreshold: String { String(localized: "settings.conflictDetection.minThreshold", bundle: bundle) }
    public static var conflictDetectionOverlapOnly: String { String(localized: "settings.conflictDetection.overlapOnly", bundle: bundle) }
    public static var conflictDetectionCustom: String { String(localized: "settings.conflictDetection.custom", bundle: bundle) }
    public static var conflictDetectionMinuteUnit: String { String(localized: "settings.conflictDetection.minuteUnit", bundle: bundle) }
    public static var conflictDetectionThresholdHint: String { String(localized: "settings.conflictDetection.thresholdHint", bundle: bundle) }
    public static var conflictDetectionExample: String { String(localized: "settings.conflictDetection.example", bundle: bundle) }
    public static var conflictDetectionNewEvent: String { String(localized: "settings.conflictDetection.newEvent", bundle: bundle) }
    public static var conflictDetectionExistingEvents: String { String(localized: "settings.conflictDetection.existingEvents", bundle: bundle) }
    public static var conflictDetectionPreviewHint: String { String(localized: "settings.conflictDetection.previewHint", bundle: bundle) }
    public static var conflictDetectionConflict: String { String(localized: "settings.conflictDetection.conflict", bundle: bundle) }
    public static var conflictDetectionMargin: String { String(localized: "settings.conflictDetection.margin", bundle: bundle) }
    public static var conflictDetectionOverlapOnlyHint: String { String(localized: "settings.conflictDetection.overlapOnlyHint", bundle: bundle) }
    public static func conflictDetectionThresholdDescriptionHours(_ hours: Int) -> String {
      String(localized: "settings.conflictDetection.thresholdDesc.hours", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(hours)")
    }
    public static func conflictDetectionThresholdDescriptionHoursMinutes(_ hours: Int, _ minutes: Int) -> String {
      String(localized: "settings.conflictDetection.thresholdDesc.hoursMinutes", bundle: bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(hours)")
        .replacingOccurrences(of: "%2$lld", with: "\(minutes)")
    }
    public static func conflictDetectionThresholdDescriptionMinutes(_ minutes: Int) -> String {
      String(localized: "settings.conflictDetection.thresholdDesc.minutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static func conflictDetectionCurrentMinutes(_ minutes: Int) -> String {
      String(localized: "settings.conflictDetection.currentMinutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static var conflictPreviewLunchSchedule: String {
      String(localized: "settings.conflictDetection.preview.lunch", bundle: bundle)
    }
    public static var conflictPreviewTeamMeeting: String {
      String(localized: "settings.conflictDetection.preview.teamMeeting", bundle: bundle)
    }
    public static var conflictPreviewDinnerPlan: String {
      String(localized: "settings.conflictDetection.preview.dinner", bundle: bundle)
    }

    // Briefing Settings
    public static var briefingSettingsTitle: String { String(localized: "settings.briefing.title", bundle: bundle) }
    public static var briefingStyle: String { String(localized: "settings.briefing.style", bundle: bundle) }
    public static var briefingStyleDescription: String { String(localized: "settings.briefing.style.description", bundle: bundle) }
    public static var briefingStyleFriendly: String { String(localized: "settings.briefing.style.option.friendly", bundle: bundle) }
    public static var briefingStyleHumorous: String { String(localized: "settings.briefing.style.option.humorous", bundle: bundle) }
    public static var briefingStyleConcise: String { String(localized: "settings.briefing.style.option.concise", bundle: bundle) }
    public static var briefingStyleMotivational: String { String(localized: "settings.briefing.style.option.motivational", bundle: bundle) }
    public static var briefingStyleCalm: String { String(localized: "settings.briefing.style.option.calm", bundle: bundle) }
    public static var briefingStyleFriendlyDescription: String { String(localized: "settings.briefing.style.option.friendly.description", bundle: bundle) }
    public static var briefingStyleHumorousDescription: String { String(localized: "settings.briefing.style.option.humorous.description", bundle: bundle) }
    public static var briefingStyleConciseDescription: String { String(localized: "settings.briefing.style.option.concise.description", bundle: bundle) }
    public static var briefingStyleMotivationalDescription: String { String(localized: "settings.briefing.style.option.motivational.description", bundle: bundle) }
    public static var briefingStyleCalmDescription: String { String(localized: "settings.briefing.style.option.calm.description", bundle: bundle) }
    public static var briefingTransport: String { String(localized: "settings.briefing.transport", bundle: bundle) }
    public static var briefingTransportDescription: String { String(localized: "settings.briefing.transport.description", bundle: bundle) }
    public static var briefingTransportTransit: String { String(localized: "settings.briefing.transport.option.transit", bundle: bundle) }
    public static var briefingTransportCar: String { String(localized: "settings.briefing.transport.option.car", bundle: bundle) }
    public static var briefingNotification: String { String(localized: "settings.briefing.notification", bundle: bundle) }
    public static var briefingNotificationDescription: String { String(localized: "settings.briefing.notification.description", bundle: bundle) }
    public static var briefingNotificationToggle: String { String(localized: "settings.briefing.notification.toggle", bundle: bundle) }
    public static var briefingNotificationTime: String { String(localized: "settings.briefing.notification.time", bundle: bundle) }
    public static var briefingNotificationPermissionRequired: String { String(localized: "settings.briefing.notification.permissionRequired", bundle: bundle) }
    public static var briefingDefaultLocation: String { String(localized: "settings.briefing.defaultLocation", bundle: bundle) }
    public static var briefingDefaultLocationDescription: String { String(localized: "settings.briefing.defaultLocation.description", bundle: bundle) }
    public static var briefingDefaultLocationPlaceholder: String { String(localized: "settings.briefing.defaultLocation.placeholder", bundle: bundle) }
  }

  // MARK: - Errors
  public enum Error {
    public static var networkError: String { String(localized: "error.network", bundle: bundle) }
    public static var unknownError: String { String(localized: "error.unknown", bundle: bundle) }
    public static var serverError: String { String(localized: "error.server", bundle: bundle) }
    public static func serverErrorWithMessage(_ message: String) -> String {
      String(localized: "error.server.withMessage", bundle: bundle)
        .replacingOccurrences(of: "%@", with: message)
    }
    public static var timeoutError: String { String(localized: "error.timeout", bundle: bundle) }
    public static var validationError: String { String(localized: "error.validation", bundle: bundle) }
    public static var permissionError: String { String(localized: "error.permission", bundle: bundle) }
    public static var notFoundError: String { String(localized: "error.notFound", bundle: bundle) }
    public static var invalidResponse: String { String(localized: "error.invalidResponse", bundle: bundle) }
    public static var weatherInvalidResponse: String { String(localized: "error.weather.invalidResponse", bundle: bundle) }
    public static var subscriptionProductNotFound: String {
      String(localized: "error.subscription.productNotFound", bundle: bundle)
    }
    public static var subscriptionPurchaseCancelled: String {
      String(localized: "error.subscription.purchaseCancelled", bundle: bundle)
    }
    public static var subscriptionPurchasePending: String {
      String(localized: "error.subscription.purchasePending", bundle: bundle)
    }
    public static var subscriptionVerificationFailed: String {
      String(localized: "error.subscription.verificationFailed", bundle: bundle)
    }
    public static var holidayServiceKeyNotFound: String {
      String(localized: "error.holiday.serviceKeyNotFound", bundle: bundle)
    }
    public static func holidayApiError(_ code: String, _ message: String) -> String {
      String(localized: "error.holiday.api", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: code)
        .replacingOccurrences(of: "%2$@", with: message)
    }
    public static var holidayInvalidURL: String { String(localized: "error.holiday.invalidURL", bundle: bundle) }

    // Auth
    public static var authInvalidCredentials: String { String(localized: "error.auth.invalidCredentials", bundle: bundle) }
    public static var authAlreadyExists: String { String(localized: "error.auth.alreadyExists", bundle: bundle) }
    public static var authNetwork: String { String(localized: "error.auth.network", bundle: bundle) }
    public static var authInvalidAppleCredential: String { String(localized: "error.auth.invalidAppleCredential", bundle: bundle) }
    public static var authMissingIdentityToken: String { String(localized: "error.auth.missingIdentityToken", bundle: bundle) }
    public static var authProviderUnavailable: String { String(localized: "error.auth.providerUnavailable", bundle: bundle) }
    public static var authIsGroupHost: String { String(localized: "error.auth.isGroupHost", bundle: bundle) }

    // Notification
    public static var notificationAuthRequired: String { String(localized: "error.notification.authRequired", bundle: bundle) }
    public static var notificationTokenNotFound: String { String(localized: "error.notification.tokenNotFound", bundle: bundle) }
    public static var notificationSaveFailed: String { String(localized: "error.notification.saveFailed", bundle: bundle) }
    public static var notificationDeleteFailed: String { String(localized: "error.notification.deleteFailed", bundle: bundle) }

    // Calendar
    public static var calendarNoWritePermission: String { String(localized: "error.calendar.noWritePermission", bundle: bundle) }
    public static var calendarFetchFailed: String { String(localized: "error.calendar.fetchFailed", bundle: bundle) }
    public static var calendarSyncFailed: String { String(localized: "error.calendar.syncFailed", bundle: bundle) }
    public static var calendarAccessDenied: String { String(localized: "error.calendar.accessDenied", bundle: bundle) }
    public static var calendarAccessRestricted: String { String(localized: "error.calendar.accessRestricted", bundle: bundle) }
    public static var calendarWriteNotAllowed: String { String(localized: "error.calendar.writeNotAllowed", bundle: bundle) }
    public static var calendarSaveFailed: String { String(localized: "error.calendar.saveFailed", bundle: bundle) }
    public static var calendarStoreError: String { String(localized: "error.calendar.storeError", bundle: bundle) }

    // FAQ
    public static var faqFetchFailed: String { String(localized: "error.faq.fetchFailed", bundle: bundle) }
    public static var faqDecodingFailed: String { String(localized: "error.faq.decodingFailed", bundle: bundle) }
    public static var faqInvalidConfiguration: String { String(localized: "error.faq.invalidConfiguration", bundle: bundle) }

    // AppConfig
    public static var appConfigFetchFailed: String { String(localized: "error.appConfig.fetchFailed", bundle: bundle) }
    public static var appConfigInvalidVersion: String { String(localized: "error.appConfig.invalidVersion", bundle: bundle) }

    // User Profile
    public static var userInvalidData: String { String(localized: "error.user.invalidData", bundle: bundle) }
    public static var userNotFound: String { String(localized: "error.user.notFound", bundle: bundle) }
    public static var userUploadFailed: String { String(localized: "error.user.uploadFailed", bundle: bundle) }
    public static var userNetworkError: String { String(localized: "error.user.networkError", bundle: bundle) }
    public static var userAuthRequired: String { String(localized: "error.user.authRequired", bundle: bundle) }
    public static var userPermissionDenied: String { String(localized: "error.user.permissionDenied", bundle: bundle) }

    // Group Data Source
    public static var groupInvalidResponse: String { String(localized: "error.group.invalidResponse", bundle: bundle) }
    public static var groupInvalidRequestData: String { String(localized: "error.group.invalidRequestData", bundle: bundle) }
    public static var groupImageUploadFailed: String { String(localized: "error.group.imageUploadFailed", bundle: bundle) }
    public static var groupNotFound: String { String(localized: "error.group.notFound", bundle: bundle) }

    // Map
    public static var mapInvalidResponse: String { String(localized: "error.map.invalidResponse", bundle: bundle) }
    public static var mapHttpError: String { String(localized: "error.map.httpError", bundle: bundle) }

    // OCR
    public static var ocrImageConversionFailed: String { String(localized: "error.ocr.imageConversionFailed", bundle: bundle) }
    public static var ocrRecognitionFailed: String { String(localized: "error.ocr.recognitionFailed", bundle: bundle) }
    public static var ocrNoTextFound: String { String(localized: "error.ocr.noTextFound", bundle: bundle) }
    public static var imageCompressionFailed: String { String(localized: "error.image.compressionFailed", bundle: bundle) }
    public static func imageUploadFailed(_ message: String) -> String {
      String(localized: "error.image.uploadFailed", bundle: bundle)
        .replacingOccurrences(of: "%@", with: message)
    }
    public static var imageUploadAllFailed: String { String(localized: "error.image.allFailed", bundle: bundle) }

    // Feature Error Messages (Toast/Alert)
    public static var scheduleCreationFailed: String { String(localized: "error.scheduleCreationFailed", bundle: bundle) }
    public static var eventDeleteFailed: String { String(localized: "error.eventDeleteFailed", bundle: bundle) }
    public static var markAsReadFailed: String { String(localized: "error.markAsReadFailed", bundle: bundle) }
    public static var scheduleFetchFailed: String { String(localized: "error.scheduleFetchFailed", bundle: bundle) }
    public static var logoutFailed: String { String(localized: "error.logoutFailed", bundle: bundle) }
    public static var profileSaveFailed: String { String(localized: "error.profileSaveFailed", bundle: bundle) }
    public static var calendarSyncSaveFailed: String { String(localized: "error.calendarSyncSaveFailed", bundle: bundle) }
    public static var notificationSettingSaveFailed: String { String(localized: "error.notificationSettingSaveFailed", bundle: bundle) }
    public static var responseSendFailed: String { String(localized: "error.responseSendFailed", bundle: bundle) }
    public static var scheduleDeleteFailed: String { String(localized: "error.scheduleDeleteFailed", bundle: bundle) }
    public static var accountDeleteFailed: String { String(localized: "error.accountDeleteFailed", bundle: bundle) }
    public static var notificationPermissionDenied: String { String(localized: "error.notificationPermissionDenied", bundle: bundle) }
    public static var memberExpelFailed: String { String(localized: "error.memberExpelFailed", bundle: bundle) }
    public static var colorChangeFailed: String { String(localized: "error.colorChangeFailed", bundle: bundle) }
    public static var settingSaveFailed: String { String(localized: "error.settingSaveFailed", bundle: bundle) }
  }

  // MARK: - Tab Bar
  public enum TabBar {
    public static var home: String { String(localized: "tab.home", bundle: bundle) }
    public static var schedule: String { String(localized: "tab.schedule", bundle: bundle) }
    public static var calendar: String { String(localized: "tab.calendar", bundle: bundle) }
    public static var group: String { String(localized: "tab.group", bundle: bundle) }
    public static var settings: String { String(localized: "tab.settings", bundle: bundle) }
  }

  // MARK: - Notification
  public enum Notification {
    public static var title: String { String(localized: "notification.title", bundle: bundle) }
    public static var markAllAsRead: String { String(localized: "notification.markAllAsRead", bundle: bundle) }
    public static var selectAll: String { String(localized: "notification.selectAll", bundle: bundle) }
    public static func selectedCount(_ count: Int) -> String {
      String(localized: "notification.selectedCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var emptyTitle: String { String(localized: "notification.empty.title", bundle: bundle) }
    public static var emptySubtitle: String { String(localized: "notification.empty.subtitle", bundle: bundle) }
    public static var loadFailed: String { String(localized: "notification.error.loadFailed", bundle: bundle) }
    public static var filterAll: String { String(localized: "notification.filter.all", bundle: bundle) }
    public static var filterUnread: String { String(localized: "notification.filter.unread", bundle: bundle) }
  }

  // MARK: - Onboarding
  public enum Onboarding {
    public static var start: String { String(localized: "onboarding.start", bundle: bundle) }
    public static var readyTitle: String { String(localized: "onboarding.ready.title", bundle: bundle) }
    public static var readySubtitle: String { String(localized: "onboarding.ready.subtitle", bundle: bundle) }
    public static var readyDescription: String { String(localized: "onboarding.ready.description", bundle: bundle) }
    public static var hasInviteCode: String { String(localized: "onboarding.hasInviteCode", bundle: bundle) }
    public static var skipForNow: String { String(localized: "onboarding.skipForNow", bundle: bundle) }
    public static var laterHint: String { String(localized: "onboarding.laterHint", bundle: bundle) }

    // Intro - Problem
    public static var introProblemCountLabel: String {
      String(localized: "onboarding.intro.problem.countLabel", bundle: bundle)
    }
    public static var introProblemPainPoint1: String {
      String(localized: "onboarding.intro.problem.painPoint1", bundle: bundle)
    }
    public static var introProblemPainPoint2: String {
      String(localized: "onboarding.intro.problem.painPoint2", bundle: bundle)
    }
    public static var introProblemPainPoint3: String {
      String(localized: "onboarding.intro.problem.painPoint3", bundle: bundle)
    }
    public static var introProblemBottomLine1: String {
      String(localized: "onboarding.intro.problem.bottomLine1", bundle: bundle)
    }
    public static var introProblemBottomLine2: String {
      String(localized: "onboarding.intro.problem.bottomLine2", bundle: bundle)
    }

    // Intro - Confirm
    public static var introConfirmTitle: String {
      String(localized: "onboarding.intro.confirm.title", bundle: bundle)
    }
    public static var introConfirmSubtitle: String {
      String(localized: "onboarding.intro.confirm.subtitle", bundle: bundle)
    }

    // Intro - Vote
    public static var introVoteTitle: String {
      String(localized: "onboarding.intro.vote.title", bundle: bundle)
    }
    public static var introVoteSubtitle: String {
      String(localized: "onboarding.intro.vote.subtitle", bundle: bundle)
    }
    public static var introVoteGroupName: String {
      String(localized: "onboarding.intro.vote.groupName", bundle: bundle)
    }
    public static func introVoteAcceptedCount(_ accepted: Int, _ total: Int) -> String {
      String(localized: "onboarding.intro.vote.acceptedCount", bundle: bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(accepted)")
        .replacingOccurrences(of: "%2$lld", with: "\(total)")
    }
    public static func introVoteMinimumRequired(_ count: Int) -> String {
      String(localized: "onboarding.intro.vote.minimumRequired", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var introVoteAutoConfirmed: String {
      String(localized: "onboarding.intro.vote.autoConfirmed", bundle: bundle)
    }
    public static var introVoteAccepted: String {
      String(localized: "onboarding.intro.vote.accepted", bundle: bundle)
    }
    public static var introVoteWaiting: String {
      String(localized: "onboarding.intro.vote.waiting", bundle: bundle)
    }
    public static var introVoteNow: String {
      String(localized: "onboarding.intro.vote.now", bundle: bundle)
    }
    public static var introVoteNotificationTitle: String {
      String(localized: "onboarding.intro.vote.notificationTitle", bundle: bundle)
    }
    public static var introVoteNotificationSubtitle: String {
      String(localized: "onboarding.intro.vote.notificationSubtitle", bundle: bundle)
    }

    // Intro - Home
    public static var introHomeTitle: String {
      String(localized: "onboarding.intro.home.title", bundle: bundle)
    }
    public static var introHomeSubtitle: String {
      String(localized: "onboarding.intro.home.subtitle", bundle: bundle)
    }
    public static var introHomeTodayTitle: String {
      String(localized: "onboarding.intro.home.todayTitle", bundle: bundle)
    }
    public static func introHomeItemCount(_ count: Int) -> String {
      String(localized: "onboarding.intro.home.itemCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var introHomeTodayRow1Title: String {
      String(localized: "onboarding.intro.home.todayRow1.title", bundle: bundle)
    }
    public static var introHomeTodayRow1Tag: String {
      String(localized: "onboarding.intro.home.todayRow1.tag", bundle: bundle)
    }
    public static var introHomeTodayRow2Title: String {
      String(localized: "onboarding.intro.home.todayRow2.title", bundle: bundle)
    }
    public static var introHomeTodayRow2Tag: String {
      String(localized: "onboarding.intro.home.todayRow2.tag", bundle: bundle)
    }
    public static var introHomeNeedResponseTitle: String {
      String(localized: "onboarding.intro.home.needResponseTitle", bundle: bundle)
    }
    public static var introHomeUpcomingTitle: String {
      String(localized: "onboarding.intro.home.upcomingTitle", bundle: bundle)
    }
    public static var introHomeUpcomingRow1Day: String {
      String(localized: "onboarding.intro.home.upcomingRow1.day", bundle: bundle)
    }
    public static var introHomeUpcomingRow1Title: String {
      String(localized: "onboarding.intro.home.upcomingRow1.title", bundle: bundle)
    }
    public static var introHomeUpcomingRow1Time: String {
      String(localized: "onboarding.intro.home.upcomingRow1.time", bundle: bundle)
    }
    public static var introHomeUpcomingRow2Day: String {
      String(localized: "onboarding.intro.home.upcomingRow2.day", bundle: bundle)
    }
    public static var introHomeUpcomingRow2Title: String {
      String(localized: "onboarding.intro.home.upcomingRow2.title", bundle: bundle)
    }
    public static var introHomeUpcomingRow2Time: String {
      String(localized: "onboarding.intro.home.upcomingRow2.time", bundle: bundle)
    }

    // Intro - Live
    public static func introLiveEtaMinutes(_ minutes: Int) -> String {
      String(localized: "onboarding.intro.live.etaMinutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static var introLiveEtaArrived: String {
      String(localized: "onboarding.intro.live.etaArrived", bundle: bundle)
    }
    public static var introLiveTapHint: String {
      String(localized: "onboarding.intro.live.tapHint", bundle: bundle)
    }
    public static var introLiveTitle: String {
      String(localized: "onboarding.intro.live.title", bundle: bundle)
    }
    public static var introLiveSubtitle: String {
      String(localized: "onboarding.intro.live.subtitle", bundle: bundle)
    }
    public static var introLiveMinuteUnit: String {
      String(localized: "onboarding.intro.live.minuteUnit", bundle: bundle)
    }
    public static var introLiveGroupName: String {
      String(localized: "onboarding.intro.live.groupName", bundle: bundle)
    }
    public static var introLiveTimeRemaining: String {
      String(localized: "onboarding.intro.live.timeRemaining", bundle: bundle)
    }
    public static var introLiveRealtime: String {
      String(localized: "onboarding.intro.live.realtime", bundle: bundle)
    }
    public static var introLiveMe: String {
      String(localized: "onboarding.intro.live.me", bundle: bundle)
    }
    public static var introLiveStatusBeforeStart: String {
      String(localized: "onboarding.intro.live.status.beforeStart", bundle: bundle)
    }
    public static var introLiveStatusArrived: String {
      String(localized: "onboarding.intro.live.status.arrived", bundle: bundle)
    }
    public static var introLiveStatusAlmostThere: String {
      String(localized: "onboarding.intro.live.status.almostThere", bundle: bundle)
    }
    public static var introLiveStatusLateExpected: String {
      String(localized: "onboarding.intro.live.status.lateExpected", bundle: bundle)
    }
    public static var introLiveStatusOnTheWay: String {
      String(localized: "onboarding.intro.live.status.onTheWay", bundle: bundle)
    }
    public static var introLiveBadgeArrived: String {
      String(localized: "onboarding.intro.live.badge.arrived", bundle: bundle)
    }
    public static var introLiveBadgeWaiting: String {
      String(localized: "onboarding.intro.live.badge.waiting", bundle: bundle)
    }

    // Intro - Hero
    public static var introHeroBubble1: String {
      String(localized: "onboarding.intro.hero.bubble1", bundle: bundle)
    }
    public static var introHeroBubble2: String {
      String(localized: "onboarding.intro.hero.bubble2", bundle: bundle)
    }
    public static var introHeroBubble3: String {
      String(localized: "onboarding.intro.hero.bubble3", bundle: bundle)
    }
    public static var introHeroBubble4: String {
      String(localized: "onboarding.intro.hero.bubble4", bundle: bundle)
    }
    public static var introHeroGroupClassmates: String {
      String(localized: "onboarding.intro.hero.group.classmates", bundle: bundle)
    }
    public static var introHeroGroupFries: String {
      String(localized: "onboarding.intro.hero.group.fries", bundle: bundle)
    }
    public static func introHeroGroupParticipantCount(_ countText: String) -> String {
      String(localized: "onboarding.intro.hero.group.participantCount", bundle: bundle)
        .replacingOccurrences(of: "%@", with: countText)
    }
    public static var introHeroFriesTitle: String {
      String(localized: "onboarding.intro.hero.fries.title", bundle: bundle)
    }
    public static var introHeroFriesDetail: String {
      String(localized: "onboarding.intro.hero.fries.detail", bundle: bundle)
    }
    public static var introHeroFriesLocation: String {
      String(localized: "onboarding.intro.hero.fries.location", bundle: bundle)
    }
    public static var introHeroPendingOneLeft: String {
      String(localized: "onboarding.intro.hero.pendingOneLeft", bundle: bundle)
    }
    public static var introHeroConfirmedBadge: String {
      String(localized: "onboarding.intro.hero.confirmedBadge", bundle: bundle)
    }
    public static var introHeroPersonalBadge: String {
      String(localized: "onboarding.intro.hero.personalBadge", bundle: bundle)
    }
    public static var introHeroTaglineLine1: String {
      String(localized: "onboarding.intro.hero.tagline.line1", bundle: bundle)
    }
    public static var introHeroTaglineLine2: String {
      String(localized: "onboarding.intro.hero.tagline.line2", bundle: bundle)
    }

    public static func introHeroConfirmedTitle(_ index: Int) -> String {
      switch index {
      case 1: return String(localized: "onboarding.intro.hero.confirmed.1.title", bundle: bundle)
      case 2: return String(localized: "onboarding.intro.hero.confirmed.2.title", bundle: bundle)
      case 3: return String(localized: "onboarding.intro.hero.confirmed.3.title", bundle: bundle)
      case 4: return String(localized: "onboarding.intro.hero.confirmed.4.title", bundle: bundle)
      case 5: return String(localized: "onboarding.intro.hero.confirmed.5.title", bundle: bundle)
      default: return String(localized: "onboarding.intro.hero.confirmed.1.title", bundle: bundle)
      }
    }
    public static func introHeroConfirmedDetail(_ index: Int) -> String {
      switch index {
      case 1: return String(localized: "onboarding.intro.hero.confirmed.1.detail", bundle: bundle)
      case 2: return String(localized: "onboarding.intro.hero.confirmed.2.detail", bundle: bundle)
      case 3: return String(localized: "onboarding.intro.hero.confirmed.3.detail", bundle: bundle)
      case 4: return String(localized: "onboarding.intro.hero.confirmed.4.detail", bundle: bundle)
      case 5: return String(localized: "onboarding.intro.hero.confirmed.5.detail", bundle: bundle)
      default: return String(localized: "onboarding.intro.hero.confirmed.1.detail", bundle: bundle)
      }
    }
    public static func introHeroConfirmedLocation(_ index: Int) -> String {
      switch index {
      case 1: return String(localized: "onboarding.intro.hero.confirmed.1.location", bundle: bundle)
      case 2: return String(localized: "onboarding.intro.hero.confirmed.2.location", bundle: bundle)
      case 3: return String(localized: "onboarding.intro.hero.confirmed.3.location", bundle: bundle)
      case 4: return String(localized: "onboarding.intro.hero.confirmed.4.location", bundle: bundle)
      case 5: return String(localized: "onboarding.intro.hero.confirmed.5.location", bundle: bundle)
      default: return String(localized: "onboarding.intro.hero.confirmed.1.location", bundle: bundle)
      }
    }
    public static func introHeroUpcomingTitle(_ index: Int) -> String {
      switch index {
      case 1: return String(localized: "onboarding.intro.hero.upcoming.1.title", bundle: bundle)
      case 2: return String(localized: "onboarding.intro.hero.upcoming.2.title", bundle: bundle)
      case 3: return String(localized: "onboarding.intro.hero.upcoming.3.title", bundle: bundle)
      case 4: return String(localized: "onboarding.intro.hero.upcoming.4.title", bundle: bundle)
      case 5: return String(localized: "onboarding.intro.hero.upcoming.5.title", bundle: bundle)
      default: return String(localized: "onboarding.intro.hero.upcoming.1.title", bundle: bundle)
      }
    }
    public static func introHeroUpcomingDetail(_ index: Int) -> String {
      switch index {
      case 1: return String(localized: "onboarding.intro.hero.upcoming.1.detail", bundle: bundle)
      case 2: return String(localized: "onboarding.intro.hero.upcoming.2.detail", bundle: bundle)
      case 3: return String(localized: "onboarding.intro.hero.upcoming.3.detail", bundle: bundle)
      case 4: return String(localized: "onboarding.intro.hero.upcoming.4.detail", bundle: bundle)
      case 5: return String(localized: "onboarding.intro.hero.upcoming.5.detail", bundle: bundle)
      default: return String(localized: "onboarding.intro.hero.upcoming.1.detail", bundle: bundle)
      }
    }
    public static func introHeroUpcomingLocation(_ index: Int) -> String {
      switch index {
      case 1: return String(localized: "onboarding.intro.hero.upcoming.1.location", bundle: bundle)
      case 2: return String(localized: "onboarding.intro.hero.upcoming.2.location", bundle: bundle)
      case 3: return String(localized: "onboarding.intro.hero.upcoming.3.location", bundle: bundle)
      case 4: return String(localized: "onboarding.intro.hero.upcoming.4.location", bundle: bundle)
      case 5: return String(localized: "onboarding.intro.hero.upcoming.5.location", bundle: bundle)
      default: return String(localized: "onboarding.intro.hero.upcoming.1.location", bundle: bundle)
      }
    }
    public static func introHeroUpcomingTime(_ index: Int) -> String {
      switch index {
      case 1: return String(localized: "onboarding.intro.hero.upcoming.1.time", bundle: bundle)
      case 2: return String(localized: "onboarding.intro.hero.upcoming.2.time", bundle: bundle)
      case 3: return String(localized: "onboarding.intro.hero.upcoming.3.time", bundle: bundle)
      case 4: return String(localized: "onboarding.intro.hero.upcoming.4.time", bundle: bundle)
      case 5: return String(localized: "onboarding.intro.hero.upcoming.5.time", bundle: bundle)
      default: return String(localized: "onboarding.intro.hero.upcoming.1.time", bundle: bundle)
      }
    }
    public static func introHeroPersonalTitle(_ index: Int) -> String {
      switch index {
      case 1: return String(localized: "onboarding.intro.hero.personal.1.title", bundle: bundle)
      case 2: return String(localized: "onboarding.intro.hero.personal.2.title", bundle: bundle)
      case 3: return String(localized: "onboarding.intro.hero.personal.3.title", bundle: bundle)
      case 4: return String(localized: "onboarding.intro.hero.personal.4.title", bundle: bundle)
      case 5: return String(localized: "onboarding.intro.hero.personal.5.title", bundle: bundle)
      default: return String(localized: "onboarding.intro.hero.personal.1.title", bundle: bundle)
      }
    }
    public static func introHeroPersonalDetail(_ index: Int) -> String {
      switch index {
      case 1: return String(localized: "onboarding.intro.hero.personal.1.detail", bundle: bundle)
      case 2: return String(localized: "onboarding.intro.hero.personal.2.detail", bundle: bundle)
      case 3: return String(localized: "onboarding.intro.hero.personal.3.detail", bundle: bundle)
      case 4: return String(localized: "onboarding.intro.hero.personal.4.detail", bundle: bundle)
      case 5: return String(localized: "onboarding.intro.hero.personal.5.detail", bundle: bundle)
      default: return String(localized: "onboarding.intro.hero.personal.1.detail", bundle: bundle)
      }
    }
    public static func introHeroPersonalLocation(_ index: Int) -> String {
      switch index {
      case 1: return String(localized: "onboarding.intro.hero.personal.1.location", bundle: bundle)
      case 2: return String(localized: "onboarding.intro.hero.personal.2.location", bundle: bundle)
      case 3: return String(localized: "onboarding.intro.hero.personal.3.location", bundle: bundle)
      case 4: return String(localized: "onboarding.intro.hero.personal.4.location", bundle: bundle)
      case 5: return String(localized: "onboarding.intro.hero.personal.5.location", bundle: bundle)
      default: return String(localized: "onboarding.intro.hero.personal.1.location", bundle: bundle)
      }
    }
    public static func introHeroPersonalTime(_ index: Int) -> String {
      switch index {
      case 1: return String(localized: "onboarding.intro.hero.personal.1.time", bundle: bundle)
      case 2: return String(localized: "onboarding.intro.hero.personal.2.time", bundle: bundle)
      case 3: return String(localized: "onboarding.intro.hero.personal.3.time", bundle: bundle)
      case 4: return String(localized: "onboarding.intro.hero.personal.4.time", bundle: bundle)
      case 5: return String(localized: "onboarding.intro.hero.personal.5.time", bundle: bundle)
      default: return String(localized: "onboarding.intro.hero.personal.1.time", bundle: bundle)
      }
    }
  }

  // MARK: - AppEntry
  public enum AppEntry {
    public static var forceUpdateTitle: String { String(localized: "appEntry.update.forceTitle", bundle: bundle) }
    public static var recommendUpdateTitle: String { String(localized: "appEntry.update.recommendTitle", bundle: bundle) }
    public static func forceUpdateMessage(_ current: String, _ required: String) -> String {
      String(localized: "appEntry.update.forceMessage", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: current)
        .replacingOccurrences(of: "%2$@", with: required)
    }
    public static func recommendUpdateMessage(_ current: String, _ recommended: String) -> String {
      String(localized: "appEntry.update.recommendMessage", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: current)
        .replacingOccurrences(of: "%2$@", with: recommended)
    }
    public static var updateAction: String { String(localized: "appEntry.update.action", bundle: bundle) }
    public static var updateLater: String { String(localized: "appEntry.update.later", bundle: bundle) }
  }

  // MARK: - Profile
  public enum Profile {
    public static var nicknameCheckRequired: String { String(localized: "profile.error.nicknameCheckRequired", bundle: bundle) }
    public static var nicknameTaken: String { String(localized: "profile.error.nicknameTaken", bundle: bundle) }
    public static var nicknameCheckFailed: String { String(localized: "profile.error.nicknameCheckFailed", bundle: bundle) }
    public static var saveFailed: String { String(localized: "profile.error.saveFailed", bundle: bundle) }
    public static func nicknameTooShort(_ minimum: Int) -> String {
      String(localized: "profile.validation.nicknameTooShort", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minimum)")
    }
    public static func nicknameTooLong(_ maximum: Int) -> String {
      String(localized: "profile.validation.nicknameTooLong", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(maximum)")
    }
    public static var nicknameContainsWhitespace: String {
      String(localized: "profile.validation.nicknameContainsWhitespace", bundle: bundle)
    }
    public static var nicknameTrimWhitespace: String {
      String(localized: "profile.validation.nicknameTrimWhitespace", bundle: bundle)
    }
    public static var setupTitle1: String { String(localized: "profile.setup.title1", bundle: bundle) }
    public static var setupTitle2: String { String(localized: "profile.setup.title2", bundle: bundle) }
    public static var nickname: String { String(localized: "profile.nickname", bundle: bundle) }
    public static var nicknamePlaceholder: String { String(localized: "profile.nickname.placeholder", bundle: bundle) }
    public static var saving: String { String(localized: "profile.saving", bundle: bundle) }
    public static var nicknameChecking: String { String(localized: "profile.nickname.checking", bundle: bundle) }
    public static var nicknameAvailable: String { String(localized: "profile.nickname.available", bundle: bundle) }
    public static var selectPhoto: String { String(localized: "profile.selectPhoto", bundle: bundle) }
  }

  // MARK: - Home
  public enum Home {
    // Pending Section
    public static var needResponse: String { String(localized: "home.pending.needResponse", bundle: bundle) }
    public static var closed: String { String(localized: "home.pending.closed", bundle: bundle) }
    public static func minutesRemaining(_ minutes: Int) -> String {
      String(localized: "home.pending.minutesRemaining", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static func hoursRemaining(_ hours: Int) -> String {
      String(localized: "home.pending.hoursRemaining", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(hours)")
    }

    // Briefing
    public static var briefingUpdatedBadge: String { String(localized: "home.briefing.updated.badge", bundle: bundle) }
    public static var briefingProUpgrade: String { String(localized: "home.briefing.pro.upgrade", bundle: bundle) }
    public static var briefingUpdateInfoTooltip: String { String(localized: "home.briefing.updateInfoTooltip", bundle: bundle) }
    public static func briefingNotificationChipAM(_ hour: Int) -> String {
      String(localized: "home.briefing.notificationChip.am", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(hour)")
    }
    public static func briefingNotificationChipPM(_ hour: Int) -> String {
      String(localized: "home.briefing.notificationChip.pm", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(hour)")
    }

    // Timeline
    public static var accepted: String { String(localized: "home.timeline.accepted", bundle: bundle) }
    public static var declined: String { String(localized: "home.timeline.declined", bundle: bundle) }
    public static var tomorrow: String { String(localized: "home.timeline.tomorrow", bundle: bundle) }
    public static var dayAfterTomorrow: String { String(localized: "home.timeline.dayAfterTomorrow", bundle: bundle) }

    // Need Response Banner
    public static var responseNeeded: String { String(localized: "home.banner.responseNeeded", bundle: bundle) }
    public static func schedulesToRespond(_ count: Int) -> String {
      String(localized: "home.banner.schedulesToRespond", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }

    // Empty State
    public static var emptyNoSchedulesTitle: String { String(localized: "home.empty.noSchedules.title", bundle: bundle) }
    public static var emptyNoSchedulesMessage: String { String(localized: "home.empty.noSchedules.message", bundle: bundle) }
    public static var emptyNoFilterTitle: String { String(localized: "home.empty.noFilter.title", bundle: bundle) }
    public static var emptyNoFilterMessage: String { String(localized: "home.empty.noFilter.message", bundle: bundle) }
    public static var emptyNoGroupsTitle: String { String(localized: "home.empty.noGroups.title", bundle: bundle) }
    public static var emptyNoGroupsMessage: String { String(localized: "home.empty.noGroups.message", bundle: bundle) }
    public static var createNewSchedule: String { String(localized: "home.empty.createSchedule", bundle: bundle) }
    public static var resetFilter: String { String(localized: "home.empty.resetFilter", bundle: bundle) }
    public static var findGroups: String { String(localized: "home.empty.findGroups", bundle: bundle) }
    public static var joinWithInviteLink: String { String(localized: "home.empty.joinWithLink", bundle: bundle) }

    // Today Schedule
    public static var todaySchedule: String { String(localized: "home.today.schedule", bundle: bundle) }
    public static func itemCount(_ count: Int) -> String {
      String(localized: "home.today.itemCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var nextScheduleUntil: String { String(localized: "home.today.nextUntil", bundle: bundle) }
    public static var startingSoon: String { String(localized: "home.today.startingSoon", bundle: bundle) }
    public static func hoursMinutes(_ hours: Int, _ minutes: Int) -> String {
      String(localized: "home.today.hoursMinutes", bundle: bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(hours)")
        .replacingOccurrences(of: "%2$lld", with: "\(minutes)")
    }
    public static func minutesOnly(_ minutes: Int) -> String {
      String(localized: "home.today.minutesOnly", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }

    // Today Empty State Messages
    public static var emptyDawnTitle: String { String(localized: "home.today.empty.dawn.title", bundle: bundle) }
    public static var emptyDawnSubtitle: String { String(localized: "home.today.empty.dawn.subtitle", bundle: bundle) }
    public static var emptyMorningTitle: String { String(localized: "home.today.empty.morning.title", bundle: bundle) }
    public static var emptyMorningSubtitle: String { String(localized: "home.today.empty.morning.subtitle", bundle: bundle) }
    public static var emptyLunchTitle: String { String(localized: "home.today.empty.lunch.title", bundle: bundle) }
    public static var emptyLunchSubtitle: String { String(localized: "home.today.empty.lunch.subtitle", bundle: bundle) }
    public static var emptyAfternoonTitle: String { String(localized: "home.today.empty.afternoon.title", bundle: bundle) }
    public static var emptyAfternoonSubtitle: String { String(localized: "home.today.empty.afternoon.subtitle", bundle: bundle) }
    public static var emptyEveningTitle: String { String(localized: "home.today.empty.evening.title", bundle: bundle) }
    public static var emptyEveningSubtitle: String { String(localized: "home.today.empty.evening.subtitle", bundle: bundle) }
    public static var emptyNightTitle: String { String(localized: "home.today.empty.night.title", bundle: bundle) }
    public static var emptyNightSubtitle: String { String(localized: "home.today.empty.night.subtitle", bundle: bundle) }

    public static var emptyRandom1Title: String { String(localized: "home.today.empty.random1.title", bundle: bundle) }
    public static var emptyRandom1Subtitle: String { String(localized: "home.today.empty.random1.subtitle", bundle: bundle) }
    public static var emptyRandom2Title: String { String(localized: "home.today.empty.random2.title", bundle: bundle) }
    public static var emptyRandom2Subtitle: String { String(localized: "home.today.empty.random2.subtitle", bundle: bundle) }
    public static var emptyRandom3Title: String { String(localized: "home.today.empty.random3.title", bundle: bundle) }
    public static var emptyRandom3Subtitle: String { String(localized: "home.today.empty.random3.subtitle", bundle: bundle) }
    public static var emptyRandom4Title: String { String(localized: "home.today.empty.random4.title", bundle: bundle) }
    public static var emptyRandom4Subtitle: String { String(localized: "home.today.empty.random4.subtitle", bundle: bundle) }
    public static var emptyRandom5Title: String { String(localized: "home.today.empty.random5.title", bundle: bundle) }
    public static var emptyRandom5Subtitle: String { String(localized: "home.today.empty.random5.subtitle", bundle: bundle) }
    public static var emptyRandom6Title: String { String(localized: "home.today.empty.random6.title", bundle: bundle) }
    public static var emptyRandom6Subtitle: String { String(localized: "home.today.empty.random6.subtitle", bundle: bundle) }
    public static var emptyRandom7Title: String { String(localized: "home.today.empty.random7.title", bundle: bundle) }
    public static var emptyRandom7Subtitle: String { String(localized: "home.today.empty.random7.subtitle", bundle: bundle) }
    public static var emptyRandom8Title: String { String(localized: "home.today.empty.random8.title", bundle: bundle) }
    public static var emptyRandom8Subtitle: String { String(localized: "home.today.empty.random8.subtitle", bundle: bundle) }
    public static var emptyRandom9Title: String { String(localized: "home.today.empty.random9.title", bundle: bundle) }
    public static var emptyRandom9Subtitle: String { String(localized: "home.today.empty.random9.subtitle", bundle: bundle) }
    public static var emptyRandom10Title: String { String(localized: "home.today.empty.random10.title", bundle: bundle) }
    public static var emptyRandom10Subtitle: String { String(localized: "home.today.empty.random10.subtitle", bundle: bundle) }
    public static var emptyRandom11Title: String { String(localized: "home.today.empty.random11.title", bundle: bundle) }
    public static var emptyRandom11Subtitle: String { String(localized: "home.today.empty.random11.subtitle", bundle: bundle) }
    public static var emptyRandom12Title: String { String(localized: "home.today.empty.random12.title", bundle: bundle) }
    public static var emptyRandom12Subtitle: String { String(localized: "home.today.empty.random12.subtitle", bundle: bundle) }

    // Complete Messages
    public static var completeDawnTitle: String { String(localized: "home.today.complete.dawn.title", bundle: bundle) }
    public static var completeMorningTitle: String { String(localized: "home.today.complete.morning.title", bundle: bundle) }
    public static var completeLunchTitle: String { String(localized: "home.today.complete.lunch.title", bundle: bundle) }
    public static var completeAfternoonTitle: String { String(localized: "home.today.complete.afternoon.title", bundle: bundle) }
    public static var completeEveningTitle: String { String(localized: "home.today.complete.evening.title", bundle: bundle) }
    public static var completeNightTitle: String { String(localized: "home.today.complete.night.title", bundle: bundle) }

    public static var completeRandom1Title: String { String(localized: "home.today.complete.random1.title", bundle: bundle) }
    public static var completeRandom2Title: String { String(localized: "home.today.complete.random2.title", bundle: bundle) }
    public static var completeRandom3Title: String { String(localized: "home.today.complete.random3.title", bundle: bundle) }
    public static var completeRandom4Title: String { String(localized: "home.today.complete.random4.title", bundle: bundle) }
    public static var completeRandom5Title: String { String(localized: "home.today.complete.random5.title", bundle: bundle) }
    public static var completeRandom6Title: String { String(localized: "home.today.complete.random6.title", bundle: bundle) }

    // Upcoming
    public static var upcomingSchedule: String { String(localized: "home.upcoming.title", bundle: bundle) }
    public static var noUpcomingTitle: String { String(localized: "home.upcoming.empty.title", bundle: bundle) }
    public static var noUpcomingSubtitle: String { String(localized: "home.upcoming.empty.subtitle", bundle: bundle) }
    public static var noRecurringTitle: String { String(localized: "home.upcoming.recurring.empty.title", bundle: bundle) }
    public static var noRecurringSubtitle: String { String(localized: "home.upcoming.recurring.empty.subtitle", bundle: bundle) }
    public static var createScheduleDialogTitle: String { String(localized: "home.upcoming.createDialog.title", bundle: bundle) }
    public static var createPersonalEvent: String { String(localized: "home.upcoming.createDialog.personalEvent", bundle: bundle) }
    public static var createGroupSchedule: String { String(localized: "home.upcoming.createDialog.groupSchedule", bundle: bundle) }
    public static func recurringCount(_ count: Int) -> String {
      String(localized: "home.upcoming.recurringCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func participantsConfirmed(_ count: Int) -> String {
      String(localized: "home.upcoming.participantsConfirmed", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func groupParticipants(_ group: String, _ count: Int) -> String {
      String(localized: "home.upcoming.groupParticipants", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: group)
        .replacingOccurrences(of: "%2$lld", with: "\(count)")
    }

    // PersonalEventTimeline
    public static var personalLabel: String { String(localized: "home.personalEvent.label", bundle: bundle) }
    public static func reminderHoursBefore(_ hours: Int) -> String {
      String(localized: "home.personalEvent.reminderHours", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(hours)")
    }
    public static func reminderMinutesBefore(_ minutes: Int) -> String {
      String(localized: "home.personalEvent.reminderMinutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static var briefingTitle: String { String(localized: "home.briefing.title", bundle: bundle) }
    public static var briefingReportIssue: String { String(localized: "home.briefing.reportIssue", bundle: bundle) }
    public static var briefingReportMailSubject: String {
      String(localized: "home.briefing.reportMail.subject", bundle: bundle)
    }
    public static func briefingReportMailBody(
      _ uid: String,
      _ generatedAt: String,
      _ summary: String,
      _ detail: String,
      _ notificationEnabled: String,
      _ locationEnabled: String,
      _ timeZone: String,
      _ locale: String
    ) -> String {
      String(localized: "home.briefing.reportMail.body", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: uid)
        .replacingOccurrences(of: "%2$@", with: generatedAt)
        .replacingOccurrences(of: "%3$@", with: summary)
        .replacingOccurrences(of: "%4$@", with: detail)
        .replacingOccurrences(of: "%5$@", with: notificationEnabled)
        .replacingOccurrences(of: "%6$@", with: locationEnabled)
        .replacingOccurrences(of: "%7$@", with: timeZone)
        .replacingOccurrences(of: "%8$@", with: locale)
    }
    public static var briefingNotificationOffMessage: String {
      String(localized: "home.briefing.notificationOffMessage", bundle: bundle)
    }
    public static var briefingLocationOffMessage: String {
      String(localized: "home.briefing.locationOffMessage", bundle: bundle)
    }

    // Timeline
    public static var startLiveSharing: String { String(localized: "home.timeline.startLiveSharing", bundle: bundle) }
    public static var departurePrompt: String { String(localized: "home.timeline.departurePrompt", bundle: bundle) }
    public static func departureAlertDone(_ time: String) -> String {
      String(localized: "home.timeline.departureAlertDone", bundle: bundle)
        .replacingOccurrences(of: "%@", with: time)
    }
    public static func departureAlertUpcoming(_ time: String) -> String {
      String(localized: "home.timeline.departureAlertUpcoming", bundle: bundle)
        .replacingOccurrences(of: "%@", with: time)
    }

    // StatusFilter display titles
    public static var filterAll: String { String(localized: "home.filter.all", bundle: bundle) }
    public static var filterNeedResponse: String { String(localized: "home.filter.needResponse", bundle: bundle) }
    public static var filterConfirmed: String { String(localized: "home.filter.confirmed", bundle: bundle) }
    public static var filterInProgress: String { String(localized: "home.filter.inProgress", bundle: bundle) }

    // Now label
    public static var timelineNow: String { String(localized: "home.timeline.now", bundle: bundle) }

    // Transport
    public static var transportTitle: String { String(localized: "home.transport.title", bundle: bundle) }
    public static var transportMapAppDialog: String { String(localized: "home.transport.mapAppDialog", bundle: bundle) }
    public static var transportCurrentLocation: String { String(localized: "home.transport.currentLocation", bundle: bundle) }
    public static var transportDriving: String { String(localized: "home.transport.type.driving", bundle: bundle) }
    public static var transportTransit: String { String(localized: "home.transport.type.transit", bundle: bundle) }
    public static var transportWalking: String { String(localized: "home.transport.type.walking", bundle: bundle) }
    public static var transportMapAppKakao: String { String(localized: "home.transport.mapApp.kakao", bundle: bundle) }
    public static var transportMapAppNaver: String { String(localized: "home.transport.mapApp.naver", bundle: bundle) }
    public static var transportRouteDetailTitle: String { String(localized: "home.transport.routeDetail", bundle: bundle) }
    public static var transportDuration: String { String(localized: "home.transport.info.duration", bundle: bundle) }
    public static var transportTotalDuration: String { String(localized: "home.transport.info.totalDuration", bundle: bundle) }
    public static var transportExpectedDeparture: String { String(localized: "home.transport.info.expectedDeparture", bundle: bundle) }
    public static var transportToll: String { String(localized: "home.transport.info.toll", bundle: bundle) }
    public static func transportTollAmount(_ amount: String) -> String {
      String(localized: "home.transport.info.tollAmount", bundle: bundle)
        .replacingOccurrences(of: "%@", with: amount)
    }
    public static var transportFare: String { String(localized: "home.transport.info.fare", bundle: bundle) }
    public static var transportTransfers: String { String(localized: "home.transport.info.transfers", bundle: bundle) }
    public static var transportDistance: String { String(localized: "home.transport.info.distance", bundle: bundle) }
    public static var transportBufferTime: String { String(localized: "home.transport.bufferTime", bundle: bundle) }
    public static var transportNoBuffer: String { String(localized: "home.transport.buffer.none", bundle: bundle) }
    public static var transportNoBufferAccessibility: String { String(localized: "home.transport.buffer.none.accessibility", bundle: bundle) }
    public static var transportOpenInMap: String { String(localized: "home.transport.openInMap", bundle: bundle) }
    public static var transportNotifyWithThis: String { String(localized: "home.transport.notifyWithThis", bundle: bundle) }
    public static var transportSubway: String { String(localized: "home.transport.subway", bundle: bundle) }
    public static var transportBus: String { String(localized: "home.transport.bus", bundle: bundle) }
    public static var transportWalkingNotRecommended: String { String(localized: "home.transport.walkingNotRecommended", bundle: bundle) }
    public static func transportApproxMinutes(_ minutes: Int) -> String {
      String(localized: "home.transport.approxMinutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static var routeTagFastest: String { String(localized: "home.transport.routeTag.fastest", bundle: bundle) }
    public static var routeTagLeastTransfers: String { String(localized: "home.transport.routeTag.leastTransfers", bundle: bundle) }
    public static var routeTagCheapest: String { String(localized: "home.transport.routeTag.cheapest", bundle: bundle) }

    // Departure Alert
    public static var departureDetail: String { String(localized: "home.departure.detail", bundle: bundle) }
    public static var departureStart: String { String(localized: "home.departure.start", bundle: bundle) }
    public static var departureArrival: String { String(localized: "home.departure.arrival", bundle: bundle) }
    public static var departureChangeOrigin: String { String(localized: "home.departure.changeOrigin", bundle: bundle) }
    public static var departureTransportSection: String { String(localized: "home.departure.transportSection", bundle: bundle) }
    public static var departureTimePassed: String { String(localized: "home.departure.timePassed", bundle: bundle) }
    public static var departureNotRecommended: String { String(localized: "home.departure.notRecommended", bundle: bundle) }
    public static var departureAlertButton: String { String(localized: "home.departure.alertButton", bundle: bundle) }
    public static var departureAlertScheduled: String { String(localized: "home.departure.alertScheduled", bundle: bundle) }
    public static var departureLoadFailed: String { String(localized: "home.departure.loadFailed", bundle: bundle) }
    public static var departureOpenSettings: String { String(localized: "home.departure.openSettings", bundle: bundle) }
    public static var departureLocationPermissionRequired: String {
      String(localized: "home.departure.locationPermissionRequired", bundle: bundle)
    }
    public static var departureLocationPermissionMessage: String { String(localized: "home.departure.locationPermissionMessage", bundle: bundle) }
    public static var departureTransportLoadFailed: String {
      String(localized: "home.departure.transportLoadFailed", bundle: bundle)
    }
    public static func departureNotificationTitleSoon(_ title: String) -> String {
      String(localized: "home.departure.notification.title.soon", bundle: bundle)
        .replacingOccurrences(of: "%@", with: title)
    }
    public static func departureNotificationTitleNow(_ title: String) -> String {
      String(localized: "home.departure.notification.title.now", bundle: bundle)
        .replacingOccurrences(of: "%@", with: title)
    }
    public static func departureNotificationTitleReady(_ title: String) -> String {
      String(localized: "home.departure.notification.title.ready", bundle: bundle)
        .replacingOccurrences(of: "%@", with: title)
    }
    public static func departureNotificationBodySoonWithBuffer(_ time: String, _ transport: String, _ duration: Int, _ buffer: Int) -> String {
      String(localized: "home.departure.notification.body.soon.buffer", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: time)
        .replacingOccurrences(of: "%2$@", with: transport)
        .replacingOccurrences(of: "%3$lld", with: "\(duration)")
        .replacingOccurrences(of: "%4$lld", with: "\(buffer)")
    }
    public static func departureNotificationBodySoon(_ time: String, _ transport: String, _ duration: Int) -> String {
      String(localized: "home.departure.notification.body.soon.noBuffer", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: time)
        .replacingOccurrences(of: "%2$@", with: transport)
        .replacingOccurrences(of: "%3$lld", with: "\(duration)")
    }
    public static func departureNotificationBodyNowWithBuffer(_ time: String, _ transport: String, _ duration: Int, _ buffer: Int) -> String {
      String(localized: "home.departure.notification.body.now.buffer", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: time)
        .replacingOccurrences(of: "%2$@", with: transport)
        .replacingOccurrences(of: "%3$lld", with: "\(duration)")
        .replacingOccurrences(of: "%4$lld", with: "\(buffer)")
    }
    public static func departureNotificationBodyNow(_ time: String, _ transport: String, _ duration: Int) -> String {
      String(localized: "home.departure.notification.body.now.noBuffer", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: time)
        .replacingOccurrences(of: "%2$@", with: transport)
        .replacingOccurrences(of: "%3$lld", with: "\(duration)")
    }
    public static func departureNotificationBodyReadyWithBuffer(_ time: String, _ transport: String, _ duration: Int, _ buffer: Int) -> String {
      String(localized: "home.departure.notification.body.ready.buffer", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: time)
        .replacingOccurrences(of: "%2$@", with: transport)
        .replacingOccurrences(of: "%3$lld", with: "\(duration)")
        .replacingOccurrences(of: "%4$lld", with: "\(buffer)")
    }
    public static func departureNotificationBodyReady(_ time: String, _ transport: String, _ duration: Int) -> String {
      String(localized: "home.departure.notification.body.ready.noBuffer", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: time)
        .replacingOccurrences(of: "%2$@", with: transport)
        .replacingOccurrences(of: "%3$lld", with: "\(duration)")
    }
    public static func departureSelectionNoBuffer(_ transport: String, _ time: String) -> String {
      String(localized: "home.departure.selection.noBuffer", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: transport)
        .replacingOccurrences(of: "%2$@", with: time)
    }
    public static func departureSelectionWithBuffer(_ transport: String, _ time: String, _ buffer: Int) -> String {
      String(localized: "home.departure.selection.withBuffer", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: transport)
        .replacingOccurrences(of: "%2$@", with: time)
        .replacingOccurrences(of: "%3$lld", with: "\(buffer)")
    }
  }

  // MARK: - Shared (SharedFeature)
  public enum Shared {
    // Edit Schedule
    public static var editScheduleTitle: String { String(localized: "shared.editSchedule.title", bundle: bundle) }
    public static var editFailed: String { String(localized: "shared.editSchedule.failed", bundle: bundle) }
    public static var scheduleTitlePlaceholder: String { String(localized: "shared.editSchedule.titlePlaceholder", bundle: bundle) }
    public static var optional: String { String(localized: "shared.editSchedule.optional", bundle: bundle) }
    public static var addLocation: String { String(localized: "shared.editSchedule.addLocation", bundle: bundle) }
    public static var minimumParticipants: String { String(localized: "shared.editSchedule.minimumParticipants", bundle: bundle) }
    public static func maxMembers(_ count: Int) -> String {
      String(localized: "shared.editSchedule.maxMembers", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func minMembersDescription(_ count: Int) -> String {
      String(localized: "shared.editSchedule.minMembersDescription", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var liveSharing: String { String(localized: "shared.editSchedule.liveSharing", bundle: bundle) }
    public static func liveStartMinutes(_ minutes: Int) -> String {
      String(localized: "shared.editSchedule.liveStartMinutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static func liveSharingDescription(_ minutes: Int) -> String {
      String(localized: "shared.editSchedule.liveSharingDescription", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static var manualStart: String { String(localized: "shared.editSchedule.manualStart", bundle: bundle) }
    public static func minutesBefore(_ minutes: Int) -> String {
      String(localized: "shared.editSchedule.minutesBefore", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static var minutesBeforeStartLabel: String { String(localized: "shared.editSchedule.minutesBeforeStartLabel", bundle: bundle) }

    // Schedule Detail
    public static var voteDeadline: String { String(localized: "shared.scheduleDetail.voteDeadline", bundle: bundle) }
    public static var minimumConfirmMembers: String { String(localized: "shared.scheduleDetail.minimumConfirm", bundle: bundle) }
    public static func membersCount(_ count: Int) -> String {
      String(localized: "shared.scheduleDetail.membersCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var participantsSection: String { String(localized: "shared.scheduleDetail.participants", bundle: bundle) }
    public static func participantsJoined(_ current: Int, _ total: Int) -> String {
      String(localized: "shared.scheduleDetail.participantsJoined", bundle: bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(current)")
        .replacingOccurrences(of: "%2$lld", with: "\(total)")
    }
    public static var responseAccepted: String { String(localized: "shared.scheduleDetail.accepted", bundle: bundle) }
    public static var responseDeclined: String { String(localized: "shared.scheduleDetail.declined", bundle: bundle) }
    public static var responseNoAnswer: String { String(localized: "shared.scheduleDetail.noAnswer", bundle: bundle) }
    public static var myResponse: String { String(localized: "shared.scheduleDetail.myResponse", bundle: bundle) }
    public static var editSchedule: String { String(localized: "shared.scheduleDetail.edit", bundle: bundle) }
    public static var deleteSchedule: String { String(localized: "shared.scheduleDetail.delete", bundle: bundle) }
    public static var undetermined: String { String(localized: "shared.scheduleDetail.undetermined", bundle: bundle) }
    public static func deleteScheduleConfirm(_ title: String) -> String {
      String(localized: "shared.scheduleDetail.deleteConfirm", bundle: bundle)
        .replacingOccurrences(of: "%@", with: title)
    }

    // Schedule Detail Status
    public static var statusNeedResponse: String { String(localized: "shared.scheduleDetail.status.needResponse", bundle: bundle) }
    public static var statusWaitingConfirm: String { String(localized: "shared.scheduleDetail.status.waitingConfirm", bundle: bundle) }
    public static var statusConfirmed: String { String(localized: "shared.scheduleDetail.status.confirmed", bundle: bundle) }
    public static var statusFailed: String { String(localized: "shared.scheduleDetail.status.failed", bundle: bundle) }

    // Location Picker
    public static var locationSearch: String { String(localized: "shared.location.search", bundle: bundle) }
    public static var searchPlaceholder: String { String(localized: "shared.location.searchPlaceholder", bundle: bundle) }
    public static var recentSearch: String { String(localized: "shared.location.recentSearch", bundle: bundle) }
    public static var noSearchResults: String { String(localized: "shared.location.noResults", bundle: bundle) }
    public static var tryOtherKeyword: String { String(localized: "shared.location.tryOther", bundle: bundle) }
    public static var searchError: String { String(localized: "shared.location.searchError", bundle: bundle) }
    public static var selectThisLocation: String { String(localized: "shared.location.select", bundle: bundle) }
    public static var searchLocationHint: String { String(localized: "shared.location.searchHint", bundle: bundle) }
    public static var searchExamples: String { String(localized: "shared.location.searchExamples", bundle: bundle) }

    // Notification Permission
    public static var goToSettings: String { String(localized: "shared.notification.goToSettings", bundle: bundle) }
    public static var notificationTitle: String { String(localized: "shared.notification.title", bundle: bundle) }
    public static var notificationSubtitle: String { String(localized: "shared.notification.subtitle", bundle: bundle) }
    public static var notificationPreviewTitle: String { String(localized: "shared.notification.previewTitle", bundle: bundle) }
    public static var notificationPreviewBody: String { String(localized: "shared.notification.previewBody", bundle: bundle) }
    public static var allowNotification: String { String(localized: "shared.notification.allow", bundle: bundle) }
    public static var permissionTitle: String { String(localized: "shared.notification.permissionTitle", bundle: bundle) }
    public static var benefitInvite: String { String(localized: "shared.notification.benefit.invite", bundle: bundle) }
    public static var benefitConfirm: String { String(localized: "shared.notification.benefit.confirm", bundle: bundle) }
    public static var benefitMember: String { String(localized: "shared.notification.benefit.member", bundle: bundle) }
    public static var benefitChange: String { String(localized: "shared.notification.benefit.change", bundle: bundle) }
    public static var now: String { String(localized: "shared.notification.now", bundle: bundle) }

    // Personal Event Detail
    public static var deleteEvent: String { String(localized: "shared.personalDetail.deleteEvent", bundle: bundle) }
    public static func deleteEventConfirm(_ title: String) -> String {
      String(localized: "shared.personalDetail.deleteConfirm", bundle: bundle)
        .replacingOccurrences(of: "%@", with: title)
    }
    public static var statusOngoing: String { String(localized: "shared.personalDetail.status.ongoing", bundle: bundle) }
    public static var statusEnded: String { String(localized: "shared.personalDetail.status.ended", bundle: bundle) }
    public static var statusToday: String { String(localized: "shared.personalDetail.status.today", bundle: bundle) }
    public static var statusUpcoming: String { String(localized: "shared.personalDetail.status.upcoming", bundle: bundle) }
    public static func reminderHours(_ hours: Int) -> String {
      String(localized: "shared.personalDetail.reminderHours", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(hours)")
    }
    public static func reminderMinutes(_ minutes: Int) -> String {
      String(localized: "shared.personalDetail.reminderMinutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }

    // Create Personal Event
    public static var newEvent: String { String(localized: "shared.createEvent.new", bundle: bundle) }
    public static var editEvent: String { String(localized: "shared.createEvent.edit", bundle: bundle) }
    public static var eventTitlePlaceholder: String { String(localized: "shared.createEvent.titlePlaceholder", bundle: bundle) }
    public static var reminderLabel: String { String(localized: "shared.createEvent.reminder", bundle: bundle) }
    public static var memoPlaceholder: String { String(localized: "shared.createEvent.memoPlaceholder", bundle: bundle) }

    // Reminder Options
    public static var reminder5min: String { String(localized: "shared.reminder.5min", bundle: bundle) }
    public static var reminder10min: String { String(localized: "shared.reminder.10min", bundle: bundle) }
    public static var reminder15min: String { String(localized: "shared.reminder.15min", bundle: bundle) }
    public static var reminder30min: String { String(localized: "shared.reminder.30min", bundle: bundle) }
    public static var reminder1hour: String { String(localized: "shared.reminder.1hour", bundle: bundle) }
    public static var reminder2hours: String { String(localized: "shared.reminder.2hours", bundle: bundle) }
    public static var reminderNone: String { String(localized: "shared.reminder.none", bundle: bundle) }
    public static var reminderAtEvent: String { String(localized: "shared.reminder.atEvent", bundle: bundle) }
    public static var reminder1day: String { String(localized: "shared.reminder.1day", bundle: bundle) }
    public static var reminder2days: String { String(localized: "shared.reminder.2days", bundle: bundle) }
    public static var reminder1week: String { String(localized: "shared.reminder.1week", bundle: bundle) }

    // Image Attachment
    public static var imageUploading: String { String(localized: "shared.image.uploading", bundle: bundle) }

    // Conflict Warning
    public static var conflictChecking: String { String(localized: "shared.conflict.checking", bundle: bundle) }
    public static var conflictCheckingEvents: String { String(localized: "shared.conflict.checkingEvents", bundle: bundle) }
    public static var conflictOverlappingEvents: String { String(localized: "shared.conflict.overlappingEvents", bundle: bundle) }
    public static var conflictNewEvent: String { String(localized: "shared.conflict.newEvent", bundle: bundle) }
    public static var conflictExistingEvent: String { String(localized: "shared.conflict.existingEvent", bundle: bundle) }
    public static var conflictOverlap: String { String(localized: "shared.conflict.overlap", bundle: bundle) }
    public static func conflictCount(_ count: Int) -> String {
      String(localized: "shared.conflict.count", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func conflictFocusedOn(_ title: String) -> String {
      String(localized: "shared.conflict.focusedOn", bundle: bundle)
        .replacingOccurrences(of: "%@", with: title)
    }
    public static func conflictMarginHoursMinutes(_ hours: Int, _ remaining: Int) -> String {
      String(localized: "shared.conflict.margin.hoursMinutes", bundle: bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(hours)")
        .replacingOccurrences(of: "%2$lld", with: "\(remaining)")
    }
    public static func conflictMarginHours(_ hours: Int) -> String {
      String(localized: "shared.conflict.margin.hours", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(hours)")
    }
    public static func conflictMarginMinutes(_ minutes: Int) -> String {
      String(localized: "shared.conflict.margin.minutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static func conflictOverlapHoursMinutes(_ hours: Int, _ remaining: Int) -> String {
      String(localized: "shared.conflict.overlap.hoursMinutes", bundle: bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(hours)")
        .replacingOccurrences(of: "%2$lld", with: "\(remaining)")
    }
    public static func conflictOverlapHours(_ hours: Int) -> String {
      String(localized: "shared.conflict.overlap.hours", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(hours)")
    }
    public static func conflictOverlapMinutes(_ minutes: Int) -> String {
      String(localized: "shared.conflict.overlap.minutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }

    // Weather
    public static func weatherCheckingWithLocation(_ name: String) -> String {
      String(localized: "shared.weather.checkingWithLocation", bundle: bundle)
        .replacingOccurrences(of: "%@", with: name)
    }
    public static var weatherChecking: String { String(localized: "shared.weather.checking", bundle: bundle) }
  }

  // MARK: - Calendar
  public enum Calendar {
    public static var loadingSchedules: String { String(localized: "calendar.loading", bundle: bundle) }
    public static var noSchedulesTitle: String { String(localized: "calendar.empty.title", bundle: bundle) }
    public static var createNewSchedule: String { String(localized: "calendar.empty.subtitle", bundle: bundle) }
    public static var monthSchedule: String { String(localized: "calendar.monthSchedule", bundle: bundle) }
    public static func dayCount(_ count: Int) -> String {
      String(localized: "calendar.dayCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }

    // Weekday
    public static var weekdaySun: String { String(localized: "calendar.weekday.sun", bundle: bundle) }
    public static var weekdayMon: String { String(localized: "calendar.weekday.mon", bundle: bundle) }
    public static var weekdayTue: String { String(localized: "calendar.weekday.tue", bundle: bundle) }
    public static var weekdayWed: String { String(localized: "calendar.weekday.wed", bundle: bundle) }
    public static var weekdayThu: String { String(localized: "calendar.weekday.thu", bundle: bundle) }
    public static var weekdayFri: String { String(localized: "calendar.weekday.fri", bundle: bundle) }
    public static var weekdaySat: String { String(localized: "calendar.weekday.sat", bundle: bundle) }

    /// 설정에 따라 정렬된 요일 심볼 배열
    public static func orderedWeekdaySymbols(startOnMonday: Bool) -> [String] {
      if startOnMonday {
        return [weekdayMon, weekdayTue, weekdayWed, weekdayThu, weekdayFri, weekdaySat, weekdaySun]
      } else {
        return [weekdaySun, weekdayMon, weekdayTue, weekdayWed, weekdayThu, weekdayFri, weekdaySat]
      }
    }

    // Calendar Permission Banner
    public static var syncCalendarTitle: String { String(localized: "calendar.sync.title", bundle: bundle) }
    public static var syncCalendarSubtitle: String { String(localized: "calendar.sync.subtitle", bundle: bundle) }
    public static var syncAction: String { String(localized: "calendar.sync.action", bundle: bundle) }
    public static var readAccessTitle: String { String(localized: "calendar.sync.readAccess.title", bundle: bundle) }
    public static var readAccessSubtitle: String { String(localized: "calendar.sync.readAccess.subtitle", bundle: bundle) }
    public static var calendarPermissionTitle: String { String(localized: "calendar.sync.permission.title", bundle: bundle) }
    public static var calendarPermissionSubtitle: String { String(localized: "calendar.sync.permission.subtitle", bundle: bundle) }
    public static var doNotShowAgain: String { String(localized: "calendar.sync.doNotShow", bundle: bundle) }

    // Day Detail
    public static var noSchedules: String { String(localized: "calendar.dayDetail.noSchedules", bundle: bundle) }
    public static var dayPeriodMorning: String { String(localized: "calendar.dayPeriod.morning", bundle: bundle) }
    public static var dayPeriodAfternoon: String { String(localized: "calendar.dayPeriod.afternoon", bundle: bundle) }
    public static var dayPeriodNight: String { String(localized: "calendar.dayPeriod.night", bundle: bundle) }

    // Weather Permission
    public static var weatherPermissionTitle: String { String(localized: "calendar.weather.permission.title", bundle: bundle) }
    public static var weatherPermissionDescription: String { String(localized: "calendar.weather.permission.description", bundle: bundle) }

    // Weather Denied
    public static var weatherDeniedTitle: String { String(localized: "calendar.weather.denied.title", bundle: bundle) }
    public static var weatherDeniedDescription: String { String(localized: "calendar.weather.denied.description", bundle: bundle) }

    // Weather Failed
    public static var weatherFailedTitle: String { String(localized: "calendar.weather.failed.title", bundle: bundle) }
    public static var weatherFailedDescription: String { String(localized: "calendar.weather.failed.description", bundle: bundle) }
    public static var weatherCurrentLocation: String { String(localized: "calendar.weather.currentLocation", bundle: bundle) }
    public static func weatherReference(_ value: String) -> String {
      String(localized: "calendar.weather.reference", bundle: bundle)
        .replacingOccurrences(of: "%@", with: value)
    }

    // Weather Detail
    public static var weatherDetailTitle: String { String(localized: "calendar.weather.detail.title", bundle: bundle) }
    public static var weatherHourlyTitle: String { String(localized: "calendar.weather.hourly.title", bundle: bundle) }
    public static var weatherWeeklyTitle: String { String(localized: "calendar.weather.weekly.title", bundle: bundle) }
    public static var weatherSuggestionsTitle: String { String(localized: "calendar.weather.suggestions.title", bundle: bundle) }
    public static func weatherFeelsLike(_ temp: String) -> String {
      String(localized: "calendar.weather.feelsLike", bundle: bundle)
        .replacingOccurrences(of: "%@", with: temp)
    }
    public static var weatherToday: String { String(localized: "calendar.weather.today", bundle: bundle) }
    public static var weatherTomorrow: String { String(localized: "calendar.weather.tomorrow", bundle: bundle) }
    public static func weatherMinMax(_ low: String, _ high: String) -> String {
      String(localized: "calendar.weather.minMax", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: low)
        .replacingOccurrences(of: "%2$@", with: high)
    }

    // Schedule Card Status
    public static var statusWaiting: String { String(localized: "calendar.schedule.statusWaiting", bundle: bundle) }
    public static var statusVoting: String { String(localized: "calendar.schedule.statusVoting", bundle: bundle) }
    public static var statusConfirmed: String { String(localized: "calendar.schedule.statusConfirmed", bundle: bundle) }
    public static var statusFailed: String { String(localized: "calendar.schedule.statusFailed", bundle: bundle) }
    public static var statusExpired: String { String(localized: "calendar.schedule.statusExpired", bundle: bundle) }
    public static var respondAction: String { String(localized: "calendar.schedule.respond", bundle: bundle) }
    public static func additionalItems(_ count: Int) -> String {
      String(localized: "calendar.schedule.additionalItems", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }

    // Schedule Creation
    public static var addSchedule: String { String(localized: "calendar.schedule.add", bundle: bundle) }
    public static var personalSchedule: String { String(localized: "calendar.schedule.personal", bundle: bundle) }
    public static var groupSchedule: String { String(localized: "calendar.schedule.group", bundle: bundle) }
    public static var cannotCreatePastSchedule: String { String(localized: "calendar.schedule.cannotCreatePast", bundle: bundle) }

    // Context Menu
    public static var viewSchedule: String { String(localized: "calendar.contextMenu.viewSchedule", bundle: bundle) }
    public static var addPersonalEvent: String { String(localized: "calendar.contextMenu.addPersonalEvent", bundle: bundle) }
    public static var createSchedule: String { String(localized: "calendar.contextMenu.createSchedule", bundle: bundle) }

    // Filter
    public static var filterTitle: String { String(localized: "calendar.filter.title", bundle: bundle) }
    public static var filterSelectAll: String { String(localized: "calendar.filter.selectAll", bundle: bundle) }
    public static var filterGroup: String { String(localized: "calendar.filter.group", bundle: bundle) }
    public static var filterPersonal: String { String(localized: "calendar.filter.personal", bundle: bundle) }
    public static var filterStatusDescription: String {
      String(localized: "calendar.filter.statusDescription", bundle: bundle)
    }
    public static var filterCalendarEvents: String { String(localized: "calendar.filter.calendarEvents", bundle: bundle) }
    public static var filterStatus: String { String(localized: "calendar.filter.status", bundle: bundle) }
    public static var filterStatusNeedResponse: String { String(localized: "calendar.filter.status.needResponse", bundle: bundle) }
    public static var filterStatusWaiting: String { String(localized: "calendar.filter.status.waiting", bundle: bundle) }
    public static var filterStatusConfirmed: String { String(localized: "calendar.filter.status.confirmed", bundle: bundle) }
    public static var filterStatusCompleted: String { String(localized: "calendar.filter.status.completed", bundle: bundle) }
    public static var filterStatusFailed: String { String(localized: "calendar.filter.status.failed", bundle: bundle) }

    // Display Mode
    public static var modeWeek: String { String(localized: "calendar.mode.week", bundle: bundle) }
    public static var modeMonth: String { String(localized: "calendar.mode.month", bundle: bundle) }
    public static var modeMonthExpanded: String { String(localized: "calendar.mode.monthExpanded", bundle: bundle) }
    public static var modeWeekDescription: String { String(localized: "calendar.mode.week.description", bundle: bundle) }
    public static var modeMonthDescription: String { String(localized: "calendar.mode.month.description", bundle: bundle) }
    public static var modeMonthExpandedDescription: String { String(localized: "calendar.mode.monthExpanded.description", bundle: bundle) }

    // Indicator
    public static var indicatorPersonal: String { String(localized: "calendar.indicator.personal", bundle: bundle) }
    public static var indicatorCalendar: String { String(localized: "calendar.indicator.calendar", bundle: bundle) }
    public static func indicatorEventCount(_ count: Int) -> String {
      String(localized: "calendar.indicator.eventCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }

    // Calendar Event Detail
    public static var calendarEventSource: String { String(localized: "calendar.event.source", bundle: bundle) }
    public static var openInCalendarApp: String { String(localized: "calendar.event.openInCalendar", bundle: bundle) }
  }

  // MARK: - Personal
  public enum Personal {
    public static var emptyToday: String { String(localized: "personal.empty.today", bundle: bundle) }
    public static var emptyFuture: String { String(localized: "personal.empty.future", bundle: bundle) }
    public static var emptyAll: String { String(localized: "personal.empty.all", bundle: bundle) }
    public static var emptyPast: String { String(localized: "personal.empty.past", bundle: bundle) }
    public static var emptyRecurring: String { String(localized: "personal.empty.recurring", bundle: bundle) }
    public static var viewDetail: String { String(localized: "personal.event.viewDetail", bundle: bundle) }
    public static func photoCount(_ count: Int) -> String {
      String(localized: "personal.event.photoCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var reminderSent: String { String(localized: "personal.event.reminderSent", bundle: bundle) }
    public static var reminderAtEvent: String { String(localized: "personal.event.reminderAtEvent", bundle: bundle) }
    public static var reminderConfigured: String { String(localized: "personal.event.reminderConfigured", bundle: bundle) }
    public static func reminderHours(_ hours: Int) -> String {
      String(localized: "personal.event.reminderHours", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(hours)")
    }
    public static func reminderDays(_ days: Int) -> String {
      String(localized: "personal.event.reminderDays", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(days)")
    }
    public static func reminderWeeks(_ weeks: Int) -> String {
      String(localized: "personal.event.reminderWeeks", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(weeks)")
    }
    public static func reminderMinutes(_ minutes: Int) -> String {
      String(localized: "personal.event.reminderMinutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static var statusEnded: String { String(localized: "personal.event.status.ended", bundle: bundle) }
    public static var statusToday: String { String(localized: "personal.event.status.today", bundle: bundle) }
    public static var statusUpcoming: String { String(localized: "personal.event.status.upcoming", bundle: bundle) }
    public static var filterToday: String { String(localized: "personal.filter.today", bundle: bundle) }
    public static var filterFuture: String { String(localized: "personal.filter.future", bundle: bundle) }
    public static var filterAll: String { String(localized: "personal.filter.all", bundle: bundle) }
    public static var filterPast: String { String(localized: "personal.filter.past", bundle: bundle) }
    public static var filterRecurring: String { String(localized: "personal.filter.recurring", bundle: bundle) }
    public static var notificationStartsNow: String { String(localized: "personal.event.notification.startsNow", bundle: bundle) }
    public static func notificationStartsInWeeks(_ weeks: Int) -> String {
      String(localized: "personal.event.notification.startsInWeeks", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(weeks)")
    }
    public static func notificationStartsInDays(_ days: Int) -> String {
      String(localized: "personal.event.notification.startsInDays", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(days)")
    }
    public static func notificationStartsInHours(_ hours: Int) -> String {
      String(localized: "personal.event.notification.startsInHours", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(hours)")
    }
    public static func notificationStartsInMinutes(_ minutes: Int) -> String {
      String(localized: "personal.event.notification.startsInMinutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static var addPersonalEvent: String { String(localized: "personal.add.personalEvent", bundle: bundle) }
    public static var addRecurringEvent: String { String(localized: "personal.add.recurringEvent", bundle: bundle) }
    public static var reminderTooSoonWarning: String {
      String(localized: "personal.event.reminderTooSoonWarning", bundle: bundle)
    }
    public static var recurrenceFrequency: String { String(localized: "personal.recurrence.frequency", bundle: bundle) }
    public static var recurrenceDaily: String { String(localized: "personal.recurrence.daily", bundle: bundle) }
    public static var recurrenceWeekly: String { String(localized: "personal.recurrence.weekly", bundle: bundle) }
    public static var recurrenceMonthly: String { String(localized: "personal.recurrence.monthly", bundle: bundle) }
    public static var recurrenceDayOfMonth: String {
      String(localized: "personal.recurrence.dayOfMonth", bundle: bundle)
    }
    public static func recurrenceDayOfMonthValue(_ day: Int) -> String {
      String(localized: "personal.recurrence.dayOfMonthValue", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(day)")
    }
    public static var recurringDetailTitle: String { String(localized: "personal.recurringDetail.title", bundle: bundle) }
    public static var recurringDetailExcludeInstance: String {
      String(localized: "personal.recurringDetail.excludeInstance", bundle: bundle)
    }
    public static var recurringDeleteSeries: String {
      String(localized: "personal.recurringDetail.deleteSeries", bundle: bundle)
    }
    public static var recurringDeleteOptionsMessage: String {
      String(localized: "personal.recurringDetail.deleteOptionsMessage", bundle: bundle)
    }
    public static var recurringDetailRule: String { String(localized: "personal.recurringDetail.rule", bundle: bundle) }
    public static var recurringDetailStartDate: String {
      String(localized: "personal.recurringDetail.startDate", bundle: bundle)
    }
    public static var recurringDetailEndDate: String { String(localized: "personal.recurringDetail.endDate", bundle: bundle) }
    public static var recurringDetailEndTime: String { String(localized: "personal.recurringDetail.endTime", bundle: bundle) }
    public static var recurringDeleteSeriesMessage: String {
      String(localized: "personal.recurringDetail.deleteSeriesMessage", bundle: bundle)
    }
  }

  // MARK: - ProPlan
  public enum ProPlan {
    public static var manageTitle: String { String(localized: "proPlan.manage.title", bundle: bundle) }
    public static var manageAction: String { String(localized: "proPlan.manage.action", bundle: bundle) }
    public static var subscriptionInfo: String { String(localized: "proPlan.manage.subscriptionInfo", bundle: bundle) }
    public static var status: String { String(localized: "proPlan.manage.status", bundle: bundle) }
    public static var plan: String { String(localized: "proPlan.manage.plan", bundle: bundle) }
    public static func planValue(_ name: String) -> String {
      String(localized: "proPlan.manage.planValue", bundle: bundle)
        .replacingOccurrences(of: "%@", with: name)
    }
    public static func activePlan(_ name: String) -> String {
      String(localized: "proPlan.manage.activePlan", bundle: bundle)
        .replacingOccurrences(of: "%@", with: name)
    }
    public static var startDate: String { String(localized: "proPlan.manage.startDate", bundle: bundle) }
    public static var renewalDate: String { String(localized: "proPlan.manage.renewalDate", bundle: bundle) }
    public static var gracePeriodEnds: String { String(localized: "proPlan.manage.gracePeriodEnds", bundle: bundle) }
    public static var proFeatures: String { String(localized: "proPlan.manage.features", bundle: bundle) }
    public static var manageAppleSubscription: String { String(localized: "proPlan.manage.appleSubscription", bundle: bundle) }
    public static var manageHelpText: String { String(localized: "proPlan.manage.helpText", bundle: bundle) }
    public static var offerCodeApplied: String { String(localized: "proPlan.manage.offerCodeApplied", bundle: bundle) }
    public static var statusActive: String { String(localized: "proPlan.manage.status.active", bundle: bundle) }
    public static var statusLifetime: String { String(localized: "proPlan.manage.status.lifetime", bundle: bundle) }
    public static var statusGracePeriod: String { String(localized: "proPlan.manage.status.gracePeriod", bundle: bundle) }
    public static var statusExpired: String { String(localized: "proPlan.manage.status.expired", bundle: bundle) }
    public static var statusRefunded: String { String(localized: "proPlan.manage.status.refunded", bundle: bundle) }
    public static var statusNone: String { String(localized: "proPlan.manage.status.none", bundle: bundle) }
    public static var featureConflictTitle: String { String(localized: "proPlan.feature.conflict.title", bundle: bundle) }
    public static var featureConflictDescription: String { String(localized: "proPlan.feature.conflict.description", bundle: bundle) }
    public static var featureRecommendationTitle: String { String(localized: "proPlan.feature.recommendation.title", bundle: bundle) }
    public static var featureRecommendationDescription: String { String(localized: "proPlan.feature.recommendation.description", bundle: bundle) }
    public static var featureStatsTitle: String { String(localized: "proPlan.feature.stats.title", bundle: bundle) }
    public static var featureStatsDescription: String { String(localized: "proPlan.feature.stats.description", bundle: bundle) }
    public static var heroTitleTop: String { String(localized: "proPlan.paywall.hero.title.top", bundle: bundle) }
    public static var heroTitleBottom: String { String(localized: "proPlan.paywall.hero.title.bottom", bundle: bundle) }
    public static var viewPlans: String { String(localized: "proPlan.paywall.viewPlans", bundle: bundle) }
    public static var celebrationTitle: String { String(localized: "proPlan.paywall.celebration.title", bundle: bundle) }
    public static var celebrationSubtitle: String { String(localized: "proPlan.paywall.celebration.subtitle", bundle: bundle) }
    public static var startButton: String { String(localized: "proPlan.startButton", bundle: bundle) }
    public static var heroSubtitle: String { String(localized: "proPlan.paywall.hero.subtitle", bundle: bundle) }
    public static var paywallDepartureProblem: String { String(localized: "proPlan.paywall.feature.departure.problem", bundle: bundle) }
    public static var paywallDepartureSolution: String { String(localized: "proPlan.paywall.feature.departure.solution", bundle: bundle) }
    public static var paywallConflictProblem: String { String(localized: "proPlan.paywall.feature.conflict.problem", bundle: bundle) }
    public static var paywallConflictSolution: String { String(localized: "proPlan.paywall.feature.conflict.solution", bundle: bundle) }
    public static var paywallBriefingProblem: String { String(localized: "proPlan.paywall.feature.briefing.problem", bundle: bundle) }
    public static var paywallBriefingSolution: String { String(localized: "proPlan.paywall.feature.briefing.solution", bundle: bundle) }
    public static var featureSmartBriefingTitle: String { String(localized: "proPlan.feature.smartBriefing.title", bundle: bundle) }
    public static var featureSmartBriefingDescription: String { String(localized: "proPlan.feature.smartBriefing.description", bundle: bundle) }
    public static var featureWidgetTitle: String { String(localized: "proPlan.feature.widget.title", bundle: bundle) }
    public static var featureWidgetDescription: String { String(localized: "proPlan.feature.widget.description", bundle: bundle) }
    public static var comparisonTitle: String { String(localized: "proPlan.paywall.comparison.title", bundle: bundle) }
    public static var comparisonSubtitle: String { String(localized: "proPlan.paywall.comparison.subtitle", bundle: bundle) }
    public static var comparisonFeatureLabel: String { String(localized: "proPlan.paywall.comparison.featureLabel", bundle: bundle) }
    public static var comparisonFreeLabel: String { String(localized: "proPlan.paywall.comparison.freeLabel", bundle: bundle) }
    public static var comparisonProLabel: String { String(localized: "proPlan.paywall.comparison.proLabel", bundle: bundle) }
    public static var comparisonBasicSchedule: String { String(localized: "proPlan.paywall.comparison.basicSchedule", bundle: bundle) }
    public static var comparisonCalendar: String { String(localized: "proPlan.paywall.comparison.calendar", bundle: bundle) }
    public static var comparisonWidget: String { String(localized: "proPlan.paywall.comparison.widget", bundle: bundle) }
    public static var comparisonGroupSchedule: String { String(localized: "proPlan.paywall.comparison.groupSchedule", bundle: bundle) }
    public static var comparisonLiveActivity: String { String(localized: "proPlan.paywall.comparison.liveActivity", bundle: bundle) }
    public static var comparisonDepartureAlert: String { String(localized: "proPlan.paywall.comparison.departureAlert", bundle: bundle) }
    public static var comparisonConflictDetection: String { String(localized: "proPlan.paywall.comparison.conflictDetection", bundle: bundle) }
    public static var comparisonWeather: String { String(localized: "proPlan.paywall.comparison.weather", bundle: bundle) }
    public static var comparisonDailyBriefing: String { String(localized: "proPlan.paywall.comparison.dailyBriefing", bundle: bundle) }
    public static var comparisonComingSoon: String { String(localized: "proPlan.paywall.comparison.comingSoon", bundle: bundle) }
    public static var trustText: String { String(localized: "proPlan.paywall.trustText", bundle: bundle) }
    public static func freeTrialTrustText(_ days: Int) -> String {
      String(localized: "proPlan.paywall.trust.freeTrial", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(days)")
    }
    public static var restorePurchases: String { String(localized: "proPlan.paywall.restorePurchases", bundle: bundle) }
    public static var redeemOfferCode: String { String(localized: "proPlan.paywall.redeemOfferCode", bundle: bundle) }
    public static var legalTrialDisclaimer: String { String(localized: "proPlan.paywall.legal.trialDisclaimer", bundle: bundle) }
    public static var legalSubscriptionDisclaimer: String { String(localized: "proPlan.paywall.legal.subscriptionDisclaimer", bundle: bundle) }
    public static func legalTrialDynamic(_ days: Int, _ priceAndPeriod: String) -> String {
      String(localized: "proPlan.paywall.legal.dynamic.trial", bundle: bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(days)")
        .replacingOccurrences(of: "%2$@", with: priceAndPeriod)
    }
    public static func legalSubscriptionDynamic(_ priceAndPeriod: String) -> String {
      String(localized: "proPlan.paywall.legal.dynamic.subscription", bundle: bundle)
        .replacingOccurrences(of: "%@", with: priceAndPeriod)
    }
    public static func legalLifetimeDynamic(_ price: String) -> String {
      String(localized: "proPlan.paywall.legal.dynamic.lifetime", bundle: bundle)
        .replacingOccurrences(of: "%@", with: price)
    }
    public static var legalTerms: String { String(localized: "proPlan.paywall.legal.terms", bundle: bundle) }
    public static var legalPrivacy: String { String(localized: "proPlan.paywall.legal.privacy", bundle: bundle) }
    public static var processing: String { String(localized: "proPlan.paywall.processing", bundle: bundle) }
    public static var mockDepartureNow: String { String(localized: "proPlan.mock.departureNow", bundle: bundle) }
    public static var mockTravelTime: String { String(localized: "proPlan.mock.travelTime", bundle: bundle) }
    public static var mockRainAlert: String { String(localized: "proPlan.mock.rainAlert", bundle: bundle) }
    public static var mockLeaveRecommendation: String { String(localized: "proPlan.mock.leaveRecommendation", bundle: bundle) }
    public static var mockNextSchedule: String { String(localized: "proPlan.mock.nextSchedule", bundle: bundle) }
    public static var mockNextScheduleSummary: String { String(localized: "proPlan.mock.nextSchedule.summary", bundle: bundle) }
    public static var mockTemperature: String { String(localized: "proPlan.mock.temperature", bundle: bundle) }
    public static var mockTravelDuration: String { String(localized: "proPlan.mock.travelDuration", bundle: bundle) }
    public static var mockDepartureTime: String { String(localized: "proPlan.mock.departureTime", bundle: bundle) }
    public static var mockConflictTitle: String { String(localized: "proPlan.mock.conflict.title", bundle: bundle) }
    public static var mockConflictExistingTitle: String { String(localized: "proPlan.mock.conflict.existingTitle", bundle: bundle) }
    public static var mockConflictExistingTime: String { String(localized: "proPlan.mock.conflict.existingTime", bundle: bundle) }
    public static var mockConflictNewTitle: String { String(localized: "proPlan.mock.conflict.newTitle", bundle: bundle) }
    public static var mockConflictNewTime: String { String(localized: "proPlan.mock.conflict.newTime", bundle: bundle) }
    public static var previewOrigin: String { String(localized: "proPlan.paywall.preview.origin", bundle: bundle) }
    public static var previewDestination: String { String(localized: "proPlan.paywall.preview.destination", bundle: bundle) }
    public static func previewStartsAt(_ time: String) -> String {
      String(localized: "proPlan.paywall.preview.startsAt", bundle: bundle)
        .replacingOccurrences(of: "%@", with: time)
    }
    public static var previewBriefingBody: String { String(localized: "proPlan.paywall.preview.briefingBody", bundle: bundle) }
    public static func previewTransportIncluded(_ transport: String) -> String {
      String(localized: "proPlan.paywall.preview.transportIncluded", bundle: bundle)
        .replacingOccurrences(of: "%@", with: transport)
    }
    public static func badgeDiscountPercent(_ percent: Int) -> String {
      String(localized: "proPlan.paywall.badge.discountPercent", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(percent)")
    }
    public static var badgeTwoMonthsFree: String { String(localized: "proPlan.paywall.badge.twoMonthsFree", bundle: bundle) }
    public static var badgeLifetime: String { String(localized: "proPlan.paywall.badge.lifetime", bundle: bundle) }
    public static var badgeLimited: String { String(localized: "proPlan.paywall.badge.limited", bundle: bundle) }
    public static var perMonth: String { String(localized: "proPlan.paywall.price.perMonth", bundle: bundle) }
    public static var perYear: String { String(localized: "proPlan.paywall.price.perYear", bundle: bundle) }
    public static func freeTrialStartsAfter(_ days: Int) -> String {
      String(localized: "proPlan.paywall.freeTrialStartsAfter", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(days)")
    }
    public static var lifetimePurchaseButton: String { String(localized: "proPlan.paywall.cta.lifetimePurchase", bundle: bundle) }
    public static var productMonthlyDescription: String {
      String(localized: "proPlan.paywall.product.monthlyDescription", bundle: bundle)
    }
    public static var productYearlyDescription: String {
      String(localized: "proPlan.paywall.product.yearlyDescription", bundle: bundle)
    }
    public static var productLifetimeDescription: String {
      String(localized: "proPlan.paywall.product.lifetimeDescription", bundle: bundle)
    }
    public static var productsLoadFailed: String { String(localized: "proPlan.error.productsLoadFailed", bundle: bundle) }
    public static var purchaseFailed: String { String(localized: "proPlan.error.purchaseFailed", bundle: bundle) }
    public static var restoreNoPurchaseHistory: String {
      String(localized: "proPlan.error.restoreNoPurchaseHistory", bundle: bundle)
    }
    public static var restoreFailed: String { String(localized: "proPlan.error.restoreFailed", bundle: bundle) }
    public static var onboardingConflictTitle: String { String(localized: "proPlan.onboarding.conflict.title", bundle: bundle) }
    public static var onboardingConflictSubtitle: String { String(localized: "proPlan.onboarding.conflict.subtitle", bundle: bundle) }
    public static var onboardingConflictSubtitleNew: String { String(localized: "proPlan.onboarding.conflict.subtitleNew", bundle: bundle) }
    public static var onboardingConflictDetected: String { String(localized: "proPlan.onboarding.conflict.detected", bundle: bundle) }
    public static var onboardingConflictExistingTitle: String { String(localized: "proPlan.onboarding.conflict.existingTitle", bundle: bundle) }
    public static var onboardingConflictExistingTime: String { String(localized: "proPlan.onboarding.conflict.existingTime", bundle: bundle) }
    public static var onboardingConflictNewTitle: String { String(localized: "proPlan.onboarding.conflict.newTitle", bundle: bundle) }
    public static var onboardingConflictNewTime: String { String(localized: "proPlan.onboarding.conflict.newTime", bundle: bundle) }
    public static var onboardingConflictOverlap: String { String(localized: "proPlan.onboarding.conflict.overlap", bundle: bundle) }
    public static var onboardingBriefingSubtitle: String { String(localized: "proPlan.onboarding.briefing.subtitle", bundle: bundle) }
    public static var onboardingBriefingSettingsTitle: String { String(localized: "proPlan.onboarding.briefingSettings.title", bundle: bundle) }
    public static var onboardingBriefingSettingsSubtitle: String { String(localized: "proPlan.onboarding.briefingSettings.subtitle", bundle: bundle) }
    public static var onboardingBriefingStyleTitle: String { String(localized: "proPlan.onboarding.briefingStyle.title", bundle: bundle) }
    public static var onboardingBriefingStyleSubtitle: String { String(localized: "proPlan.onboarding.briefingStyle.subtitle", bundle: bundle) }
    public static var onboardingAlertAndTransport: String { String(localized: "proPlan.onboarding.alertAndTransport", bundle: bundle) }
    public static var onboardingMultipleSelectHint: String { String(localized: "proPlan.onboarding.multipleSelectHint", bundle: bundle) }
    public static var onboardingTodayBriefing: String { String(localized: "proPlan.onboarding.todayBriefing", bundle: bundle) }
    public static var onboardingTodayBriefingTime: String { String(localized: "proPlan.onboarding.todayBriefing.time", bundle: bundle) }
    public static var onboardingTodayBriefingMessage: String { String(localized: "proPlan.onboarding.todayBriefing.message", bundle: bundle) }
    public static var onboardingTodayBriefingWeather: String { String(localized: "proPlan.onboarding.todayBriefing.weather", bundle: bundle) }
    public static var onboardingTodayBriefingTransport: String { String(localized: "proPlan.onboarding.todayBriefing.transport", bundle: bundle) }
    public static var onboardingTodayBriefingDeparture: String { String(localized: "proPlan.onboarding.todayBriefing.departure", bundle: bundle) }
    public static var onboardingCompleteTitle: String { String(localized: "proPlan.onboarding.complete.title", bundle: bundle) }
    public static var onboardingCompleteSubtitle: String { String(localized: "proPlan.onboarding.complete.subtitle", bundle: bundle) }
    public static var weatherLocationRequiredHint: String {
      String(localized: "proPlan.weather.locationRequiredHint", bundle: bundle)
    }
    public static var weatherDateLimitHint: String {
      String(localized: "proPlan.weather.dateLimitHint", bundle: bundle)
    }
    public static var noConflict: String { String(localized: "proPlan.conflict.none", bundle: bundle) }
    public static func noConflictWithinMinutes(_ minutes: Int) -> String {
      String(localized: "proPlan.conflict.noneWithinMinutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static func freeTrialStart(_ days: Int) -> String {
      String(localized: "proPlan.paywall.freeTrialStart", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(days)")
    }
    public static func freeTrialAfter(_ days: Int, _ description: String) -> String {
      String(localized: "proPlan.paywall.freeTrialAfter", bundle: bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(days)")
        .replacingOccurrences(of: "%2$@", with: description)
    }
    public static var transferTitle: String { String(localized: "proPlan.transfer.title", bundle: bundle) }
    public static var transferMessage: String { String(localized: "proPlan.transfer.message", bundle: bundle) }
    public static var transferConfirm: String { String(localized: "proPlan.transfer.confirm", bundle: bundle) }
  }

  // MARK: - RootTab
  public enum RootTab {
    // ScheduleTabMode
    public static var tabModeGroup: String { String(localized: "rootTab.tabMode.group", bundle: bundle) }
    public static var tabModePersonal: String { String(localized: "rootTab.tabMode.personal", bundle: bundle) }
  }

  // MARK: - CreateGroup
  public enum CreateGroup {
    public static var title: String { String(localized: "createGroup.title", bundle: bundle) }
    public static var groupPhoto: String { String(localized: "createGroup.groupPhoto", bundle: bundle) }
    public static var addPhoto: String { String(localized: "createGroup.addPhoto", bundle: bundle) }
    public static var groupName: String { String(localized: "createGroup.groupName", bundle: bundle) }
    public static var groupNamePlaceholder: String { String(localized: "createGroup.groupNamePlaceholder", bundle: bundle) }
    public static var groupNameMinLength: String { String(localized: "createGroup.groupNameMinLength", bundle: bundle) }
    public static var groupNameCannotChange: String { String(localized: "createGroup.groupNameCannotChange", bundle: bundle) }
    public static var groupDescription: String { String(localized: "createGroup.groupDescription", bundle: bundle) }
    public static var groupDescriptionPlaceholder: String { String(localized: "createGroup.groupDescriptionPlaceholder", bundle: bundle) }
    public static var maxMembers: String { String(localized: "createGroup.maxMembers", bundle: bundle) }
    public static var creating: String { String(localized: "createGroup.creating", bundle: bundle) }
    public static var createButton: String { String(localized: "createGroup.createButton", bundle: bundle) }
    public static var adminHint: String { String(localized: "createGroup.adminHint", bundle: bundle) }
    public static var creationFailedTitle: String { String(localized: "createGroup.creationFailedTitle", bundle: bundle) }
    public static var creationFailedDefault: String { String(localized: "createGroup.creationFailedDefault", bundle: bundle) }
    // Success
    public static var successTitle: String { String(localized: "createGroup.successTitle", bundle: bundle) }
    public static func successTitleWithName(_ groupName: String) -> String {
      String(localized: "createGroup.successTitleWithName", bundle: bundle)
        .replacingOccurrences(of: "%@", with: groupName)
    }
    public static var successSubtitle: String { String(localized: "createGroup.successSubtitle", bundle: bundle) }
    public static var createScheduleButton: String { String(localized: "createGroup.createScheduleButton", bundle: bundle) }
    public static var inviteCode: String { String(localized: "createGroup.inviteCode", bundle: bundle) }
    public static var copied: String { String(localized: "createGroup.copied", bundle: bundle) }
    public static var share: String { String(localized: "createGroup.share", bundle: bundle) }
    public static var kakaoInviteButton: String { String(localized: "createGroup.kakaoInviteButton", bundle: bundle) }
    public static var inviteTooltip: String { String(localized: "createGroup.inviteTooltip", bundle: bundle) }
    // MaxMembers display
    public static func membersCount(_ count: Int) -> String {
      String(localized: "createGroup.membersCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
  }

  // MARK: - GroupSettings (CreateGroupSettingsView)
  public enum GroupSettings {
    public static var calendarPermissionTitle: String { String(localized: "groupSettings.calendarPermissionTitle", bundle: bundle) }
    public static var calendarPermissionMessage: String { String(localized: "groupSettings.calendarPermissionMessage", bundle: bundle) }
    public static func notificationSettingsTitle(_ groupName: String) -> String {
      String(localized: "groupSettings.notificationSettingsTitle", bundle: bundle)
        .replacingOccurrences(of: "%@", with: groupName)
    }
    public static var notificationSettingsSubtitle: String { String(localized: "groupSettings.notificationSettingsSubtitle", bundle: bundle) }
    public static var pushNotification: String { String(localized: "groupSettings.pushNotification", bundle: bundle) }
    public static var notificationDenied: String { String(localized: "groupSettings.notificationDenied", bundle: bundle) }
    public static var notificationDescription: String { String(localized: "groupSettings.notificationDescription", bundle: bundle) }
    public static var calendarSync: String { String(localized: "groupSettings.calendarSync", bundle: bundle) }
    public static var calendarDeniedSyncOn: String { String(localized: "groupSettings.calendarDeniedSyncOn", bundle: bundle) }
    public static var calendarDeniedSyncOff: String { String(localized: "groupSettings.calendarDeniedSyncOff", bundle: bundle) }
    public static var calendarDescription: String { String(localized: "groupSettings.calendarDescription", bundle: bundle) }
    public static var saving: String { String(localized: "groupSettings.saving", bundle: bundle) }
    public static var complete: String { String(localized: "groupSettings.complete", bundle: bundle) }
    public static var createGroupComplete: String { String(localized: "groupSettings.createGroupComplete", bundle: bundle) }
    public static var joinGroupComplete: String { String(localized: "groupSettings.joinGroupComplete", bundle: bundle) }
    public static var personalSettings: String { String(localized: "groupSettings.personalSettings", bundle: bundle) }
    public static var skip: String { String(localized: "groupSettings.skip", bundle: bundle) }
    public static var changeableHint: String { String(localized: "groupSettings.changeableHint", bundle: bundle) }
    public static var notificationSectionTitle: String { String(localized: "groupSettings.notificationSectionTitle", bundle: bundle) }
    public static var notificationSectionSubtitle: String { String(localized: "groupSettings.notificationSectionSubtitle", bundle: bundle) }
    public static var groupColorSectionTitle: String { String(localized: "groupSettings.groupColorSectionTitle", bundle: bundle) }
    public static var groupColorSectionSubtitle: String { String(localized: "groupSettings.groupColorSectionSubtitle", bundle: bundle) }
    public static func groupColorUsedBy(_ groupName: String) -> String {
      String(localized: "groupSettings.groupColorUsedBy", bundle: bundle)
        .replacingOccurrences(of: "%@", with: groupName)
    }
    public static var calendarSectionTitle: String { String(localized: "groupSettings.calendarSectionTitle", bundle: bundle) }
    public static var calendarSectionSubtitle: String { String(localized: "groupSettings.calendarSectionSubtitle", bundle: bundle) }
    public static func settingsHeaderTitle(_ groupName: String) -> String {
      String(localized: "groupSettings.settingsHeaderTitle", bundle: bundle)
        .replacingOccurrences(of: "%@", with: groupName)
    }
  }

  // MARK: - CreateSchedule
  public enum CreateSchedule {
    // Step headers
    public static var step1Title: String { String(localized: "createSchedule.step1Title", bundle: bundle) }
    public static var step1Subtitle: String { String(localized: "createSchedule.step1Subtitle", bundle: bundle) }
    public static var step2Title: String { String(localized: "createSchedule.step2Title", bundle: bundle) }
    public static var step2Subtitle: String { String(localized: "createSchedule.step2Subtitle", bundle: bundle) }
    public static var step3Title: String { String(localized: "createSchedule.step3Title", bundle: bundle) }
    public static var step3Subtitle: String { String(localized: "createSchedule.step3Subtitle", bundle: bundle) }
    // Step 1
    public static var titleSection: String { String(localized: "createSchedule.titleSection", bundle: bundle) }
    public static var titlePlaceholder: String { String(localized: "createSchedule.titlePlaceholder", bundle: bundle) }
    public static var groupSelection: String { String(localized: "createSchedule.groupSelection", bundle: bundle) }
    public static var noGroupsTitle: String { String(localized: "createSchedule.noGroupsTitle", bundle: bundle) }
    public static var noGroupsSubtitle: String { String(localized: "createSchedule.noGroupsSubtitle", bundle: bundle) }
    public static var createNewGroup: String { String(localized: "createSchedule.createNewGroup", bundle: bundle) }
    public static var loadGroupsFailed: String { String(localized: "createSchedule.loadGroupsFailed", bundle: bundle) }
    public static var retryButton: String { String(localized: "createSchedule.retryButton", bundle: bundle) }
    public static func memberCount(_ count: Int) -> String {
      String(localized: "createSchedule.memberCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var noMembersInGroup: String { String(localized: "createSchedule.noMembersInGroup", bundle: bundle) }
    public static func activeSchedulesAtLimit(_ count: Int) -> String {
      String(localized: "createSchedule.activeSchedulesAtLimit", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    // Step 2
    public static var startTime: String { String(localized: "createSchedule.startTime", bundle: bundle) }
    public static var endTime: String { String(localized: "createSchedule.endTime", bundle: bundle) }
    public static var locationSection: String { String(localized: "createSchedule.locationSection", bundle: bundle) }
    public static var searchLocation: String { String(localized: "createSchedule.searchLocation", bundle: bundle) }
    public static var totalDurationPrefix: String { String(localized: "createSchedule.totalDurationPrefix", bundle: bundle) }
    public static var startTimeWarning: String { String(localized: "createSchedule.startTimeWarning", bundle: bundle) }
    // Step 3
    public static var liveSharing: String { String(localized: "createSchedule.liveSharing", bundle: bundle) }
    public static var liveSharingDescription: String { String(localized: "createSchedule.liveSharingDescription", bundle: bundle) }
    public static var minutes15Before: String { String(localized: "createSchedule.minutes15Before", bundle: bundle) }
    public static var minutes30Before: String { String(localized: "createSchedule.minutes30Before", bundle: bundle) }
    public static var hour1Before: String { String(localized: "createSchedule.hour1Before", bundle: bundle) }
    public static var customInput: String { String(localized: "createSchedule.customInput", bundle: bundle) }
    public static var minutesBefore: String { String(localized: "createSchedule.minutesBefore", bundle: bundle) }
    public static var descriptionSection: String { String(localized: "createSchedule.descriptionSection", bundle: bundle) }
    public static var descriptionPlaceholder: String { String(localized: "createSchedule.descriptionPlaceholder", bundle: bundle) }
    public static var minimumParticipants: String { String(localized: "createSchedule.minimumParticipants", bundle: bundle) }
    public static func participantsCount(_ count: Int) -> String {
      String(localized: "createSchedule.participantsCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func maxParticipants(_ count: Int) -> String {
      String(localized: "createSchedule.maxParticipants", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var fixedParticipantsInfo: String { String(localized: "createSchedule.fixedParticipantsInfo", bundle: bundle) }
    public static func autoConfirmInfo(_ count: Int) -> String {
      String(localized: "createSchedule.autoConfirmInfo", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var maxParticipantsWarning: String { String(localized: "createSchedule.maxParticipantsWarning", bundle: bundle) }
    public static var navigationTitle: String { String(localized: "createSchedule.navigationTitle", bundle: bundle) }
  }

  // MARK: - ManageGroup
  public enum ManageGroup {
    public static var title: String { String(localized: "manageGroup.title", bundle: bundle) }
    public static var introduction: String { String(localized: "manageGroup.introduction", bundle: bundle) }
    public static var currentMembers: String { String(localized: "manageGroup.currentMembers", bundle: bundle) }
    public static var maxMembers: String { String(localized: "manageGroup.maxMembers", bundle: bundle) }
    public static var activeSchedules: String { String(localized: "manageGroup.activeSchedules", bundle: bundle) }
    public static var pastSchedules: String { String(localized: "manageGroup.pastSchedules", bundle: bundle) }
    public static var memberLoadFailed: String { String(localized: "manageGroup.memberLoadFailed", bundle: bundle) }
    public static var host: String { String(localized: "manageGroup.host", bundle: bundle) }
    public static var memberRole: String { String(localized: "manageGroup.memberRole", bundle: bundle) }
    public static var transferHost: String { String(localized: "manageGroup.transferHost", bundle: bundle) }
    public static var transferHostFailed: String { String(localized: "manageGroup.transferHostFailed", bundle: bundle) }
    public static var selectNewHost: String { String(localized: "manageGroup.selectNewHost", bundle: bundle) }
    public static var selectNewHostDescription: String { String(localized: "manageGroup.selectNewHostDescription", bundle: bundle) }
    public static var transfer: String { String(localized: "manageGroup.transfer", bundle: bundle) }
    public static func transferHostConfirm(_ name: String) -> String {
      String(localized: "manageGroup.transferHostConfirm", bundle: bundle)
        .replacingOccurrences(of: "%@", with: name)
    }
    public static var leaveGroup: String { String(localized: "manageGroup.leaveGroup", bundle: bundle) }
    public static var leave: String { String(localized: "manageGroup.leave", bundle: bundle) }
    public static var leaveGroupConfirm: String { String(localized: "manageGroup.leaveGroupConfirm", bundle: bundle) }
    public static var deleteGroup: String { String(localized: "manageGroup.deleteGroup", bundle: bundle) }
    public static var deleteGroupConfirm: String { String(localized: "manageGroup.deleteGroupConfirm", bundle: bundle) }
    public static func membersCount(_ count: Int) -> String {
      String(localized: "manageGroup.membersCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
  }

  // MARK: - PastSchedules
  public enum PastSchedules {
    public static var title: String { String(localized: "pastSchedules.title", bundle: bundle) }
    public static var searchPlaceholder: String { String(localized: "pastSchedules.searchPlaceholder", bundle: bundle) }
    public static var emptyTitle: String { String(localized: "pastSchedules.emptyTitle", bundle: bundle) }
    public static var emptySubtitle: String { String(localized: "pastSchedules.emptySubtitle", bundle: bundle) }
    public static var emptyFilteredTitle: String { String(localized: "pastSchedules.emptyFilteredTitle", bundle: bundle) }
    public static var emptyFilteredSubtitle: String { String(localized: "pastSchedules.emptyFilteredSubtitle", bundle: bundle) }
    public static var loadFailed: String { String(localized: "pastSchedules.loadFailed", bundle: bundle) }
    // StatusFilter
    public static var filterAll: String { String(localized: "pastSchedules.filter.all", bundle: bundle) }
    public static var filterConfirmed: String { String(localized: "pastSchedules.filter.confirmed", bundle: bundle) }
    public static var filterFailed: String { String(localized: "pastSchedules.filter.failed", bundle: bundle) }
    // SortOption
    public static var sortNewest: String { String(localized: "pastSchedules.sort.newest", bundle: bundle) }
    public static var sortOldest: String { String(localized: "pastSchedules.sort.oldest", bundle: bundle) }
    public static var sortParticipants: String { String(localized: "pastSchedules.sort.participants", bundle: bundle) }
  }

  // MARK: - JoinGroup
  public enum JoinGroup {
    public static var title: String { String(localized: "joinGroup.title", bundle: bundle) }
    public static var initialSettings: String { String(localized: "joinGroup.initialSettings", bundle: bundle) }
    public static var enterInviteCode: String { String(localized: "joinGroup.enterInviteCode", bundle: bundle) }
    public static var enterCodeDescription: String { String(localized: "joinGroup.enterCodeDescription", bundle: bundle) }
    public static var paste: String { String(localized: "joinGroup.paste", bundle: bundle) }
    public static var copy: String { String(localized: "joinGroup.copy", bundle: bundle) }
    public static var checking: String { String(localized: "joinGroup.checking", bundle: bundle) }
    public static var joining: String { String(localized: "joinGroup.joining", bundle: bundle) }
    public static var joinButton: String { String(localized: "joinGroup.joinButton", bundle: bundle) }
    public static var joinFailed: String { String(localized: "joinGroup.joinFailed", bundle: bundle) }
    public static var seeMore: String { String(localized: "joinGroup.seeMore", bundle: bundle) }
  }

  // MARK: - GroupSettingsView
  public enum GroupSettingsView {
    public static var title: String { String(localized: "groupSettingsView.title", bundle: bundle) }
    public static var invite: String { String(localized: "groupSettingsView.invite", bundle: bundle) }
    public static var noDescription: String { String(localized: "groupSettingsView.noDescription", bundle: bundle) }
    public static var notificationSettings: String { String(localized: "groupSettingsView.notificationSettings", bundle: bundle) }
    // Notification banners
    public static var notificationPermissionNeeded: String { String(localized: "groupSettingsView.notificationPermissionNeeded", bundle: bundle) }
    public static var allowNotificationPermission: String { String(localized: "groupSettingsView.allowNotificationPermission", bundle: bundle) }
    public static var notificationDeniedMessage: String { String(localized: "groupSettingsView.notificationDeniedMessage", bundle: bundle) }
    public static var openNotificationSettings: String { String(localized: "groupSettingsView.openNotificationSettings", bundle: bundle) }
    // Notification sections
    public static var groupAll: String { String(localized: "groupSettingsView.groupAll", bundle: bundle) }
    public static var groupNotification: String { String(localized: "groupSettingsView.groupNotification", bundle: bundle) }
    public static var scheduleSection: String { String(localized: "groupSettingsView.scheduleSection", bundle: bundle) }
    public static var groupSection: String { String(localized: "groupSettingsView.groupSection", bundle: bundle) }
    // Tooltip
    public static var tooltipGroupNotificationSubtitle: String { String(localized: "groupSettingsView.tooltip.groupNotificationSubtitle", bundle: bundle) }
    public static var tooltipToggleDescription: String { String(localized: "groupSettingsView.tooltip.toggleDescription", bundle: bundle) }
    // Tooltip previews
    public static var tooltipNewSchedule: String { String(localized: "groupSettingsView.tooltip.newSchedule", bundle: bundle) }
    public static var tooltipNewScheduleBody: String { String(localized: "groupSettingsView.tooltip.newScheduleBody", bundle: bundle) }
    public static var tooltipConfirmed: String { String(localized: "groupSettingsView.tooltip.confirmed", bundle: bundle) }
    public static var tooltipConfirmedBody: String { String(localized: "groupSettingsView.tooltip.confirmedBody", bundle: bundle) }
    public static var tooltipCancelled: String { String(localized: "groupSettingsView.tooltip.cancelled", bundle: bundle) }
    public static var tooltipCancelledBody: String { String(localized: "groupSettingsView.tooltip.cancelledBody", bundle: bundle) }
    public static var tooltipUpdated: String { String(localized: "groupSettingsView.tooltip.updated", bundle: bundle) }
    public static var tooltipUpdatedBody: String { String(localized: "groupSettingsView.tooltip.updatedBody", bundle: bundle) }
    public static var tooltipNewMember: String { String(localized: "groupSettingsView.tooltip.newMember", bundle: bundle) }
    public static var tooltipNewMemberBody: String { String(localized: "groupSettingsView.tooltip.newMemberBody", bundle: bundle) }
    public static var now: String { String(localized: "groupSettingsView.now", bundle: bundle) }
    // Edit Group
    public static var editGroupTitle: String { String(localized: "groupSettingsView.editGroupTitle", bundle: bundle) }
    public static var groupPhoto: String { String(localized: "groupSettingsView.groupPhoto", bundle: bundle) }
    public static var groupNameCannotChange: String { String(localized: "groupSettingsView.groupNameCannotChange", bundle: bundle) }
    public static var groupDescriptionPlaceholder: String { String(localized: "groupSettingsView.groupDescriptionPlaceholder", bundle: bundle) }
    public static var changePhoto: String { String(localized: "groupSettingsView.changePhoto", bundle: bundle) }
    public static var editGroupFailed: String { String(localized: "groupSettingsView.editGroupFailed", bundle: bundle) }
    public static var tryAgainLater: String { String(localized: "groupSettingsView.tryAgainLater", bundle: bundle) }
    public static var saving: String { String(localized: "groupSettingsView.saving", bundle: bundle) }
    public static var editGroupButton: String { String(localized: "groupSettingsView.editGroupButton", bundle: bundle) }
    public static func currentMembersMax(_ current: Int) -> String {
      String(localized: "groupSettingsView.currentMembersMax", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(current)")
    }
    // Transfer Host
    public static var selectNewHost: String { String(localized: "groupSettingsView.selectNewHost", bundle: bundle) }
    public static var transferHostDescription: String { String(localized: "groupSettingsView.transferHostDescription", bundle: bundle) }
    // Members
    public static var editMembers: String { String(localized: "groupSettingsView.editMembers", bundle: bundle) }
    public static var expelMember: String { String(localized: "groupSettingsView.expelMember", bundle: bundle) }
    public static var expel: String { String(localized: "groupSettingsView.expel", bundle: bundle) }
    public static func expelConfirm(_ name: String) -> String {
      String(localized: "groupSettingsView.expelConfirm", bundle: bundle)
        .replacingOccurrences(of: "%@", with: name)
    }
    public static var expelFailed: String { String(localized: "groupSettingsView.expelFailed", bundle: bundle) }
    public static var me: String { String(localized: "groupSettingsView.me", bundle: bundle) }
    // Invite
    public static var inviteFriends: String { String(localized: "groupSettingsView.inviteFriends", bundle: bundle) }
    public static var inviteFriendsDescription: String { String(localized: "groupSettingsView.inviteFriendsDescription", bundle: bundle) }
    public static var inviteTitle: String { String(localized: "groupSettingsView.inviteTitle", bundle: bundle) }
    public static var inviteSubtitle: String { String(localized: "groupSettingsView.inviteSubtitle", bundle: bundle) }
    public static var shareLink: String { String(localized: "groupSettingsView.shareLink", bundle: bundle) }
    // Alerts
    public static func leaveGroupConfirm(_ name: String) -> String {
      String(localized: "groupSettingsView.leaveGroupConfirm", bundle: bundle)
        .replacingOccurrences(of: "%@", with: name)
    }
    public static func deleteGroupConfirm(_ name: String) -> String {
      String(localized: "groupSettingsView.deleteGroupConfirm", bundle: bundle)
        .replacingOccurrences(of: "%@", with: name)
    }
    public static var unknownError: String { String(localized: "groupSettingsView.unknownError", bundle: bundle) }
    public static func membersTitle(_ count: Int) -> String {
      String(localized: "groupSettingsView.membersTitle", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func membersCount(_ count: Int) -> String {
      String(localized: "groupSettingsView.membersCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }

    // Group Color
    public static var groupColorTitle: String { String(localized: "groupSettingsView.groupColor.title", bundle: bundle) }
    public static var groupColorPreview: String { String(localized: "groupSettingsView.groupColor.preview", bundle: bundle) }
    public static var groupColorGroupTab: String { String(localized: "groupSettingsView.groupColor.groupTab", bundle: bundle) }
    public static var groupColorScheduleCard: String { String(localized: "groupSettingsView.groupColor.scheduleCard", bundle: bundle) }
    public static var groupColorReset: String { String(localized: "groupSettingsView.groupColor.reset", bundle: bundle) }

    // Color Settings
    public static var colorNotSet: String { String(localized: "groupSettingsView.colorNotSet", bundle: bundle) }
    public static var colorPreviewBarDescription: String { String(localized: "groupSettingsView.colorPreview.barDescription", bundle: bundle) }
    public static var colorPreviewCardDescription: String { String(localized: "groupSettingsView.colorPreview.cardDescription", bundle: bundle) }
    public static var colorPickerTitle: String { String(localized: "groupSettingsView.colorPicker.title", bundle: bundle) }
    public static var colorPreviewSampleTime: String { String(localized: "groupSettingsView.colorPreview.sampleTime", bundle: bundle) }
    public static var colorPreviewSampleTitle: String { String(localized: "groupSettingsView.colorPreview.sampleTitle", bundle: bundle) }
  }

  // MARK: - GroupOverview
  public enum GroupOverview {
    public static var title: String { String(localized: "groupOverview.title", bundle: bundle) }
    public static var myGroups: String { String(localized: "groupOverview.myGroups", bundle: bundle) }
    public static var groupManagement: String { String(localized: "groupOverview.groupManagement", bundle: bundle) }
    public static var createGroup: String { String(localized: "groupOverview.createGroup", bundle: bundle) }
    public static var joinGroup: String { String(localized: "groupOverview.joinGroup", bundle: bundle) }
    public static var host: String { String(localized: "groupOverview.host", bundle: bundle) }
  }

  // MARK: - GroupMain
  public enum GroupMain {
    public static var createSchedule: String { String(localized: "groupMain.createSchedule", bundle: bundle) }
    public static var groupSettings: String { String(localized: "groupMain.groupSettings", bundle: bundle) }
    public static var noGroupsTitle: String { String(localized: "groupMain.noGroupsTitle", bundle: bundle) }
    // Swipe actions
    public static var undo: String { String(localized: "groupMain.undo", bundle: bundle) }
    public static var accept: String { String(localized: "groupMain.accept", bundle: bundle) }
    public static var reject: String { String(localized: "groupMain.reject", bundle: bundle) }
    // Empty filter descriptions
    public static var emptyNeedResponse: String { String(localized: "groupMain.empty.needResponse", bundle: bundle) }
    public static var emptyResponded: String { String(localized: "groupMain.empty.responded", bundle: bundle) }
    public static var emptyConfirmed: String { String(localized: "groupMain.empty.confirmed", bundle: bundle) }
    public static var emptyAll: String { String(localized: "groupMain.empty.all", bundle: bundle) }
    public static var emptyPast: String { String(localized: "groupMain.empty.past", bundle: bundle) }
    public static var retry: String { String(localized: "groupMain.retry", bundle: bundle) }
    public static var noGroupsDescription: String { String(localized: "groupMain.noGroupsDescription", bundle: bundle) }
    // ScheduleFilter displayTitles
    public static var filterNeedResponse: String { String(localized: "groupMain.filter.needResponse", bundle: bundle) }
    public static var filterResponded: String { String(localized: "groupMain.filter.responded", bundle: bundle) }
    public static var filterConfirmed: String { String(localized: "groupMain.filter.confirmed", bundle: bundle) }
    public static var filterAll: String { String(localized: "groupMain.filter.all", bundle: bundle) }
    public static var filterPast: String { String(localized: "groupMain.filter.past", bundle: bundle) }
    // Onboarding
    public static var createGroupCard: String { String(localized: "groupMain.onboarding.createGroup", bundle: bundle) }
    public static var createGroupCardSubtitle: String { String(localized: "groupMain.onboarding.createGroupSubtitle", bundle: bundle) }
    public static var joinGroupCard: String { String(localized: "groupMain.onboarding.joinGroup", bundle: bundle) }
    public static var joinGroupCardSubtitle: String { String(localized: "groupMain.onboarding.joinGroupSubtitle", bundle: bundle) }
    public static var onboardingGroupName: String { String(localized: "groupMain.onboarding.groupName", bundle: bundle) }
    // Deeplink
    public static var joinGroupRequiredForDeeplinkTitle: String { String(localized: "groupMain.deeplink.joinGroupRequired.title", bundle: bundle) }
    public static var joinGroupRequiredForDeeplinkSubtitle: String { String(localized: "groupMain.deeplink.joinGroupRequired.subtitle", bundle: bundle) }
    // Delete alert
    public static var deleteScheduleTitle: String { String(localized: "groupMain.deleteSchedule.title", bundle: bundle) }
    public static func deleteScheduleConfirm(_ title: String) -> String {
      String(localized: "groupMain.deleteSchedule.confirm", bundle: bundle)
        .replacingOccurrences(of: "%@", with: title)
    }
  }

  // MARK: - GroupHorizontalBar
  public enum GroupHorizontalBar {
    public static var createGroup: String { String(localized: "groupHorizontalBar.createGroup", bundle: bundle) }
    public static var joinWithCode: String { String(localized: "groupHorizontalBar.joinWithCode", bundle: bundle) }
    public static var sortGroups: String { String(localized: "groupHorizontalBar.sortGroups", bundle: bundle) }
    // Context Menu
    public static var inviteMembers: String { String(localized: "groupHorizontalBar.inviteMembers", bundle: bundle) }
    public static var notificationSettings: String { String(localized: "groupHorizontalBar.notificationSettings", bundle: bundle) }
    public static var groupSettings: String { String(localized: "groupHorizontalBar.groupSettings", bundle: bundle) }
    public static var createSchedule: String { String(localized: "groupHorizontalBar.createSchedule", bundle: bundle) }
  }

  // MARK: - GroupSortSettings
  public enum GroupSortSettings {
    public static var title: String { String(localized: "groupSortSettings.title", bundle: bundle) }
    public static var longPressHint: String { String(localized: "groupSortSettings.longPressHint", bundle: bundle) }
    public static var preview: String { String(localized: "groupSortSettings.preview", bundle: bundle) }
    // SortType displayTitles
    public static var sortJoined: String { String(localized: "groupSortSettings.sort.joined", bundle: bundle) }
    public static var sortName: String { String(localized: "groupSortSettings.sort.name", bundle: bundle) }
    public static var sortCustom: String { String(localized: "groupSortSettings.sort.custom", bundle: bundle) }
  }

  // MARK: - ScheduleShare
  public enum ScheduleShare {
    public static var title: String { String(localized: "scheduleShare.title", bundle: bundle) }
    public static var subtitle: String { String(localized: "scheduleShare.subtitle", bundle: bundle) }
    public static var kakaoButton: String { String(localized: "scheduleShare.kakaoButton", bundle: bundle) }
    public static var systemButton: String { String(localized: "scheduleShare.systemButton", bundle: bundle) }
  }

  // MARK: - Weather
  public enum Weather {
    public static var sectionTitle: String { String(localized: "weather.sectionTitle", bundle: bundle) }
    public static func feelsLike(_ temp: Int) -> String {
      String(localized: "weather.feelsLike", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(temp)")
    }
    public static func precipitation(_ percent: Int) -> String {
      String(localized: "weather.precipitation", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(percent)")
        .replacingOccurrences(of: "%%", with: "%")
    }
    public static var hourlyForecast: String { String(localized: "weather.hourlyForecast", bundle: bundle) }
    public static var dailyForecast: String { String(localized: "weather.dailyForecast", bundle: bundle) }
    public static var feelsLikeLabel: String { String(localized: "weather.feelsLikeLabel", bundle: bundle) }
    public static var humidity: String { String(localized: "weather.humidity", bundle: bundle) }
    public static var wind: String { String(localized: "weather.wind", bundle: bundle) }
    public static var midTermSource: String { String(localized: "weather.midTermSource", bundle: bundle) }
    public static var shortTermSource: String { String(localized: "weather.shortTermSource", bundle: bundle) }
    public static func scheduleTime(_ time: String) -> String {
      String(localized: "weather.scheduleTime", bundle: bundle)
        .replacingOccurrences(of: "%@", with: time)
    }
    public static func hourLabel(_ hour: Int) -> String {
      String(localized: "weather.hourLabel", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(hour)")
    }
    // Tooltip
    public static func feelsLikeRange(_ range: String) -> String {
      String(localized: "weather.tooltip.feelsLikeRange", bundle: bundle)
        .replacingOccurrences(of: "%@", with: range)
    }
    public static var precipitationLabel: String { String(localized: "weather.tooltip.precipitationLabel", bundle: bundle) }
    public static var tempRangeLabel: String { String(localized: "weather.tooltip.tempRangeLabel", bundle: bundle) }
    public static var weatherLabel: String { String(localized: "weather.tooltip.weatherLabel", bundle: bundle) }
    public static func referenceTime(_ time: String) -> String {
      String(localized: "weather.tooltip.referenceTime", bundle: bundle)
        .replacingOccurrences(of: "%@", with: time)
    }
    // Condition
    public static var conditionClear: String { String(localized: "weather.condition.clear", bundle: bundle) }
    public static var conditionCloudy: String { String(localized: "weather.condition.cloudy", bundle: bundle) }
    public static var conditionOvercast: String { String(localized: "weather.condition.overcast", bundle: bundle) }
    public static var conditionRain: String { String(localized: "weather.condition.rain", bundle: bundle) }
    public static var conditionRainSnow: String { String(localized: "weather.condition.rainSnow", bundle: bundle) }
    public static var conditionSnow: String { String(localized: "weather.condition.snow", bundle: bundle) }
    public static var conditionShower: String { String(localized: "weather.condition.shower", bundle: bundle) }
    public static var conditionUnknown: String { String(localized: "weather.condition.unknown", bundle: bundle) }
    // Advice
    public static var adviceBringUmbrella: String { String(localized: "weather.advice.bringUmbrella", bundle: bundle) }
    public static var adviceDressWarm: String { String(localized: "weather.advice.dressWarm", bundle: bundle) }
    public static var adviceDressCool: String { String(localized: "weather.advice.dressCool", bundle: bundle) }
    public static var adviceStrongWind: String { String(localized: "weather.advice.strongWind", bundle: bundle) }
    public static var adviceHeavySnow: String { String(localized: "weather.advice.heavySnow", bundle: bundle) }
    public static var adviceClearWeather: String { String(localized: "weather.advice.clearWeather", bundle: bundle) }
    public static var adviceHotWeather: String { String(localized: "weather.advice.hotWeather", bundle: bundle) }
    // Suggestion
    public static var suggestExtremeCold: String { String(localized: "weather.suggest.extremeCold", bundle: bundle) }
    public static var suggestBelowFreezing: String { String(localized: "weather.suggest.belowFreezing", bundle: bundle) }
    public static var suggestVeryCold: String { String(localized: "weather.suggest.veryCold", bundle: bundle) }
    public static var suggestChilly: String { String(localized: "weather.suggest.chilly", bundle: bundle) }
    public static var suggestCool: String { String(localized: "weather.suggest.cool", bundle: bundle) }
    public static var suggestComfortable: String { String(localized: "weather.suggest.comfortable", bundle: bundle) }
    public static var suggestWarm: String { String(localized: "weather.suggest.warm", bundle: bundle) }
    public static var suggestHot: String { String(localized: "weather.suggest.hot", bundle: bundle) }
    public static var suggestVeryHot: String { String(localized: "weather.suggest.veryHot", bundle: bundle) }
    public static var suggestExtremeHeat: String { String(localized: "weather.suggest.extremeHeat", bundle: bundle) }
    public static func suggestFeelsLikeDiff(_ feels: Int, _ diff: Int) -> String {
      String(localized: "weather.suggest.feelsLikeDiff", bundle: bundle)
        .replacingOccurrences(of: "{feels}", with: "\(feels)")
        .replacingOccurrences(of: "{diff}", with: "\(diff)")
    }
    public static var suggestHeavySnow: String { String(localized: "weather.suggest.heavySnow", bundle: bundle) }
    public static var suggestPossibleSnow: String { String(localized: "weather.suggest.possibleSnow", bundle: bundle) }
    public static var suggestLikelyRain: String { String(localized: "weather.suggest.likelyRain", bundle: bundle) }
    public static var suggestPossibleRain: String { String(localized: "weather.suggest.possibleRain", bundle: bundle) }
    public static var suggestRainSnow: String { String(localized: "weather.suggest.rainSnow", bundle: bundle) }
    public static func suggestPrecipChance(_ prob: Int) -> String {
      String(localized: "weather.suggest.precipChance", bundle: bundle)
        .replacingOccurrences(of: "{prob}", with: "\(prob)")
    }
    public static var suggestStrongWind: String { String(localized: "weather.suggest.strongWind", bundle: bundle) }
    public static var suggestModerateWind: String { String(localized: "weather.suggest.moderateWind", bundle: bundle) }
    public static var suggestHighHumidity: String { String(localized: "weather.suggest.highHumidity", bundle: bundle) }
    public static var suggestDry: String { String(localized: "weather.suggest.dry", bundle: bundle) }
    public static var suggestUvWarning: String { String(localized: "weather.suggest.uvWarning", bundle: bundle) }
    public static var suggestNiceWeather: String { String(localized: "weather.suggest.niceWeather", bundle: bundle) }
    // Hint Loading
    public static func hintLoading(_ dateText: String, _ locationName: String) -> String {
      var result = String(localized: "weather.hint.loading", bundle: bundle)
      if let range = result.range(of: "%@") {
        result = result.replacingCharacters(in: range, with: dateText)
      }
      if let range = result.range(of: "%@") {
        result = result.replacingCharacters(in: range, with: locationName)
      }
      return result
    }
  }

  // MARK: - DateFormat
  public enum DateFormat {
    public static var passed: String { String(localized: "date.passed", bundle: bundle) }
    public static func secondsLater(_ sec: Int) -> String {
      String(localized: "date.secondsLater", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(sec)")
    }
    public static func minutesLater(_ min: Int) -> String {
      String(localized: "date.minutesLater", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(min)")
    }
    public static func hoursMinutesLater(_ hours: Int, _ min: Int) -> String {
      String(localized: "date.hoursMinutesLater", bundle: bundle)
        .replacingOccurrences(of: "{hours}", with: "\(hours)")
        .replacingOccurrences(of: "{min}", with: "\(min)")
    }
    public static func hoursLater(_ hours: Int) -> String {
      String(localized: "date.hoursLater", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(hours)")
    }
    public static func daysHoursLater(_ days: Int, _ hours: Int) -> String {
      String(localized: "date.daysHoursLater", bundle: bundle)
        .replacingOccurrences(of: "{days}", with: "\(days)")
        .replacingOccurrences(of: "{hours}", with: "\(hours)")
    }
    public static func daysLater(_ days: Int) -> String {
      String(localized: "date.daysLater", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(days)")
    }
    public static var today: String { String(localized: "date.today", bundle: bundle) }
    public static var tomorrow: String { String(localized: "date.tomorrow", bundle: bundle) }
    public static var yesterday: String { String(localized: "date.yesterday", bundle: bundle) }
    public static func durationDays(_ d: Int) -> String { "\(d)" + String(localized: "date.duration.days", bundle: bundle) }
    public static func durationHours(_ h: Int) -> String { "\(h)" + String(localized: "date.duration.hours", bundle: bundle) }
    public static func durationMinutes(_ m: Int) -> String { "\(m)" + String(localized: "date.duration.minutes", bundle: bundle) }
  }

  // MARK: - ThemeMode
  public enum ThemeMode {
    public static var system: String { String(localized: "themeMode.system", bundle: bundle) }
    public static var light: String { String(localized: "themeMode.light", bundle: bundle) }
    public static var dark: String { String(localized: "themeMode.dark", bundle: bundle) }
  }

  // MARK: - KakaoShare (Toast)
  public enum KakaoShare {
    public static var inviteLinkShared: String { String(localized: "kakaoShare.inviteLinkShared", bundle: bundle) }
    public static var scheduleShared: String { String(localized: "kakaoShare.scheduleShared", bundle: bundle) }
    public static var kakaoInviteButton: String { String(localized: "kakaoShare.kakaoInviteButton", bundle: bundle) }
    public static var joinButton: String { String(localized: "kakaoShare.joinButton", bundle: bundle) }
    public static func groupInviteTitle(_ inviterName: String, _ groupName: String) -> String {
      String(localized: "kakaoShare.groupInviteTitle", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: inviterName)
        .replacingOccurrences(of: "%2$@", with: groupName)
    }
    public static var groupInviteDescription: String {
      String(localized: "kakaoShare.groupInviteDescription", bundle: bundle)
    }
    public static var upcomingSchedule: String { String(localized: "kakaoShare.upcomingSchedule", bundle: bundle) }
    public static var scheduleCheckButton: String { String(localized: "kakaoShare.scheduleCheckButton", bundle: bundle) }
    public static func scheduleTitle(_ emoji: String, _ title: String) -> String {
      String(localized: "kakaoShare.scheduleTitle", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: emoji)
        .replacingOccurrences(of: "%2$@", with: title)
    }
  }

  // MARK: - GroupComponents
  public enum GroupComponents {
    // CurrentGroupCard
    public static func activeCount(_ count: Int) -> String {
      String(localized: "groupComponents.activeCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func pendingCount(_ count: Int) -> String {
      String(localized: "groupComponents.pendingCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    // GroupDetailView
    public static var members: String { String(localized: "groupComponents.members", bundle: bundle) }
    public static var active: String { String(localized: "groupComponents.active", bundle: bundle) }
    public static var pending: String { String(localized: "groupComponents.pending", bundle: bundle) }
    public static var notification: String { String(localized: "groupComponents.notification", bundle: bundle) }
    public static var groupSettings: String { String(localized: "groupComponents.groupSettings", bundle: bundle) }
    public static var me: String { String(localized: "groupComponents.me", bundle: bundle) }
    public static func membersCount(_ count: Int) -> String {
      String(localized: "groupComponents.membersCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var tomorrow: String { String(localized: "groupComponents.tomorrow", bundle: bundle) }
    // ScheduleSectionView
    public static func seeMoreCount(_ count: Int) -> String {
      String(localized: "groupComponents.seeMoreCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    // ScheduleTimelineView
    public static var errorOccurred: String { String(localized: "groupComponents.errorOccurred", bundle: bundle) }
    public static var emptyAll: String { String(localized: "groupComponents.empty.all", bundle: bundle) }
    public static var emptyNeedResponse: String { String(localized: "groupComponents.empty.needResponse", bundle: bundle) }
    public static var emptyResponded: String { String(localized: "groupComponents.empty.responded", bundle: bundle) }
    public static var emptyConfirmed: String { String(localized: "groupComponents.empty.confirmed", bundle: bundle) }
  }

  // MARK: - ScheduleCard
  public enum ScheduleCard {
    // Host section
    public static var myProposal: String { String(localized: "scheduleCard.myProposal", bundle: bundle) }
    public static func hostProposal(_ name: String) -> String {
      String(localized: "scheduleCard.hostProposal", bundle: bundle)
        .replacingOccurrences(of: "%@", with: name)
    }
    public static var proposal: String { String(localized: "scheduleCard.proposal", bundle: bundle) }
    // Confirmation progress
    public static func confirmationRemaining(_ count: Int) -> String {
      String(localized: "scheduleCard.confirmationRemaining", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    // Arrival sharing
    public static func liveShareStart(_ minutes: Int) -> String {
      String(localized: "scheduleCard.liveShareStart", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    // Photo count
    public static func photoCount(_ count: Int) -> String {
      String(localized: "scheduleCard.photoCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    // Vote count
    public static func voteCount(_ voted: Int, _ total: Int) -> String {
      String(localized: "scheduleCard.voteCount", bundle: bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(voted)")
        .replacingOccurrences(of: "%2$lld", with: "\(total)")
    }
    // Context menu
    public static var changeResponse: String { String(localized: "scheduleCard.changeResponse", bundle: bundle) }
    public static var acceptAction: String { String(localized: "scheduleCard.acceptAction", bundle: bundle) }
    public static var rejectAction: String { String(localized: "scheduleCard.rejectAction", bundle: bundle) }
    public static var resetToPending: String { String(localized: "scheduleCard.resetToPending", bundle: bundle) }
    public static var editSchedule: String { String(localized: "scheduleCard.editSchedule", bundle: bundle) }
    public static var deleteSchedule: String { String(localized: "scheduleCard.deleteSchedule", bundle: bundle) }
    public static var viewDetail: String { String(localized: "scheduleCard.viewDetail", bundle: bundle) }
    public static var share: String { String(localized: "scheduleCard.share", bundle: bundle) }
    // Response badge
    public static var responseAccepted: String { String(localized: "scheduleCard.responseAccepted", bundle: bundle) }
    public static var responseDeclined: String { String(localized: "scheduleCard.responseDeclined", bundle: bundle) }
    public static func myResponseLabel(_ status: String) -> String {
      String(localized: "scheduleCard.myResponseLabel", bundle: bundle)
        .replacingOccurrences(of: "%@", with: status)
    }
    // Status badge (responding)
    public static var accepting: String { String(localized: "scheduleCard.accepting", bundle: bundle) }
    public static var rejecting: String { String(localized: "scheduleCard.rejecting", bundle: bundle) }
    public static var resetting: String { String(localized: "scheduleCard.resetting", bundle: bundle) }
    // Schedule response status
    public static var statusNeedResponse: String { String(localized: "scheduleCard.status.needResponse", bundle: bundle) }
    public static var statusResponded: String { String(localized: "scheduleCard.status.responded", bundle: bundle) }
    public static var statusConfirmed: String { String(localized: "scheduleCard.status.confirmed", bundle: bundle) }
    public static var statusFailed: String { String(localized: "scheduleCard.status.failed", bundle: bundle) }
    public static func acceptedCount(_ count: Int) -> String {
      String(localized: "scheduleCard.acceptedCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func declinedCount(_ count: Int) -> String {
      String(localized: "scheduleCard.declinedCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func confirmedCount(_ count: Int) -> String {
      String(localized: "scheduleCard.confirmedCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func totalCount(_ count: Int) -> String {
      String(localized: "scheduleCard.totalCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
  }

  // MARK: - OverlayScheduleDetail
  public enum OverlayScheduleDetail {
    public static var personalEvent: String { String(localized: "overlayScheduleDetail.personalEvent", bundle: bundle) }
    public static var now: String { String(localized: "overlayScheduleDetail.now", bundle: bundle) }
    public static var startsAfter: String { String(localized: "overlayScheduleDetail.startsAfter", bundle: bundle) }
    public static var inProgress: String { String(localized: "overlayScheduleDetail.inProgress", bundle: bundle) }
    public static var pastEvent: String { String(localized: "overlayScheduleDetail.pastEvent", bundle: bundle) }
    public static var memo: String { String(localized: "overlayScheduleDetail.memo", bundle: bundle) }
    public static var viewFullDetail: String { String(localized: "overlayScheduleDetail.viewFullDetail", bundle: bundle) }
    public static var accept: String { String(localized: "overlayScheduleDetail.accept", bundle: bundle) }
    public static var pending: String { String(localized: "overlayScheduleDetail.pending", bundle: bundle) }
    public static var reject: String { String(localized: "overlayScheduleDetail.reject", bundle: bundle) }
    public static var respondFailed: String { String(localized: "overlayScheduleDetail.respondFailed", bundle: bundle) }
    public static var confirmed: String { String(localized: "overlayScheduleDetail.confirmed", bundle: bundle) }
    public static func confirmationRemaining(_ count: Int) -> String {
      String(localized: "overlayScheduleDetail.confirmationRemaining", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func participationCount(_ count: Int) -> String {
      String(localized: "overlayScheduleDetail.participationCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func declinedCount(_ count: Int) -> String {
      String(localized: "overlayScheduleDetail.declinedCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func confirmThreshold(_ count: Int) -> String {
      String(localized: "overlayScheduleDetail.confirmThreshold", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func totalCount(_ count: Int) -> String {
      String(localized: "overlayScheduleDetail.totalCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var participated: String { String(localized: "overlayScheduleDetail.participated", bundle: bundle) }
    public static var declined: String { String(localized: "overlayScheduleDetail.declined", bundle: bundle) }
  }

  // MARK: - GroupScheduleList
  public enum GroupScheduleList {
    public static func navigationTitle(_ groupName: String) -> String {
      String(localized: "groupScheduleList.navigationTitle", bundle: bundle)
        .replacingOccurrences(of: "%@", with: groupName)
    }
    public static var emptyNeedResponse: String { String(localized: "groupScheduleList.empty.needResponse", bundle: bundle) }
    public static var emptyResponded: String { String(localized: "groupScheduleList.empty.responded", bundle: bundle) }
    public static var emptyConfirmed: String { String(localized: "groupScheduleList.empty.confirmed", bundle: bundle) }
    public static var emptyAll: String { String(localized: "groupScheduleList.empty.all", bundle: bundle) }
    // StatusFilter display titles
    public static var filterNeedResponse: String { String(localized: "groupScheduleList.filter.needResponse", bundle: bundle) }
    public static var filterResponded: String { String(localized: "groupScheduleList.filter.responded", bundle: bundle) }
    public static var filterConfirmed: String { String(localized: "groupScheduleList.filter.confirmed", bundle: bundle) }
    public static var filterAll: String { String(localized: "groupScheduleList.filter.all", bundle: bundle) }
    public static var statusFilterLabel: String { String(localized: "groupScheduleList.statusFilterLabel", bundle: bundle) }
  }

  // MARK: - LiveSchedule
  public enum LiveSchedule {
    public static var infoTitle: String { String(localized: "liveSchedule.info.title", bundle: bundle) }
    public static var infoSubtitle: String { String(localized: "liveSchedule.info.subtitle", bundle: bundle) }
    public static var infoDynamicIsland: String {
      String(localized: "liveSchedule.info.dynamicIsland", bundle: bundle)
    }
    public static var infoLockScreen: String { String(localized: "liveSchedule.info.lockScreen", bundle: bundle) }
    public static var infoSupportNote: String { String(localized: "liveSchedule.info.supportNote", bundle: bundle) }
    public static var infoDefaultTitle: String {
      String(localized: "liveSchedule.info.defaultTitle", bundle: bundle)
    }
    public static var infoDefaultLocation: String {
      String(localized: "liveSchedule.info.defaultLocation", bundle: bundle)
    }

    // Detail Tabs
    public static var tabStatus: String { String(localized: "liveSchedule.tab.status", bundle: bundle) }
    public static var tabMap: String { String(localized: "liveSchedule.tab.map", bundle: bundle) }
    public static var tabChat: String { String(localized: "liveSchedule.tab.chat", bundle: bundle) }

    // Participant
    public static func participantCount(_ count: Int) -> String {
      String(localized: "liveSchedule.participantCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }

    // Time Display
    public static func hoursMinutes(_ hours: Int, _ minutes: Int) -> String {
      String(localized: "liveSchedule.time.hoursMinutes", bundle: bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(hours)")
        .replacingOccurrences(of: "%2$lld", with: "\(minutes)")
    }
    public static func minutesOnly(_ minutes: Int) -> String {
      String(localized: "liveSchedule.time.minutesOnly", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static var elapsed: String { String(localized: "liveSchedule.time.elapsed", bundle: bundle) }
    public static var realtime: String { String(localized: "liveSchedule.realtime", bundle: bundle) }
    public static var directions: String { String(localized: "liveSchedule.directions", bundle: bundle) }

    // Participants Section
    public static var participantsStatus: String { String(localized: "liveSchedule.participants.status", bundle: bundle) }
    public static func arrivedCount(_ arrived: Int, _ total: Int) -> String {
      String(localized: "liveSchedule.participants.arrivedCount", bundle: bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(arrived)")
        .replacingOccurrences(of: "%2$lld", with: "\(total)")
    }
    public static var etaNotice1: String { String(localized: "liveSchedule.eta.notice1", bundle: bundle) }
    public static var etaNotice2: String { String(localized: "liveSchedule.eta.notice2", bundle: bundle) }
    public static var me: String { String(localized: "liveSchedule.me", bundle: bundle) }
    public static var changeAction: String { String(localized: "liveSchedule.change", bundle: bundle) }

    // Status
    public static var arrived: String { String(localized: "liveSchedule.status.arrived", bundle: bundle) }
    public static func etaMinutes(_ minutes: Int) -> String {
      String(localized: "liveSchedule.status.etaMinutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static var waiting: String { String(localized: "liveSchedule.status.waiting", bundle: bundle) }
    public static var late: String { String(localized: "liveSchedule.status.late", bundle: bundle) }
    public static var beforeStart: String { String(localized: "liveSchedule.status.beforeStart", bundle: bundle) }
    public static var almostThere: String { String(localized: "liveSchedule.status.almostThere", bundle: bundle) }
    public static var lateExpected: String { String(localized: "liveSchedule.status.lateExpected", bundle: bundle) }
    public static var onTheWay: String { String(localized: "liveSchedule.status.onTheWay", bundle: bundle) }
    public static func groupedName(_ name: String, _ count: Int) -> String {
      String(localized: "liveSchedule.groupedName", bundle: bundle)
        .replacingOccurrences(of: "%1$@", with: name)
        .replacingOccurrences(of: "%2$lld", with: "\(count)")
    }

    // ETA Sheet
    public static var etaArrived: String { String(localized: "liveSchedule.eta.arrived", bundle: bundle) }
    public static var directInput: String { String(localized: "liveSchedule.eta.directInput", bundle: bundle) }
    public static var minuteUnit: String { String(localized: "liveSchedule.eta.minuteUnit", bundle: bundle) }
    public static var minutesUntilArrival: String { String(localized: "liveSchedule.eta.minutesUntilArrival", bundle: bundle) }
    public static var confirm: String { String(localized: "liveSchedule.eta.confirm", bundle: bundle) }

    // Error
    public static var errorNotSupported: String { String(localized: "liveSchedule.error.notSupported", bundle: bundle) }
    public static var errorActivityNotFound: String { String(localized: "liveSchedule.error.activityNotFound", bundle: bundle) }
    public static var errorStartFailed: String { String(localized: "liveSchedule.error.startFailed", bundle: bundle) }
    public static var errorUpdateFailed: String { String(localized: "liveSchedule.error.updateFailed", bundle: bundle) }

    // Fallback
    public static var groupFallback: String { String(localized: "liveSchedule.groupFallback", bundle: bundle) }

    // LiveActivity
    public static var scheduleTime: String { String(localized: "liveSchedule.scheduleTime", bundle: bundle) }
    public static var manualInput: String { String(localized: "liveSchedule.manualInput", bundle: bundle) }
    public static var autoStartDescription: String { String(localized: "liveSchedule.autoStartDescription", bundle: bundle) }
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

// MARK: - App Language

public enum AppLanguage: String, CaseIterable, Sendable {
  case korean = "ko"
  case english = "en"

  public var displayName: String {
    LocaleManager.appLocale.localizedString(forLanguageCode: rawValue) ?? rawValue
  }

  public var icon: String {
    switch self {
    case .korean: return "🇰🇷"
    case .english: return "🇺🇸"
    }
  }

  public var locale: Locale {
    switch self {
    case .korean: return Locale(identifier: "ko_KR")
    case .english: return Locale(identifier: "en_US")
    }
  }

  /// 현재 설정된 언어 (UserDefaults 기반, nil이면 시스템 기본)
  public static var current: AppLanguage? {
    current(userDefaults: .standard)
  }

  /// 현재 앱에서 해석된 언어 (저장값 우선, 없으면 시스템 선호 언어)
  public static var resolved: AppLanguage {
    resolveLanguage()
  }

  /// 저장된 언어가 없으면 시스템 선호 언어를 초기값으로 저장
  public static func initializeIfNeeded() {
    initializeIfNeeded(userDefaults: .standard)
  }

  static func initializeIfNeeded(
    userDefaults: UserDefaults,
    preferredLocalizations: [String] = Bundle.main.preferredLocalizations,
    preferredLanguages: [String] = Locale.preferredLanguages
  ) {
    guard current(userDefaults: userDefaults) == nil else { return }

    userDefaults.set(
      resolveLanguage(
        userDefaults: userDefaults,
        preferredLocalizations: preferredLocalizations,
        preferredLanguages: preferredLanguages
      ).rawValue,
      forKey: AppConstants.UserDefaults.preferredLanguage
    )
  }

  static func resolveLanguage(
    userDefaults: UserDefaults = .standard,
    preferredLocalizations: [String] = Bundle.main.preferredLocalizations,
    preferredLanguages: [String] = Locale.preferredLanguages
  ) -> AppLanguage {
    if let current = current(userDefaults: userDefaults) {
      return current
    }

    for identifier in preferredLocalizations + preferredLanguages {
      if let language = language(from: identifier) {
        return language
      }
    }

    return .korean
  }

  static func current(userDefaults: UserDefaults) -> AppLanguage? {
    guard let raw = userDefaults.string(forKey: AppConstants.UserDefaults.preferredLanguage) else {
      return nil
    }
    return AppLanguage(rawValue: raw)
  }

  private static func language(from identifier: String) -> AppLanguage? {
    let locale = Locale(identifier: identifier)
    let code = locale.language.languageCode?.identifier ?? identifier
    return AppLanguage(rawValue: code)
  }
}

// MARK: - Locale Manager

public enum LocaleManager {
  /// 앱에서 사용할 Locale (저장값 우선, 없으면 시스템 선호 언어 기반)
  public static var appLocale: Locale {
    AppLanguage.resolved.locale
  }
}

// MARK: - Widget Strings

extension LocalizedStrings {
  /// 위젯에서 사용하는 문자열
  public enum Widget {
    // MARK: - Error
    public static var errorTitle: String { String(localized: "widget.error.title", bundle: bundle) }
    public static var errorRetryHint: String { String(localized: "widget.error.retryHint", bundle: bundle) }

    // MARK: - Auth
    public static var authNotLoggedInTitle: String { String(localized: "widget.auth.notLoggedInTitle", bundle: bundle) }
    public static var authOpenAppHint: String { String(localized: "widget.auth.openAppHint", bundle: bundle) }

    // MARK: - Empty
    public static var emptyCreateScheduleButton: String { String(localized: "widget.empty.createScheduleButton", bundle: bundle) }
    public static var emptyNoSchedulesMessage: String { String(localized: "widget.empty.noSchedulesMessage", bundle: bundle) }
    public static var emptyCreateNewHint: String { String(localized: "widget.empty.createNewHint", bundle: bundle) }
    public static var emptyNoTodaySchedules: String { String(localized: "widget.empty.noTodaySchedules", bundle: bundle) }

    // MARK: - Configuration
    public static var configNextSchedule: String { String(localized: "widget.config.nextSchedule", bundle: bundle) }
    public static var configNextScheduleDescription: String { String(localized: "widget.config.nextScheduleDescription", bundle: bundle) }
    public static var configTodaySchedules: String { String(localized: "widget.config.todaySchedules", bundle: bundle) }
    public static var configTodaySchedulesDescription: String { String(localized: "widget.config.todaySchedulesDescription", bundle: bundle) }
    public static var configAllSchedules: String { String(localized: "widget.config.allSchedules", bundle: bundle) }
    public static var configAllSchedulesDescription: String { String(localized: "widget.config.allSchedulesDescription", bundle: bundle) }
    public static var configDaysRemaining: String { String(localized: "widget.config.daysRemaining", bundle: bundle) }
    public static var configScheduleInfo: String { String(localized: "widget.config.scheduleInfo", bundle: bundle) }

    // MARK: - Common
    public static var today: String { String(localized: "widget.common.today", bundle: bundle) }
    public static var tomorrow: String { String(localized: "widget.common.tomorrow", bundle: bundle) }
    public static var upcomingSchedule: String { String(localized: "widget.common.upcomingSchedule", bundle: bundle) }
    public static var personal: String { String(localized: "widget.common.personal", bundle: bundle) }
    public static var personalEvent: String { String(localized: "widget.common.personalEvent", bundle: bundle) }
    public static var participantCount: String { String(localized: "widget.common.participantCount", bundle: bundle) }
    public static var updatedBasis: String { String(localized: "widget.common.updatedBasis", bundle: bundle) }
    public static var refresh: String { String(localized: "widget.common.refresh", bundle: bundle) }
    public static var noSchedules: String { String(localized: "widget.common.noSchedules", bundle: bundle) }
    public static var loginRequired: String { String(localized: "widget.common.loginRequired", bundle: bundle) }
    public static var noScheduledSchedules: String { String(localized: "widget.common.noScheduledSchedules", bundle: bundle) }
    public static var dataLoadFailed: String { String(localized: "widget.common.dataLoadFailed", bundle: bundle) }
    public static var button: String { String(localized: "widget.button", bundle: bundle) }
    public static var update: String { String(localized: "widget.update", bundle: bundle) }
    public static var daysLater: String { String(localized: "widget.daysLater", bundle: bundle) }
    public static var participantCountShort: String { String(localized: "widget.participantCountShort", bundle: bundle) }
  }

  // MARK: - ScheduleModeSegment
  public enum ScheduleModeSegment {
    public static var group: String { String(localized: "scheduleModeSegment.group", bundle: bundle) }
    public static var personal: String { String(localized: "scheduleModeSegment.personal", bundle: bundle) }
    public static var scheduleTitle: String { String(localized: "scheduleModeSegment.scheduleTitle", bundle: bundle) }
    public static var modePickerLabel: String { String(localized: "scheduleModeSegment.modePickerLabel", bundle: bundle) }
  }

}
