import Foundation
import PromisoShared
import WidgetKit

/// Widget Timeline Entry
///
/// 그룹 약속과 개인 일정이 `WidgetPromiseData.type`으로 구분되어
/// 단일 `promises` 배열에 통합 저장됩니다.
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

  // MARK: - Unified Schedule Properties

  /// 다음 일정 (현재 시간 이후 첫 번째, 약속+개인 일정 통합)
  var nextItem: WidgetPromiseData? {
    promises.first { $0.startAt > Date() }
  }

  /// 오늘 일정 (약속+개인 일정 통합)
  var todayItems: [WidgetPromiseData] {
    promises.filter { Calendar.current.isDateInToday($0.startAt) }
  }

  /// 다가오는 일정 (오늘 제외, 약속+개인 일정 통합)
  var upcomingItems: [WidgetPromiseData] {
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

  /// 오늘 일정 엔트리 (약속 + 개인 일정)
  static var previewToday: WidgetPromiseEntry {
    let items = (WidgetPromiseData.previewTodayPromises + WidgetPromiseData.previewTodayPersonalEvents)
      .sorted { $0.startAt < $1.startAt }
    return WidgetPromiseEntry(
      date: Date(),
      promises: items,
      state: .loaded
    )
  }

  /// 다가오는 일정 엔트리 (약속 + 개인 일정)
  static var previewUpcoming: WidgetPromiseEntry {
    let items = (WidgetPromiseData.previewUpcomingPromises + WidgetPromiseData.previewUpcomingPersonalEvents)
      .sorted { $0.startAt < $1.startAt }
    return WidgetPromiseEntry(
      date: Date(),
      promises: items,
      state: .loaded
    )
  }

  /// 전체 일정 엔트리 (오늘 + 다가오는)
  static var previewFull: WidgetPromiseEntry {
    let items = (WidgetPromiseData.previewAllPromises + WidgetPromiseData.previewAllPersonalEvents)
      .sorted { $0.startAt < $1.startAt }
    return WidgetPromiseEntry(
      date: Date(),
      promises: items,
      state: .loaded
    )
  }
  #endif
}
