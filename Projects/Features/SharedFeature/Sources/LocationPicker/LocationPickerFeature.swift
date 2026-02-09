//
//  LocationPickerFeature.swift
//  SharedFeature
//

import ComposableArchitecture
import Clients

public enum LocationPicker {

  @Reducer
  public struct Feature {

    @Dependency(\.mapClient) var mapClient
    @Dependency(\.searchHistoryClient) var searchHistoryClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID: Hashable {
      case searchDebounce
    }

    @ObservableState
    public struct State: Equatable {
      var searchText: String = ""
      var searchResults: [Place] = []
      var searchHistory: [SearchHistoryItem] = []
      var isSearching: Bool = false
      var isLoadingHistory: Bool = true
      var searchError: String?
      var selectedPlace: Place?
      /// 지도 미리보기에 표시할 장소
      var previewPlace: Place?

      public init(
        searchText: String = "",
        searchResults: [Place] = [],
        searchHistory: [SearchHistoryItem] = [],
        isSearching: Bool = false,
        isLoadingHistory: Bool = true,
        searchError: String? = nil,
        selectedPlace: Place? = nil,
        previewPlace: Place? = nil
      ) {
        self.searchText = searchText
        self.searchResults = searchResults
        self.searchHistory = searchHistory
        self.isSearching = isSearching
        self.isLoadingHistory = isLoadingHistory
        self.searchError = searchError
        self.selectedPlace = selectedPlace
        self.previewPlace = previewPlace
      }

      /// 검색어가 비어있는지 여부
      var isSearchEmpty: Bool {
        searchText.trimmingCharacters(in: .whitespaces).isEmpty
      }
    }

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)

      public enum View: Sendable {
        case onAppear
        case searchTextChanged(String)
        case clearSearchTapped
        case placeSelected(Place)
        case placeTapped(Place)
        case historyItemTapped(SearchHistoryItem)
        case deleteHistoryItem(String)
        case confirmSelectionTapped
        case closePreviewTapped
        case dismissTapped
      }

      public enum Internal: Sendable {
        case searchDebounced(String)
        case searchResponse(Result<[Place], Error>)
        case historyLoaded([SearchHistoryItem])
        case historySaved
        case historyDeleted(String)
      }

      public enum Delegate: Sendable {
        case locationSelected(LocationInfoModel)
        case dismissed
      }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {

        // MARK: - View

        case .view(let viewAction):
          switch viewAction {

          case .onAppear:
            return .run { [searchHistoryClient] send in
              let history = (try? await searchHistoryClient.fetchHistory()) ?? []
              await send(.internal(.historyLoaded(history)))
            }

          case .searchTextChanged(let text):
            state.searchText = text
            state.searchError = nil

            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
              state.searchResults = []
              state.isSearching = false
              return .cancel(id: CancelID.searchDebounce)
            }

            state.isSearching = true

            return .run { [clock, text] send in
              try await clock.sleep(for: .milliseconds(500))
              await send(.internal(.searchDebounced(text)))
            }
            .cancellable(id: CancelID.searchDebounce, cancelInFlight: true)

          case .clearSearchTapped:
            state.searchText = ""
            state.searchResults = []
            state.isSearching = false
            state.searchError = nil
            state.previewPlace = nil
            return .cancel(id: CancelID.searchDebounce)

          case .placeSelected(let place):
            state.selectedPlace = place
            let locationInfo = place.toLocationInfo()
            return .merge(
              .send(.delegate(.locationSelected(locationInfo))),
              .run { [searchHistoryClient, place] _ in
                try? await searchHistoryClient.savePlace(place)
              }
            )

          case .placeTapped(let place):
            state.previewPlace = place
            return .none

          case .historyItemTapped(let item):
            let place = item.toPlace()
            state.previewPlace = place
            return .none

          case .deleteHistoryItem(let id):
            return .run { [searchHistoryClient] send in
              try? await searchHistoryClient.deleteItem(id)
              await send(.internal(.historyDeleted(id)))
            }

          case .confirmSelectionTapped:
            guard let place = state.previewPlace else { return .none }
            state.selectedPlace = place
            let locationInfo = place.toLocationInfo()
            return .merge(
              .send(.delegate(.locationSelected(locationInfo))),
              .run { [searchHistoryClient, place] _ in
                try? await searchHistoryClient.savePlace(place)
              }
            )

          case .closePreviewTapped:
            state.previewPlace = nil
            return .none

          case .dismissTapped:
            return .send(.delegate(.dismissed))
          }

        // MARK: - Internal

        case .internal(let internalAction):
          switch internalAction {

          case .searchDebounced(let query):
            return .run { [mapClient] send in
              do {
                let places = try await mapClient.searchPlaces(query)
                await send(.internal(.searchResponse(.success(places))))
              } catch {
                await send(.internal(.searchResponse(.failure(error))))
              }
            }

          case .searchResponse(.success(let places)):
            state.isSearching = false
            state.searchResults = places
            return .none

          case .searchResponse(.failure(let error)):
            state.isSearching = false
            state.searchError = error.localizedDescription
            return .none

          case .historyLoaded(let history):
            state.isLoadingHistory = false
            state.searchHistory = history
            return .none

          case .historySaved:
            return .none

          case .historyDeleted(let id):
            state.searchHistory.removeAll { $0.id == id }
            return .none
          }

        // MARK: - Delegate

        case .delegate:
          return .none
        }
      }
    }
  }
}
