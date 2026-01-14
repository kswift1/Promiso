//
//  AppDelegate.swift
//  Promiso
//
//  Created by 김성원 on 9/17/25.
//

import UIKit

import ExternalDependency
import Clarity

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    configureClaritySDK()

// MARK: - Emulator 사용 시 주석 해제
#if DEBUG
//    connectToEmulators()
#endif

    return true
  }

  // MARK: - Microsoft Clarity SDK
  private func configureClaritySDK() {
    let projectId = "v0o95eccpc"

    #if DEBUG
    let config = ClarityConfig(projectId: projectId, logLevel: .error)
    #else
    let config = ClarityConfig(projectId: projectId, logLevel: .none)
    #endif

    ClaritySDK.initialize(config: config)
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
    let emulatorHost = "192.168.0.2"
    print("🎮 Connecting to Firebase Emulators...")
    
    // Auth Emulator
    Auth.auth().useEmulator(withHost: emulatorHost, port: 9099)
    print("✅ Auth Emulator: \(emulatorHost):9099")
    
    // Firestore Emulator
    let settings = Firestore.firestore().settings
    settings.host = "\(emulatorHost):8081"
    settings.isSSLEnabled = false
    Firestore.firestore().settings = settings
    print("✅ Firestore Emulator: \(emulatorHost):8081")
    
    // Functions Emulator
    Functions.functions().useEmulator(withHost: emulatorHost, port: 5001)
    Functions.functions(region: "asia-northeast3").useEmulator(withHost: emulatorHost, port: 5001)
    print("✅ Functions Emulator: \(emulatorHost):5001")
    
    // Storage Emulator
    Storage.storage().useEmulator(withHost: emulatorHost, port: 9199)
    print("✅ Storage Emulator: \(emulatorHost):9199")
    
    print("🎉 All emulators connected!")
  }
#endif
}
