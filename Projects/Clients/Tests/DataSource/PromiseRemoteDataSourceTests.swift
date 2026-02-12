//
//  PromiseRemoteDataSourceTests.swift
//  Clients
//
//  Mock 기반 PromiseRemoteDataSource 로직 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Data/DataSources/Protocols/PromiseRemoteDataSourceProtocol.swift`
//  - `Clients/Tests/Mocks/MockPromiseRemoteDataSource.swift`
//
//  ## 테스트 목적
//  - Mock DataSource의 호출 카운트 및 인자 캡처 검증
//  - 커스텀 핸들러 동작 검증
//  - 에러 전파 검증
//  - reset 기능 검증
//

import Foundation
import Testing
@testable import Clients
import PromisoShared

// MARK: - MockPromiseRemoteDataSource 동작 테스트

@Suite("PromiseRemoteDataSource Mock 기반 테스트")
struct PromiseRemoteDataSourceTests {

  // MARK: - CRUD 호출 카운트 및 인자 캡처 테스트

  @Test("createPromise 호출 시 callCount 증가 및 인자 캡처")
  func createPromise_incrementsCallCountAndCapturesArguments() async throws {
    let mock = MockPromiseRemoteDataSource()
    let promise = TestFactories.makePromise(title: "새 약속", groupId: "g1")

    let result = try await mock.createPromise(promise)

    #expect(mock.createPromiseCallCount == 1)
    #expect(mock.createPromiseArguments.count == 1)
    #expect(mock.createPromiseArguments.first?.title == "새 약속")
    #expect(mock.createPromiseArguments.first?.groupId == "g1")
    #expect(result == "created-promise-id")
  }

  @Test("createPromise 커스텀 핸들러가 반환값 오버라이드")
  func createPromise_customHandler_overridesDefaultReturn() async throws {
    let mock = MockPromiseRemoteDataSource()
    mock.createPromiseHandler = { promise in
      return "custom-id-\(promise.groupId)"
    }

    let promise = TestFactories.makePromise(groupId: "my-group")
    let result = try await mock.createPromise(promise)

    #expect(result == "custom-id-my-group")
    #expect(mock.createPromiseCallCount == 1)
  }

  @Test("getPromise 기본 핸들러는 nil 반환, 커스텀 핸들러 설정 시 약속 반환")
  func getPromise_defaultReturnsNil_customHandlerReturnsPromise() async throws {
    let mock = MockPromiseRemoteDataSource()

    // 기본 핸들러: nil 반환
    let nilResult = try await mock.getPromise(id: "promise-1")
    #expect(nilResult == nil)
    #expect(mock.getPromiseCallCount == 1)
    #expect(mock.getPromiseArguments == ["promise-1"])

    // 커스텀 핸들러: 약속 반환
    mock.getPromiseHandler = { id in
      return TestFactories.makePromise(id: id, title: "조회된 약속")
    }

    let result = try await mock.getPromise(id: "promise-2")
    #expect(result?.id == "promise-2")
    #expect(result?.title == "조회된 약속")
    #expect(mock.getPromiseCallCount == 2)
  }

  // MARK: - 에러 전파 테스트

  @Test("핸들러에서 에러 발생 시 에러가 정상적으로 전파")
  func handler_throwsError_propagatesCorrectly() async {
    let mock = MockPromiseRemoteDataSource()
    mock.deletePromiseHandler = { _ in
      throw PromiseClientError.notFound
    }

    do {
      try await mock.deletePromise(id: "nonexistent")
      #expect(Bool(false), "에러가 발생해야 합니다")
    } catch {
      #expect(error is PromiseClientError)
      #expect(mock.deletePromiseCallCount == 1)
      #expect(mock.deletePromiseArguments == ["nonexistent"])
    }
  }

  // MARK: - 쿼리 Operations 테스트

  @Test("getActivePromises 빈 그룹에서 빈 배열 반환, 핸들러 설정 시 데이터 반환")
  func getActivePromises_defaultEmpty_customHandlerReturnsData() async throws {
    let mock = MockPromiseRemoteDataSource()

    // 기본: 빈 배열
    let emptyResult = try await mock.getActivePromises(groupId: "g1", limit: 10)
    #expect(emptyResult.isEmpty)
    #expect(mock.getActivePromisesCallCount == 1)

    // 커스텀 핸들러: 데이터 반환
    mock.getActivePromisesHandler = { groupId, limit in
      return [
        TestFactories.makePromise(id: "p1", groupId: groupId),
        TestFactories.makePromise(id: "p2", groupId: groupId),
      ]
    }

    let result = try await mock.getActivePromises(groupId: "g1", limit: 10)
    #expect(result.count == 2)
    #expect(result.first?.groupId == "g1")
    #expect(mock.getActivePromisesCallCount == 2)
  }

  // MARK: - reset 테스트

  @Test("reset 호출 시 모든 카운트와 캡처 인자 초기화")
  func reset_clearsAllCountsAndArguments() async throws {
    let mock = MockPromiseRemoteDataSource()

    // 몇 가지 호출 수행
    _ = try await mock.createPromise(TestFactories.makePromise())
    _ = try await mock.getPromise(id: "p1")
    try await mock.deletePromise(id: "p2")

    #expect(mock.createPromiseCallCount == 1)
    #expect(mock.getPromiseCallCount == 1)
    #expect(mock.deletePromiseCallCount == 1)

    // reset
    mock.reset()

    #expect(mock.createPromiseCallCount == 0)
    #expect(mock.getPromiseCallCount == 0)
    #expect(mock.deletePromiseCallCount == 0)
    #expect(mock.createPromiseArguments.isEmpty)
    #expect(mock.getPromiseArguments.isEmpty)
    #expect(mock.deletePromiseArguments.isEmpty)
  }
}
