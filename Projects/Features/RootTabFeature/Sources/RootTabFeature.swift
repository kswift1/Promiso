// MARK: - RootTabFeature.swift
// TCA 1.22.2를 사용한 RootTab Feature의 Implementation layer

import ComposableArchitecture
import SwiftUI

import PromisoShared
import CalendarFeature
import ProfileFeature
import ResourceKit

public enum Tab: String, CaseIterable {
  case home = "홈"
  case group = "그룹"
  case calendar = "캘린더"
  case profile = "프로필"

  var iconName: String {
    switch self {
    case .home: return "house.fill"
    case .group: return "person.3.fill"
    case .calendar: return "calendar"
    case .profile: return "person.fill"
    }
  }
}

// MARK: - Feature Namespace

/// RootTab Feature 컴포넌트를 위한 Namespace
public enum RootTab {}

// MARK: - Reducer

extension RootTab {
  @Reducer
  public struct Feature {
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    @ObservableState
    public struct State {
      /// 현재 선택된 탭
      var selectedTab: Tab = .home

      /// Home Main State
      var home: Home.Feature.State

      /// Calendar State
      var calendar: CalendarFeature.Feature.State

      /// Group Main State
      var groupMain: GroupMain.Feature.State

      /// Profile State
      var profile: Profile.Feature.State

      /// 현재 사용자 정보 (Profile에 전달)
      var currentUser: UserPrivateModel

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
        self.groupMain = GroupMain.Feature.State(currentUser: currentUser)
        self.home = Home.Feature.State(currentUser: currentUser)
        self.calendar = CalendarFeature.Feature.State(currentUser: currentUser)
        self.profile = Profile.Feature.State(currentUser: currentUser)
      }
    }

    public enum Action {
      /// 앱이 나타날 때 호출
      case onAppear
      /// 탭이 선택되었을 때 호출
      case tabSelected(Tab)
      /// Home Main 액션
      case home(Home.Feature.Action)
      /// Calendar 액션
      case calendar(CalendarFeature.Feature.Action)
      /// Group Main 액션
      case groupMain(GroupMain.Feature.Action)
      /// Profile 액션
      case profile(Profile.Feature.Action)
      /// 상위로 전달되는 델리게이트 액션
      case delegate(Delegate)
      /// 딥링크로 그룹 참여 열기
      case openJoinGroupWithCode(String)
    }

    public enum Delegate: Equatable {
      case logoutRequested
      case openJoinGroup(inviteCode: String)
    }

    public var body: some ReducerOf<Self> {
      Scope(state: \.groupMain, action: \.groupMain) {
        GroupMain.Feature()
      }

      Scope(state: \.home, action: \.home) {
        Home.Feature()
      }

      Scope(state: \.calendar, action: \.calendar) {
        CalendarFeature.Feature()
      }

      Scope(state: \.profile, action: \.profile) {
        Profile.Feature()
      }

      Reduce { state, action in
        switch action {
        case .onAppear:
          return .none

        case .tabSelected(let tab):
          state.selectedTab = tab
          return .run { _ in
            await hapticFeedback.buttonTap()
          }

        case .home(.delegate(.navigateToGroup(let groupId))):
          state.selectedTab = .group
          if let groupInfo = state.groupMain.allGroupSummaries?.first(where: { $0.id == groupId }) {
            return .send(.groupMain(.view(.groupChanged(groupInfo))))
          }
          return .none

        case .home:
          return .none

        case .calendar:
          return .none

        case .groupMain:
          return .none

        case .profile(.delegate(.didLogout)):
          return .send(.delegate(.logoutRequested))

        case .profile:
          return .none

        case .openJoinGroupWithCode(let inviteCode):
          state.selectedTab = .group
          return .send(.groupMain(.view(.joinGroupWithCode(inviteCode))))

        case .delegate:
          return .none
        }
      }
    }
  }
}

// MARK: - View

extension RootTab {
  public struct RootView: View {
    @Bindable var store: StoreOf<RootTab.Feature>

    public init(store: StoreOf<RootTab.Feature>) {
      self.store = store
    }

    public var body: some View {
      TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
        ForEach(Tab.allCases, id: \.self) { tab in
          tabContentView(for: tab)
            .tabItem {
              Label(tab.rawValue, systemImage: tab.iconName)
            }
            .tag(tab)
        }
      }
      .tint(Color.pmbrand.primary)
      .onAppear {
        store.send(.onAppear)
      }
    }

    @ViewBuilder
    private func tabContentView(for tab: Tab) -> some View {
      switch tab {
      case .home:
        NavigationStack {
          Home.RootView(
            store: store.scope(
              state: \.home,
              action: \.home
            )
          )
        }

      case .calendar:
        CalendarFeature.RootView(
          store: store.scope(
            state: \.calendar,
            action: \.calendar
          )
        )

      case .group:
        NavigationStack {
          GroupMain.RootView(
            store: store.scope(
              state: \.groupMain,
              action: \.groupMain
            )
          )
        }

      case .profile:
        Profile.RootView(
          store: store.scope(
            state: \.profile,
            action: \.profile
          )
        )
      }
    }
  }
}
