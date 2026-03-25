//
//  KakaoMiniMapView.swift
//  PromisoShared
//

import SwiftUI
import UIKit
import KakaoMapsSDK
import ResourceKit

/// 카카오 지도 미니맵 뷰
/// - 지도 제스처 비활성화 (스크롤과 충돌 방지)
/// - 마커 표시 지원
/// - 동적 좌표 업데이트 지원
public struct KakaoMiniMapView: UIViewRepresentable {
  public let latitude: Double
  public let longitude: Double
  public let zoomLevel: Int
  public let markerImage: UIImage?

  public init(
    latitude: Double,
    longitude: Double,
    zoomLevel: Int = 18,
    markerImage: UIImage? = nil
  ) {
    self.latitude = latitude
    self.longitude = longitude
    self.zoomLevel = zoomLevel
    self.markerImage = markerImage
  }

  public func makeUIView(context: Context) -> KMViewContainer {
    let container = KMViewContainer()
    container.backgroundColor = .systemGray6
    container.isUserInteractionEnabled = false
    return container
  }

  public func updateUIView(_ container: KMViewContainer, context: Context) {
    // 이미 엔진이 있으면 위치만 업데이트
    if let mapView = context.coordinator.mapController?.getView("mapview") as? KakaoMap {
      let position = MapPoint(longitude: longitude, latitude: latitude)
      mapView.moveCamera(
        CameraUpdate.make(
          target: position,
          zoomLevel: zoomLevel,
          mapView: mapView
        )
      )
      context.coordinator.updateMarker(mapView: mapView, latitude: latitude, longitude: longitude)
      return
    }

    // 처음 생성 시
    context.coordinator.createEngine(
      container: container,
      latitude: latitude,
      longitude: longitude,
      zoomLevel: zoomLevel,
      markerImage: markerImage
    )
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  public static func dismantleUIView(_ container: KMViewContainer, coordinator: Coordinator) {
    coordinator.cleanupMapController()
  }

  public class Coordinator: NSObject, MapControllerDelegate {
    var mapController: KMController?

    deinit {
      cleanupMapController()
    }

    func cleanupMapController() {
      mapController?.delegate = nil
      mapController?.pauseEngine()
      mapController?.resetEngine()
      mapController = nil
    }

    private var pendingLatitude: Double?
    private var pendingLongitude: Double?
    private var pendingZoomLevel: Int = 18
    private var pendingMarkerImage: UIImage?

    func createEngine(
      container: KMViewContainer,
      latitude: Double,
      longitude: Double,
      zoomLevel: Int,
      markerImage: UIImage?
    ) {
      pendingLatitude = latitude
      pendingLongitude = longitude
      pendingZoomLevel = zoomLevel
      pendingMarkerImage = markerImage

      mapController = KMController(viewContainer: container)
      mapController?.proMotionSupport = true  // 120Hz ProMotion Display 지원
      mapController?.delegate = self
      mapController?.prepareEngine()
    }

    func updateMarker(mapView: KakaoMap, latitude: Double, longitude: Double) {
      let manager = mapView.getLabelManager()

      if let existingLayer = manager.getLabelLayer(layerID: "markerLayer") {
        existingLayer.clearAllItems()
      }

      addMarker(mapView: mapView, latitude: latitude, longitude: longitude)
    }

    private func addMarker(mapView: KakaoMap, latitude: Double, longitude: Double) {
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
        guard let newLayer = manager.addLabelLayer(option: layerOption) else { return }
        layer = newLayer
      }

      // POI 스타일 생성
      let markerIcon = pendingMarkerImage ?? ResourceKitAsset.mapPinMedium.image
      let iconStyle = PoiIconStyle(
        symbol: markerIcon,
        anchorPoint: CGPoint(x: 0.5, y: 1.0)
      )
      let poiStyle = PoiStyle(styleID: "markerStyle", styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)])
      manager.addPoiStyle(poiStyle)

      // POI 옵션
      let poiOption = PoiOptions(styleID: "markerStyle")
      poiOption.rank = 0
      poiOption.clickable = false

      // POI 생성
      let position = MapPoint(longitude: longitude, latitude: latitude)
      if let poi = layer.addPoi(option: poiOption, at: position) {
        poi.show()
      }
    }

    // MARK: - MapControllerDelegate

    public func addViews() {
      guard let controller = mapController,
            let latitude = pendingLatitude,
            let longitude = pendingLongitude else { return }

      let position = MapPoint(longitude: longitude, latitude: latitude)
      let mapviewInfo = MapviewInfo(
        viewName: "mapview",
        viewInfoName: "map",
        defaultPosition: position,
        defaultLevel: pendingZoomLevel
      )

      controller.addView(mapviewInfo)
    }

    public func addViewSucceeded(_ viewName: String, viewInfoName: String) {
      guard let mapView = mapController?.getView("mapview") as? KakaoMap,
            let latitude = pendingLatitude,
            let longitude = pendingLongitude else { return }

      addMarker(mapView: mapView, latitude: latitude, longitude: longitude)
    }

    public func addViewFailed(_ viewName: String, viewInfoName: String) {}

    public func containerDidResized(_ size: CGSize) {
      guard let mapView = mapController?.getView("mapview") as? KakaoMap else { return }
      mapView.viewRect = CGRect(origin: .zero, size: size)
    }

    public func authenticationSucceeded() {
      mapController?.activateEngine()
    }

    public func authenticationFailed(_ errorCode: Int, desc: String) {}
  }
}
