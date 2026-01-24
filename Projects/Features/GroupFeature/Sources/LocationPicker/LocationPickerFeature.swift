//
//  LocationPickerFeature.swift
//  GroupFeature
//

import ComposableArchitecture
import Clients

public enum LocationPicker {

  @Reducer
  public struct Feature {

    @Dependency(\.mapClient) var mapClient
    @Dependency(\.continuousClock) var clock

    private enum CancelID: Hashable {
      case searchDebounce
    }

    @ObservableState
    public struct State: Equatable {
      var searchText: String = ""
      var searchResults: [Place] = []
      var isSearching: Bool = false
      var searchError: String?
      var selectedPlace: Place?
      /// 지도 미리보기에 표시할 장소
      var previewPlace: Place?

      public init(
        searchText: String = "",
        searchResults: [Place] = [],
        isSearching: Bool = false,
        searchError: String? = nil,
        selectedPlace: Place? = nil,
        previewPlace: Place? = nil
      ) {
        self.searchText = searchText
        self.searchResults = searchResults
        self.isSearching = isSearching
        self.searchError = searchError
        self.selectedPlace = selectedPlace
        self.previewPlace = previewPlace
      }
    }

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)

      public enum View: Sendable {
        case searchTextChanged(String)
        case clearSearchTapped
        case placeSelected(Place)
        case placeTapped(Place)
        case confirmSelectionTapped
        case closePreviewTapped
        case dismissTapped
      }

      public enum Internal: Sendable {
        case searchDebounced(String)
        case searchResponse(Result<[Place], Error>)
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

          case .searchTextChanged(let text):
            state.searchText = text
            state.searchError = nil

            // 빈 검색어면 결과 초기화
            guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
              state.searchResults = []
              state.isSearching = false
              return .cancel(id: CancelID.searchDebounce)
            }

            state.isSearching = true

            // 300ms 디바운스
            return .run { [clock, text] send in
              try await clock.sleep(for: .milliseconds(300))
              await send(.internal(.searchDebounced(text)))
            }
            .cancellable(id: CancelID.searchDebounce, cancelInFlight: true)

          case .clearSearchTapped:
            state.searchText = ""
            state.searchResults = []
            state.isSearching = false
            state.searchError = nil
            return .cancel(id: CancelID.searchDebounce)

          case .placeSelected(let place):
            state.selectedPlace = place
            let locationInfo = place.toLocationInfo()
            return .send(.delegate(.locationSelected(locationInfo)))

          case .placeTapped(let place):
            state.previewPlace = place
            return .none

          case .confirmSelectionTapped:
            guard let place = state.previewPlace else { return .none }
            state.selectedPlace = place
            let locationInfo = place.toLocationInfo()
            return .send(.delegate(.locationSelected(locationInfo)))

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
          }

        // MARK: - Delegate

        case .delegate:
          return .none
        }
      }
    }
  }
}
