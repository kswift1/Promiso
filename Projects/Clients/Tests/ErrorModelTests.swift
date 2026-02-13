//
//  ErrorModelTests.swift
//  Clients
//
//  에러 모델 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Domain/Errors/AppError.swift`
//  - `Clients/Sources/Domain/Errors/UserError.swift`
//
//  ## 테스트 목적
//  - AppError: localizedDescription, errorDescription, 초기화 방식 검증
//  - UserProfileError: 각 케이스별 errorDescription 한글 메시지 검증
//  - UserPlan: displayName 검증
//  - UserSettings: 기본값 검증
//  - ProviderInfo: 초기화, 속성 검증
//

import Foundation
import Testing
@testable import Clients

// MARK: - AppError 테스트

@Suite("AppError 테스트")
struct AppErrorTests {

  @Test("message 문자열로 초기화")
  func init_withMessage_setsMessage() {
    let error = AppError(message: "네트워크 오류")
    #expect(error.message == "네트워크 오류")
  }

  @Test("errorDescription은 message와 동일")
  func errorDescription_equalsMessage() {
    let error = AppError(message: "서버 에러")
    #expect(error.errorDescription == "서버 에러")
  }

  @Test("Error 객체로 초기화하면 localizedDescription이 message에 저장")
  func init_withError_usesLocalizedDescription() {
    let nsError = NSError(domain: "test", code: 42, userInfo: [
      NSLocalizedDescriptionKey: "테스트 에러 메시지"
    ])
    let appError = AppError(nsError)
    #expect(appError.message == "테스트 에러 메시지")
  }

  @Test("AppError는 Equatable 비교 가능")
  func equatable_sameMessage_areEqual() {
    let error1 = AppError(message: "동일 메시지")
    let error2 = AppError(message: "동일 메시지")
    #expect(error1 == error2)
  }

  @Test("다른 메시지의 AppError는 같지 않음")
  func equatable_differentMessage_areNotEqual() {
    let error1 = AppError(message: "에러 A")
    let error2 = AppError(message: "에러 B")
    #expect(error1 != error2)
  }

  @Test("AppError는 Error 프로토콜 준수")
  func conformsToError() {
    let error: Error = AppError(message: "테스트")
    #expect(error.localizedDescription == "테스트")
  }
}

// MARK: - UserProfileError 테스트

@Suite("UserProfileError 테스트")
struct UserProfileErrorTests {

  @Test("invalidData 에러 메시지")
  func invalidData_errorDescription() {
    let error = UserProfileError.invalidData
    #expect(error.errorDescription == "프로필 데이터 형식이 올바르지 않습니다.")
  }

  @Test("userNotFound 에러 메시지")
  func userNotFound_errorDescription() {
    let error = UserProfileError.userNotFound
    #expect(error.errorDescription == "사용자를 찾을 수 없습니다.")
  }

  @Test("uploadFailed 에러 메시지")
  func uploadFailed_errorDescription() {
    let error = UserProfileError.uploadFailed
    #expect(error.errorDescription == "프로필 업로드에 실패했습니다.")
  }

  @Test("networkError 에러 메시지")
  func networkError_errorDescription() {
    let error = UserProfileError.networkError
    #expect(error.errorDescription == "네트워크 연결을 확인해주세요.")
  }

  @Test("authenticationRequired 에러 메시지")
  func authenticationRequired_errorDescription() {
    let error = UserProfileError.authenticationRequired
    #expect(error.errorDescription == "로그인이 필요합니다.")
  }

  @Test("permissionDenied 에러 메시지")
  func permissionDenied_errorDescription() {
    let error = UserProfileError.permissionDenied
    #expect(error.errorDescription == "권한이 없습니다.")
  }

  @Test("UserProfileError는 Equatable 비교 가능")
  func equatable_sameCases_areEqual() {
    #expect(UserProfileError.invalidData == UserProfileError.invalidData)
    #expect(UserProfileError.userNotFound != UserProfileError.networkError)
  }
}

// MARK: - UserPlan 테스트

@Suite("UserPlan 테스트")
struct UserPlanTests {

  @Test("free 플랜 displayName은 '무료'")
  func free_displayName() {
    #expect(UserPlan.free.displayName == "무료")
  }

  @Test("pro 플랜 displayName은 '프로'")
  func pro_displayName() {
    #expect(UserPlan.pro.displayName == "프로")
  }

  @Test("UserPlan rawValue 올바름")
  func rawValues() {
    #expect(UserPlan.free.rawValue == "free")
    #expect(UserPlan.pro.rawValue == "pro")
  }
}

// MARK: - UserSettings 테스트

@Suite("UserSettings 테스트")
struct UserSettingsTests {

  @Test("기본 설정값 확인")
  func defaultSettings_haveCorrectValues() {
    let settings = UserSettings.default
    #expect(settings.notificationEnabled == true)
    #expect(settings.plan == .free)
  }

  @Test("커스텀 초기화")
  func customInit_setsProperties() {
    let settings = UserSettings(
      notificationEnabled: false,
      plan: .pro
    )
    #expect(settings.notificationEnabled == false)
    #expect(settings.plan == .pro)
  }
}

// MARK: - ProviderInfo 테스트

@Suite("ProviderInfo 테스트")
struct ProviderInfoTests {

  @Test("ProviderInfo 초기화 및 속성 확인")
  func init_setsProperties() {
    let provider = ProviderInfo(type: "google", uid: "uid-123", email: "test@gmail.com")
    #expect(provider.type == "google")
    #expect(provider.uid == "uid-123")
    #expect(provider.email == "test@gmail.com")
  }

  @Test("ProviderInfo Equatable 비교")
  func equatable_sameValues_areEqual() {
    let p1 = ProviderInfo(type: "apple", uid: "uid-1", email: "a@b.com")
    let p2 = ProviderInfo(type: "apple", uid: "uid-1", email: "a@b.com")
    #expect(p1 == p2)
  }
}
