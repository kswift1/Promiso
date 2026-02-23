import UIKit

public enum SafeArea {
  /// 현재 키 윈도우의 상단 safe area inset
  public static var topInset: CGFloat {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .safeAreaInsets.top ?? 0
  }

  /// 표준 네비게이션 바 높이
  private static let standardNavigationBarHeight: CGFloat = 44

  /// Navigation bar 높이를 포함한 상단 오프셋 (safe area top + toolbar 영역)
  public static var topOffset: CGFloat {
    topInset + standardNavigationBarHeight
  }
}
