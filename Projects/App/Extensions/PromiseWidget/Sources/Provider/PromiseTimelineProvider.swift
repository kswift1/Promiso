import Foundation
import os.log
import PromisoShared
import WidgetKit

let logger = Logger(subsystem: "com.promiso.widget", category: "Timeline")

/// Widget Timeline Provider
/// iOS 17+: 위젯에서 직접 API 호출하여 데이터 갱신
struct PromiseTimelineProvider: TimelineProvider {
  typealias Entry = WidgetPromiseEntry

  // MARK: - 위젯 갤러리 미리보기

  func placeholder(in context: Context) -> Entry {
    .placeholder
  }

  // MARK: - 위젯 추가 시 스냅샷

  func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
    if context.isPreview {
      completion(.placeholder)
      return
    }

    // 빠른 응답을 위해 캐시 사용
    let entry = createEntryFromCache()
    completion(entry)
  }

  // MARK: - 실제 타임라인 (iOS 17+: 직접 네트워크 호출)

  func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
    Task {
      // 로그인 체크
      guard WidgetDataManager.isLoggedIn() else {
        let entry = Entry(date: Date(), promises: [], state: .notLoggedIn)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(3600)))
        completion(timeline)
        return
      }

      // 서버에서 직접 데이터 가져오기 (실패 시 캐시 반환)
      let promises = await WidgetDataManager.fetchFromServer()
      let state: Entry.WidgetState = promises.isEmpty ? .empty : .loaded
      let entry = Entry(date: Date(), promises: promises, state: state)

      let refreshDate = calculateNextRefresh(promises: promises)
      let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
      completion(timeline)
    }
  }

  // MARK: - Private Methods

  private func createEntryFromCache() -> Entry {
    guard WidgetDataManager.isLoggedIn() else {
      return Entry(date: Date(), promises: [], state: .notLoggedIn)
    }

    let promises = WidgetDataManager.loadPromises()
    let state: Entry.WidgetState = promises.isEmpty ? .empty : .loaded
    return Entry(date: Date(), promises: promises, state: state)
  }

  private func calculateNextRefresh(promises: [WidgetPromiseData]) -> Date {
    // 항상 5분 후 갱신
    Date().addingTimeInterval(300)
  }
}
