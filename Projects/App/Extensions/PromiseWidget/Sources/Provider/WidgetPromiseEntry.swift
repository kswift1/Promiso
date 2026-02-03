import Foundation
import PromisoShared
import WidgetKit

/// Widget Timeline Entry
struct WidgetPromiseEntry: TimelineEntry {
  let date: Date
  let promises: [WidgetPromiseData]
  let state: WidgetState

  enum WidgetState: Equatable {
    case loaded
    case empty
    case notLoggedIn
    case error
  }

  // MARK: - Computed Properties

  /// 다음 약속 (현재 시간 이후 첫 번째)
  var nextPromise: WidgetPromiseData? {
    promises.first { $0.startAt > Date() }
  }

  /// 오늘 약속
  var todayPromises: [WidgetPromiseData] {
    promises.filter { Calendar.current.isDateInToday($0.startAt) }
  }

  /// 다가오는 약속 (오늘 제외)
  var upcomingPromises: [WidgetPromiseData] {
    promises.filter {
      !Calendar.current.isDateInToday($0.startAt) && $0.startAt > Date()
    }
  }

  /// 캐시가 오래됐는지
  var hasStaleData: Bool {
    promises.contains { $0.isStale }
  }

  // MARK: - Placeholder

  static var placeholder: WidgetPromiseEntry {
    WidgetPromiseEntry(
      date: Date(),
      promises: [.placeholder],
      state: .loaded
    )
  }

  #if DEBUG
  // MARK: - Preview Entries

  /// 오늘 약속만 있는 엔트리
  static var previewToday: WidgetPromiseEntry {
    WidgetPromiseEntry(
      date: Date(),
      promises: WidgetPromiseData.previewTodayPromises,
      state: .loaded
    )
  }

  /// 다가오는 약속만 있는 엔트리
  static var previewUpcoming: WidgetPromiseEntry {
    WidgetPromiseEntry(
      date: Date(),
      promises: WidgetPromiseData.previewUpcomingPromises,
      state: .loaded
    )
  }

  /// 전체 약속 엔트리 (오늘 + 다가오는)
  static var previewFull: WidgetPromiseEntry {
    WidgetPromiseEntry(
      date: Date(),
      promises: WidgetPromiseData.previewAllPromises,
      state: .loaded
    )
  }
  #endif
}
