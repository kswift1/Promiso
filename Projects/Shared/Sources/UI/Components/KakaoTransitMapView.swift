import SwiftUI
import UIKit
import KakaoMapsSDK
import ResourceKit

private enum TransitMapColors {
  static var indigo: UIColor { UIColor(Color.pmindigo.n500) }
  static var error: UIColor { UIColor(Color.pmerror.n500) }
  static var gray: UIColor { UIColor(Color.pmgray.n300) }
  static var bgGray: UIColor { UIColor(Color.pmgray.n100) }
}

/// 대중교통 경로 구간 (지도 렌더링용)
public struct TransitRouteSegmentData: Equatable, Sendable {
  /// 경유 정류장 좌표 [[lng, lat], ...]
  public let coords: [[Double]]
  /// 노선 색상 (Hex, 예: "#0052A4"), nil이면 도보
  public let color: String?
  /// 교통 수단 (1=지하철, 2=버스, 3=도보)
  public let trafficType: Int

  public init(coords: [[Double]], color: String?, trafficType: Int) {
    self.coords = coords
    self.color = color
    self.trafficType = trafficType
  }
}

public struct KakaoTransitMapView: UIViewRepresentable {
  public let segments: [TransitRouteSegmentData]
  public let originLatitude: Double
  public let originLongitude: Double
  public let destinationLatitude: Double
  public let destinationLongitude: Double
  @Binding public var moveToOrigin: Bool

  public init(
    segments: [TransitRouteSegmentData],
    originLatitude: Double,
    originLongitude: Double,
    destinationLatitude: Double,
    destinationLongitude: Double,
    moveToOrigin: Binding<Bool> = .constant(false)
  ) {
    self.segments = segments
    self.originLatitude = originLatitude
    self.originLongitude = originLongitude
    self.destinationLatitude = destinationLatitude
    self.destinationLongitude = destinationLongitude
    self._moveToOrigin = moveToOrigin
  }

  public func makeUIView(context: Context) -> KMViewContainer {
    let container = KMViewContainer()
    container.backgroundColor = TransitMapColors.bgGray
    container.isUserInteractionEnabled = true
    return container
  }

  public func updateUIView(_ container: KMViewContainer, context: Context) {
    if context.coordinator.mapController != nil {
      if moveToOrigin {
        DispatchQueue.main.async { moveToOrigin = false }
        if let mapView = context.coordinator.mapController?.getView("mapview") as? KakaoMap {
          let position = MapPoint(longitude: originLongitude, latitude: originLatitude)
          mapView.moveCamera(CameraUpdate.make(target: position, zoomLevel: 15, mapView: mapView))
        }
      }
      return
    }

    // container가 레이아웃되기 전이면 다음 런루프에서 재시도
    guard container.bounds.size != .zero else {
      DispatchQueue.main.async { [segments, originLatitude, originLongitude, destinationLatitude, destinationLongitude] in
        guard context.coordinator.mapController == nil else { return }
        context.coordinator.createEngine(
          container: container,
          segments: segments,
          originLatitude: originLatitude,
          originLongitude: originLongitude,
          destinationLatitude: destinationLatitude,
          destinationLongitude: destinationLongitude
        )
      }
      return
    }

    context.coordinator.createEngine(
      container: container,
      segments: segments,
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

  public class Coordinator: NSObject, MapControllerDelegate {
    var mapController: KMController?
    private var pendingSegments: [TransitRouteSegmentData] = []
    private var pendingOriginLatitude: Double = 0
    private var pendingOriginLongitude: Double = 0
    private var pendingDestinationLatitude: Double = 0
    private var pendingDestinationLongitude: Double = 0

    func createEngine(
      container: KMViewContainer,
      segments: [TransitRouteSegmentData],
      originLatitude: Double,
      originLongitude: Double,
      destinationLatitude: Double,
      destinationLongitude: Double
    ) {
      pendingSegments = segments
      pendingOriginLatitude = originLatitude
      pendingOriginLongitude = originLongitude
      pendingDestinationLatitude = destinationLatitude
      pendingDestinationLongitude = destinationLongitude

      mapController = KMController(viewContainer: container)
      mapController?.proMotionSupport = true
      mapController?.delegate = self
      mapController?.prepareEngine()
    }

    private func addTransitRoutes(mapView: KakaoMap) {
      guard !pendingSegments.isEmpty else { return }

      let manager = mapView.getRouteManager()
      guard let layer = manager.addRouteLayer(layerID: "transitRouteLayer", zOrder: 0) else { return }

      for (index, segment) in pendingSegments.enumerated() {
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

        if segment.trafficType == 3 {
          lineColor = TransitMapColors.gray
          strokeColor = TransitMapColors.gray.withAlphaComponent(0.3)
          lineWidth = 6
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

    private func addMarkers(mapView: KakaoMap) {
      let manager = mapView.getLabelManager()

      let layerOption = LabelLayerOptions(
        layerID: "transitMarkerLayer",
        competitionType: .none,
        competitionUnit: .symbolFirst,
        orderType: .rank,
        zOrder: 10001
      )
      guard let layer = manager.addLabelLayer(option: layerOption) else { return }

      let originIcon = makeCircleImage(color: TransitMapColors.indigo, size: 20)
      let originIconStyle = PoiIconStyle(symbol: originIcon, anchorPoint: CGPoint(x: 0.5, y: 0.5))
      let originPoiStyle = PoiStyle(styleID: "transitOriginStyle", styles: [PerLevelPoiStyle(iconStyle: originIconStyle, level: 0)])
      manager.addPoiStyle(originPoiStyle)

      let destIcon = makeCircleImage(color: TransitMapColors.error, size: 20)
      let destIconStyle = PoiIconStyle(symbol: destIcon, anchorPoint: CGPoint(x: 0.5, y: 0.5))
      let destPoiStyle = PoiStyle(styleID: "transitDestStyle", styles: [PerLevelPoiStyle(iconStyle: destIconStyle, level: 0)])
      manager.addPoiStyle(destPoiStyle)

      let originOption = PoiOptions(styleID: "transitOriginStyle")
      originOption.rank = 1
      originOption.clickable = false
      let originPosition = MapPoint(longitude: pendingOriginLongitude, latitude: pendingOriginLatitude)
      if let poi = layer.addPoi(option: originOption, at: originPosition) {
        poi.show()
      }

      let destOption = PoiOptions(styleID: "transitDestStyle")
      destOption.rank = 1
      destOption.clickable = false
      let destPosition = MapPoint(longitude: pendingDestinationLongitude, latitude: pendingDestinationLatitude)
      if let poi = layer.addPoi(option: destOption, at: destPosition) {
        poi.show()
      }
    }

    private func fitCamera(mapView: KakaoMap) {
      var lats: [Double] = []
      var lngs: [Double] = []

      for segment in pendingSegments {
        for coord in segment.coords {
          guard coord.count >= 2 else { continue }
          lngs.append(coord[0])
          lats.append(coord[1])
        }
      }

      lats.append(contentsOf: [pendingOriginLatitude, pendingDestinationLatitude])
      lngs.append(contentsOf: [pendingOriginLongitude, pendingDestinationLongitude])

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

    private func hexColor(_ hex: String?) -> UIColor {
      guard let hex = hex, hex.count >= 7 else {
        return TransitMapColors.indigo
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

      addTransitRoutes(mapView: mapView)
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
