import SwiftUI
import KakaoMapsSDK
import ResourceKit
import Clients
import PromisoShared
import ComposableArchitecture

// MARK: - MapTrackingMode

public enum MapTrackingMode: Equatable {
  case none
  case follow
  case followWithHeading
}

/// 일정 장소 상세 지도 뷰 (Push Navigation)
public struct LocationDetailMapView: View {
  @Environment(\.dismiss) private var dismiss

  private let location: LocationInfoModel
  private let onDirectionsTapped: () -> Void

  @State private var trackingMode: MapTrackingMode = .none

  public init(
    location: LocationInfoModel,
    onDirectionsTapped: @escaping () -> Void
  ) {
    self.location = location
    self.onDirectionsTapped = onDirectionsTapped
  }

  public var body: some View {
    ZStack(alignment: .bottom) {
      if let latitude = location.latitude,
         let longitude = location.longitude {
        KakaoInteractiveMapView(
          latitude: latitude,
          longitude: longitude,
          zoomLevel: 16,
          trackingMode: $trackingMode
        )
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(edges: .top)
      }

      VStack(spacing: 12) {
        HStack {
          Spacer()
          trackingButton
        }
        .padding(.horizontal, 16)

        bottomInfoCard
      }
    }
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .topBarLeading) {
        Button {
          dismiss()
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 16, weight: .semibold))
        }
      }
    }
  }

  // MARK: - Tracking Button

  private var trackingButton: some View {
    Button {
      switch trackingMode {
      case .none:
        trackingMode = .follow
      case .follow:
        trackingMode = .followWithHeading
      case .followWithHeading:
        trackingMode = .none
      }
    } label: {
      Image(systemName: trackingModeIcon)
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(Color.pmindigo.n500)
        .frame(width: 44, height: 44)
        .background(.ultraThinMaterial)
        .clipShape(Circle())
        .contentShape(Circle())
    }
  }

  private var trackingModeIcon: String {
    switch trackingMode {
    case .none:
      return "location"
    case .follow:
      return "location.fill"
    case .followWithHeading:
      return "location.north.line.fill"
    }
  }

  // MARK: - Bottom Info Card

  private var bottomInfoCard: some View {
    VStack(spacing: 16) {
      HStack(alignment: .top, spacing: 12) {
        ResourceKitAsset.locationIcon.swiftUIImage
          .renderingMode(.template)
          .resizable()
          .frame(width: 24, height: 24)
          .foregroundStyle(Color.pmindigo.n400)

        VStack(alignment: .leading, spacing: 4) {
          Text(location.name)
            .font(.system(size: 18, weight: .bold))
            .foregroundStyle(.primary)

          if let address = location.address {
            Text(address)
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }
        }

        Spacer()
      }

      Button(action: onDirectionsTapped) {
        HStack(spacing: 8) {
          Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
            .font(.system(size: 16))
          Text(LocalizedStrings.Common.directions)
            .font(.system(size: 16, weight: .semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.pmindigo.n500)
        .clipShape(RoundedRectangle(cornerRadius: 12))
      }
    }
    .padding(20)
    .background(.ultraThinMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 20))
    .padding(.horizontal, 16)
    .padding(.bottom, 16)
  }
}

// MARK: - Interactive Kakao Map View

public struct KakaoInteractiveMapView: UIViewRepresentable {
  public let latitude: Double
  public let longitude: Double
  public let zoomLevel: Int
  @Binding public var trackingMode: MapTrackingMode

  public init(
    latitude: Double,
    longitude: Double,
    zoomLevel: Int = 16,
    trackingMode: Binding<MapTrackingMode> = .constant(.none)
  ) {
    self.latitude = latitude
    self.longitude = longitude
    self.zoomLevel = zoomLevel
    self._trackingMode = trackingMode
  }

  public func makeUIView(context: Context) -> KMViewContainer {
    let container = KMViewContainer()
    container.backgroundColor = .systemGray6
    return container
  }

  public func updateUIView(_ container: KMViewContainer, context: Context) {
    let coordinator = context.coordinator

    if coordinator.trackingMode != trackingMode {
      coordinator.setTrackingMode(trackingMode)
    }

    if coordinator.mapController != nil { return }

    coordinator.createEngine(
      container: container,
      latitude: latitude,
      longitude: longitude,
      zoomLevel: zoomLevel
    )
  }

  public func makeCoordinator() -> Coordinator {
    @Dependency(\.locationClient) var locationClient
    return Coordinator(
      locationClient: locationClient,
      trackingModeBinding: $trackingMode
    )
  }

  public static func dismantleUIView(_ container: KMViewContainer, coordinator: Coordinator) {
    coordinator.cleanup()
  }

  // MARK: - Coordinator

  public class Coordinator: NSObject, MapControllerDelegate {
    var mapController: KMController?
    private(set) var trackingMode: MapTrackingMode = .none

    private let locationClient: LocationClient
    private let trackingModeBinding: Binding<MapTrackingMode>
    private var cameraEventHandler: (any DisposableEventHandler)?
    private var compassTapHandler: (any DisposableEventHandler)?

    // 위치 스트림 (항상 활성 — 마커 표시용)
    private var locationTask: Task<Void, Never>?
    // 방향 스트림 (followWithHeading만)
    private var headingTask: Task<Void, Never>?

    private var userLocationPoi: Poi?
    private var lastUserCoordinate: Coordinate?
    private var lastHeading: Double = 0
    private var isHeadingMode = false

    deinit {
      cleanupMapController()
    }

    func cleanupMapController() {
      cameraEventHandler?.dispose()
      cameraEventHandler = nil
      mapController?.delegate = nil
      mapController?.pauseEngine()
      mapController?.resetEngine()
      mapController = nil
    }

    private var pendingLatitude: Double?
    private var pendingLongitude: Double?
    private var pendingZoomLevel: Int = 16

    init(locationClient: LocationClient, trackingModeBinding: Binding<MapTrackingMode>) {
      self.locationClient = locationClient
      self.trackingModeBinding = trackingModeBinding
    }

    deinit {
      locationTask?.cancel()
      headingTask?.cancel()
      cleanupMapController()
    }

    // MARK: - Tracking Mode

    func setTrackingMode(_ mode: MapTrackingMode) {
      let prevMode = trackingMode
      trackingMode = mode

      guard let mapView = mapController?.getView("mapview") as? KakaoMap else { return }
      let trackingManager = mapView.getTrackingManager()

      // heading 스트림 정리
      headingTask?.cancel()
      headingTask = nil

      switch mode {
      case .none:
        trackingManager.stopTracking()
        isHeadingMode = false
        mapView.hideCompass()
        if prevMode == .followWithHeading {
          swapUserLocationIcon(mapView: mapView, withHeading: false)
        }

      case .follow:
        isHeadingMode = false
        mapView.hideCompass()
        if prevMode == .followWithHeading {
          swapUserLocationIcon(mapView: mapView, withHeading: false)
        }
        guard let poi = userLocationPoi else { return }
        trackingManager.isTrackingRoll = false
        trackingManager.startTrackingPoi(poi)

      case .followWithHeading:
        isHeadingMode = true
        mapView.showCompass()
        // 점 → 부채꼴 마커로 교체
        swapUserLocationIcon(mapView: mapView, withHeading: true)
        // TrackingManager 끔 — 위치+회전 모두 직접 카메라 제어
        trackingManager.stopTracking()
        startHeadingTracking()
        // 현재 위치로 즉시 카메라
        if let coord = lastUserCoordinate {
          updateHeadingCamera(mapView: mapView, coordinate: coord, headingDegrees: lastHeading)
        }
      }
    }

    // MARK: - Location Stream (항상 활성)

    func startAlwaysOnLocationTracking() {
      locationTask = Task { [weak self] in
        guard let self else { return }
        for await coordinate in self.locationClient.streamLocation() {
          guard !Task.isCancelled else { return }
          await MainActor.run {
            self.lastUserCoordinate = coordinate
            self.userLocationPoi?.position = MapPoint(
              longitude: coordinate.longitude,
              latitude: coordinate.latitude
            )
            // heading 모드: 위치 이동도 직접 카메라 제어
            if self.isHeadingMode,
               let mapView = self.mapController?.getView("mapview") as? KakaoMap {
              self.updateHeadingCamera(mapView: mapView, coordinate: coordinate, headingDegrees: self.lastHeading)
            }
          }
        }
      }
    }

    // MARK: - Heading Stream (followWithHeading만)

    private func startHeadingTracking() {
      headingTask = Task { [weak self] in
        guard let self else { return }
        for await heading in self.locationClient.streamHeading() {
          guard !Task.isCancelled else { return }
          let diff = abs(heading - self.lastHeading)
          let normalizedDiff = min(diff, 360 - diff)
          guard normalizedDiff > 1 else { continue }
          await MainActor.run {
            self.lastHeading = heading
            // POI 부채꼴 회전 (radian)
            self.userLocationPoi?.rotateAt(heading * .pi / 180.0, duration: 200)
            // 카메라 회전 (moveCamera = 즉시, 애니메이션 큐잉 없음)
            if let mapView = self.mapController?.getView("mapview") as? KakaoMap,
               let coord = self.lastUserCoordinate {
              self.updateHeadingCamera(mapView: mapView, coordinate: coord, headingDegrees: heading)
            }
          }
        }
      }
    }

    /// heading 모드 카메라 업데이트 (즉시 이동, 애니메이션 없음)
    private func updateHeadingCamera(mapView: KakaoMap, coordinate: Coordinate, headingDegrees: Double) {
      let position = MapPoint(longitude: coordinate.longitude, latitude: coordinate.latitude)
      let cameraUpdate = CameraUpdate.make(
        target: position,
        zoomLevel: Int(mapView.zoomLevel),
        rotation: -(headingDegrees * .pi / 180.0),
        tilt: mapView.tiltAngle,
        mapView: mapView
      )
      mapView.moveCamera(cameraUpdate)
    }

    // MARK: - User Location POI

    private func ensureUserLocationPoi(mapView: KakaoMap) {
      guard userLocationPoi == nil else { return }

      let manager = mapView.getLabelManager()
      let layerOption = LabelLayerOptions(
        layerID: "userLocationLayer",
        competitionType: .none,
        competitionUnit: .symbolFirst,
        orderType: .rank,
        zOrder: 10002
      )
      let layer: LabelLayer
      if let existing = manager.getLabelLayer(layerID: "userLocationLayer") {
        layer = existing
      } else {
        guard let newLayer = manager.addLabelLayer(option: layerOption) else { return }
        layer = newLayer
      }

      let markerImage = makeUserLocationImage()
      let iconStyle = PoiIconStyle(symbol: markerImage, anchorPoint: CGPoint(x: 0.5, y: 0.5))
      let poiStyle = PoiStyle(
        styleID: "userLocationStyle",
        styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)]
      )
      manager.addPoiStyle(poiStyle)

      let poiOption = PoiOptions(styleID: "userLocationStyle")
      poiOption.rank = 0
      poiOption.clickable = false

      let center = mapView.getPosition(CGPoint(x: mapView.viewRect.midX, y: mapView.viewRect.midY))
      if let poi = layer.addPoi(option: poiOption, at: center) {
        poi.show()
        userLocationPoi = poi
      }
    }

    private func swapUserLocationIcon(mapView: KakaoMap, withHeading: Bool) {
      guard let existing = userLocationPoi else { return }
      let position = existing.position
      let manager = mapView.getLabelManager()

      guard let layer = manager.getLabelLayer(layerID: "userLocationLayer") else { return }
      layer.clearAllItems()
      userLocationPoi = nil

      let styleID = withHeading ? "userLocationHeadingStyle" : "userLocationStyle"
      let markerImage = withHeading ? makeUserLocationHeadingImage() : makeUserLocationImage()

      let iconStyle = PoiIconStyle(symbol: markerImage, anchorPoint: CGPoint(x: 0.5, y: 0.5))
      let poiStyle = PoiStyle(styleID: styleID, styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)])
      manager.addPoiStyle(poiStyle)

      let poiOption = PoiOptions(styleID: styleID)
      poiOption.rank = 0
      poiOption.clickable = false

      if let poi = layer.addPoi(option: poiOption, at: position) {
        poi.show()
        userLocationPoi = poi
      }
    }

    private func makeUserLocationImage() -> UIImage {
      let size = CGSize(width: 14, height: 14)
      let renderer = UIGraphicsImageRenderer(size: size)
      return renderer.image { ctx in
        let rect = CGRect(origin: .zero, size: size)
        UIColor.white.setFill()
        ctx.cgContext.fillEllipse(in: rect)
        let innerRect = rect.insetBy(dx: 2, dy: 2)
        UIColor(Color.pmindigo.n500).setFill()
        ctx.cgContext.fillEllipse(in: innerRect)
      }
    }

    private func makeUserLocationHeadingImage() -> UIImage {
      let size = CGSize(width: 52, height: 52)
      let renderer = UIGraphicsImageRenderer(size: size)
      return renderer.image { ctx in
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let coneRadius: CGFloat = 24
        let coneAngle: CGFloat = .pi / 4

        let path = UIBezierPath()
        path.move(to: center)
        path.addArc(
          withCenter: center,
          radius: coneRadius,
          startAngle: -.pi / 2 - coneAngle / 2,
          endAngle: -.pi / 2 + coneAngle / 2,
          clockwise: true
        )
        path.close()
        UIColor(Color.pmindigo.n500).withAlphaComponent(0.2).setFill()
        path.fill()

        let dotSize: CGFloat = 14
        let dotRect = CGRect(
          x: center.x - dotSize / 2,
          y: center.y - dotSize / 2,
          width: dotSize,
          height: dotSize
        )
        UIColor.white.setFill()
        ctx.cgContext.fillEllipse(in: dotRect)

        let innerRect = dotRect.insetBy(dx: 2, dy: 2)
        UIColor(Color.pmindigo.n500).setFill()
        ctx.cgContext.fillEllipse(in: innerRect)
      }
    }

    // MARK: - Engine Lifecycle

    func cleanup() {
      locationTask?.cancel()
      locationTask = nil
      headingTask?.cancel()
      headingTask = nil
      cleanupMapController()
    }

    private func cleanupMapController() {
      cameraEventHandler?.dispose()
      cameraEventHandler = nil
      compassTapHandler?.dispose()
      compassTapHandler = nil
      userLocationPoi = nil

      guard let controller = mapController else { return }
      mapController = nil

      controller.delegate = nil
      controller.pauseEngine()
      controller.resetEngine()

      DispatchQueue.main.async { _ = controller }
    }

    func createEngine(
      container: KMViewContainer,
      latitude: Double,
      longitude: Double,
      zoomLevel: Int
    ) {
      guard mapController == nil else { return }

      pendingLatitude = latitude
      pendingLongitude = longitude
      pendingZoomLevel = zoomLevel

      mapController = KMController(viewContainer: container)
      mapController?.proMotionSupport = true
      mapController?.delegate = self
      mapController?.prepareEngine()
    }

    // MARK: - Destination Marker

    private func addDestinationMarker(mapView: KakaoMap, latitude: Double, longitude: Double) {
      let manager = mapView.getLabelManager()

      let layerOption = LabelLayerOptions(
        layerID: "markerLayer",
        competitionType: .none,
        competitionUnit: .symbolFirst,
        orderType: .rank,
        zOrder: 10001
      )
      guard let layer = manager.getLabelLayer(layerID: "markerLayer")
              ?? manager.addLabelLayer(option: layerOption) else { return }

      let iconStyle = PoiIconStyle(
        symbol: ResourceKitAsset.mapPinMedium.image,
        anchorPoint: CGPoint(x: 0.5, y: 1.0)
      )
      let poiStyle = PoiStyle(styleID: "markerStyle", styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)])
      manager.addPoiStyle(poiStyle)

      let poiOption = PoiOptions(styleID: "markerStyle")
      poiOption.rank = 0
      poiOption.clickable = false

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

      // SDK 내장 나침반 (위치만 설정, 나침반 모드에서만 표시)
      mapView.setCompassPosition(
        origin: GuiAlignment(vAlign: .top, hAlign: .right),
        position: CGPoint(x: 16, y: 60)
      )
      mapView.hideCompass()

      // 나침반 탭 → 정북 복귀 + 추적 해제
      compassTapHandler = mapView.addCompassTappedEventHandler(target: self) { coordinator in
        return { _ in
          guard let mapView = coordinator.mapController?.getView("mapview") as? KakaoMap else { return }
          DispatchQueue.main.async {
            coordinator.setTrackingMode(.none)
            coordinator.trackingModeBinding.wrappedValue = .none
          }
          let current = mapView.getPosition(CGPoint(x: mapView.viewRect.midX, y: mapView.viewRect.midY))
          let cameraUpdate = CameraUpdate.make(
            target: current,
            zoomLevel: Int(mapView.zoomLevel),
            rotation: 0,
            tilt: mapView.tiltAngle,
            mapView: mapView
          )
          mapView.animateCamera(
            cameraUpdate: cameraUpdate,
            options: CameraAnimationOptions(autoElevation: false, consecutive: true, durationInMillis: 300)
          )
        }
      }

      // 팬(드래그)만 추적 해제
      cameraEventHandler = mapView.addCameraWillMovedEventHandler(target: self) { coordinator in
        return { param in
          if param.by == .pan || param.by == .longTapAndDrag {
            DispatchQueue.main.async {
              coordinator.setTrackingMode(.none)
              coordinator.trackingModeBinding.wrappedValue = .none
            }
          }
        }
      }

      // 목적지 마커
      addDestinationMarker(mapView: mapView, latitude: latitude, longitude: longitude)

      // 사용자 위치 마커 (항상 표시) + 위치 스트림 시작
      ensureUserLocationPoi(mapView: mapView)
      startAlwaysOnLocationTracking()
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
