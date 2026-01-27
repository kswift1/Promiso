import Foundation
import WidgetKit

/// Widget과 App 간 데이터 공유를 위한 매니저
/// App Group UserDefaults를 통해 데이터를 공유합니다.
public enum WidgetDataManager {
  private static let suiteName = "group.com.promiso.shared"
  private static let promisesKey = "widget.promises"
  private static let userIdKey = "widget.userId"
  private static let lastUpdatedKey = "widget.lastUpdated"

  private static var defaults: UserDefaults? {
    UserDefaults(suiteName: suiteName)
  }

  // MARK: - App에서 호출 (저장)

  /// 약속 목록 저장
  public static func savePromises(_ promises: [WidgetPromiseData]) {
    guard let defaults = defaults,
          let data = try? JSONEncoder().encode(promises) else { return }
    defaults.set(data, forKey: promisesKey)
    defaults.set(Date(), forKey: lastUpdatedKey)
  }

  /// 사용자 ID 저장 (로그인 시)
  public static func saveUserId(_ userId: String?) {
    if let userId = userId {
      defaults?.set(userId, forKey: userIdKey)
    } else {
      defaults?.removeObject(forKey: userIdKey)
    }
  }

  // MARK: - Widget에서 호출 (읽기)

  /// 약속 목록 로드
  public static func loadPromises() -> [WidgetPromiseData] {
    guard let defaults = defaults,
          let data = defaults.data(forKey: promisesKey),
          let promises = try? JSONDecoder().decode([WidgetPromiseData].self, from: data)
    else { return [] }

    // 과거 약속 필터링 + 시간순 정렬
    return promises
      .filter { $0.startAt > Date().addingTimeInterval(-3600) }
      .sorted { $0.startAt < $1.startAt }
  }

  /// 로그인 상태 확인
  public static func isLoggedIn() -> Bool {
    defaults?.string(forKey: userIdKey) != nil
  }

  /// 마지막 업데이트 시간
  public static func lastUpdated() -> Date? {
    defaults?.object(forKey: lastUpdatedKey) as? Date
  }

  // MARK: - 초기화

  /// 모든 데이터 삭제 (로그아웃 시)
  public static func clearAll() {
    defaults?.removeObject(forKey: promisesKey)
    defaults?.removeObject(forKey: userIdKey)
    defaults?.removeObject(forKey: lastUpdatedKey)
  }

  // MARK: - Widget 갱신 트리거

  /// 모든 Widget 타임라인 갱신
  public static func reloadWidgets() {
    WidgetCenter.shared.reloadTimelines(ofKind: "SmallPromiseWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "MediumPromiseWidget")
    WidgetCenter.shared.reloadTimelines(ofKind: "LargePromiseWidget")
  }
}
