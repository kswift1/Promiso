//
//  LocationPickerView.swift
//  GroupFeature
//

import SwiftUI
import ComposableArchitecture
import Clients
import ResourceKit

extension LocationPicker {

  public struct RootView: View {
    @Bindable var store: StoreOf<LocationPicker.Feature>

    public init(store: StoreOf<LocationPicker.Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStack {
        ZStack(alignment: .bottom) {
          VStack(spacing: 0) {
            // 검색바
            SearchBar(
              text: Binding(
                get: { store.searchText },
                set: { store.send(.view(.searchTextChanged($0))) }
              ),
              onClear: { store.send(.view(.clearSearchTapped)) }
            )
            .padding(16)

            Divider()

            // 콘텐츠
            if store.isSearching {
              LoadingView()
            } else if let error = store.searchError {
              ErrorView(message: error)
            } else if store.searchResults.isEmpty && !store.searchText.isEmpty {
              EmptyResultView()
            } else if store.searchResults.isEmpty {
              PlaceholderView()
            } else {
              SearchResultsList(
                places: store.searchResults,
                highlightedId: store.previewPlace?.id,
                onSelect: { store.send(.view(.placeTapped($0))) }
              )
              // 지도 미리보기가 있으면 하단 여백 추가
              .padding(.bottom, store.previewPlace != nil ? 320 : 0)
            }
          }

          // 지도 미리보기
          if let previewPlace = store.previewPlace {
            MapPreviewContainer(
              place: previewPlace,
              onConfirm: { store.send(.view(.confirmSelectionTapped)) },
              onClose: { store.send(.view(.closePreviewTapped)) }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
          }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.previewPlace)
        .navigationTitle("장소 검색")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("취소") {
              store.send(.view(.dismissTapped))
            }
          }
        }
      }
    }
  }
}

// MARK: - Search Bar

private struct SearchBar: View {
  @Binding var text: String
  let onClear: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "magnifyingglass")
        .foregroundColor(.secondary)
        .font(.system(size: 16))

      TextField("장소를 검색하세요", text: $text)
        .textFieldStyle(.plain)
        .autocorrectionDisabled()

      if !text.isEmpty {
        Button(action: onClear) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(.secondary)
            .font(.system(size: 16))
        }
      }
    }
    .padding(12)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

// MARK: - Search Results List

private struct SearchResultsList: View {
  let places: [Place]
  var highlightedId: String?
  let onSelect: (Place) -> Void

  var body: some View {
    ScrollView {
      LazyVStack(spacing: 0) {
        ForEach(places) { place in
          PlaceRow(place: place, isHighlighted: place.id == highlightedId)
            .contentShape(Rectangle())
            .onTapGesture {
              onSelect(place)
            }

          if place.id != places.last?.id {
            Divider()
              .padding(.leading, 56)
          }
        }
      }
    }
  }
}

// MARK: - Place Row

private struct PlaceRow: View {
  let place: Place
  var isHighlighted: Bool = false

  var body: some View {
    HStack(spacing: 12) {
      // 아이콘
      ZStack {
        Circle()
          .fill(isHighlighted ? Color.pmindigo.n500 : Color.pmindigo.n100)
          .frame(width: 40, height: 40)

        Image(systemName: "mappin.circle.fill")
          .font(.system(size: 20))
          .foregroundColor(isHighlighted ? .white : Color.pmindigo.n500)
      }

      // 정보
      VStack(alignment: .leading, spacing: 4) {
        Text(place.name)
          .font(.system(size: 16, weight: .medium))
          .foregroundColor(.primary)
          .lineLimit(1)

        if let address = place.displayAddress {
          Text(address)
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .lineLimit(1)
        }

        if let category = place.category {
          Text(category)
            .font(.system(size: 12))
            .foregroundColor(Color.pmindigo.n500)
            .lineLimit(1)
        }
      }

      Spacer()

      // 선택 표시
      if isHighlighted {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 20))
          .foregroundColor(Color.pmindigo.n500)
      } else {
        Image(systemName: "chevron.right")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.secondary)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(isHighlighted ? Color.pmindigo.n50 : Color.clear)
    .animation(.easeInOut(duration: 0.2), value: isHighlighted)
  }
}

// MARK: - Loading View

private struct LoadingView: View {
  var body: some View {
    VStack(spacing: 16) {
      Spacer()

      ProgressView()
        .scaleEffect(1.2)

      Text("검색 중...")
        .font(.system(size: 14))
        .foregroundColor(.secondary)

      Spacer()
    }
  }
}

// MARK: - Empty Result View

private struct EmptyResultView: View {
  var body: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: "magnifyingglass")
        .font(.system(size: 48))
        .foregroundColor(.secondary)

      Text("검색 결과가 없습니다")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.secondary)

      Text("다른 키워드로 검색해 보세요")
        .font(.system(size: 14))
        .foregroundColor(.secondary.opacity(0.8))

      Spacer()
    }
  }
}

// MARK: - Error View

private struct ErrorView: View {
  let message: String

  var body: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 48))
        .foregroundColor(.orange)

      Text("검색 중 오류가 발생했습니다")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.primary)

      Text(message)
        .font(.system(size: 14))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 32)

      Spacer()
    }
  }
}

// MARK: - Placeholder View

private struct PlaceholderView: View {
  var body: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(systemName: "map")
        .font(.system(size: 48))
        .foregroundColor(Color.pmindigo.n300)

      Text("장소를 검색해 보세요")
        .font(.system(size: 16, weight: .medium))
        .foregroundColor(.secondary)

      Text("카페, 식당, 영화관 등")
        .font(.system(size: 14))
        .foregroundColor(.secondary.opacity(0.8))

      Spacer()
    }
  }
}

// MARK: - Preview

#Preview("기본 상태") {
  LocationPicker.RootView(
    store: Store(initialState: LocationPicker.Feature.State()) {
      LocationPicker.Feature()
    }
  )
}

#Preview("검색 결과") {
  LocationPicker.RootView(
    store: Store(
      initialState: LocationPicker.Feature.State(
        searchText: "강남",
        searchResults: [
          Place(
            id: "1",
            name: "스타벅스 강남역점",
            coordinate: Coordinate(latitude: 37.498095, longitude: 127.027610),
            address: "서울 강남구 강남대로 390",
            roadAddress: "서울 강남구 강남대로 390",
            category: "카페",
            phone: nil
          ),
          Place(
            id: "2",
            name: "CGV 강남",
            coordinate: Coordinate(latitude: 37.501087, longitude: 127.026632),
            address: "서울 강남구 강남대로 438",
            roadAddress: "서울 강남구 강남대로 438",
            category: "영화관",
            phone: nil
          ),
        ]
      )
    ) {
      LocationPicker.Feature()
    }
  )
}
