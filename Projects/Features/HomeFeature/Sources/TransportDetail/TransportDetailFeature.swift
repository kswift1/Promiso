import Clients
import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - TransportDetail Namespace

public enum TransportDetail {}

// MARK: - Feature Implementation

extension TransportDetail {

  @Reducer
  public struct Feature {

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      public let scheduleTitle: String
      public let scheduleEmoji: String
      public let scheduleStartAt: Date
      public let transportData: HomeModels.DepartureTransportData
      public var selectedSegment: HomeModels.TransportType = .transit
      public var selectedTransitIndex: Int = 0
      /// 출발 여유시간 (분, 0/10/20/30)
      public var bufferMinutes: Int = 10

      // 출발지/도착지 정보
      public let originCoordinate: Coordinate?  // 출발지 좌표 (nil이면 현재위치)
      public let originName: String?            // 출발지 이름
      public let destinationCoordinate: Coordinate  // 도착지 좌표
      public let destinationName: String        // 도착지 이름

      /// 지도 앱 선택 시트 표시 여부
      public var isMapAppSheetPresented: Bool = false
      /// 설치된 지도 앱 목록
      public var availableMapApps: [MapApp] = []

      public init(
        scheduleTitle: String,
        scheduleEmoji: String,
        scheduleStartAt: Date,
        transportData: HomeModels.DepartureTransportData,
        originCoordinate: Coordinate?,
        originName: String?,
        destinationCoordinate: Coordinate,
        destinationName: String
      ) {
        self.scheduleTitle = scheduleTitle
        self.scheduleEmoji = scheduleEmoji
        self.scheduleStartAt = scheduleStartAt
        self.transportData = transportData
        self.originCoordinate = originCoordinate
        self.originName = originName
        self.destinationCoordinate = destinationCoordinate
        self.destinationName = destinationName
      }


      /// 현재 선택된 TransportSelection
      public var currentSelection: HomeModels.TransportSelection {
        switch selectedSegment {
        case .driving: return .driving
        case .transit: return .transit(index: selectedTransitIndex)
        case .walking: return .walking
        }
      }

      /// 현재 선택된 대중교통 경로 (transit 탭일 때)
      public var selectedTransitRoute: HomeModels.TransitRouteOption? {
        guard selectedSegment == .transit else { return nil }
        return transportData.transitRoutes.first { $0.id == selectedTransitIndex }
      }
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Equatable {
      case view(View)
      case `internal`(InternalAction)
      case delegate(Delegate)

      @CasePathable
      public enum View: Equatable {
        case segmentChanged(HomeModels.TransportType)
        case transitRouteChanged(Int)
        case bufferChanged(Int)
        case alertButtonTapped
        case openMapTapped           // "지도에서 경로보기" 버튼 탭
        case mapAppSelected(MapApp)  // 지도 앱 선택
        case mapAppSheetDismissed    // 시트 닫기
        case onAppear                // 설치된 앱 목록 조회
      }

      @CasePathable
      public enum InternalAction: Equatable {
        case openMapInApp(MapApp)
      }

      @CasePathable
      public enum Delegate: Equatable {
        case alertRequested(HomeModels.TransportSelection, Int)
      }
    }

    // MARK: - Dependencies

    @Dependency(\.mapClient) var mapClient

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .segmentChanged(let segment):
            state.selectedSegment = segment
            return .none

          case .transitRouteChanged(let index):
            state.selectedTransitIndex = index
            return .none

          case .bufferChanged(let minutes):
            state.bufferMinutes = minutes
            return .none

          case .alertButtonTapped:
            return .send(.delegate(.alertRequested(state.currentSelection, state.bufferMinutes)))

          case .onAppear:
            state.availableMapApps = mapClient.availableMapApps()
            return .none

          case .openMapTapped:
            let apps = state.availableMapApps
            if apps.count == 1 {
              return .send(.internal(.openMapInApp(apps[0])))
            } else if apps.isEmpty {
              // 설치된 앱 없으면 카카오맵 웹으로 폴백
              return .send(.internal(.openMapInApp(.kakao)))
            } else {
              state.isMapAppSheetPresented = true
              return .none
            }

          case .mapAppSelected(let app):
            state.isMapAppSheetPresented = false
            return .send(.internal(.openMapInApp(app)))

          case .mapAppSheetDismissed:
            state.isMapAppSheetPresented = false
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .openMapInApp(let app):
            let transportMode: TransportMode = switch state.selectedSegment {
            case .driving: .car
            case .transit: .transit
            case .walking: .walking
            }
            mapClient.openDirectionsInApp(
              app,
              state.originCoordinate,
              state.destinationCoordinate,
              state.destinationName,
              transportMode
            )
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}
