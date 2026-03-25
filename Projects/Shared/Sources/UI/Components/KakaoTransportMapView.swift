import SwiftUI
import UIKit
import KakaoMapsSDK
import ResourceKit

// MARK: - TransportMapData

/// 교통수단별 지도 표시 데이터
public enum TransportMapData: Equatable {
  /// 자동차: routePoints [[lng, lat], ...]
  case driving(routePoints: [[Double]])
  /// 대중교통: 구간별 좌표 + 색상
  case transit(segments: [TransitRouteSegmentData])
  /// 도보: routePoints [[lng, lat], ...]
  case walking(routePoints: [[Double]] = [])
}

// MARK: - TransitRouteSegmentData

/// 대중교통 경로 구간 (지도 렌더링용)
public struct TransitRouteSegmentData: Equatable, Sendable {
  /// 경유 정류장 좌표 [[lng, lat], ...]
  public let coords: [[Double]]
  /// 노선 색상 (Hex, 예: "#0052A4"), nil이면 도보
  public let color: String?
  /// 교통 수단 (1=지하철, 2=버스, 3=도보)
  public let trafficType: Int
  /// 도보 구간 점선 표시 여부
  public let isWalking: Bool

  public init(coords: [[Double]], color: String?, trafficType: Int, isWalking: Bool = false) {
    self.coords = coords
    self.color = color
    self.trafficType = trafficType
    self.isWalking = isWalking
  }
}

// MARK: - MapColors

private enum MapColors {
  static var indigo: UIColor { UIColor(Color.pmindigo.n500) }
  static var error: UIColor { UIColor(Color.pmerror.n500) }
  static var gray: UIColor { UIColor(Color.pmgray.n500) }
  static var bgGray: UIColor { UIColor(Color.pmgray.n100) }
}

// MARK: - KakaoTransportMapView

public struct KakaoTransportMapView: UIViewRepresentable {
  public let data: TransportMapData
  public let originLatitude: Double
  public let originLongitude: Double
  public let destinationLatitude: Double
  public let destinationLongitude: Double
  @Binding public var moveToOrigin: Bool

  public init(
    data: TransportMapData,
    originLatitude: Double,
    originLongitude: Double,
    destinationLatitude: Double,
    destinationLongitude: Double,
    moveToOrigin: Binding<Bool> = .constant(false)
  ) {
    self.data = data
    self.originLatitude = originLatitude
    self.originLongitude = originLongitude
    self.destinationLatitude = destinationLatitude
    self.destinationLongitude = destinationLongitude
    self._moveToOrigin = moveToOrigin
  }

  public func makeUIView(context: Context) -> KMViewContainer {
    let container = KMViewContainer()
    container.backgroundColor = MapColors.bgGray
    container.isUserInteractionEnabled = true
    return container
  }

  public func updateUIView(_ container: KMViewContainer, context: Context) {
    let coordinator = context.coordinator

    // 엔진이 이미 생성된 경우
    if coordinator.mapController != nil {
      // moveToOrigin 처리
      if moveToOrigin {
        DispatchQueue.main.async { moveToOrigin = false }
        if let mapView = coordinator.mapController?.getView("mapview") as? KakaoMap {
          let position = MapPoint(longitude: originLongitude, latitude: originLatitude)
          mapView.moveCamera(CameraUpdate.make(target: position, zoomLevel: 15, mapView: mapView))
        }
        return
      }

      // 데이터 변경 감지 → clear & redraw
      if coordinator.currentData != data {
        coordinator.currentData = data
        coordinator.pendingOriginLatitude = originLatitude
        coordinator.pendingOriginLongitude = originLongitude
        coordinator.pendingDestinationLatitude = destinationLatitude
        coordinator.pendingDestinationLongitude = destinationLongitude

        if let mapView = coordinator.mapController?.getView("mapview") as? KakaoMap {
          coordinator.clearAndRedraw(mapView: mapView)
        }
      }
      return
    }

    // 최초 엔진 생성
    guard container.bounds.size != .zero else {
      DispatchQueue.main.async { [data, originLatitude, originLongitude, destinationLatitude, destinationLongitude] in
        guard context.coordinator.mapController == nil else { return }
        context.coordinator.createEngine(
          container: container,
          data: data,
          originLatitude: originLatitude,
          originLongitude: originLongitude,
          destinationLatitude: destinationLatitude,
          destinationLongitude: destinationLongitude
        )
      }
      return
    }

    coordinator.createEngine(
      container: container,
      data: data,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude
    )
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  public static func dismantleUIView(_ container: KMViewContainer, coordinator: Coordinator) {
    coordinator.mapController?.pauseEngine()
    coordinator.mapController?.resetEngine()
  }

  // MARK: - Coordinator

  public class Coordinator: NSObject, MapControllerDelegate {
    var mapController: KMController?
    var currentData: TransportMapData = .walking()
    var pendingOriginLatitude: Double = 0
    var pendingOriginLongitude: Double = 0
    var pendingDestinationLatitude: Double = 0
    var pendingDestinationLongitude: Double = 0

    private let routeLayerID = "transportRouteLayer"
    private let markerLayerID = "transportMarkerLayer"

    func createEngine(
      container: KMViewContainer,
      data: TransportMapData,
      originLatitude: Double,
      originLongitude: Double,
      destinationLatitude: Double,
      destinationLongitude: Double
    ) {
      currentData = data
      pendingOriginLatitude = originLatitude
      pendingOriginLongitude = originLongitude
      pendingDestinationLatitude = destinationLatitude
      pendingDestinationLongitude = destinationLongitude

      mapController = KMController(viewContainer: container)
      mapController?.proMotionSupport = true
      mapController?.delegate = self
      mapController?.prepareEngine()
    }

    func clearAndRedraw(mapView: KakaoMap) {
      // 기존 레이어 제거
      let routeManager = mapView.getRouteManager()
      routeManager.removeRouteLayer(layerID: routeLayerID)

      let labelManager = mapView.getLabelManager()
      labelManager.removeLabelLayer(layerID: markerLayerID)

      // 새로 그리기
      addRoute(mapView: mapView)
      addMarkers(mapView: mapView)
      fitCamera(mapView: mapView)
    }

    // MARK: - Route Drawing

    private func addRoute(mapView: KakaoMap) {
      switch currentData {
      case .driving(let routePoints):
        addDrivingRoute(mapView: mapView, routePoints: routePoints)
      case .transit(let segments):
        addTransitRoutes(mapView: mapView, segments: segments)
      case .walking(let routePoints):
        addWalkingRoute(mapView: mapView, routePoints: routePoints)
      }
    }

    private func addDrivingRoute(mapView: KakaoMap, routePoints: [[Double]]) {
      guard !routePoints.isEmpty else { return }

      let manager = mapView.getRouteManager()
      guard let layer = manager.addRouteLayer(layerID: routeLayerID, zOrder: 0) else { return }

      let lineStyle = RouteStyle(styles: [
        PerLevelRouteStyle(
          width: 12,
          color: MapColors.indigo,
          strokeWidth: 2,
          strokeColor: MapColors.indigo.withAlphaComponent(0.3),
          level: 0
        )
      ])
      let styleSet = RouteStyleSet(styleID: "drivingRouteStyle", styles: [lineStyle])
      manager.addRouteStyleSet(styleSet)

      let points = routePoints.compactMap { point -> MapPoint? in
        guard point.count >= 2 else { return nil }
        return MapPoint(longitude: point[0], latitude: point[1])
      }
      guard !points.isEmpty else { return }

      let segment = RouteSegment(points: points, styleIndex: 0)
      let routeOption = RouteOptions(routeID: "drivingRoute", styleID: "drivingRouteStyle", zOrder: 0)
      routeOption.segments = [segment]
      let route = layer.addRoute(option: routeOption)
      route?.show()
    }

    private func addWalkingRoute(mapView: KakaoMap, routePoints: [[Double]]) {
      guard !routePoints.isEmpty else { return }

      let manager = mapView.getRouteManager()
      guard let layer = manager.addRouteLayer(layerID: routeLayerID, zOrder: 0) else { return }

      let lineStyle = RouteStyle(styles: [
        PerLevelRouteStyle(
          width: 10,
          color: MapColors.gray,
          strokeWidth: 2,
          strokeColor: MapColors.gray.withAlphaComponent(0.3),
          level: 0
        )
      ])
      let styleSet = RouteStyleSet(styleID: "walkingRouteStyle", styles: [lineStyle])
      manager.addRouteStyleSet(styleSet)

      let points = routePoints.compactMap { point -> MapPoint? in
        guard point.count >= 2 else { return nil }
        return MapPoint(longitude: point[0], latitude: point[1])
      }
      guard !points.isEmpty else { return }

      let segment = RouteSegment(points: points, styleIndex: 0)
      let routeOption = RouteOptions(routeID: "walkingRoute", styleID: "walkingRouteStyle", zOrder: 0)
      routeOption.segments = [segment]
      let route = layer.addRoute(option: routeOption)
      route?.show()
    }

    private func addTransitRoutes(mapView: KakaoMap, segments: [TransitRouteSegmentData]) {
      guard !segments.isEmpty else { return }

      let manager = mapView.getRouteManager()
      guard let layer = manager.addRouteLayer(layerID: routeLayerID, zOrder: 0) else { return }

      for (index, segment) in segments.enumerated() {
        guard !segment.coords.isEmpty else { continue }

        let points = segment.coords.compactMap { coord -> MapPoint? in
          guard coord.count >= 2 else { return nil }
          return MapPoint(longitude: coord[0], latitude: coord[1])
        }
        guard !points.isEmpty else { continue }

        let styleID = "transitStyle_\(index)"
        let routeID = "transitRoute_\(index)"

        let lineColor: UIColor
        let strokeColor: UIColor
        let lineWidth: UInt

        if segment.isWalking {
          lineColor = MapColors.gray
          strokeColor = MapColors.gray.withAlphaComponent(0.3)
          lineWidth = 10
        } else {
          lineColor = hexColor(segment.color)
          strokeColor = lineColor.withAlphaComponent(0.3)
          lineWidth = 10
        }

        let lineStyle = RouteStyle(styles: [
          PerLevelRouteStyle(
            width: lineWidth,
            color: lineColor,
            strokeWidth: 2,
            strokeColor: strokeColor,
            level: 0
          )
        ])
        let styleSet = RouteStyleSet(styleID: styleID, styles: [lineStyle])
        manager.addRouteStyleSet(styleSet)

        let routeSegment = RouteSegment(points: points, styleIndex: 0)
        let routeOption = RouteOptions(routeID: routeID, styleID: styleID, zOrder: 0)
        routeOption.segments = [routeSegment]
        let route = layer.addRoute(option: routeOption)
        route?.show()
      }
    }

    // MARK: - Markers

    private func addMarkers(mapView: KakaoMap) {
      let manager = mapView.getLabelManager()

      let layerOption = LabelLayerOptions(
        layerID: markerLayerID,
        competitionType: .none,
        competitionUnit: .symbolFirst,
        orderType: .rank,
        zOrder: 10001
      )
      guard let layer = manager.addLabelLayer(option: layerOption) else { return }

      let originIcon = makeCircleImage(color: MapColors.indigo, size: 10)
      let originIconStyle = PoiIconStyle(symbol: originIcon, anchorPoint: CGPoint(x: 0.5, y: 0.5))
      let originPoiStyle = PoiStyle(styleID: "transportOriginStyle", styles: [PerLevelPoiStyle(iconStyle: originIconStyle, level: 0)])
      manager.addPoiStyle(originPoiStyle)

      let destIcon = makeCircleImage(color: MapColors.error, size: 10)
      let destIconStyle = PoiIconStyle(symbol: destIcon, anchorPoint: CGPoint(x: 0.5, y: 0.5))
      let destPoiStyle = PoiStyle(styleID: "transportDestStyle", styles: [PerLevelPoiStyle(iconStyle: destIconStyle, level: 0)])
      manager.addPoiStyle(destPoiStyle)

      let originOption = PoiOptions(styleID: "transportOriginStyle")
      originOption.rank = 1
      originOption.clickable = false
      let originPosition = MapPoint(longitude: pendingOriginLongitude, latitude: pendingOriginLatitude)
      if let poi = layer.addPoi(option: originOption, at: originPosition) {
        poi.show()
      }

      let destOption = PoiOptions(styleID: "transportDestStyle")
      destOption.rank = 1
      destOption.clickable = false
      let destPosition = MapPoint(longitude: pendingDestinationLongitude, latitude: pendingDestinationLatitude)
      if let poi = layer.addPoi(option: destOption, at: destPosition) {
        poi.show()
      }
    }

    // MARK: - Camera

    private func fitCamera(mapView: KakaoMap) {
      var lats: [Double] = [pendingOriginLatitude, pendingDestinationLatitude]
      var lngs: [Double] = [pendingOriginLongitude, pendingDestinationLongitude]

      switch currentData {
      case .driving(let routePoints):
        lats.append(contentsOf: routePoints.compactMap { $0.count >= 2 ? $0[1] : nil })
        lngs.append(contentsOf: routePoints.compactMap { $0.count >= 2 ? $0[0] : nil })
      case .transit(let segments):
        for segment in segments {
          for coord in segment.coords {
            guard coord.count >= 2 else { continue }
            lngs.append(coord[0])
            lats.append(coord[1])
          }
        }
      case .walking(let routePoints):
        lats.append(contentsOf: routePoints.compactMap { $0.count >= 2 ? $0[1] : nil })
        lngs.append(contentsOf: routePoints.compactMap { $0.count >= 2 ? $0[0] : nil })
      }

      guard let minLat = lats.min(),
            let maxLat = lats.max(),
            let minLng = lngs.min(),
            let maxLng = lngs.max() else { return }

      let southWest = MapPoint(longitude: minLng, latitude: minLat)
      let northEast = MapPoint(longitude: maxLng, latitude: maxLat)
      let areaRect = AreaRect(southWest: southWest, northEast: northEast)
      mapView.setMargins(UIEdgeInsets(top: 100, left: 100, bottom: 100, right: 100))
      mapView.moveCamera(CameraUpdate.make(area: areaRect))
    }

    // MARK: - Helpers

    private func hexColor(_ hex: String?) -> UIColor {
      guard let hex = hex, hex.count >= 7 else {
        return MapColors.indigo
      }
      var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
      hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
      var rgb: UInt64 = 0
      Scanner(string: hexSanitized).scanHexInt64(&rgb)
      return UIColor(
        red: CGFloat((rgb >> 16) & 0xFF) / 255,
        green: CGFloat((rgb >> 8) & 0xFF) / 255,
        blue: CGFloat(rgb & 0xFF) / 255,
        alpha: 1
      )
    }

    private func makeCircleImage(color: UIColor, size: CGFloat) -> UIImage {
      let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
      return renderer.image { ctx in
        color.setFill()
        ctx.cgContext.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
        UIColor.white.setFill()
        let innerSize = size * 0.4
        let offset = (size - innerSize) / 2
        ctx.cgContext.fillEllipse(in: CGRect(x: offset, y: offset, width: innerSize, height: innerSize))
      }
    }

    // MARK: - MapControllerDelegate

    public func addViews() {
      guard let controller = mapController else { return }

      let centerLat = (pendingOriginLatitude + pendingDestinationLatitude) / 2
      let centerLng = (pendingOriginLongitude + pendingDestinationLongitude) / 2
      let position = MapPoint(longitude: centerLng, latitude: centerLat)
      let mapviewInfo = MapviewInfo(
        viewName: "mapview",
        viewInfoName: "map",
        defaultPosition: position,
        defaultLevel: 14
      )

      controller.addView(mapviewInfo)
    }

    public func addViewSucceeded(_ viewName: String, viewInfoName: String) {
      guard let mapView = mapController?.getView("mapview") as? KakaoMap else { return }

      addRoute(mapView: mapView)
      addMarkers(mapView: mapView)
      fitCamera(mapView: mapView)
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
