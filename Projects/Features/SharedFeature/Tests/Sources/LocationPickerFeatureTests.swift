import Testing
@testable import SharedFeature

@Suite("LocationPicker.Feature reducer 테스트")
@MainActor
struct LocationPickerFeatureTests {

  private struct TestError: Error {}

  private func makePlace(
    id: String = "place-1",
    name: String = "강남역",
    latitude: Double = 37.4979,
    longitude: Double = 127.0276
  ) -> Place {
    Place(
      id: id,
      name: name,
      coordinate: Coordinate(latitude: latitude, longitude: longitude),
      address: "서울 강남구"
    )
  }

  private func makeHistoryItem(
    id: String = "place-1",
    name: String = "강남역"
  ) -> SearchHistoryItem {
    SearchHistoryItem(
      id: id,
      name: name,
      address: "서울 강남구",
      latitude: 37.4979,
      longitude: 127.0276,
      createdAt: Date()
    )
  }

  @Test("onAppear 시 검색 기록을 로드한다")
  func onAppear_loadsHistory() async {
    let history = [
      makeHistoryItem(id: "place-1", name: "강남역"),
      makeHistoryItem(id: "place-2", name: "선릉역")
    ]

    let store = TestStore(initialState: LocationPicker.Feature.State()) {
      LocationPicker.Feature()
    } withDependencies: {
      $0.searchHistoryClient.fetchHistory = { history }
    }

    await store.send(.view(.onAppear))
    await store.receive(\.internal) {
      $0.isLoadingHistory = false
      $0.searchHistory = history
    }
  }

  @Test("searchTextChanged 시 debounce 후 장소 검색 결과를 반영한다")
  func searchTextChanged_searchesPlaces() async {
    let results = [
      makePlace(id: "place-1", name: "강남역"),
      makePlace(id: "place-2", name: "강남역 CGV")
    ]

    let store = TestStore(initialState: LocationPicker.Feature.State()) {
      LocationPicker.Feature()
    } withDependencies: {
      $0.continuousClock = ImmediateClock()
      $0.mapClient.searchPlaces = { query in
        #expect(query == "강남")
        return results
      }
    }

    await store.send(.view(.searchTextChanged("강남"))) {
      $0.searchText = "강남"
      $0.isSearching = true
      $0.searchError = nil
    }
    await store.receive(\.internal)
    await store.receive(\.internal) {
      $0.isSearching = false
      $0.searchResults = results
    }
  }

  @Test("clearSearchTapped 시 검색 상태를 초기화한다")
  func clearSearchTapped_clearsSearchState() async {
    let place = makePlace()
    var state = LocationPicker.Feature.State()
    state.searchText = "강남"
    state.searchResults = [place]
    state.isSearching = true
    state.searchError = "오류"
    state.previewPlace = place

    let store = TestStore(initialState: state) {
      LocationPicker.Feature()
    }

    await store.send(.view(.clearSearchTapped)) {
      $0.searchText = ""
      $0.searchResults = []
      $0.isSearching = false
      $0.searchError = nil
      $0.previewPlace = nil
    }
  }

  @Test("confirmSelectionTapped 시 위치 선택 delegate를 보내고 히스토리에 저장한다")
  func confirmSelectionTapped_sendsDelegateAndSavesHistory() async {
    let place = makePlace()
    let savedPlace = LockIsolated<Place?>(nil)

    var state = LocationPicker.Feature.State()
    state.previewPlace = place

    let store = TestStore(initialState: state) {
      LocationPicker.Feature()
    } withDependencies: {
      $0.searchHistoryClient.savePlace = { place in
        savedPlace.setValue(place)
      }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)

    await store.send(.view(.confirmSelectionTapped)) {
      $0.selectedPlace = place
    }
    await store.finish()

    #expect(store.state.selectedPlace == place)
    #expect(savedPlace.value == place)
  }

  @Test("deleteHistoryItem 시 삭제 완료 후 검색 기록 목록에서 제거한다")
  func deleteHistoryItem_removesHistoryItem() async {
    let deletedID = LockIsolated<String?>(nil)
    let removed = makeHistoryItem(id: "place-1", name: "강남역")
    let remained = makeHistoryItem(id: "place-2", name: "선릉역")

    var state = LocationPicker.Feature.State()
    state.searchHistory = [removed, remained]
    state.isLoadingHistory = false

    let store = TestStore(initialState: state) {
      LocationPicker.Feature()
    } withDependencies: {
      $0.searchHistoryClient.deleteItem = { id in
        deletedID.setValue(id)
      }
    }

    await store.send(.view(.deleteHistoryItem(removed.id)))
    await store.receive(\.internal) {
      $0.searchHistory = [remained]
    }
    #expect(deletedID.value == removed.id)
  }

  @Test("searchResponse 실패 시 에러 메시지를 표시한다")
  func searchResponse_failure_setsError() async {
    var state = LocationPicker.Feature.State()
    state.isSearching = true
    state.searchResults = [makePlace()]

    let store = TestStore(initialState: state) {
      LocationPicker.Feature()
    }

    await store.send(.internal(.searchResponse(.failure(TestError())))) {
      $0.isSearching = false
      $0.searchError = LocalizedStrings.Error.unknownError
    }
  }
}
