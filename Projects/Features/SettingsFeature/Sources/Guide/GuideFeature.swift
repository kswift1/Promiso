import ComposableArchitecture
import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Guide

public enum Guide {}

extension Guide {
  @Reducer
  public struct Feature {
    @ObservableState
    public struct State: Equatable {
      public var isShowingGuide: GuideTab? = nil

      public init() {}
    }

    public enum Action {
      case view(ViewAction)
      case `internal`(InternalAction)
      case delegate(DelegateAction)
    }

    @CasePathable
    public enum ViewAction: Sendable {
      case onAppear
      case guideTapped(GuideTab)
      case dismissGuide
    }

    @CasePathable
    public enum InternalAction: Sendable {}

    public enum DelegateAction: Equatable {}

    @Dependency(\.userDefaultsClient) var userDefaultsClient

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.onAppear):
          return .none

        case let .view(.guideTapped(tab)):
          state.isShowingGuide = tab
          return .none

        case .view(.dismissGuide):
          state.isShowingGuide = nil
          return .none

        case .delegate:
          return .none
        }
      }
    }
  }
}

// MARK: - GuideTab

public enum GuideTab: String, CaseIterable, Identifiable, Equatable, Sendable {
  case home
  case schedule
  case calendar
  case settings

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .home: LocalizedStrings.TabBar.home
    case .schedule: LocalizedStrings.TabBar.schedule
    case .calendar: LocalizedStrings.TabBar.calendar
    case .settings: LocalizedStrings.TabBar.settings
    }
  }

  public var icon: String {
    switch self {
    case .home: "house.fill"
    case .schedule: "list.bullet.rectangle.fill"
    case .calendar: "calendar"
    case .settings: "gearshape.fill"
    }
  }

  public var isAvailable: Bool {
    switch self {
    case .calendar: true
    case .home, .schedule, .settings: false  // 준비 중
    }
  }
}
