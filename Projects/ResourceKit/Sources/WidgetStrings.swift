import Foundation

/// 위젯에서 사용하는 문자열 상수
public enum WidgetStrings {
  /// 에러 관련 문자열
  public enum Error {
    public static let title = "데이터를 불러올 수 없어요"
    public static let retryHint = "탭하여 다시 시도"
  }

  /// 빈 상태 관련 문자열
  public enum Empty {
    public static let createPromiseButton = "약속 만들기"
  }

  /// 로그인 관련 문자열
  public enum Auth {
    public static let notLoggedInTitle = "로그인이 필요해요"
    public static let openAppHint = "탭하여 앱 열기"
  }
}
