import SwiftUI
import KakaoMapsSDK
import ResourceKit
import Clients
import PromisoShared

/// 약속 장소 상세 지도 뷰 (Push Navigation)
public struct LocationDetailMapView: View {
  @Environment(\.dismiss) private var dismiss

  private let location: LocationInfoModel
  private let onDirectionsTapped: () -> Void

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
          zoomLevel: 16
        )
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(edges: .top)
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

  public init(
    latitude: Double,
    longitude: Double,
    zoomLevel: Int = 16
  ) {
    self.latitude = latitude
    self.longitude = longitude
    self.zoomLevel = zoomLevel
  }

  public func makeUIView(context: Context) -> KMViewContainer {
    let container = KMViewContainer()
    container.backgroundColor = .systemGray6
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
      zoomLevel: zoomLevel
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
    private var pendingLatitude: Double?
    private var pendingLongitude: Double?
    private var pendingZoomLevel: Int = 16

    func createEngine(
      container: KMViewContainer,
      latitude: Double,
      longitude: Double,
      zoomLevel: Int
    ) {
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

