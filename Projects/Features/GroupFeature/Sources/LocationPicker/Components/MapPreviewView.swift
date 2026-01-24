//
//  MapPreviewView.swift
//  GroupFeature
//

import SwiftUI
import UIKit
import Clients
import KakaoMapsSDK

// MARK: - Map Preview View

struct MapPreviewView: UIViewRepresentable {
  let coordinate: Coordinate
  let placeName: String

  func makeUIView(context: Context) -> KMViewContainer {
    let container = KMViewContainer()
    container.backgroundColor = .systemBackground
    return container
  }

  func updateUIView(_ container: KMViewContainer, context: Context) {
    // 이미 엔진이 있으면 위치만 업데이트
    if let mapView = context.coordinator.mapController?.getView("mapview") as? KakaoMap {
      let position = MapPoint(longitude: coordinate.longitude, latitude: coordinate.latitude)
      mapView.moveCamera(
        CameraUpdate.make(
          target: position,
          zoomLevel: 15,
          mapView: mapView
        )
      )
      context.coordinator.updateMarker(mapView: mapView, coordinate: coordinate, name: placeName)
      return
    }

    // 처음 생성 시
    context.coordinator.createEngine(container: container, coordinate: coordinate, placeName: placeName)
  }

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  static func dismantleUIView(_ container: KMViewContainer, coordinator: Coordinator) {
    coordinator.mapController?.pauseEngine()
    coordinator.mapController?.resetEngine()
  }

  class Coordinator: NSObject, MapControllerDelegate {
    var mapController: KMController?
    private var pendingCoordinate: Coordinate?
    private var pendingPlaceName: String?
    private var markerLayer: LabelLayer?

    func createEngine(container: KMViewContainer, coordinate: Coordinate, placeName: String) {
      pendingCoordinate = coordinate
      pendingPlaceName = placeName

      mapController = KMController(viewContainer: container)
      mapController?.delegate = self
      mapController?.prepareEngine()
    }

    func updateMarker(mapView: KakaoMap, coordinate: Coordinate, name: String) {
      // 기존 마커 제거 후 새로 추가
      let manager = mapView.getLabelManager()

      if let existingLayer = manager.getLabelLayer(layerID: "markerLayer") {
        existingLayer.clearAllItems()
      }

      addMarker(mapView: mapView, coordinate: coordinate, name: name)
    }

    private func addMarker(mapView: KakaoMap, coordinate: Coordinate, name: String) {
      let manager = mapView.getLabelManager()

      // 레이어 생성 또는 가져오기
      let layer: LabelLayer
      if let existingLayer = manager.getLabelLayer(layerID: "markerLayer") {
        layer = existingLayer
      } else {
        let layerOption = LabelLayerOptions(
          layerID: "markerLayer",
          competitionType: .none,
          competitionUnit: .symbolFirst,
          orderType: .rank,
          zOrder: 10001
        )
        layer = manager.addLabelLayer(option: layerOption)!
      }

      // POI 스타일 생성
      let iconStyle = PoiIconStyle(symbol: UIImage(systemName: "mappin.circle.fill")?.withTintColor(.systemBlue, renderingMode: .alwaysOriginal), anchorPoint: CGPoint(x: 0.5, y: 1.0))
      let poiStyle = PoiStyle(styleID: "markerStyle", styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)])
      manager.addPoiStyle(poiStyle)

      // POI 옵션
      let poiOption = PoiOptions(styleID: "markerStyle")
      poiOption.rank = 0
      poiOption.clickable = false

      // POI 생성
      let position = MapPoint(longitude: coordinate.longitude, latitude: coordinate.latitude)
      if let poi = layer.addPoi(option: poiOption, at: position) {
        poi.show()
      }
    }

    // MARK: - MapControllerDelegate

    func addViews() {
      guard let controller = mapController,
            let coordinate = pendingCoordinate else { return }

      let position = MapPoint(longitude: coordinate.longitude, latitude: coordinate.latitude)
      let mapviewInfo = MapviewInfo(
        viewName: "mapview",
        viewInfoName: "map",
        defaultPosition: position,
        defaultLevel: 15
      )

      controller.addView(mapviewInfo)
    }

    func addViewSucceeded(_ viewName: String, viewInfoName: String) {
      guard let mapView = mapController?.getView("mapview") as? KakaoMap,
            let coordinate = pendingCoordinate,
            let name = pendingPlaceName else { return }

      addMarker(mapView: mapView, coordinate: coordinate, name: name)
    }

    func addViewFailed(_ viewName: String, viewInfoName: String) {
      print("MapPreviewView: Failed to add view - \(viewName)")
    }

    func containerDidResized(_ size: CGSize) {
      guard let mapView = mapController?.getView("mapview") as? KakaoMap else { return }
      mapView.viewRect = CGRect(origin: .zero, size: size)
    }

    func authenticationSucceeded() {
      mapController?.activateEngine()
    }

    func authenticationFailed(_ errorCode: Int, desc: String) {
      print("MapPreviewView: Auth failed - \(errorCode): \(desc)")
    }
  }
}

// MARK: - Preview Container

struct MapPreviewContainer: View {
  let place: Place
  let onConfirm: () -> Void
  let onClose: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      // 핸들
      RoundedRectangle(cornerRadius: 2.5)
        .fill(Color(.systemGray4))
        .frame(width: 36, height: 5)
        .padding(.top, 8)
        .padding(.bottom, 12)

      // 장소 정보
      HStack(spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(place.name)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.primary)

          if let address = place.displayAddress {
            Text(address)
              .font(.system(size: 14))
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
        }

        Spacer()

        Button(action: onClose) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 24))
            .foregroundColor(.secondary)
        }
      }
      .padding(.horizontal, 16)
      .padding(.bottom, 12)

      // 지도
      MapPreviewView(
        coordinate: place.coordinate,
        placeName: place.name
      )
      .frame(height: 200)
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .padding(.horizontal, 16)

      // 선택 버튼
      Button(action: onConfirm) {
        HStack {
          Image(systemName: "checkmark.circle.fill")
          Text("이 장소 선택")
        }
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.blue)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
      .padding(16)
    }
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .shadow(color: .black.opacity(0.15), radius: 20, y: -5)
  }
}
