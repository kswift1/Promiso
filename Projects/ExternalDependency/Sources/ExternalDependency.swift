// MARK: - ExternalDependency 모듈
// 외부 라이브러리들의 중앙 집중 관리를 위한 모듈입니다.
// @_exported import를 통해 다른 모듈에서 한 번의 import로 모든 외부 의존성을 사용할 수 있습니다.

@_exported import ComposableArchitecture
@_exported import Dependencies
@_exported import XCTestDynamicOverlay
@_exported import FirebaseCore
@_exported import FirebaseAuth
@_exported import FirebaseFirestore
@_exported import FirebaseAnalytics
@_exported import FirebaseCrashlytics
@_exported import FirebaseStorage
@_exported import FirebaseFunctions
@_exported import FirebaseMessaging
@_exported import RenderMeThis
@_exported import GoogleSignIn
@_exported import GoogleSignInSwift
@_exported import Lottie
@_exported import KakaoMapsSDK
@_exported import KakaoSDKCommon
@_exported import KakaoSDKShare
// KakaoSDKTemplate은 Content 타입이 ViewModifier.Content와 충돌하므로
// @_exported하지 않고 KakaoShareClient.swift에서만 직접 import
@_exported import Pulse
@_exported import PulseUI

