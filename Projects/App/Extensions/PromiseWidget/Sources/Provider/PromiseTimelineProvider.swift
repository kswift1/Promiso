import Foundation
import os.log
import PromisoShared
import WidgetKit

let logger = Logger(subsystem: "com.promiso.widget", category: "Timeline")

/// Widget Timeline Provider
/// iOS 17+: 위젯에서 직접 API 호출하여 데이터 갱신
struct PromiseTimelineProvider: TimelineProvider {
  typealias Entry = WidgetPromiseEntry

  // MARK: - Constants

  /// 에러 발생 시 재시도 간격 (1분)
  private static let errorRefreshInterval: TimeInterval = 1 * 60
  /// 정상 갱신 간격 (5분)
  private static let normalRefreshInterval: TimeInterval = 5 * 60
  /// 비로그인 시 갱신 간격 (1시간)
  private static let notLoggedInRefreshInterval: TimeInterval = 1 * 60 * 60

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
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(Self.notLoggedInRefreshInterval)))
        completion(timeline)
        return
      }

      // 서버에서 직접 데이터 가져오기
      let result = await WidgetDataManager.fetchFromServer()

      let state: Entry.WidgetState
      if result.promises.isEmpty {
        // 데이터가 없으면 빈 상태 표시 (서버 에러 여부 무관)
        // 에러로 인한 빈 결과도 사용자에게는 "약속 없음"으로 표시
        state = .empty
      } else {
        state = .loaded
      }

      let entry = Entry(date: Date(), promises: result.promises, state: state)

      // 에러 시 빠른 재시도, 정상 시 일반 간격 갱신
      let refreshDate = result.hadError
        ? Date().addingTimeInterval(Self.errorRefreshInterval)
        : calculateNextRefresh(promises: result.promises)
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
    Date().addingTimeInterval(Self.normalRefreshInterval)
  }
}
