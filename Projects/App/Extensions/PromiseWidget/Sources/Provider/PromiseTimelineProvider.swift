import Foundation
import PromisoShared
import WidgetKit

/// Widget Timeline Provider
struct PromiseTimelineProvider: TimelineProvider {
  typealias Entry = WidgetPromiseEntry

  // MARK: - 위젯 갤러리 미리보기

  func placeholder(in context: Context) -> Entry {
    .placeholder
  }

  // MARK: - 위젯 추가 시 스냅샷

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    completion(createEntry())
  }

  // MARK: - 실제 타임라인

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    let entry = createEntry()
    let refreshDate = calculateNextRefresh(promises: entry.promises)
    let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
    completion(timeline)
  }

  // MARK: - Private Methods

  private func createEntry() -> Entry {
    // 로그인 체크
    guard WidgetDataManager.isLoggedIn() else {
      return Entry(date: Date(), promises: [], state: .notLoggedIn)
    }

    let promises = WidgetDataManager.loadPromises()
    let state: Entry.WidgetState = promises.isEmpty ? .empty : .loaded
    return Entry(date: Date(), promises: promises, state: state)
  }

  private func calculateNextRefresh(promises: [WidgetPromiseData]) -> Date {
    let now = Date()
    let maxInterval: TimeInterval = 3600 // 최대 1시간 (Fallback)

    guard let nextPromise = promises.first(where: { $0.startAt > now }) else {
      return now.addingTimeInterval(7200) // 2시간
    }

    let timeUntil = nextPromise.startAt.timeIntervalSince(now)

    // 1시간 이내 → 15분
    if timeUntil <= 3600 {
      return now.addingTimeInterval(min(900, maxInterval))
    }
    // 6시간 이내 → 30분
    if timeUntil <= 21600 {
      return now.addingTimeInterval(min(1800, maxInterval))
    }
    // 그 외 → 1시간
    return now.addingTimeInterval(maxInterval)
  }
}
