// MARK: - RootTabFeature.swift
// TCA 1.22.2를 사용한 RootTab Feature의 Implementation layer

import ComposableArchitecture
import SwiftUI
import UIKit

import PromisoShared
import CalendarFeature
import ProfileFeature
import ResourceKit
import SharedFeature

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

      /// LivePromise State (약속 추적 바) - nil이면 숨김
      var livePromise: LivePromise.Feature.State?

      /// LivePromise 상세 뷰 Presentation
      @Presents var livePromiseDetail: LivePromise.Detail.State?

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
        self.groupMain = GroupMain.Feature.State(currentUser: currentUser)
        self.home = Home.Feature.State(currentUser: currentUser)
        self.calendar = CalendarFeature.Feature.State(currentUser: currentUser)
        self.profile = Profile.Feature.State(currentUser: currentUser)
        
        // TODO: 테스트 완료 후 mock 데이터 제거
        self.livePromise = LivePromise.Feature.State(
          emoji: "🎂",
          title: "일이삼사오육칠팔구십십일십이",
          location: "강남역 11번 출구 강남역 11번 출구 강남역 11번 출구 강남역 11번 출구",
          scheduledTime: Date().addingTimeInterval(3600),
          participants: [
            ParticipantState(id: currentUser.id, name: "나", estimatedArrivalMinutes: 5),
            ParticipantState(id: "user2", name: "친구1", estimatedArrivalMinutes: 0),
            ParticipantState(id: "user3", name: "친구2", estimatedArrivalMinutes: 10)
          ],
          currentUserId: currentUser.id
        )
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
      /// LivePromise 액션
      case livePromise(LivePromise.Feature.Action)
      /// LivePromise 상세 뷰 액션
      case livePromiseDetail(PresentationAction<LivePromise.Detail.Action>)
      /// 상위로 전달되는 델리게이트 액션
      case delegate(Delegate)
      /// 딥링크로 그룹 참여 열기
      case openJoinGroupWithCode(String)
      /// 그룹 탭 딥링크 처리
      case handleGroupDeeplink(GroupMain.Deeplink)
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

        case .livePromise(.delegate(.showDetail)):
          // CompactView 탭 → 상세 뷰 표시 (같은 @Shared 전달)
          guard let livePromise = state.livePromise else { return .none }
          state.livePromiseDetail = LivePromise.Detail.State(data: livePromise.$data)
          return .none

        case .livePromise:
          return .none

        case .livePromiseDetail:
          return .none

        case .openJoinGroupWithCode(let inviteCode):
          state.selectedTab = .group
          return .send(.groupMain(.view(.joinGroupWithCode(inviteCode))))

        case .handleGroupDeeplink(let deeplink):
          state.selectedTab = .group
          return .send(.groupMain(.view(.handleDeeplink(deeplink))))

        case .delegate:
          return .none
        }
      }
      .ifLet(\.livePromise, action: \.livePromise) {
        LivePromise.Feature()
      }
      .ifLet(\.$livePromiseDetail, action: \.livePromiseDetail) {
        LivePromise.Detail()
      }
    }
  }
}

// MARK: - View

extension RootTab {
  public struct RootView: View {
    @Bindable var store: StoreOf<RootTab.Feature>
    @Namespace private var animation
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Presentation State
    // ⚠️ @State + TCA 병행 사용 이유:
    // matchedTransitionSource + navigationTransition(.zoom) 조합이 동작하려면
    // @State를 직접 토글해야 합니다. TCA의 Binding(get:set:)이나 onChange 동기화로는
    // SwiftUI transition 타이밍이 맞지 않아 zoom 애니메이션이 동작하지 않습니다.
    // 따라서 @State는 presentation 제어용, TCA는 상태/로직 관리용으로 분리합니다.
    @State private var expandLivePromise: Bool = false

    // MARK: - Constants

    private let livePromiseTransitionID = "LIVE_PROMISE_TRANSITION"
    private let tabBarHeight: CGFloat = 49
    private let compactViewBottomSpacing: CGFloat = 8
    private let compactViewCornerRadius: CGFloat = 15
    private let compactViewPadding: CGFloat = 15
    private let compactViewVerticalPadding: CGFloat = 8

    public init(store: StoreOf<RootTab.Feature>) {
      self.store = store
    }

    public var body: some View {
      tabViewWithLivePromise
        .tint(Color.pmbrand.primary)
        .onAppear { store.send(.onAppear) }
        .fullScreenCover(isPresented: $expandLivePromise) {
          expandedLivePromiseView
        }
    }

    // MARK: - Colors

    private var cardBackgroundColor: Color {
      Color(UIColor.secondarySystemBackground)
    }

    private var backgroundColor: Color {
      Color(UIColor.systemBackground)
    }

    // MARK: - Expanded LivePromise View

    @ViewBuilder
    private var expandedLivePromiseView: some View {
      detailTabContent
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
        .safeAreaInset(edge: .top, spacing: 0) {
          VStack(spacing: 0) {
            // Drag Indicator
            Capsule()
              .fill(.primary.secondary)
              .frame(width: 35, height: 3)
              .padding(.vertical, 10)

            // Close Button Row
            HStack {
              Spacer()
              Button {
                expandLivePromise = false  // transition용 직접 토글
                store.send(.livePromiseDetail(.dismiss))  // TCA 상태 정리
              } label: {
                Image(systemName: "xmark.circle.fill")
                  .font(.title2)
                  .foregroundStyle(.secondary)
                  .symbolRenderingMode(.hierarchical)
              }
            }
            .padding(.horizontal, 16)

            // Header Content
            if let data = store.livePromise?.data {
              livePromiseHeader(data: data)
                .padding(.top, 8)
                .padding(.horizontal, 16)

              // Action Buttons
              actionButtons
                .padding(.top, 16)
                .padding(.horizontal, 16)

              // Tab Bar
              detailTabBar
                .padding(.top, 20)
                .padding(.bottom, 8)
            }
          }
          .background(backgroundColor)
          .navigationTransition(.zoom(sourceID: livePromiseTransitionID, in: animation))
        }
        .presentationBackground(.ultraThinMaterial)
    }

    // MARK: - Header

    @ViewBuilder
    private func livePromiseHeader(data: LivePromise.Data) -> some View {
      HStack(spacing: 12) {
        // Emoji
        Text(data.emoji)
          .font(.system(size: 44))

        // Info
        VStack(alignment: .leading, spacing: 4) {
          Text(data.title)
            .font(.title3.weight(.bold))

          HStack(spacing: 6) {
            if let location = data.location {
              Text("📍")
                .font(.caption)
              Text(location)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Text("•")
              .font(.caption)
              .foregroundStyle(.tertiary)
            Text("\(data.participants.count)명 참여")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
        }

        Spacer(minLength: 0)

        // Time
        if let time = data.scheduledTime {
          VStack(alignment: .trailing, spacing: 0) {
            Text(formatTime(time))
              .font(.title2.weight(.bold).monospacedDigit())
            Text(formatPeriod(time))
              .font(.caption.weight(.medium))
              .foregroundStyle(.secondary)
          }
        }
      }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
      HStack(spacing: 12) {
        actionButton(icon: "doc.on.doc", title: "복사") {
          store.send(.livePromiseDetail(.presented(.copyButtonTapped)))
        }
        actionButton(icon: "bell", title: "알림") {
          store.send(.livePromiseDetail(.presented(.notificationButtonTapped)))
        }
        actionButton(icon: "ellipsis", title: "더보기") {
          store.send(.livePromiseDetail(.presented(.moreButtonTapped)))
        }
      }
    }

    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
      Button(action: action) {
        HStack(spacing: 6) {
          Image(systemName: icon)
            .font(.subheadline)
          Text(title)
            .font(.subheadline)
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 10))
      }
    }

    // MARK: - Detail Tab Bar

    private var detailTabBar: some View {
      HStack(spacing: 0) {
        ForEach(LivePromise.DetailTab.allCases, id: \.self) { tab in
          detailTabButton(tab)
        }
      }
      .padding(4)
      .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 12))
      .padding(.horizontal, 16)
    }

    private func detailTabButton(_ tab: LivePromise.DetailTab) -> some View {
      let isSelected = store.livePromiseDetail?.selectedTab == tab

      return Button {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        store.send(.livePromiseDetail(.presented(.tabSelected(tab))))
      } label: {
        Text(tab.rawValue)
          .font(.subheadline.weight(isSelected ? .semibold : .regular))
          .foregroundStyle(isSelected ? .white : .secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 10)
          .background(
            isSelected ? Color.pmindigo.n500 : Color.clear,
            in: RoundedRectangle(cornerRadius: 8)
          )
      }
      .buttonStyle(.plain)
    }

    // MARK: - Detail Tab Content

    @ViewBuilder
    private var detailTabContent: some View {
      switch store.livePromiseDetail?.selectedTab ?? .status {
      case .status:
        statusTabContent
      case .map:
        mapTabContent
      case .chat:
        chatTabContent
      }
    }

    // MARK: - Status Tab

    private var statusTabContent: some View {
      ScrollView {
        if let data = store.livePromise?.data {
          VStack(spacing: 20) {
            // Racing Track (Horizontal Scroll)
            racingTrackSection(data: data)

            // Participants List
            participantsListSection(data: data)

            // ETA Buttons
            etaButtonsSection
          }
          .padding(.top, 16)
          .padding(.bottom, 32)
        }
      }
    }

    private func racingTrackSection(data: LivePromise.Data) -> some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("이동 현황")
          .font(.headline)
          .foregroundStyle(.primary)
          .padding(.horizontal, 16)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 16) {
            ForEach(data.participants) { participant in
              participantTrackItem(participant, data: data)
            }
          }
          .padding(.horizontal, 16)
        }
      }
    }

    private func participantTrackItem(_ participant: ParticipantState, data: LivePromise.Data) -> some View {
      let isArrived = participant.estimatedArrivalMinutes == 0
      let isCurrentUser = participant.id == data.currentUserId

      return VStack(spacing: 8) {
        // Avatar with status ring
        ZStack {
          Circle()
            .stroke(statusColor(for: participant), lineWidth: 3)
            .frame(width: 56, height: 56)

          Circle()
            .fill(
              LinearGradient(
                colors: isCurrentUser
                  ? [Color.pmindigo.n400, Color.pmindigo.n600]
                  : [Color.pmgray.n400, Color.pmgray.n500],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
            .frame(width: 48, height: 48)
            .overlay {
              Text(String(participant.name.prefix(1)))
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            }

          // Checkmark for arrived
          if isArrived {
            Circle()
              .fill(Color.green)
              .frame(width: 20, height: 20)
              .overlay {
                Image(systemName: "checkmark")
                  .font(.caption2.weight(.bold))
                  .foregroundStyle(.white)
              }
              .offset(x: 18, y: 18)
          }
        }

        // Name
        Text(isCurrentUser ? "나" : participant.name)
          .font(.caption)
          .foregroundStyle(.primary)
          .lineLimit(1)
      }
    }

    private func participantsListSection(data: LivePromise.Data) -> some View {
      VStack(spacing: 0) {
        ForEach(data.participants) { participant in
          participantRow(participant, data: data)

          if participant.id != data.participants.last?.id {
            Divider()
              .padding(.horizontal, 16)
          }
        }
      }
      .background(cardBackgroundColor, in: RoundedRectangle(cornerRadius: 16))
      .padding(.horizontal, 16)
    }

    private func participantRow(_ participant: ParticipantState, data: LivePromise.Data) -> some View {
      let isCurrentUser = participant.id == data.currentUserId

      return HStack(spacing: 12) {
        // Avatar
        Circle()
          .fill(
            LinearGradient(
              colors: isCurrentUser
                ? [Color.pmindigo.n400, Color.pmindigo.n600]
                : [Color.pmgray.n400, Color.pmgray.n500],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 40, height: 40)
          .overlay {
            Text(String(participant.name.prefix(1)))
              .font(.body.weight(.semibold))
              .foregroundStyle(.white)
          }

        // Name + Status
        VStack(alignment: .leading, spacing: 2) {
          Text(isCurrentUser ? "나" : participant.name)
            .font(.body.weight(.medium))
            .foregroundStyle(.primary)

          Text(statusDescription(for: participant))
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        // ETA Badge
        etaBadge(for: participant)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }

    private func etaBadge(for participant: ParticipantState) -> some View {
      Group {
        if let eta = participant.estimatedArrivalMinutes {
          if eta == 0 {
            HStack(spacing: 4) {
              Image(systemName: "checkmark")
                .font(.caption.weight(.bold))
              Text("도착")
                .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.green)
          } else {
            Text("\(eta)분")
              .font(.title3.weight(.bold))
              .foregroundStyle(etaColor(for: eta))
          }
        } else {
          Text("대기")
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
      }
    }

    private var etaButtonsSection: some View {
      VStack(spacing: 12) {
        Text("내 상태 변경")
          .font(.caption)
          .foregroundStyle(.secondary)

        HStack(spacing: 12) {
          etaButton(icon: "checkmark.circle.fill", title: "도착", minutes: 0, color: .green)
          etaButton(icon: "clock", title: "+5분", minutes: 5, color: .orange)
          etaButton(icon: "clock", title: "+10분", minutes: 10, color: .red)
        }
        .padding(.horizontal, 16)
      }
    }

    private func etaButton(icon: String, title: String, minutes: Int, color: Color) -> some View {
      let currentETA = store.livePromise?.data.currentUserETA
      let isSelected = currentETA == minutes

      return Button {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        store.send(.livePromiseDetail(.presented(.etaButtonTapped(minutes))))
      } label: {
        VStack(spacing: 8) {
          Image(systemName: icon)
            .font(.title2)
            .foregroundStyle(isSelected ? .white : color)

          Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(isSelected ? .white : .primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
          isSelected ? color : cardBackgroundColor,
          in: RoundedRectangle(cornerRadius: 16)
        )
      }
    }

    // MARK: - Map Tab

    private var mapTabContent: some View {
      VStack {
        Spacer()
        Text("지도 기능 준비 중")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
      }
    }

    // MARK: - Chat Tab

    private var chatTabContent: some View {
      VStack {
        Spacer()
        Text("채팅 기능 준비 중")
          .font(.headline)
          .foregroundStyle(.secondary)
        Spacer()
      }
    }

    // MARK: - Helper Functions

    private func formatTime(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "h:mm"
      return formatter.string(from: date)
    }

    private func formatPeriod(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "a"
      formatter.locale = Locale(identifier: "en_US")
      return formatter.string(from: date)
    }

    private func statusColor(for participant: ParticipantState) -> Color {
      if let eta = participant.estimatedArrivalMinutes {
        if eta == 0 { return .green }
        if eta <= 5 { return .yellow }
        return .orange
      }
      return .gray
    }

    private func statusDescription(for participant: ParticipantState) -> String {
      if let eta = participant.estimatedArrivalMinutes {
        if eta == 0 { return "도착 완료" }
        if eta <= 3 { return "거의 도착" }
        return "이동 중"
      }
      return "아직 출발 전"
    }

    private func etaColor(for eta: Int) -> Color {
      if eta <= 3 { return .green }
      if eta <= 5 { return .yellow }
      if eta <= 10 { return .orange }
      return .red
    }

    // MARK: - TabView

    private var tabView: some View {
      TabView(selection: $store.selectedTab.sending(\.tabSelected)) {
        ForEach(Tab.allCases, id: \.self) { tab in
          tabContentView(for: tab)
            .tabItem { Label(tab.rawValue, systemImage: tab.iconName) }
            .tag(tab)
        }
      }
    }

    // MARK: - TabView with LivePromise

    @ViewBuilder
    private var tabViewWithLivePromise: some View {
      if #available(iOS 26.1, *) {
        tabViewWithBottomAccessoryNew
      } else if #available(iOS 26.0, *) {
        tabViewWithBottomAccessoryLegacy
      } else {
        tabViewWithOverlay
      }
    }

    @available(iOS 26.1, *)
    @ViewBuilder
    private var tabViewWithBottomAccessoryNew: some View {
      tabView
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: store.livePromise != nil) {
          if let livePromiseStore = store.scope(state: \.livePromise, action: \.livePromise) {
            LivePromise.CompactView(store: livePromiseStore)
              .matchedTransitionSource(id: livePromiseTransitionID, in: animation)
              .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.send(.livePromise(.view(.tapped)))  // TCA 상태 생성
                expandLivePromise = true  // transition용 직접 토글
              }
          }
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private var tabViewWithBottomAccessoryLegacy: some View {
      if let livePromiseStore = store.scope(state: \.livePromise, action: \.livePromise) {
        tabView
          .tabBarMinimizeBehavior(.onScrollDown)
          .tabViewBottomAccessory {
            LivePromise.CompactView(store: livePromiseStore)
              .matchedTransitionSource(id: livePromiseTransitionID, in: animation)
              .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.send(.livePromise(.view(.tapped)))
                expandLivePromise = true
              }
          }
      } else {
        tabView
      }
    }

    private var tabViewWithOverlay: some View {
      tabView
        .overlay(alignment: .bottom) {
          if let livePromiseStore = store.scope(state: \.livePromise, action: \.livePromise) {
            LivePromise.CompactView(store: livePromiseStore)
              .padding(.vertical, compactViewVerticalPadding)
              .background(.ultraThinMaterial, in: .rect(cornerRadius: compactViewCornerRadius))
              .matchedTransitionSource(id: livePromiseTransitionID, in: animation)
              .onTapGesture {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                store.send(.livePromise(.view(.tapped)))
                expandLivePromise = true
              }
              .offset(y: -(tabBarHeight + compactViewBottomSpacing))
              .padding(.horizontal, compactViewPadding)
          }
        }
        .ignoresSafeArea(.keyboard, edges: .all)
    }

    // MARK: - Tab Content

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


