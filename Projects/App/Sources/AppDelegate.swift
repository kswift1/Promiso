//
//  AppDelegate.swift
//  Promiso
//
//  Created by 김성원 on 9/17/25.
//

import UIKit

import ExternalDependency

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

#if DEBUG
    connectToEmulators()
#endif
    
    return true
  }
  
  /// Google Sign-In 리디렉션 URL 처리
  func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    GIDSignIn.sharedInstance.handle(url)
  }
  
#if DEBUG
  private func connectToEmulators() {
    print("🎮 Connecting to Firebase Emulators...")
    
    // Auth Emulator
    Auth.auth().useEmulator(withHost: "localhost", port: 9099)
    print("✅ Auth Emulator: localhost:9099")
    
    // Firestore Emulator
    let settings = Firestore.firestore().settings
    settings.host = "localhost:8080"
    settings.isSSLEnabled = false
    Firestore.firestore().settings = settings
    print("✅ Firestore Emulator: localhost:8080")
    
    // Functions Emulator
    Functions.functions().useEmulator(withHost: "localhost", port: 5001)
    Functions.functions(region: "asia-northeast3").useEmulator(withHost: "localhost", port: 5001)
    print("✅ Functions Emulator: localhost:5001")
    
    // Storage Emulator
    Storage.storage().useEmulator(withHost: "localhost", port: 9199)
    print("✅ Storage Emulator: localhost:9199")
    
    print("🎉 All emulators connected!")
  }
#endif
}
