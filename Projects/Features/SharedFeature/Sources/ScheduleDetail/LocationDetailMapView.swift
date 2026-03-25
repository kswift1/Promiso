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
  @State private var userLocation: Coordinate?
  @State private var userHeading: Double = 0

  // TCA Feature가 아니므로 직접 Dependency 해결
  @State private var locationClient: LocationClient = {
    @Dependency(\.locationClient) var client
    return client
  }()

  public init(
    location: LocationInfoModel,
    onDirectionsTapped: @escaping () -> Void
  ) {
    self.location = location
    self.onDirectionsTapped = onDirectionsTapped
  }

  public var body: some View {
    ZStack(alignment: .bottom) {
      // 전체 화면 지도
      if let latitude = location.latitude,
         let longitude = location.longitude {
        KakaoInteractiveMapView(
          latitude: latitude,
          longitude: longitude,
          zoomLevel: 16,
          trackingMode: $trackingMode,
          userLocation: userLocation,
          userHeading: userHeading,
          onUserGesture: {
            trackingMode = .none
          }
        )
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(edges: .top)
      }

      // 추적 버튼 (우측 상단)
      VStack {
        HStack {
          Spacer()
          trackingButton
            .padding(.trailing, 16)
            .padding(.top, 16)
        }
        Spacer()
      }

      // 하단 정보 카드
      bottomInfoCard
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
    .task(id: trackingMode) {
      guard trackingMode != .none else { return }

      await withTaskGroup(of: Void.self) { group in
        // 위치 스트림
        group.addTask {
          for await coordinate in locationClient.streamLocation() {
            await MainActor.run { userLocation = coordinate }
          }
        }

        // 방향 스트림 (followWithHeading만)
        if trackingMode == .followWithHeading {
          group.addTask {
            for await heading in locationClient.streamHeading() {
              await MainActor.run { userHeading = heading }
            }
          }
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
      // 장소 정보
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

      // 길찾기 버튼
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

/// 상호작용 가능한 카카오 지도 뷰
public struct KakaoInteractiveMapView: UIViewRepresentable {
  public let latitude: Double
  public let longitude: Double
  public let zoomLevel: Int
  @Binding public var trackingMode: MapTrackingMode
  public var userLocation: Coordinate?
  public var userHeading: Double
  public var onUserGesture: (() -> Void)?

  public init(
    latitude: Double,
    longitude: Double,
    zoomLevel: Int = 16,
    trackingMode: Binding<MapTrackingMode> = .constant(.none),
    userLocation: Coordinate? = nil,
    userHeading: Double = 0,
    onUserGesture: (() -> Void)? = nil
  ) {
    self.latitude = latitude
    self.longitude = longitude
    self.zoomLevel = zoomLevel
    self._trackingMode = trackingMode
    self.userLocation = userLocation
    self.userHeading = userHeading
    self.onUserGesture = onUserGesture
  }

  public func makeUIView(context: Context) -> KMViewContainer {
    let container = KMViewContainer()
    container.backgroundColor = .systemGray6
    return container
  }

  public func updateUIView(_ container: KMViewContainer, context: Context) {
    context.coordinator.onUserGesture = onUserGesture

    // 엔진이 이미 존재하면 (준비 중이든 활성화됐든) 재생성 방지
    if context.coordinator.mapController != nil {
      if let mapView = context.coordinator.mapController?.getView("mapview") as? KakaoMap {
        // 추적 모드일 때만 카메라 업데이트 (none이면 사용자 자유 탐색)
        if trackingMode == .follow, let userLoc = userLocation {
          let position = MapPoint(longitude: userLoc.longitude, latitude: userLoc.latitude)
          let cameraUpdate = CameraUpdate.make(target: position, zoomLevel: 16, mapView: mapView)
          mapView.animateCamera(
            cameraUpdate: cameraUpdate,
            options: CameraAnimationOptions(autoElevation: false, consecutive: true, durationInMillis: 200)
          )
        } else if trackingMode == .followWithHeading, let userLoc = userLocation {
          let position = MapPoint(longitude: userLoc.longitude, latitude: userLoc.latitude)
          let cameraUpdate = CameraUpdate.make(
            target: position,
            zoomLevel: 16,
            rotation: -userHeading,
            tilt: 0,
            mapView: mapView
          )
          mapView.animateCamera(
            cameraUpdate: cameraUpdate,
            options: CameraAnimationOptions(autoElevation: false, consecutive: true, durationInMillis: 200)
          )
        }

        context.coordinator.updateMarker(mapView: mapView, latitude: latitude, longitude: longitude)
        context.coordinator.updateUserLocationMarker(mapView: mapView, userLocation: userLocation, trackingMode: trackingMode)
      }
      return
    }

    // 처음 생성 시
    context.coordinator.createEngine(
      container: container,
      latitude: latitude,
      longitude: longitude,
      zoomLevel: zoomLevel
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
    var onUserGesture: (() -> Void)?
    var cameraEventHandler: (any DisposableEventHandler)?

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

    deinit {
      cleanupMapController()
    }

    func cleanupMapController() {
      cameraEventHandler?.dispose()
      cameraEventHandler = nil

      guard let controller = mapController else { return }
      mapController = nil

      controller.delegate = nil
      controller.pauseEngine()
      controller.resetEngine()

      // KMController.dealloc → stopEngine → notification → dispose 재진입 크래시 방지
      // SwiftUI update cycle 밖에서 release 되도록 수명 연장
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

    func updateMarker(mapView: KakaoMap, latitude: Double, longitude: Double) {
      let manager = mapView.getLabelManager()

      if let existingLayer = manager.getLabelLayer(layerID: "markerLayer") {
        existingLayer.clearAllItems()
      }

      addMarker(mapView: mapView, latitude: latitude, longitude: longitude)
    }

    func updateUserLocationMarker(mapView: KakaoMap, userLocation: Coordinate?, trackingMode: MapTrackingMode) {
      let manager = mapView.getLabelManager()

      if trackingMode == .none || userLocation == nil {
        // 추적 모드 아닐 때 마커 제거
        if let layer = manager.getLabelLayer(layerID: "userLocationLayer") {
          layer.clearAllItems()
        }
        return
      }

      guard let userLoc = userLocation else { return }

      let layer: LabelLayer
      if let existingLayer = manager.getLabelLayer(layerID: "userLocationLayer") {
        existingLayer.clearAllItems()
        layer = existingLayer
      } else {
        let layerOption = LabelLayerOptions(
          layerID: "userLocationLayer",
          competitionType: .none,
          competitionUnit: .symbolFirst,
          orderType: .rank,
          zOrder: 10002
        )
        guard let newLayer = manager.addLabelLayer(option: layerOption) else { return }
        layer = newLayer
      }

      // 파란 원 마커 이미지 생성
      let markerImage = makeUserLocationImage()

      let iconStyle = PoiIconStyle(
        symbol: markerImage,
        anchorPoint: CGPoint(x: 0.5, y: 0.5)
      )
      let poiStyle = PoiStyle(
        styleID: "userLocationStyle",
        styles: [PerLevelPoiStyle(iconStyle: iconStyle, level: 0)]
      )
      manager.addPoiStyle(poiStyle)

      let poiOption = PoiOptions(styleID: "userLocationStyle")
      poiOption.rank = 0
      poiOption.clickable = false

      let position = MapPoint(longitude: userLoc.longitude, latitude: userLoc.latitude)
      if let poi = layer.addPoi(option: poiOption, at: position) {
        poi.show()
      }
    }

    private func makeUserLocationImage() -> UIImage {
      let size = CGSize(width: 24, height: 24)
      let renderer = UIGraphicsImageRenderer(size: size)
      return renderer.image { ctx in
        let rect = CGRect(origin: .zero, size: size)
        // 흰색 테두리
        UIColor.white.setFill()
        ctx.cgContext.fillEllipse(in: rect)
        // 파란 원 (inner)
        let inset: CGFloat = 3
        let innerRect = rect.insetBy(dx: inset, dy: inset)
        UIColor(Color.pmindigo.n500).setFill()
        ctx.cgContext.fillEllipse(in: innerRect)
      }
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
      let iconStyle = PoiIconStyle(
        symbol: ResourceKitAsset.mapPinMedium.image,
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

      // 나침반 표시 (SDK 내장)
      mapView.showCompass()
      mapView.setCompassPosition(
        origin: GuiAlignment(vAlign: .top, hAlign: .right),
        position: CGPoint(x: -16, y: 16)
      )

      // 카메라 이동 이벤트 핸들러 등록 (사용자 제스처 감지)
      cameraEventHandler = mapView.addCameraWillMovedEventHandler(target: self) { coordinator in
        return { param in
          if param.by != .notUserAction {
            DispatchQueue.main.async {
              coordinator.onUserGesture?()
            }
          }
        }
      }

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
