import SwiftUI
import Clients
import ComposableArchitecture
import ResourceKit
import PromisoShared

// MARK: - Step 2 Content View
struct CreatePromiseStep2View: View {
  let store: StoreOf<CreatePromise.Feature>

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 32) {
          // 헤더
          CreatePromiseStep.second.headerView

          // 시작 날짜/시간
          StartDateTimeSection(store: store, scrollProxy: proxy)
            .id("startDateTime")

          // 종료 날짜/시간 (선택)
          EndDateTimeSection(store: store, scrollProxy: proxy)
            .id("endDateTime")

          // 장소 (선택)
          LocationSection(store: store)
        }
        .padding(16)
      }
    }
  }
}

// MARK: - Location Section
struct LocationSection: View {
  @Bindable var store: StoreOf<CreatePromise.Feature>

  private var useLocation: Bool {
    store.useLocation
  }

  var body: some View {
    SectionPlaceHolder(
      placeHolderTitle: LocalizedStrings.CreatePromise.locationSection,
      placeHolderAccessory: {
        Toggle("", isOn: Binding(
          get: { useLocation },
          set: { _ in
            store.send(.view(.toggleUseLocation), animation: .spring(response: 0.4, dampingFraction: 0.85))
          }
        ))
        .labelsHidden()
      },
      content: {
        VStack {
          if useLocation {
            if let location = store.promise.location {
              // 장소가 선택된 경우: 미니맵 + 정보
              LocationWithMapCard(
                location: location,
                onChangeTapped: { store.send(.view(.locationPickerTapped)) }
              )

            } else {
              // 장소 미선택: 검색 버튼
              Button {
                store.send(.view(.locationPickerTapped))
              } label: {
                HStack(spacing: 12) {
                  Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.pmindigo.n500)
                  Text(LocalizedStrings.CreatePromise.searchLocation)
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)

                  Spacer()
                }
                .padding(16)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
              }
              .buttonStyle(.hapticBounce(.light))
            }
          }
        }
      }
    )
    .sheet(item: $store.scope(state: \.locationPicker, action: \.locationPicker)) { pickerStore in
      LocationPicker.RootView(store: pickerStore)
    }
  }

}

// MARK: - Location With Map Card

private struct LocationWithMapCard: View {
  let location: LocationInfoModel
  let onChangeTapped: () -> Void

  private var hasCoordinates: Bool {
    location.latitude != nil && location.longitude != nil
  }

  var body: some View {
    Button(action: onChangeTapped) {
      VStack(spacing: 0) {
        // 미니맵 (좌표가 있는 경우만)
        if hasCoordinates,
           let lat = location.latitude,
           let lng = location.longitude {
          KakaoMiniMapView(
            latitude: lat,
            longitude: lng,
            zoomLevel: 15,
            markerImage: ResourceKitAsset.mapPinMedium.image
          )
          .frame(height: 240)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(Color(.systemGray4), lineWidth: 0.5)
          )
        }

        // 장소 정보
        HStack(spacing: 12) {
          ResourceKitAsset.mapPinMedium.swiftUIImage
            .fixedSize()
            .frame(width: 24, height: 24)

          VStack(alignment: .leading, spacing: 2) {
            Text(location.name)
              .font(.system(size: 16, weight: .medium))
              .foregroundColor(.primary)

            if let address = location.address {
              Text(address)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }

          Spacer()

          Text(LocalizedStrings.Common.change)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color.pmindigo.n500)
        }
        .padding(.horizontal, 4)
        .padding(.top, hasCoordinates ? 12 : 0)
      }
    }
    .buttonStyle(.hapticBounce(.light))
  }
}

