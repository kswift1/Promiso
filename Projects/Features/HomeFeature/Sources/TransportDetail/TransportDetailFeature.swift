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

      public init(
        scheduleTitle: String,
        scheduleEmoji: String,
        scheduleStartAt: Date,
        transportData: HomeModels.DepartureTransportData
      ) {
        self.scheduleTitle = scheduleTitle
        self.scheduleEmoji = scheduleEmoji
        self.scheduleStartAt = scheduleStartAt
        self.transportData = transportData
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
      }

      @CasePathable
      public enum InternalAction: Equatable {}

      @CasePathable
      public enum Delegate: Equatable {
        case alertRequested(HomeModels.TransportSelection, Int)
      }
    }

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
          }

        case .internal:
          return .none

        case .delegate:
          return .none
        }
      }
    }
  }
}
