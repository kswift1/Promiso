//
//  AppDelegate.swift
//  Promiso
//
//  Created by 김성원 on 9/17/25.
//

import UIKit

import FirebaseCore
import KakaoSDKCommon
import KakaoSDKAuth

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()
    
    initKakaoSDK()
    return true
  }
}

private extension AppDelegate {
  func initKakaoSDK() {
    guard let appKey: String = Bundle.main.object(forInfoDictionaryKey: "KAKAO_API_KEY") as? String else { return }
    KakaoSDK.initSDK(appKey: appKey, loggingEnable: true)
  }
}
