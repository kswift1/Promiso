import Foundation

// MARK: - Localized Strings

/// 앱에서 사용하는 모든 문자열을 관리하는 구조체
public enum LocalizedStrings {

  /// 현재 활성 번들 (언어 전환 시 변경됨)
  private static var _bundle: Bundle = Bundle.module

  /// 현재 활성 번들
  public static var bundle: Bundle { _bundle }

  /// 선호 언어로 번들 설정
  /// - AppMain.init()과 appRestartRequested에서 호출
  public static func configure() {
    guard let lang = UserDefaults.standard.string(forKey: "promisoPreferredLanguage"),
          let path = Bundle.module.path(forResource: lang, ofType: "lproj"),
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
    public static var modify: String { String(localized: "common.modify", bundle: bundle) }
    public static var change: String { String(localized: "common.change", bundle: bundle) }
    public static var laterAction: String { String(localized: "common.later", bundle: bundle) }
    public static var all: String { String(localized: "common.all", bundle: bundle) }
    public static var today: String { String(localized: "common.today", bundle: bundle) }
    public static var photo: String { String(localized: "common.photo", bundle: bundle) }
    public static var settings: String { String(localized: "common.settings", bundle: bundle) }
    public static var start: String { String(localized: "common.start", bundle: bundle) }
    public static var endTime: String { String(localized: "common.endTime", bundle: bundle) }
    public static var date: String { String(localized: "common.date", bundle: bundle) }
    public static var time: String { String(localized: "common.time", bundle: bundle) }
    public static var location: String { String(localized: "common.location", bundle: bundle) }
    public static var reminder: String { String(localized: "common.reminder", bundle: bundle) }
    public static var directions: String { String(localized: "common.directions", bundle: bundle) }
    public static var schedule: String { String(localized: "common.schedule", bundle: bundle) }
    public static var personalEvent: String { String(localized: "common.personalEvent", bundle: bundle) }
    public static var seeMore: String { String(localized: "common.seeMore", bundle: bundle) }
    public static var collapse: String { String(localized: "common.collapse", bundle: bundle) }
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
    public static var heroPromisesWord: String { String(localized: "auth.hero.promisesWord", bundle: bundle) }
    public static var heroMoreSpecial: String { String(localized: "auth.hero.moreSpecial", bundle: bundle) }
    public static var heroPreciousMoments: String { String(localized: "auth.hero.preciousMoments", bundle: bundle) }
    public static var heroWithPromiso: String { String(localized: "auth.hero.withPromiso", bundle: bundle) }

    // Social Login
    public static var continueWithApple: String { String(localized: "auth.continueWithApple", bundle: bundle) }
    public static var continueWithGoogle: String { String(localized: "auth.continueWithGoogle", bundle: bundle) }
  }

  // MARK: - Promises
  public enum Promise {
    public static var promise: String { String(localized: "promise.promise", bundle: bundle) }
    public static var promises: String { String(localized: "promise.promises", bundle: bundle) }
    public static var createPromise: String { String(localized: "promise.create", bundle: bundle) }
    public static var editPromise: String { String(localized: "promise.edit", bundle: bundle) }
    public static var deletePromise: String { String(localized: "promise.delete", bundle: bundle) }
    public static var joinPromise: String { String(localized: "promise.join", bundle: bundle) }
    public static var leavePromise: String { String(localized: "promise.leave", bundle: bundle) }
    public static var completePromise: String { String(localized: "promise.complete", bundle: bundle) }
    public static var cancelPromise: String { String(localized: "promise.cancel", bundle: bundle) }

    public static var title: String { String(localized: "promise.title", bundle: bundle) }
    public static var description: String { String(localized: "promise.description", bundle: bundle) }
    public static var location: String { String(localized: "promise.location", bundle: bundle) }
    public static var dateTime: String { String(localized: "promise.dateTime", bundle: bundle) }
    public static var participants: String { String(localized: "promise.participants", bundle: bundle) }

    // Status
    public static var scheduled: String { String(localized: "promise.status.scheduled", bundle: bundle) }
    public static var ongoing: String { String(localized: "promise.status.ongoing", bundle: bundle) }
    public static var completed: String { String(localized: "promise.status.completed", bundle: bundle) }
    public static var missed: String { String(localized: "promise.status.missed", bundle: bundle) }
    public static var cancelled: String { String(localized: "promise.status.cancelled", bundle: bundle) }

    // Priority
    public static var priorityLow: String { String(localized: "promise.priority.low", bundle: bundle) }
    public static var priorityNormal: String { String(localized: "promise.priority.normal", bundle: bundle) }
    public static var priorityHigh: String { String(localized: "promise.priority.high", bundle: bundle) }
    public static var priorityUrgent: String { String(localized: "promise.priority.urgent", bundle: bundle) }

    // Messages
    public static var noPromises: String { String(localized: "promise.empty.title", bundle: bundle) }
    public static var noPromisesSubtitle: String { String(localized: "promise.empty.subtitle", bundle: bundle) }
    public static var createFirstPromise: String { String(localized: "promise.empty.action", bundle: bundle) }

    // Success Messages
    public static var createSuccess: String { String(localized: "promise.success.create", bundle: bundle) }
    public static var updateSuccess: String { String(localized: "promise.success.update", bundle: bundle) }
    public static var deleteSuccess: String { String(localized: "promise.success.delete", bundle: bundle) }
    public static var joinSuccess: String { String(localized: "promise.success.join", bundle: bundle) }
    public static var leaveSuccess: String { String(localized: "promise.success.leave", bundle: bundle) }
    public static var completeSuccess: String { String(localized: "promise.success.complete", bundle: bundle) }
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
  public enum Settings {
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
  }

  // MARK: - Errors
  public enum Error {
    public static var networkError: String { String(localized: "error.network", bundle: bundle) }
    public static var unknownError: String { String(localized: "error.unknown", bundle: bundle) }
    public static var serverError: String { String(localized: "error.server", bundle: bundle) }
    public static var timeoutError: String { String(localized: "error.timeout", bundle: bundle) }
    public static var validationError: String { String(localized: "error.validation", bundle: bundle) }
    public static var permissionError: String { String(localized: "error.permission", bundle: bundle) }
    public static var notFoundError: String { String(localized: "error.notFound", bundle: bundle) }
  }

  // MARK: - Tab Bar
  public enum TabBar {
    public static var home: String { String(localized: "tab.home", bundle: bundle) }
    public static var promise: String { String(localized: "tab.promise", bundle: bundle) }
    public static var calendar: String { String(localized: "tab.calendar", bundle: bundle) }
    public static var group: String { String(localized: "tab.group", bundle: bundle) }
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
  }

  // MARK: - AppEntry
  public enum AppEntry {
    public static var forceUpdateTitle: String { String(localized: "appEntry.update.forceTitle", bundle: bundle) }
    public static var recommendUpdateTitle: String { String(localized: "appEntry.update.recommendTitle", bundle: bundle) }
    public static var updateAction: String { String(localized: "appEntry.update.action", bundle: bundle) }
    public static var updateLater: String { String(localized: "appEntry.update.later", bundle: bundle) }
  }

  // MARK: - Profile
  public enum Profile {
    public static var nicknameCheckRequired: String { String(localized: "profile.error.nicknameCheckRequired", bundle: bundle) }
    public static var nicknameTaken: String { String(localized: "profile.error.nicknameTaken", bundle: bundle) }
    public static var nicknameCheckFailed: String { String(localized: "profile.error.nicknameCheckFailed", bundle: bundle) }
    public static var saveFailed: String { String(localized: "profile.error.saveFailed", bundle: bundle) }
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

    // Timeline
    public static var accepted: String { String(localized: "home.timeline.accepted", bundle: bundle) }
    public static var declined: String { String(localized: "home.timeline.declined", bundle: bundle) }
    public static var tomorrow: String { String(localized: "home.timeline.tomorrow", bundle: bundle) }
    public static var dayAfterTomorrow: String { String(localized: "home.timeline.dayAfterTomorrow", bundle: bundle) }

    // Need Response Banner
    public static var responseNeeded: String { String(localized: "home.banner.responseNeeded", bundle: bundle) }
    public static func promisesToRespond(_ count: Int) -> String {
      String(localized: "home.banner.promisesToRespond", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }

    // Empty State
    public static var emptyNoPromisesTitle: String { String(localized: "home.empty.noPromises.title", bundle: bundle) }
    public static var emptyNoPromisesMessage: String { String(localized: "home.empty.noPromises.message", bundle: bundle) }
    public static var emptyNoFilterTitle: String { String(localized: "home.empty.noFilter.title", bundle: bundle) }
    public static var emptyNoFilterMessage: String { String(localized: "home.empty.noFilter.message", bundle: bundle) }
    public static var emptyNoGroupsTitle: String { String(localized: "home.empty.noGroups.title", bundle: bundle) }
    public static var emptyNoGroupsMessage: String { String(localized: "home.empty.noGroups.message", bundle: bundle) }
    public static var createNewPromise: String { String(localized: "home.empty.createPromise", bundle: bundle) }
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

    // Timeline
    public static var startLiveSharing: String { String(localized: "home.timeline.startLiveSharing", bundle: bundle) }

    // StatusFilter display titles
    public static var filterAll: String { String(localized: "home.filter.all", bundle: bundle) }
    public static var filterNeedResponse: String { String(localized: "home.filter.needResponse", bundle: bundle) }
    public static var filterConfirmed: String { String(localized: "home.filter.confirmed", bundle: bundle) }
    public static var filterInProgress: String { String(localized: "home.filter.inProgress", bundle: bundle) }
  }

  // MARK: - Shared (SharedFeature)
  public enum Shared {
    // Edit Promise
    public static var editPromiseTitle: String { String(localized: "shared.editPromise.title", bundle: bundle) }
    public static var editFailed: String { String(localized: "shared.editPromise.failed", bundle: bundle) }
    public static var promiseTitlePlaceholder: String { String(localized: "shared.editPromise.titlePlaceholder", bundle: bundle) }
    public static var optional: String { String(localized: "shared.editPromise.optional", bundle: bundle) }
    public static var addLocation: String { String(localized: "shared.editPromise.addLocation", bundle: bundle) }
    public static var minimumParticipants: String { String(localized: "shared.editPromise.minimumParticipants", bundle: bundle) }
    public static func maxMembers(_ count: Int) -> String {
      String(localized: "shared.editPromise.maxMembers", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func minMembersDescription(_ count: Int) -> String {
      String(localized: "shared.editPromise.minMembersDescription", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var liveSharing: String { String(localized: "shared.editPromise.liveSharing", bundle: bundle) }
    public static func liveStartMinutes(_ minutes: Int) -> String {
      String(localized: "shared.editPromise.liveStartMinutes", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static func liveSharingDescription(_ minutes: Int) -> String {
      String(localized: "shared.editPromise.liveSharingDescription", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static var manualStart: String { String(localized: "shared.editPromise.manualStart", bundle: bundle) }
    public static func minutesBefore(_ minutes: Int) -> String {
      String(localized: "shared.editPromise.minutesBefore", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static var minutesBeforeStartLabel: String { String(localized: "shared.editPromise.minutesBeforeStartLabel", bundle: bundle) }

    // Promise Detail
    public static var voteDeadline: String { String(localized: "shared.promiseDetail.voteDeadline", bundle: bundle) }
    public static var minimumConfirmMembers: String { String(localized: "shared.promiseDetail.minimumConfirm", bundle: bundle) }
    public static func membersCount(_ count: Int) -> String {
      String(localized: "shared.promiseDetail.membersCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var participantsSection: String { String(localized: "shared.promiseDetail.participants", bundle: bundle) }
    public static func participantsJoined(_ current: Int, _ total: Int) -> String {
      String(localized: "shared.promiseDetail.participantsJoined", bundle: bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(current)")
        .replacingOccurrences(of: "%2$lld", with: "\(total)")
    }
    public static var responseAccepted: String { String(localized: "shared.promiseDetail.accepted", bundle: bundle) }
    public static var responseDeclined: String { String(localized: "shared.promiseDetail.declined", bundle: bundle) }
    public static var responseNoAnswer: String { String(localized: "shared.promiseDetail.noAnswer", bundle: bundle) }
    public static var myResponse: String { String(localized: "shared.promiseDetail.myResponse", bundle: bundle) }
    public static var editPromise: String { String(localized: "shared.promiseDetail.edit", bundle: bundle) }
    public static var deletePromise: String { String(localized: "shared.promiseDetail.delete", bundle: bundle) }
    public static var undetermined: String { String(localized: "shared.promiseDetail.undetermined", bundle: bundle) }
    public static func deletePromiseConfirm(_ title: String) -> String {
      String(localized: "shared.promiseDetail.deleteConfirm", bundle: bundle)
        .replacingOccurrences(of: "%@", with: title)
    }

    // Promise Detail Status
    public static var statusNeedResponse: String { String(localized: "shared.promiseDetail.status.needResponse", bundle: bundle) }
    public static var statusWaitingConfirm: String { String(localized: "shared.promiseDetail.status.waitingConfirm", bundle: bundle) }
    public static var statusConfirmed: String { String(localized: "shared.promiseDetail.status.confirmed", bundle: bundle) }
    public static var statusFailed: String { String(localized: "shared.promiseDetail.status.failed", bundle: bundle) }

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
  }

  // MARK: - Calendar
  public enum Calendar {
    public static var loadingPromises: String { String(localized: "calendar.loading", bundle: bundle) }
    public static var noPromises: String { String(localized: "calendar.empty.title", bundle: bundle) }
    public static var createNewPromise: String { String(localized: "calendar.empty.subtitle", bundle: bundle) }
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

    // Calendar Permission Banner
    public static var syncCalendarTitle: String { String(localized: "calendar.sync.title", bundle: bundle) }
    public static var syncCalendarSubtitle: String { String(localized: "calendar.sync.subtitle", bundle: bundle) }
    public static var syncAction: String { String(localized: "calendar.sync.action", bundle: bundle) }
    public static var readAccessTitle: String { String(localized: "calendar.sync.readAccess.title", bundle: bundle) }
    public static var readAccessSubtitle: String { String(localized: "calendar.sync.readAccess.subtitle", bundle: bundle) }
    public static var calendarPermissionTitle: String { String(localized: "calendar.sync.permission.title", bundle: bundle) }
    public static var calendarPermissionSubtitle: String { String(localized: "calendar.sync.permission.subtitle", bundle: bundle) }
    public static var doNotShowAgain: String { String(localized: "calendar.sync.doNotShow", bundle: bundle) }

    // Promise Card Status
    public static var statusWaiting: String { String(localized: "calendar.promise.statusWaiting", bundle: bundle) }
    public static var statusVoting: String { String(localized: "calendar.promise.statusVoting", bundle: bundle) }
    public static var statusConfirmed: String { String(localized: "calendar.promise.statusConfirmed", bundle: bundle) }
    public static var statusFailed: String { String(localized: "calendar.promise.statusFailed", bundle: bundle) }
    public static var respondAction: String { String(localized: "calendar.promise.respond", bundle: bundle) }
    public static func additionalItems(_ count: Int) -> String {
      String(localized: "calendar.promise.additionalItems", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
  }

  // MARK: - Personal
  public enum Personal {
    public static var emptyToday: String { String(localized: "personal.empty.today", bundle: bundle) }
    public static var emptyFuture: String { String(localized: "personal.empty.future", bundle: bundle) }
    public static var emptyAll: String { String(localized: "personal.empty.all", bundle: bundle) }
    public static var emptyPast: String { String(localized: "personal.empty.past", bundle: bundle) }
    public static var viewDetail: String { String(localized: "personal.event.viewDetail", bundle: bundle) }
    public static func photoCount(_ count: Int) -> String {
      String(localized: "personal.event.photoCount", bundle: bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static var reminderSent: String { String(localized: "personal.event.reminderSent", bundle: bundle) }
    public static var reminderAtEvent: String { String(localized: "personal.event.reminderAtEvent", bundle: bundle) }
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

public enum AppLanguage: String, CaseIterable {
  case korean = "ko"
  case english = "en"

  public var displayName: String {
    switch self {
    case .korean: return "한국어"
    case .english: return "English"
    }
  }

  public var icon: String {
    switch self {
    case .korean: return "🇰🇷"
    case .english: return "🇺🇸"
    }
  }

  /// 현재 설정된 언어 (UserDefaults 기반, nil이면 시스템 기본)
  public static var current: AppLanguage? {
    guard let raw = UserDefaults.standard.string(forKey: "promisoPreferredLanguage") else {
      return nil
    }
    return AppLanguage(rawValue: raw)
  }
}
