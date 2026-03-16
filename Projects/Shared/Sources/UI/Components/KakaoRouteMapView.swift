import SwiftUI
import UIKit
import KakaoMapsSDK
import ResourceKit

private enum RouteMapColors {
  static var indigo: UIColor { UIColor(Color.pmindigo.n500) }
  static var error: UIColor { UIColor(Color.pmerror.n500) }
  static var gray: UIColor { UIColor(Color.pmgray.n100) }
}

public struct KakaoRouteMapView: UIViewRepresentable {
  public let routePoints: [[Double]]
  public let originLatitude: Double
  public let originLongitude: Double
  public let destinationLatitude: Double
  public let destinationLongitude: Double

  public init(
    routePoints: [[Double]],
    originLatitude: Double,
    originLongitude: Double,
    destinationLatitude: Double,
    destinationLongitude: Double
  ) {
    self.routePoints = routePoints
    self.originLatitude = originLatitude
    self.originLongitude = originLongitude
    self.destinationLatitude = destinationLatitude
    self.destinationLongitude = destinationLongitude
  }

  public func makeUIView(context: Context) -> KMViewContainer {
    let container = KMViewContainer()
    container.backgroundColor = RouteMapColors.gray
    container.isUserInteractionEnabled = false
    return container
  }

  public func updateUIView(_ container: KMViewContainer, context: Context) {
    if context.coordinator.mapController?.getView("mapview") != nil {
      return
    }

    context.coordinator.createEngine(
      container: container,
      routePoints: routePoints,
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
    private var pendingRoutePoints: [[Double]] = []
    private var pendingOriginLatitude: Double = 0
    private var pendingOriginLongitude: Double = 0
    private var pendingDestinationLatitude: Double = 0
    private var pendingDestinationLongitude: Double = 0

    func createEngine(
      container: KMViewContainer,
      routePoints: [[Double]],
      originLatitude: Double,
      originLongitude: Double,
      destinationLatitude: Double,
      destinationLongitude: Double
    ) {
      pendingRoutePoints = routePoints
      pendingOriginLatitude = originLatitude
      pendingOriginLongitude = originLongitude
      pendingDestinationLatitude = destinationLatitude
      pendingDestinationLongitude = destinationLongitude

      mapController = KMController(viewContainer: container)
      mapController?.proMotionSupport = true
      mapController?.delegate = self
      mapController?.prepareEngine()
    }

    private func addRoute(mapView: KakaoMap) {
      guard !pendingRoutePoints.isEmpty else { return }

      let manager = mapView.getRouteManager()
      guard let layer = manager.addRouteLayer(layerID: "routeLayer", zOrder: 0) else { return }

      let lineStyle = RouteStyle(styles: [
        PerLevelRouteStyle(
          width: 12,
          color: RouteMapColors.indigo,
          strokeWidth: 2,
          strokeColor: RouteMapColors.indigo.withAlphaComponent(0.3),
          level: 0
        )
      ])
      let styleSet = RouteStyleSet(styleID: "routeStyle", styles: [lineStyle])
      manager.addRouteStyleSet(styleSet)

      let points = pendingRoutePoints.compactMap { point -> MapPoint? in
        guard point.count >= 2 else { return nil }
        return MapPoint(longitude: point[0], latitude: point[1])
      }
      guard !points.isEmpty else { return }

      let segment = RouteSegment(points: points, styleIndex: 0)
      let routeOption = RouteOptions(routeID: "drivingRoute", styleID: "routeStyle", zOrder: 0)
      routeOption.segments = [segment]
      let route = layer.addRoute(option: routeOption)
      route?.show()
    }

    private func addMarkers(mapView: KakaoMap) {
      let manager = mapView.getLabelManager()

      let layerOption = LabelLayerOptions(
        layerID: "routeMarkerLayer",
        competitionType: .none,
        competitionUnit: .symbolFirst,
        orderType: .rank,
        zOrder: 10001
      )
      guard let layer = manager.addLabelLayer(option: layerOption) else { return }

      let originIcon = makeCircleImage(color: RouteMapColors.indigo, size: 20)
      let originIconStyle = PoiIconStyle(symbol: originIcon, anchorPoint: CGPoint(x: 0.5, y: 0.5))
      let originPoiStyle = PoiStyle(styleID: "originStyle", styles: [PerLevelPoiStyle(iconStyle: originIconStyle, level: 0)])
      manager.addPoiStyle(originPoiStyle)

      let destIcon = makeCircleImage(color: RouteMapColors.error, size: 20)
      let destIconStyle = PoiIconStyle(symbol: destIcon, anchorPoint: CGPoint(x: 0.5, y: 0.5))
      let destPoiStyle = PoiStyle(styleID: "destStyle", styles: [PerLevelPoiStyle(iconStyle: destIconStyle, level: 0)])
      manager.addPoiStyle(destPoiStyle)

      let originOption = PoiOptions(styleID: "originStyle")
      originOption.rank = 1
      originOption.clickable = false
      let originPosition = MapPoint(longitude: pendingOriginLongitude, latitude: pendingOriginLatitude)
      if let poi = layer.addPoi(option: originOption, at: originPosition) {
        poi.show()
      }

      let destOption = PoiOptions(styleID: "destStyle")
      destOption.rank = 1
      destOption.clickable = false
      let destPosition = MapPoint(longitude: pendingDestinationLongitude, latitude: pendingDestinationLatitude)
      if let poi = layer.addPoi(option: destOption, at: destPosition) {
        poi.show()
      }
    }

    private func fitCamera(mapView: KakaoMap) {
      var lats = pendingRoutePoints.compactMap { $0.count >= 2 ? $0[1] : nil }
      var lngs = pendingRoutePoints.compactMap { $0.count >= 2 ? $0[0] : nil }

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
