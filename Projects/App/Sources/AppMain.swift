import SwiftUI
import ComposableArchitecture
import RootTabFeatureImplement
import ScheduleFeatureInterface
import ScheduleFeatureImplement
import HomeFeatureInterface
import HomeFeatureImplement

@main
struct PromisoApp: App {
  var body: some Scene {
    WindowGroup {
      // App 레이어에서 모든 의존성을 주입
      let store = Store(initialState: RootTab.Feature.State()) {
        RootTab.Feature()
      }
      
      // Entry들을 App에서 생성 (Implement에 의존)
      let scheduleEntry = ScheduleEntry.live()
      let homeEntry = HomeEntry.live()
      
      // 의존성을 주입하여 RootView 생성
      RootTab.RootView(store: store, scheduleEntry: scheduleEntry, homeEntry: homeEntry)
    }
  }
}
