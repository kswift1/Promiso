import Foundation

// MARK: - Localized Strings

/// 앱에서 사용하는 모든 문자열을 관리하는 구조체
public enum LocalizedStrings {
  
  // MARK: - Common
  public enum Common {
    public static let ok = NSLocalizedString("common.ok", comment: "OK 버튼")
    public static let cancel = NSLocalizedString("common.cancel", comment: "취소 버튼")
    public static let save = NSLocalizedString("common.save", comment: "저장 버튼")
    public static let delete = NSLocalizedString("common.delete", comment: "삭제 버튼")
    public static let edit = NSLocalizedString("common.edit", comment: "편집 버튼")
    public static let done = NSLocalizedString("common.done", comment: "완료 버튼")
    public static let next = NSLocalizedString("common.next", comment: "다음 버튼")
    public static let back = NSLocalizedString("common.back", comment: "뒤로 버튼")
    public static let confirm = NSLocalizedString("common.confirm", comment: "확인 버튼")
    public static let retry = NSLocalizedString("common.retry", comment: "재시도 버튼")
    public static let loading = NSLocalizedString("common.loading", comment: "로딩 중")
    public static let error = NSLocalizedString("common.error", comment: "오류")
    public static let success = NSLocalizedString("common.success", comment: "성공")
    public static let warning = NSLocalizedString("common.warning", comment: "경고")
    public static let info = NSLocalizedString("common.info", comment: "정보")
  }
  
  // MARK: - Authentication
  public enum Auth {
    public static let login = NSLocalizedString("auth.login", comment: "로그인")
    public static let logout = NSLocalizedString("auth.logout", comment: "로그아웃")
    public static let signup = NSLocalizedString("auth.signup", comment: "회원가입")
    public static let email = NSLocalizedString("auth.email", comment: "이메일")
    public static let password = NSLocalizedString("auth.password", comment: "비밀번호")
    public static let confirmPassword = NSLocalizedString("auth.confirmPassword", comment: "비밀번호 확인")
    public static let name = NSLocalizedString("auth.name", comment: "이름")
    public static let phoneNumber = NSLocalizedString("auth.phoneNumber", comment: "전화번호")
    public static let forgotPassword = NSLocalizedString("auth.forgotPassword", comment: "비밀번호를 잊으셨나요?")
    
    // Error Messages
    public static let invalidEmail = NSLocalizedString("auth.error.invalidEmail", comment: "올바른 이메일 형식이 아닙니다")
    public static let invalidPassword = NSLocalizedString("auth.error.invalidPassword", comment: "비밀번호는 8자 이상이어야 합니다")
    public static let passwordMismatch = NSLocalizedString("auth.error.passwordMismatch", comment: "비밀번호가 일치하지 않습니다")
    public static let loginFailed = NSLocalizedString("auth.error.loginFailed", comment: "로그인에 실패했습니다")
    public static let signupFailed = NSLocalizedString("auth.error.signupFailed", comment: "회원가입에 실패했습니다")
    
    // Success Messages
    public static let loginSuccess = NSLocalizedString("auth.success.login", comment: "로그인되었습니다")
    public static let signupSuccess = NSLocalizedString("auth.success.signup", comment: "회원가입이 완료되었습니다")
    public static let logoutSuccess = NSLocalizedString("auth.success.logout", comment: "로그아웃되었습니다")
  }
  
  // MARK: - Promises
  public enum Promise {
    public static let promise = NSLocalizedString("promise.promise", comment: "약속")
    public static let promises = NSLocalizedString("promise.promises", comment: "약속들")
    public static let createPromise = NSLocalizedString("promise.create", comment: "약속 만들기")
    public static let editPromise = NSLocalizedString("promise.edit", comment: "약속 편집")
    public static let deletePromise = NSLocalizedString("promise.delete", comment: "약속 삭제")
    public static let joinPromise = NSLocalizedString("promise.join", comment: "약속 참가")
    public static let leavePromise = NSLocalizedString("promise.leave", comment: "약속 나가기")
    public static let completePromise = NSLocalizedString("promise.complete", comment: "약속 완료")
    public static let cancelPromise = NSLocalizedString("promise.cancel", comment: "약속 취소")
    
    public static let title = NSLocalizedString("promise.title", comment: "제목")
    public static let description = NSLocalizedString("promise.description", comment: "설명")
    public static let location = NSLocalizedString("promise.location", comment: "장소")
    public static let dateTime = NSLocalizedString("promise.dateTime", comment: "날짜 및 시간")
    public static let participants = NSLocalizedString("promise.participants", comment: "참가자")
    
    // Status
    public static let scheduled = NSLocalizedString("promise.status.scheduled", comment: "예정됨")
    public static let ongoing = NSLocalizedString("promise.status.ongoing", comment: "진행 중")
    public static let completed = NSLocalizedString("promise.status.completed", comment: "완료됨")
    public static let missed = NSLocalizedString("promise.status.missed", comment: "놓침")
    public static let cancelled = NSLocalizedString("promise.status.cancelled", comment: "취소됨")
    
    // Priority
    public static let priorityLow = NSLocalizedString("promise.priority.low", comment: "낮음")
    public static let priorityNormal = NSLocalizedString("promise.priority.normal", comment: "보통")
    public static let priorityHigh = NSLocalizedString("promise.priority.high", comment: "높음")
    public static let priorityUrgent = NSLocalizedString("promise.priority.urgent", comment: "긴급")
    
    // Messages
    public static let noPromises = NSLocalizedString("promise.empty.title", comment: "약속이 없습니다")
    public static let noPromisesSubtitle = NSLocalizedString("promise.empty.subtitle", comment: "새로운 약속을 만들어보세요")
    public static let createFirstPromise = NSLocalizedString("promise.empty.action", comment: "첫 번째 약속 만들기")
    
    // Success Messages
    public static let createSuccess = NSLocalizedString("promise.success.create", comment: "약속이 생성되었습니다")
    public static let updateSuccess = NSLocalizedString("promise.success.update", comment: "약속이 수정되었습니다")
    public static let deleteSuccess = NSLocalizedString("promise.success.delete", comment: "약속이 삭제되었습니다")
    public static let joinSuccess = NSLocalizedString("promise.success.join", comment: "약속에 참가했습니다")
    public static let leaveSuccess = NSLocalizedString("promise.success.leave", comment: "약속에서 나왔습니다")
    public static let completeSuccess = NSLocalizedString("promise.success.complete", comment: "약속을 완료했습니다")
  }
  
  // MARK: - Groups
  public enum Group {
    public static let group = NSLocalizedString("group.group", comment: "그룹")
    public static let groups = NSLocalizedString("group.groups", comment: "그룹들")
    public static let createGroup = NSLocalizedString("group.create", comment: "그룹 만들기")
    public static let editGroup = NSLocalizedString("group.edit", comment: "그룹 편집")
    public static let deleteGroup = NSLocalizedString("group.delete", comment: "그룹 삭제")
    public static let joinGroup = NSLocalizedString("group.join", comment: "그룹 가입")
    public static let leaveGroup = NSLocalizedString("group.leave", comment: "그룹 나가기")
    
    public static let groupName = NSLocalizedString("group.name", comment: "그룹 이름")
    public static let groupDescription = NSLocalizedString("group.description", comment: "그룹 설명")
    public static let members = NSLocalizedString("group.members", comment: "멤버")
    public static let inviteCode = NSLocalizedString("group.inviteCode", comment: "초대 코드")
    public static let inviteMembers = NSLocalizedString("group.inviteMembers", comment: "멤버 초대")
    
    // Roles
    public static let owner = NSLocalizedString("group.role.owner", comment: "소유자")
    public static let admin = NSLocalizedString("group.role.admin", comment: "관리자")
    public static let moderator = NSLocalizedString("group.role.moderator", comment: "모더레이터")
    public static let member = NSLocalizedString("group.role.member", comment: "멤버")
    
    // Messages
    public static let noGroups = NSLocalizedString("group.empty.title", comment: "가입한 그룹이 없습니다")
    public static let noGroupsSubtitle = NSLocalizedString("group.empty.subtitle", comment: "새로운 그룹을 만들거나 기존 그룹에 가입해보세요")
    public static let createFirstGroup = NSLocalizedString("group.empty.action", comment: "첫 번째 그룹 만들기")
    
    // Success Messages
    public static let createSuccess = NSLocalizedString("group.success.create", comment: "그룹이 생성되었습니다")
    public static let joinSuccess = NSLocalizedString("group.success.join", comment: "그룹에 가입했습니다")
    public static let leaveSuccess = NSLocalizedString("group.success.leave", comment: "그룹에서 나왔습니다")
  }
  
  // MARK: - Settings
  public enum Settings {
    public static let settings = NSLocalizedString("settings.settings", comment: "설정")
    public static let profile = NSLocalizedString("settings.profile", comment: "프로필")
    public static let notifications = NSLocalizedString("settings.notifications", comment: "알림")
    public static let privacy = NSLocalizedString("settings.privacy", comment: "개인정보")
    public static let about = NSLocalizedString("settings.about", comment: "앱 정보")
    public static let help = NSLocalizedString("settings.help", comment: "도움말")
    public static let contactUs = NSLocalizedString("settings.contact", comment: "문의하기")
    
    // Theme
    public static let theme = NSLocalizedString("settings.theme", comment: "테마")
    public static let lightMode = NSLocalizedString("settings.theme.light", comment: "라이트 모드")
    public static let darkMode = NSLocalizedString("settings.theme.dark", comment: "다크 모드")
    public static let systemMode = NSLocalizedString("settings.theme.system", comment: "시스템 설정")
    
    // Language
    public static let language = NSLocalizedString("settings.language", comment: "언어")
    
    // Notifications
    public static let pushNotifications = NSLocalizedString("settings.notifications.push", comment: "푸시 알림")
    public static let emailNotifications = NSLocalizedString("settings.notifications.email", comment: "이메일 알림")
    
    // Success Messages
    public static let saveSuccess = NSLocalizedString("settings.success.save", comment: "설정이 저장되었습니다")
    public static let updateSuccess = NSLocalizedString("settings.success.update", comment: "정보가 업데이트되었습니다")
  }
  
  // MARK: - Errors
  public enum Error {
    public static let networkError = NSLocalizedString("error.network", comment: "네트워크 연결을 확인해주세요")
    public static let unknownError = NSLocalizedString("error.unknown", comment: "알 수 없는 오류가 발생했습니다")
    public static let serverError = NSLocalizedString("error.server", comment: "서버 오류가 발생했습니다")
    public static let timeoutError = NSLocalizedString("error.timeout", comment: "요청 시간이 초과되었습니다")
    public static let validationError = NSLocalizedString("error.validation", comment: "입력 정보를 확인해주세요")
    public static let permissionError = NSLocalizedString("error.permission", comment: "권한이 없습니다")
    public static let notFoundError = NSLocalizedString("error.notFound", comment: "요청한 정보를 찾을 수 없습니다")
  }
  
  // MARK: - Tab Bar
  public enum TabBar {
    public static let home = NSLocalizedString("tab.home", comment: "홈")
    public static let promise = NSLocalizedString("tab.promise", comment: "약속")
    public static let calendar = NSLocalizedString("tab.calendar", comment: "달력")
    public static let group = NSLocalizedString("tab.group", comment: "그룹")
  }
}

// MARK: - String Extension for Localization

public extension String {
  /// 현재 문자열을 키로 사용하여 지역화된 문자열을 반환
  var localized: String {
    return NSLocalizedString(self, comment: "")
  }
  
  /// 현재 문자열을 키로 사용하여 지역화된 문자열을 반환 (인자 포함)
  func localized(with arguments: CVarArg...) -> String {
    return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
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
    guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
          let bundle = Bundle(path: path) else {
      return NSLocalizedString(key, comment: "")
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
