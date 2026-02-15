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
    public static let modify = String(localized: "common.modify", bundle: LocalizedStrings.bundle)
    public static let change = String(localized: "common.change", bundle: LocalizedStrings.bundle)
    public static let laterAction = String(localized: "common.later", bundle: LocalizedStrings.bundle)
    public static let all = String(localized: "common.all", bundle: LocalizedStrings.bundle)
    public static let today = String(localized: "common.today", bundle: LocalizedStrings.bundle)
    public static let photo = String(localized: "common.photo", bundle: LocalizedStrings.bundle)
    public static let settings = String(localized: "common.settings", bundle: LocalizedStrings.bundle)
    public static let start = String(localized: "common.start", bundle: LocalizedStrings.bundle)
    public static let endTime = String(localized: "common.endTime", bundle: LocalizedStrings.bundle)
    public static let date = String(localized: "common.date", bundle: LocalizedStrings.bundle)
    public static let time = String(localized: "common.time", bundle: LocalizedStrings.bundle)
    public static let location = String(localized: "common.location", bundle: LocalizedStrings.bundle)
    public static let reminder = String(localized: "common.reminder", bundle: LocalizedStrings.bundle)
    public static let directions = String(localized: "common.directions", bundle: LocalizedStrings.bundle)
    public static let schedule = String(localized: "common.schedule", bundle: LocalizedStrings.bundle)
    public static let personalEvent = String(localized: "common.personalEvent", bundle: LocalizedStrings.bundle)
    public static let seeMore = String(localized: "common.seeMore", bundle: LocalizedStrings.bundle)
    public static let collapse = String(localized: "common.collapse", bundle: LocalizedStrings.bundle)
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

    // Login Request
    public static let loginRequestFailed = String(localized: "auth.error.loginRequestFailed", bundle: LocalizedStrings.bundle)

    // Hero Text
    public static let heroPromisesWord = String(localized: "auth.hero.promisesWord", bundle: LocalizedStrings.bundle)
    public static let heroMoreSpecial = String(localized: "auth.hero.moreSpecial", bundle: LocalizedStrings.bundle)
    public static let heroPreciousMoments = String(localized: "auth.hero.preciousMoments", bundle: LocalizedStrings.bundle)
    public static let heroWithPromiso = String(localized: "auth.hero.withPromiso", bundle: LocalizedStrings.bundle)

    // Social Login
    public static let continueWithApple = String(localized: "auth.continueWithApple", bundle: LocalizedStrings.bundle)
    public static let continueWithGoogle = String(localized: "auth.continueWithGoogle", bundle: LocalizedStrings.bundle)
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

  // MARK: - Notification
  public enum Notification {
    public static let title = String(localized: "notification.title", bundle: LocalizedStrings.bundle)
    public static let markAllAsRead = String(localized: "notification.markAllAsRead", bundle: LocalizedStrings.bundle)
    public static let selectAll = String(localized: "notification.selectAll", bundle: LocalizedStrings.bundle)
    public static func selectedCount(_ count: Int) -> String {
      String(localized: "notification.selectedCount", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static let emptyTitle = String(localized: "notification.empty.title", bundle: LocalizedStrings.bundle)
    public static let emptySubtitle = String(localized: "notification.empty.subtitle", bundle: LocalizedStrings.bundle)
    public static let loadFailed = String(localized: "notification.error.loadFailed", bundle: LocalizedStrings.bundle)
    public static let filterAll = String(localized: "notification.filter.all", bundle: LocalizedStrings.bundle)
    public static let filterUnread = String(localized: "notification.filter.unread", bundle: LocalizedStrings.bundle)
  }

  // MARK: - Onboarding
  public enum Onboarding {
    public static let start = String(localized: "onboarding.start", bundle: LocalizedStrings.bundle)
    public static let readyTitle = String(localized: "onboarding.ready.title", bundle: LocalizedStrings.bundle)
    public static let readySubtitle = String(localized: "onboarding.ready.subtitle", bundle: LocalizedStrings.bundle)
    public static let readyDescription = String(localized: "onboarding.ready.description", bundle: LocalizedStrings.bundle)
    public static let hasInviteCode = String(localized: "onboarding.hasInviteCode", bundle: LocalizedStrings.bundle)
    public static let skipForNow = String(localized: "onboarding.skipForNow", bundle: LocalizedStrings.bundle)
    public static let laterHint = String(localized: "onboarding.laterHint", bundle: LocalizedStrings.bundle)
  }

  // MARK: - AppEntry
  public enum AppEntry {
    public static let forceUpdateTitle = String(localized: "appEntry.update.forceTitle", bundle: LocalizedStrings.bundle)
    public static let recommendUpdateTitle = String(localized: "appEntry.update.recommendTitle", bundle: LocalizedStrings.bundle)
    public static let updateAction = String(localized: "appEntry.update.action", bundle: LocalizedStrings.bundle)
    public static let updateLater = String(localized: "appEntry.update.later", bundle: LocalizedStrings.bundle)
  }

  // MARK: - Profile
  public enum Profile {
    public static let nicknameCheckRequired = String(localized: "profile.error.nicknameCheckRequired", bundle: LocalizedStrings.bundle)
    public static let nicknameTaken = String(localized: "profile.error.nicknameTaken", bundle: LocalizedStrings.bundle)
    public static let nicknameCheckFailed = String(localized: "profile.error.nicknameCheckFailed", bundle: LocalizedStrings.bundle)
    public static let saveFailed = String(localized: "profile.error.saveFailed", bundle: LocalizedStrings.bundle)
    public static let setupTitle1 = String(localized: "profile.setup.title1", bundle: LocalizedStrings.bundle)
    public static let setupTitle2 = String(localized: "profile.setup.title2", bundle: LocalizedStrings.bundle)
    public static let nickname = String(localized: "profile.nickname", bundle: LocalizedStrings.bundle)
    public static let nicknamePlaceholder = String(localized: "profile.nickname.placeholder", bundle: LocalizedStrings.bundle)
    public static let saving = String(localized: "profile.saving", bundle: LocalizedStrings.bundle)
    public static let nicknameChecking = String(localized: "profile.nickname.checking", bundle: LocalizedStrings.bundle)
    public static let nicknameAvailable = String(localized: "profile.nickname.available", bundle: LocalizedStrings.bundle)
    public static let selectPhoto = String(localized: "profile.selectPhoto", bundle: LocalizedStrings.bundle)
  }

  // MARK: - Home
  public enum Home {
    // Pending Section
    public static let needResponse = String(localized: "home.pending.needResponse", bundle: LocalizedStrings.bundle)
    public static let closed = String(localized: "home.pending.closed", bundle: LocalizedStrings.bundle)
    public static func minutesRemaining(_ minutes: Int) -> String {
      String(localized: "home.pending.minutesRemaining", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static func hoursRemaining(_ hours: Int) -> String {
      String(localized: "home.pending.hoursRemaining", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(hours)")
    }

    // Timeline
    public static let accepted = String(localized: "home.timeline.accepted", bundle: LocalizedStrings.bundle)
    public static let declined = String(localized: "home.timeline.declined", bundle: LocalizedStrings.bundle)
    public static let tomorrow = String(localized: "home.timeline.tomorrow", bundle: LocalizedStrings.bundle)
    public static let dayAfterTomorrow = String(localized: "home.timeline.dayAfterTomorrow", bundle: LocalizedStrings.bundle)

    // Need Response Banner
    public static let responseNeeded = String(localized: "home.banner.responseNeeded", bundle: LocalizedStrings.bundle)
    public static func promisesToRespond(_ count: Int) -> String {
      String(localized: "home.banner.promisesToRespond", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }

    // Empty State
    public static let emptyNoPromisesTitle = String(localized: "home.empty.noPromises.title", bundle: LocalizedStrings.bundle)
    public static let emptyNoPromisesMessage = String(localized: "home.empty.noPromises.message", bundle: LocalizedStrings.bundle)
    public static let emptyNoFilterTitle = String(localized: "home.empty.noFilter.title", bundle: LocalizedStrings.bundle)
    public static let emptyNoFilterMessage = String(localized: "home.empty.noFilter.message", bundle: LocalizedStrings.bundle)
    public static let emptyNoGroupsTitle = String(localized: "home.empty.noGroups.title", bundle: LocalizedStrings.bundle)
    public static let emptyNoGroupsMessage = String(localized: "home.empty.noGroups.message", bundle: LocalizedStrings.bundle)
    public static let createNewPromise = String(localized: "home.empty.createPromise", bundle: LocalizedStrings.bundle)
    public static let resetFilter = String(localized: "home.empty.resetFilter", bundle: LocalizedStrings.bundle)
    public static let findGroups = String(localized: "home.empty.findGroups", bundle: LocalizedStrings.bundle)
    public static let joinWithInviteLink = String(localized: "home.empty.joinWithLink", bundle: LocalizedStrings.bundle)

    // Today Schedule
    public static let todaySchedule = String(localized: "home.today.schedule", bundle: LocalizedStrings.bundle)
    public static func itemCount(_ count: Int) -> String {
      String(localized: "home.today.itemCount", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static let nextScheduleUntil = String(localized: "home.today.nextUntil", bundle: LocalizedStrings.bundle)
    public static let startingSoon = String(localized: "home.today.startingSoon", bundle: LocalizedStrings.bundle)
    public static func hoursMinutes(_ hours: Int, _ minutes: Int) -> String {
      String(localized: "home.today.hoursMinutes", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(hours)")
        .replacingOccurrences(of: "%2$lld", with: "\(minutes)")
    }
    public static func minutesOnly(_ minutes: Int) -> String {
      String(localized: "home.today.minutesOnly", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }

    // Today Empty State Messages
    public static let emptyDawnTitle = String(localized: "home.today.empty.dawn.title", bundle: LocalizedStrings.bundle)
    public static let emptyDawnSubtitle = String(localized: "home.today.empty.dawn.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyMorningTitle = String(localized: "home.today.empty.morning.title", bundle: LocalizedStrings.bundle)
    public static let emptyMorningSubtitle = String(localized: "home.today.empty.morning.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyLunchTitle = String(localized: "home.today.empty.lunch.title", bundle: LocalizedStrings.bundle)
    public static let emptyLunchSubtitle = String(localized: "home.today.empty.lunch.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyAfternoonTitle = String(localized: "home.today.empty.afternoon.title", bundle: LocalizedStrings.bundle)
    public static let emptyAfternoonSubtitle = String(localized: "home.today.empty.afternoon.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyEveningTitle = String(localized: "home.today.empty.evening.title", bundle: LocalizedStrings.bundle)
    public static let emptyEveningSubtitle = String(localized: "home.today.empty.evening.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyNightTitle = String(localized: "home.today.empty.night.title", bundle: LocalizedStrings.bundle)
    public static let emptyNightSubtitle = String(localized: "home.today.empty.night.subtitle", bundle: LocalizedStrings.bundle)

    public static let emptyRandom1Title = String(localized: "home.today.empty.random1.title", bundle: LocalizedStrings.bundle)
    public static let emptyRandom1Subtitle = String(localized: "home.today.empty.random1.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyRandom2Title = String(localized: "home.today.empty.random2.title", bundle: LocalizedStrings.bundle)
    public static let emptyRandom2Subtitle = String(localized: "home.today.empty.random2.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyRandom3Title = String(localized: "home.today.empty.random3.title", bundle: LocalizedStrings.bundle)
    public static let emptyRandom3Subtitle = String(localized: "home.today.empty.random3.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyRandom4Title = String(localized: "home.today.empty.random4.title", bundle: LocalizedStrings.bundle)
    public static let emptyRandom4Subtitle = String(localized: "home.today.empty.random4.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyRandom5Title = String(localized: "home.today.empty.random5.title", bundle: LocalizedStrings.bundle)
    public static let emptyRandom5Subtitle = String(localized: "home.today.empty.random5.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyRandom6Title = String(localized: "home.today.empty.random6.title", bundle: LocalizedStrings.bundle)
    public static let emptyRandom6Subtitle = String(localized: "home.today.empty.random6.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyRandom7Title = String(localized: "home.today.empty.random7.title", bundle: LocalizedStrings.bundle)
    public static let emptyRandom7Subtitle = String(localized: "home.today.empty.random7.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyRandom8Title = String(localized: "home.today.empty.random8.title", bundle: LocalizedStrings.bundle)
    public static let emptyRandom8Subtitle = String(localized: "home.today.empty.random8.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyRandom9Title = String(localized: "home.today.empty.random9.title", bundle: LocalizedStrings.bundle)
    public static let emptyRandom9Subtitle = String(localized: "home.today.empty.random9.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyRandom10Title = String(localized: "home.today.empty.random10.title", bundle: LocalizedStrings.bundle)
    public static let emptyRandom10Subtitle = String(localized: "home.today.empty.random10.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyRandom11Title = String(localized: "home.today.empty.random11.title", bundle: LocalizedStrings.bundle)
    public static let emptyRandom11Subtitle = String(localized: "home.today.empty.random11.subtitle", bundle: LocalizedStrings.bundle)
    public static let emptyRandom12Title = String(localized: "home.today.empty.random12.title", bundle: LocalizedStrings.bundle)
    public static let emptyRandom12Subtitle = String(localized: "home.today.empty.random12.subtitle", bundle: LocalizedStrings.bundle)

    // Complete Messages
    public static let completeDawnTitle = String(localized: "home.today.complete.dawn.title", bundle: LocalizedStrings.bundle)
    public static let completeMorningTitle = String(localized: "home.today.complete.morning.title", bundle: LocalizedStrings.bundle)
    public static let completeLunchTitle = String(localized: "home.today.complete.lunch.title", bundle: LocalizedStrings.bundle)
    public static let completeAfternoonTitle = String(localized: "home.today.complete.afternoon.title", bundle: LocalizedStrings.bundle)
    public static let completeEveningTitle = String(localized: "home.today.complete.evening.title", bundle: LocalizedStrings.bundle)
    public static let completeNightTitle = String(localized: "home.today.complete.night.title", bundle: LocalizedStrings.bundle)

    public static let completeRandom1Title = String(localized: "home.today.complete.random1.title", bundle: LocalizedStrings.bundle)
    public static let completeRandom2Title = String(localized: "home.today.complete.random2.title", bundle: LocalizedStrings.bundle)
    public static let completeRandom3Title = String(localized: "home.today.complete.random3.title", bundle: LocalizedStrings.bundle)
    public static let completeRandom4Title = String(localized: "home.today.complete.random4.title", bundle: LocalizedStrings.bundle)
    public static let completeRandom5Title = String(localized: "home.today.complete.random5.title", bundle: LocalizedStrings.bundle)
    public static let completeRandom6Title = String(localized: "home.today.complete.random6.title", bundle: LocalizedStrings.bundle)

    // Upcoming
    public static let upcomingSchedule = String(localized: "home.upcoming.title", bundle: LocalizedStrings.bundle)
    public static let noUpcomingTitle = String(localized: "home.upcoming.empty.title", bundle: LocalizedStrings.bundle)
    public static let noUpcomingSubtitle = String(localized: "home.upcoming.empty.subtitle", bundle: LocalizedStrings.bundle)
    public static func participantsConfirmed(_ count: Int) -> String {
      String(localized: "home.upcoming.participantsConfirmed", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func groupParticipants(_ group: String, _ count: Int) -> String {
      String(localized: "home.upcoming.groupParticipants", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%1$@", with: group)
        .replacingOccurrences(of: "%2$lld", with: "\(count)")
    }

    // PersonalEventTimeline
    public static let personalLabel = String(localized: "home.personalEvent.label", bundle: LocalizedStrings.bundle)
    public static func reminderHoursBefore(_ hours: Int) -> String {
      String(localized: "home.personalEvent.reminderHours", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(hours)")
    }
    public static func reminderMinutesBefore(_ minutes: Int) -> String {
      String(localized: "home.personalEvent.reminderMinutes", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }

    // Timeline
    public static let startLiveSharing = String(localized: "home.timeline.startLiveSharing", bundle: LocalizedStrings.bundle)

    // StatusFilter display titles
    public static let filterAll = String(localized: "home.filter.all", bundle: LocalizedStrings.bundle)
    public static let filterNeedResponse = String(localized: "home.filter.needResponse", bundle: LocalizedStrings.bundle)
    public static let filterConfirmed = String(localized: "home.filter.confirmed", bundle: LocalizedStrings.bundle)
    public static let filterInProgress = String(localized: "home.filter.inProgress", bundle: LocalizedStrings.bundle)
  }

  // MARK: - Shared (SharedFeature)
  public enum Shared {
    // Edit Promise
    public static let editPromiseTitle = String(localized: "shared.editPromise.title", bundle: LocalizedStrings.bundle)
    public static let editFailed = String(localized: "shared.editPromise.failed", bundle: LocalizedStrings.bundle)
    public static let promiseTitlePlaceholder = String(localized: "shared.editPromise.titlePlaceholder", bundle: LocalizedStrings.bundle)
    public static let optional = String(localized: "shared.editPromise.optional", bundle: LocalizedStrings.bundle)
    public static let addLocation = String(localized: "shared.editPromise.addLocation", bundle: LocalizedStrings.bundle)
    public static let minimumParticipants = String(localized: "shared.editPromise.minimumParticipants", bundle: LocalizedStrings.bundle)
    public static func maxMembers(_ count: Int) -> String {
      String(localized: "shared.editPromise.maxMembers", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static func minMembersDescription(_ count: Int) -> String {
      String(localized: "shared.editPromise.minMembersDescription", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static let liveSharing = String(localized: "shared.editPromise.liveSharing", bundle: LocalizedStrings.bundle)
    public static func liveStartMinutes(_ minutes: Int) -> String {
      String(localized: "shared.editPromise.liveStartMinutes", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static func liveSharingDescription(_ minutes: Int) -> String {
      String(localized: "shared.editPromise.liveSharingDescription", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static let manualStart = String(localized: "shared.editPromise.manualStart", bundle: LocalizedStrings.bundle)
    public static func minutesBefore(_ minutes: Int) -> String {
      String(localized: "shared.editPromise.minutesBefore", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static let minutesBeforeStartLabel = String(localized: "shared.editPromise.minutesBeforeStartLabel", bundle: LocalizedStrings.bundle)

    // Promise Detail
    public static let voteDeadline = String(localized: "shared.promiseDetail.voteDeadline", bundle: LocalizedStrings.bundle)
    public static let minimumConfirmMembers = String(localized: "shared.promiseDetail.minimumConfirm", bundle: LocalizedStrings.bundle)
    public static func membersCount(_ count: Int) -> String {
      String(localized: "shared.promiseDetail.membersCount", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static let participantsSection = String(localized: "shared.promiseDetail.participants", bundle: LocalizedStrings.bundle)
    public static func participantsJoined(_ current: Int, _ total: Int) -> String {
      String(localized: "shared.promiseDetail.participantsJoined", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(current)")
        .replacingOccurrences(of: "%2$lld", with: "\(total)")
    }
    public static let responseAccepted = String(localized: "shared.promiseDetail.accepted", bundle: LocalizedStrings.bundle)
    public static let responseDeclined = String(localized: "shared.promiseDetail.declined", bundle: LocalizedStrings.bundle)
    public static let responseNoAnswer = String(localized: "shared.promiseDetail.noAnswer", bundle: LocalizedStrings.bundle)
    public static let myResponse = String(localized: "shared.promiseDetail.myResponse", bundle: LocalizedStrings.bundle)
    public static let editPromise = String(localized: "shared.promiseDetail.edit", bundle: LocalizedStrings.bundle)
    public static let deletePromise = String(localized: "shared.promiseDetail.delete", bundle: LocalizedStrings.bundle)
    public static let undetermined = String(localized: "shared.promiseDetail.undetermined", bundle: LocalizedStrings.bundle)
    public static func deletePromiseConfirm(_ title: String) -> String {
      String(localized: "shared.promiseDetail.deleteConfirm", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%@", with: title)
    }

    // Promise Detail Status
    public static let statusNeedResponse = String(localized: "shared.promiseDetail.status.needResponse", bundle: LocalizedStrings.bundle)
    public static let statusWaitingConfirm = String(localized: "shared.promiseDetail.status.waitingConfirm", bundle: LocalizedStrings.bundle)
    public static let statusConfirmed = String(localized: "shared.promiseDetail.status.confirmed", bundle: LocalizedStrings.bundle)
    public static let statusFailed = String(localized: "shared.promiseDetail.status.failed", bundle: LocalizedStrings.bundle)

    // Location Picker
    public static let locationSearch = String(localized: "shared.location.search", bundle: LocalizedStrings.bundle)
    public static let searchPlaceholder = String(localized: "shared.location.searchPlaceholder", bundle: LocalizedStrings.bundle)
    public static let recentSearch = String(localized: "shared.location.recentSearch", bundle: LocalizedStrings.bundle)
    public static let noSearchResults = String(localized: "shared.location.noResults", bundle: LocalizedStrings.bundle)
    public static let tryOtherKeyword = String(localized: "shared.location.tryOther", bundle: LocalizedStrings.bundle)
    public static let searchError = String(localized: "shared.location.searchError", bundle: LocalizedStrings.bundle)
    public static let selectThisLocation = String(localized: "shared.location.select", bundle: LocalizedStrings.bundle)
    public static let searchLocationHint = String(localized: "shared.location.searchHint", bundle: LocalizedStrings.bundle)
    public static let searchExamples = String(localized: "shared.location.searchExamples", bundle: LocalizedStrings.bundle)

    // Notification Permission
    public static let goToSettings = String(localized: "shared.notification.goToSettings", bundle: LocalizedStrings.bundle)
    public static let notificationTitle = String(localized: "shared.notification.title", bundle: LocalizedStrings.bundle)
    public static let notificationSubtitle = String(localized: "shared.notification.subtitle", bundle: LocalizedStrings.bundle)
    public static let notificationPreviewTitle = String(localized: "shared.notification.previewTitle", bundle: LocalizedStrings.bundle)
    public static let notificationPreviewBody = String(localized: "shared.notification.previewBody", bundle: LocalizedStrings.bundle)
    public static let allowNotification = String(localized: "shared.notification.allow", bundle: LocalizedStrings.bundle)
    public static let permissionTitle = String(localized: "shared.notification.permissionTitle", bundle: LocalizedStrings.bundle)
    public static let benefitInvite = String(localized: "shared.notification.benefit.invite", bundle: LocalizedStrings.bundle)
    public static let benefitConfirm = String(localized: "shared.notification.benefit.confirm", bundle: LocalizedStrings.bundle)
    public static let benefitMember = String(localized: "shared.notification.benefit.member", bundle: LocalizedStrings.bundle)
    public static let benefitChange = String(localized: "shared.notification.benefit.change", bundle: LocalizedStrings.bundle)
    public static let now = String(localized: "shared.notification.now", bundle: LocalizedStrings.bundle)

    // Personal Event Detail
    public static let deleteEvent = String(localized: "shared.personalDetail.deleteEvent", bundle: LocalizedStrings.bundle)
    public static func deleteEventConfirm(_ title: String) -> String {
      String(localized: "shared.personalDetail.deleteConfirm", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%@", with: title)
    }
    public static let statusOngoing = String(localized: "shared.personalDetail.status.ongoing", bundle: LocalizedStrings.bundle)
    public static let statusEnded = String(localized: "shared.personalDetail.status.ended", bundle: LocalizedStrings.bundle)
    public static let statusToday = String(localized: "shared.personalDetail.status.today", bundle: LocalizedStrings.bundle)
    public static let statusUpcoming = String(localized: "shared.personalDetail.status.upcoming", bundle: LocalizedStrings.bundle)
    public static func reminderHours(_ hours: Int) -> String {
      String(localized: "shared.personalDetail.reminderHours", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(hours)")
    }
    public static func reminderMinutes(_ minutes: Int) -> String {
      String(localized: "shared.personalDetail.reminderMinutes", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }

    // Create Personal Event
    public static let newEvent = String(localized: "shared.createEvent.new", bundle: LocalizedStrings.bundle)
    public static let editEvent = String(localized: "shared.createEvent.edit", bundle: LocalizedStrings.bundle)
    public static let eventTitlePlaceholder = String(localized: "shared.createEvent.titlePlaceholder", bundle: LocalizedStrings.bundle)
    public static let reminderLabel = String(localized: "shared.createEvent.reminder", bundle: LocalizedStrings.bundle)
    public static let memoPlaceholder = String(localized: "shared.createEvent.memoPlaceholder", bundle: LocalizedStrings.bundle)

    // Reminder Options
    public static let reminder5min = String(localized: "shared.reminder.5min", bundle: LocalizedStrings.bundle)
    public static let reminder10min = String(localized: "shared.reminder.10min", bundle: LocalizedStrings.bundle)
    public static let reminder15min = String(localized: "shared.reminder.15min", bundle: LocalizedStrings.bundle)
    public static let reminder30min = String(localized: "shared.reminder.30min", bundle: LocalizedStrings.bundle)
    public static let reminder1hour = String(localized: "shared.reminder.1hour", bundle: LocalizedStrings.bundle)
    public static let reminder2hours = String(localized: "shared.reminder.2hours", bundle: LocalizedStrings.bundle)

    // Image Attachment
    public static let imageUploading = String(localized: "shared.image.uploading", bundle: LocalizedStrings.bundle)
  }

  // MARK: - Calendar
  public enum Calendar {
    public static let loadingPromises = String(localized: "calendar.loading", bundle: LocalizedStrings.bundle)
    public static let noPromises = String(localized: "calendar.empty.title", bundle: LocalizedStrings.bundle)
    public static let createNewPromise = String(localized: "calendar.empty.subtitle", bundle: LocalizedStrings.bundle)
    public static let monthSchedule = String(localized: "calendar.monthSchedule", bundle: LocalizedStrings.bundle)
    public static func dayCount(_ count: Int) -> String {
      String(localized: "calendar.dayCount", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }

    // Weekday
    public static let weekdaySun = String(localized: "calendar.weekday.sun", bundle: LocalizedStrings.bundle)
    public static let weekdayMon = String(localized: "calendar.weekday.mon", bundle: LocalizedStrings.bundle)
    public static let weekdayTue = String(localized: "calendar.weekday.tue", bundle: LocalizedStrings.bundle)
    public static let weekdayWed = String(localized: "calendar.weekday.wed", bundle: LocalizedStrings.bundle)
    public static let weekdayThu = String(localized: "calendar.weekday.thu", bundle: LocalizedStrings.bundle)
    public static let weekdayFri = String(localized: "calendar.weekday.fri", bundle: LocalizedStrings.bundle)
    public static let weekdaySat = String(localized: "calendar.weekday.sat", bundle: LocalizedStrings.bundle)

    // Calendar Permission Banner
    public static let syncCalendarTitle = String(localized: "calendar.sync.title", bundle: LocalizedStrings.bundle)
    public static let syncCalendarSubtitle = String(localized: "calendar.sync.subtitle", bundle: LocalizedStrings.bundle)
    public static let syncAction = String(localized: "calendar.sync.action", bundle: LocalizedStrings.bundle)
    public static let readAccessTitle = String(localized: "calendar.sync.readAccess.title", bundle: LocalizedStrings.bundle)
    public static let readAccessSubtitle = String(localized: "calendar.sync.readAccess.subtitle", bundle: LocalizedStrings.bundle)
    public static let calendarPermissionTitle = String(localized: "calendar.sync.permission.title", bundle: LocalizedStrings.bundle)
    public static let calendarPermissionSubtitle = String(localized: "calendar.sync.permission.subtitle", bundle: LocalizedStrings.bundle)
    public static let doNotShowAgain = String(localized: "calendar.sync.doNotShow", bundle: LocalizedStrings.bundle)

    // Promise Card Status
    public static let statusWaiting = String(localized: "calendar.promise.statusWaiting", bundle: LocalizedStrings.bundle)
    public static let statusVoting = String(localized: "calendar.promise.statusVoting", bundle: LocalizedStrings.bundle)
    public static let statusConfirmed = String(localized: "calendar.promise.statusConfirmed", bundle: LocalizedStrings.bundle)
    public static let statusFailed = String(localized: "calendar.promise.statusFailed", bundle: LocalizedStrings.bundle)
    public static let respondAction = String(localized: "calendar.promise.respond", bundle: LocalizedStrings.bundle)
    public static func additionalItems(_ count: Int) -> String {
      String(localized: "calendar.promise.additionalItems", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
  }

  // MARK: - Personal
  public enum Personal {
    public static let emptyToday = String(localized: "personal.empty.today", bundle: LocalizedStrings.bundle)
    public static let emptyFuture = String(localized: "personal.empty.future", bundle: LocalizedStrings.bundle)
    public static let emptyAll = String(localized: "personal.empty.all", bundle: LocalizedStrings.bundle)
    public static let emptyPast = String(localized: "personal.empty.past", bundle: LocalizedStrings.bundle)
    public static let viewDetail = String(localized: "personal.event.viewDetail", bundle: LocalizedStrings.bundle)
    public static func photoCount(_ count: Int) -> String {
      String(localized: "personal.event.photoCount", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }
    public static let reminderSent = String(localized: "personal.event.reminderSent", bundle: LocalizedStrings.bundle)
    public static func reminderHours(_ hours: Int) -> String {
      String(localized: "personal.event.reminderHours", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(hours)")
    }
    public static func reminderMinutes(_ minutes: Int) -> String {
      String(localized: "personal.event.reminderMinutes", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
    public static let statusEnded = String(localized: "personal.event.status.ended", bundle: LocalizedStrings.bundle)
    public static let statusToday = String(localized: "personal.event.status.today", bundle: LocalizedStrings.bundle)
    public static let statusUpcoming = String(localized: "personal.event.status.upcoming", bundle: LocalizedStrings.bundle)
    public static let filterToday = String(localized: "personal.filter.today", bundle: LocalizedStrings.bundle)
    public static let filterFuture = String(localized: "personal.filter.future", bundle: LocalizedStrings.bundle)
    public static let filterAll = String(localized: "personal.filter.all", bundle: LocalizedStrings.bundle)
    public static let filterPast = String(localized: "personal.filter.past", bundle: LocalizedStrings.bundle)
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
