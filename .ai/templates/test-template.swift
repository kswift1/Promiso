// MARK: - {Name}FeatureTests Template
// 사용법: {Name}을 실제 Feature 이름으로 교체

import Testing
import ComposableArchitecture
@testable import {Name}Feature

@Suite("{Name}.Feature 테스트")
@MainActor
struct {Name}FeatureTests {

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = {Name}.Feature.State()
    #expect(state.items.isEmpty)
    #expect(state.isLoading == false)
    #expect(state.errorMessage == nil)
  }

  // MARK: - 데이터 로딩 테스트

  @Test("onAppear 시 데이터 로드 시작")
  func onAppear_startsLoading() async {
    let store = makeStore {
      $0.someClient.fetch = { [.mock] }
    }

    await store.send(.view(.onAppear)) {
      $0.isLoading = true
    }

    await store.receive(\.internal.dataResponse.success) {
      $0.isLoading = false
      $0.items = [.mock]
    }
  }

  @Test("데이터 로드 실패 시 에러 메시지 설정")
  func onAppear_failure_setsError() async {
    enum TestError: Error, LocalizedError {
      case failed
      var errorDescription: String? { "테스트 에러" }
    }

    let store = makeStore {
      $0.someClient.fetch = { throw TestError.failed }
    }

    await store.send(.view(.onAppear)) {
      $0.isLoading = true
    }

    await store.receive(\.internal.dataResponse.failure) {
      $0.isLoading = false
      $0.errorMessage = "테스트 에러"
    }
  }

  // MARK: - 사용자 인터랙션 테스트

  @Test("아이템 탭 시 delegate 전달")
  func itemTapped_sendsDelegate() async {
    var state = {Name}.Feature.State()
    state.items = [.mock]

    let store = TestStore(initialState: state) {
      {Name}.Feature()
    }

    await store.send(.view(.itemTapped("mock-id")))
    await store.receive(\.delegate.itemSelected)
  }

  // MARK: - Exhaustivity Off 패턴 (필요 시)

  // @Test("non-deterministic 값이 포함된 액션")
  // func nonDeterministic_action() async {
  //   let store = makeStore()
  //   store.exhaustivity = .off(showSkippedAssertions: false)
  //
  //   await store.send(.view(.someAction))
  //   #expect(store.state.someProperty == expectedValue)
  // }
}

// MARK: - Helpers

private extension {Name}FeatureTests {
  func makeStore(
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<{Name}.Feature> {
    TestStore(
      initialState: {Name}.Feature.State()
    ) {
      {Name}.Feature()
    } withDependencies: {
      // 기본 mock 설정
      // $0.someClient.fetch = { [] }
      configure(&$0)
    }
  }

  // 모델 팩토리
  // func makeItem(
  //   id: String = "mock-id",
  //   title: String = "테스트 아이템"
  // ) -> Item {
  //   Item(id: id, title: title)
  // }
}
