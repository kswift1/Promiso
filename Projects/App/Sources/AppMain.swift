import SwiftUI
import ComposableArchitecture
import RootTabFeature
import HomeFeature
import GroupFeature

@main
struct PromisoApp: App {
  
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  
  var body: some Scene {
    WindowGroup {
      // App 레이어에서 모든 의존성을 주입
      let store = Store(initialState: RootTab.Feature.State()) {
        RootTab.Feature()
      }
      
      // TCA Feature들을 직접 사용
      RootTab.RootView(store: store)
    }
  }
}