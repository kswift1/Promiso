//
//  PromiseClientTests.swift
//  Clients
//
//  PromiseClient liveValue 어댑터 로직 및 에러 매핑 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Clients/PromiseClient.swift`
//
//  ## 테스트 목적
//  - PromiseClientError 에러 매핑 검증 (NSError → PromiseClientError)
//  - PromiseClientError localizedDescription 검증
//  - createPromise 빈 groupId 검증
//  - PromiseClientError Equatable 동작 검증
//

import Foundation
import Testing
@testable import Clients

// MARK: - PromiseClientError 에러 매핑 테스트

@Suite("PromiseClientError 에러 매핑 테스트")
struct PromiseClientErrorMappingTests {

  @Test("FIRFunctionsErrorDomain 외 도메인은 networkError로 매핑")
  func nonFunctionsDomain_mapsToNetworkError() {
    let nsError = NSError(
      domain: "NSURLErrorDomain",
      code: -1009,
      userInfo: [NSLocalizedDescriptionKey: "인터넷 연결이 끊겼습니다"]
    )
    let error = PromiseClientError(from: nsError)
    #expect(error == .networkError)
  }

  @Test("FIRFunctionsErrorDomain code 16은 unauthorized로 매핑")
  func functionsDomain_code16_mapsToUnauthorized() {
    let nsError = NSError(
      domain: "FIRFunctionsErrorDomain",
      code: 16,
      userInfo: [NSLocalizedDescriptionKey: "인증 실패"]
    )
    let error = PromiseClientError(from: nsError)
    #expect(error == .unauthorized)
  }

  @Test("FIRFunctionsErrorDomain code 3, 9는 invalidData로 매핑")
  func functionsDomain_code3And9_mapsToInvalidData() {
    let invalidArgError = NSError(
      domain: "FIRFunctionsErrorDomain",
      code: 3,
      userInfo: [NSLocalizedDescriptionKey: "잘못된 인자"]
    )
    let invalidArg = PromiseClientError(from: invalidArgError)
    #expect(invalidArg == .invalidData("잘못된 인자"))

    let failedPreconditionError = NSError(
      domain: "FIRFunctionsErrorDomain",
      code: 9,
      userInfo: [NSLocalizedDescriptionKey: "조건 불충족"]
    )
    let failedPrecondition = PromiseClientError(from: failedPreconditionError)
    #expect(failedPrecondition == .invalidData("조건 불충족"))
  }

  @Test("FIRFunctionsErrorDomain code 5는 groupNotFound, code 7은 notGroupMember, code 13은 serverError로 매핑")
  func functionsDomain_variousCodes_mapCorrectly() {
    let notFoundError = NSError(
      domain: "FIRFunctionsErrorDomain",
      code: 5,
      userInfo: [NSLocalizedDescriptionKey: "그룹 없음"]
    )
    #expect(PromiseClientError(from: notFoundError) == .groupNotFound)

    let notMemberError = NSError(
      domain: "FIRFunctionsErrorDomain",
      code: 7,
      userInfo: [NSLocalizedDescriptionKey: "권한 없음"]
    )
    #expect(PromiseClientError(from: notMemberError) == .notGroupMember)

    let serverError = NSError(
      domain: "FIRFunctionsErrorDomain",
      code: 13,
      userInfo: [NSLocalizedDescriptionKey: "내부 서버 오류"]
    )
    #expect(PromiseClientError(from: serverError) == .serverError)
  }

  @Test("FIRFunctionsErrorDomain 알 수 없는 코드는 unknown으로 매핑")
  func functionsDomain_unknownCode_mapsToUnknown() {
    let unknownError = NSError(
      domain: "FIRFunctionsErrorDomain",
      code: 999,
      userInfo: [NSLocalizedDescriptionKey: "알 수 없는 에러"]
    )
    let error = PromiseClientError(from: unknownError)
    #expect(error == .unknown("알 수 없는 에러"))
  }
}

// MARK: - PromiseClientError localizedDescription 테스트

@Suite("PromiseClientError localizedDescription 테스트")
struct PromiseClientErrorDescriptionTests {

  @Test("각 에러 케이스의 localizedDescription이 올바른 한국어 메시지 반환")
  func allCases_returnCorrectKoreanMessage() {
    #expect(PromiseClientError.networkError.localizedDescription == "네트워크 연결을 확인해주세요")
    #expect(PromiseClientError.unauthorized.localizedDescription == "로그인이 필요합니다")
    #expect(PromiseClientError.notFound.localizedDescription == "약속을 찾을 수 없습니다")
    #expect(PromiseClientError.serverError.localizedDescription == "서버 오류가 발생했습니다")
    #expect(PromiseClientError.groupNotFound.localizedDescription == "그룹을 찾을 수 없습니다")
    #expect(PromiseClientError.notGroupMember.localizedDescription == "그룹 멤버만 약속을 만들 수 있습니다")
  }

  @Test("invalidData nil 메시지일 때 기본 메시지 반환")
  func invalidData_nilMessage_returnsDefaultMessage() {
    let error = PromiseClientError.invalidData(nil)
    #expect(error.localizedDescription == "잘못된 데이터입니다")
  }

  @Test("invalidData 커스텀 메시지 반환")
  func invalidData_customMessage_returnsCustomMessage() {
    let error = PromiseClientError.invalidData("제목은 필수입니다")
    #expect(error.localizedDescription == "제목은 필수입니다")
  }

  @Test("unknown nil 메시지일 때 기본 메시지 반환")
  func unknown_nilMessage_returnsDefaultMessage() {
    let error = PromiseClientError.unknown(nil)
    #expect(error.localizedDescription == "알 수 없는 오류가 발생했습니다")
  }

  @Test("unknown 커스텀 메시지 반환")
  func unknown_customMessage_returnsCustomMessage() {
    let error = PromiseClientError.unknown("timeout 발생")
    #expect(error.localizedDescription == "timeout 발생")
  }
}
