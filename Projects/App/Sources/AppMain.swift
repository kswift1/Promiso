import SwiftUI
import ComposableArchitecture
import RootTabFeatureImplement
import PromiseFeatureInterface
import PromiseFeatureImplement
import HomeFeatureInterface
import HomeFeatureImplement

@main
struct PromisoApp: App {
  
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  
  var body: some Scene {
    WindowGroup {
      // App 레이어에서 모든 의존성을 주입
      let store = Store(initialState: RootTab.Feature.State()) {
        RootTab.Feature()
      }
      
      // Entry들을 App에서 생성 (Implement에 의존)
      let promiseEntry = PromiseEntry.live()
      let homeEntry = HomeEntry.live()
      
      // 의존성을 주입하여 RootView 생성
      RootTab.RootView(store: store, promiseEntry: promiseEntry, homeEntry: homeEntry)
    }
  }
}
