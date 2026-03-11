import Foundation
import PromisoShared
import WidgetKit

/// Widget Timeline Entry
///
/// 그룹 일정과 개인 일정이 `WidgetScheduleData.type`으로 구분되어
/// 단일 `schedules` 배열에 통합 저장됩니다.
struct WidgetScheduleEntry: TimelineEntry {
  let date: Date
  let schedules: [WidgetScheduleData]
  let state: WidgetState

  enum WidgetState: Equatable {
    case loaded
    case empty
    case notLoggedIn
    case error
  }

  // MARK: - Unified Schedule Properties

  /// 다음 일정 (현재 시간 이후 첫 번째, 일정+개인 일정 통합)
  var nextItem: WidgetScheduleData? {
    schedules.first { $0.startAt > Date() }
  }

  /// 오늘 일정 (일정+개인 일정 통합)
  var todayItems: [WidgetScheduleData] {
    schedules.filter { Calendar.current.isDateInToday($0.startAt) }
  }

  /// 다가오는 일정 (오늘 제외, 일정+개인 일정 통합)
  var upcomingItems: [WidgetScheduleData] {
    schedules.filter {
      !Calendar.current.isDateInToday($0.startAt) && $0.startAt > Date()
    }
  }

  /// 캐시가 오래됐는지
  var hasStaleData: Bool {
    schedules.contains { $0.isStale }
  }

  // MARK: - Placeholder

  static var placeholder: WidgetScheduleEntry {
    WidgetScheduleEntry(
      date: Date(),
      schedules: [.placeholder],
      state: .loaded
    )
  }

  #if DEBUG
  // MARK: - Preview Entries

  /// 오늘 일정 엔트리 (일정 + 개인 일정)
  static var previewToday: WidgetScheduleEntry {
    let items = (WidgetScheduleData.previewTodaySchedules + WidgetScheduleData.previewTodayPersonalEvents)
      .sorted { $0.startAt < $1.startAt }
    return WidgetScheduleEntry(
      date: Date(),
      schedules: items,
      state: .loaded
    )
  }

  /// 다가오는 일정 엔트리 (일정 + 개인 일정)
  static var previewUpcoming: WidgetScheduleEntry {
    let items = (WidgetScheduleData.previewUpcomingSchedules + WidgetScheduleData.previewUpcomingPersonalEvents)
      .sorted { $0.startAt < $1.startAt }
    return WidgetScheduleEntry(
      date: Date(),
      schedules: items,
      state: .loaded
    )
  }

  /// 전체 일정 엔트리 (오늘 + 다가오는)
  static var previewFull: WidgetScheduleEntry {
    let items = (WidgetScheduleData.previewAllSchedules + WidgetScheduleData.previewAllPersonalEvents)
      .sorted { $0.startAt < $1.startAt }
    return WidgetScheduleEntry(
      date: Date(),
      schedules: items,
      state: .loaded
    )
  }
  #endif
}
