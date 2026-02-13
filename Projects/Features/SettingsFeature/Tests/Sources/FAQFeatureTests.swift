import Testing
@testable import SettingsFeature

@Suite("FAQ.Feature 테스트")
@MainActor
struct FAQFeatureTests {

  // MARK: - 초기 상태 테스트

  @Test("초기 상태 기본값 확인")
  func initialState_hasCorrectDefaults() {
    let state = FAQ.Feature.State()

    #expect(state.faqs.isEmpty)
    #expect(state.isLoading == false)
    #expect(state.errorMessage == nil)
    #expect(state.expandedFAQIds.isEmpty)
    #expect(state.selectedCategory == nil)
  }

  // MARK: - onAppear 테스트

  @Test("onAppear 시 FAQ 로드 성공")
  func onAppear_success_loadsFAQs() async {
    let faqs = [makeFAQ(id: "1"), makeFAQ(id: "2")]

    let store = makeStore {
      $0.faqClient.fetchFAQs = { faqs }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear)) {
      $0.isLoading = true
      $0.errorMessage = nil
    }
    await store.receive(\.internal.faqsLoaded) {
      $0.isLoading = false
      $0.faqs = faqs
      $0.expandedFAQIds = Set(faqs.map(\.id))
    }
  }

  @Test("onAppear 이미 로드된 경우 스킵")
  func onAppear_alreadyLoaded_skips() async {
    var state = FAQ.Feature.State()
    state.faqs = [makeFAQ(id: "1")]

    let store = makeStore(state: state)

    await store.send(.view(.onAppear))
  }

  @Test("onAppear 실패 시 에러 메시지 설정")
  func onAppear_failure_setsError() async {
    let store = makeStore {
      $0.faqClient.fetchFAQs = {
        throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "서버 에러"])
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.onAppear)) {
      $0.isLoading = true
    }
    await store.receive(\.internal.faqsLoadFailed) {
      $0.isLoading = false
      $0.errorMessage = "서버 에러"
    }
  }

  // MARK: - faqTapped 테스트

  @Test("faqTapped 시 펼침/접힘 토글")
  func faqTapped_togglesExpansion() async {
    var state = FAQ.Feature.State()
    state.faqs = [makeFAQ(id: "1")]
    state.expandedFAQIds = ["1"]

    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    // 접기
    await store.send(.view(.faqTapped("1"))) {
      $0.expandedFAQIds.remove("1")
    }

    // 다시 펼치기
    await store.send(.view(.faqTapped("1"))) {
      $0.expandedFAQIds.insert("1")
    }
  }

  // MARK: - retryTapped 테스트

  @Test("retryTapped 시 onAppear 재전송")
  func retryTapped_resendsOnAppear() async {
    let faqs = [makeFAQ(id: "1")]

    let store = makeStore {
      $0.faqClient.fetchFAQs = { faqs }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.retryTapped))
    await store.receive(\.view.onAppear) {
      $0.isLoading = true
    }
    await store.receive(\.internal.faqsLoaded) {
      $0.isLoading = false
      $0.faqs = faqs
      $0.expandedFAQIds = Set(faqs.map(\.id))
    }
  }

  // MARK: - categorySelected 테스트

  @Test("categorySelected 시 카테고리 필터링 및 펼침 유지")
  func categorySelected_filtersAndExpands() async {
    var state = FAQ.Feature.State()
    state.faqs = [
      makeFAQ(id: "1", category: "그룹"),
      makeFAQ(id: "2", category: "알림"),
      makeFAQ(id: "3", category: "그룹"),
    ]
    state.expandedFAQIds = ["1"]

    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.categorySelected("그룹"))) {
      $0.selectedCategory = "그룹"
      $0.expandedFAQIds = ["1", "3"]
    }
  }

  @Test("categorySelected nil 시 전체 선택")
  func categorySelected_nil_selectsAll() async {
    var state = FAQ.Feature.State()
    state.faqs = [makeFAQ(id: "1"), makeFAQ(id: "2")]
    state.selectedCategory = "그룹"

    let store = makeStore(state: state)
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.categorySelected(nil))) {
      $0.selectedCategory = nil
      $0.expandedFAQIds = ["1", "2"]
    }
  }

  // MARK: - 계산 프로퍼티 테스트

  @Test("filteredFAQs 카테고리 필터링")
  func filteredFAQs_filtersCorrectly() {
    var state = FAQ.Feature.State()
    state.faqs = [
      makeFAQ(id: "1", category: "그룹"),
      makeFAQ(id: "2", category: "알림"),
    ]
    state.selectedCategory = "그룹"

    #expect(state.filteredFAQs.count == 1)
    #expect(state.filteredFAQs.first?.id == "1")
  }

  @Test("availableCategories 정렬된 카테고리 목록")
  func availableCategories_sortedUniqueCategories() {
    var state = FAQ.Feature.State()
    state.faqs = [
      makeFAQ(id: "1", category: "알림"),
      makeFAQ(id: "2", category: "그룹"),
      makeFAQ(id: "3", category: "알림"),
    ]

    #expect(state.availableCategories == ["그룹", "알림"])
  }
}

// MARK: - Helpers

private extension FAQFeatureTests {

  func makeStore(
    state: FAQ.Feature.State = .init(),
    configure: (inout DependencyValues) -> Void = { _ in }
  ) -> TestStoreOf<FAQ.Feature> {
    TestStore(initialState: state) {
      FAQ.Feature()
    } withDependencies: {
      applyDefaultDependencies(&$0)
      configure(&$0)
    }
  }

  func makeFAQ(
    id: String,
    question: String = "테스트 질문",
    answer: String = "테스트 답변",
    category: String? = nil
  ) -> FAQModel {
    FAQModel(id: id, question: question, answer: answer, category: category)
  }

  func applyDefaultDependencies(_ deps: inout DependencyValues) {
    deps.faqClient.fetchFAQs = { [] }
    deps.hapticFeedback.selection = {}
    deps.hapticFeedback.error = {}
  }
}
