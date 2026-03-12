import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared
import ResourceKit
import CreateScheduleFeature

extension GroupMain {
  public struct RootView: View {
    @Bindable private var store: StoreOf<GroupMain.Feature>

    public init(store: StoreOf<GroupMain.Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStackStore(
        store.scope(state: \.path, action: \.path)) {
          rootContent
        } destination: { store in
          switch store.case {
          case .groupSettings(let groupSettingsStore):
            GroupSettings.View(store: groupSettingsStore)
          case .groupScheduleList(let groupScheduleListStore):
            GroupScheduleList.View(store: groupScheduleListStore)
          case .scheduleDetail(let scheduleDetailStore):
            ScheduleDetail.RootView(store: scheduleDetailStore)
          case .pastSchedules(let pastSchedulesStore):
            PastSchedules.RootView(store: pastSchedulesStore)
          }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
      Group {
        if store.shouldShowEmptyGroupView {
          groupDetailEmptyView
        } else {
          groupDetailView
        }
      }
      .auroraBackground()
      .toolbarVisibility(.hidden, for: .navigationBar)
      .toast(Binding(
        get: { store.toastMessage },
        set: { _ in store.send(.view(.toastDismissed)) }
      ))
      .analyticsScreen(.groupMain)
      .onAppear { store.send(.view(.onAppear)) }
      .fullScreenCover(
        store: store.scope(state: \.$createSchedule, action: \.createSchedule)
      ) { childStore in
        CreateSchedule.RootView(store: childStore)
      }
      .fullScreenCover(
        store: store.scope(state: \.$createGroup, action: \.createGroup)
      ) { childStore in
        NavigationStack {
          CreateGroup.RootView(store: childStore)
        }
      }
      .sheet(
        store: store.scope(state: \.$joinGroup, action: \.joinGroup)
      ) { childStore in
        NavigationStack {
          JoinGroup.RootView(store: childStore)
        }
      }
      .sheet(item: Binding(
        get: { store.shareSchedule },
        set: { _ in store.send(.view(.dismissScheduleShareSheet)) }
      )) { schedule in
        ScheduleShareSheet(
          schedule: schedule,
          isKakaoSharing: store.isKakaoScheduleSharing,
          onKakaoShareTapped: {
            store.send(.view(.kakaoScheduleShareTapped))
          },
          onSystemShareTapped: {
            store.send(.view(.systemScheduleShareTapped))
          }
        )
        .presentationDetents([.height(340)])
        .presentationDragIndicator(.visible)
      }
      .sheet(item: Binding(
        get: { store.systemShareText.map { ShareTextItem(text: $0) } },
        set: { _ in store.send(.view(.systemShareSheetDismissed)) }
      )) { item in
        ShareSheet(items: [item.text])
      }
      .sheet(
        store: store.scope(state: \.$editSchedule, action: \.editSchedule)
      ) { editStore in
        EditSchedule.RootView(store: editStore)
      }
      .sheet(
        isPresented: Binding(
          get: { store.sortSettings != nil },
          set: { if !$0 { store.send(.sortSettingsDismissed) } }
        )
      ) {
        if let sortSettingsState = store.sortSettings {
          SortSettingsSheetContent(
            initialState: sortSettingsState,
            onOptionChanged: { option in
              store.send(.sortOptionChanged(option))
            },
            onDismiss: {
              store.send(.sortSettingsDismissed)
            }
          )
          .presentationDetents([.height(420)])
          .presentationDragIndicator(.visible)
        }
      }
      .alert(store: store.scope(state: \.$deleteAlert, action: \.deleteAlert))
      .confirmationDialog(
        store: store.scope(state: \.$groupActionSheet, action: \.groupActionSheet)
      )
      .sheet(
        isPresented: Binding(
          get: { store.showGroupInviteSheet },
          set: { if !$0 { store.send(.view(.dismissGroupInviteSheet)) } }
        )
      ) {
        if let group = store.currentGroup {
          InviteSheet(
            groupName: group.name,
            inviteCode: group.inviteCode,
            isKakaoSharing: store.isKakaoInviteSharing,
            onKakaoShareTapped: {
              store.send(.view(.kakaoInviteShareTapped))
            },
            onSystemShareTapped: {
              store.send(.view(.systemInviteShareTapped))
            }
          )
          .presentationDetents([.height(340)])
          .presentationDragIndicator(.visible)
        }
      }
    }


    // MARK: - New Group Detail View (섹션 기반)

    @ViewBuilder
    private var groupDetailView: some View {
      VStack(spacing: 0) {
        // 헤더
        groupHeaderSection
          .padding(.horizontal, 16)
          .padding(.top, 8)

        // 그룹 가로 바 (상단 고정)
        GroupHorizontalBar(
          groups: store.groupBarItems,
          isLoading: store.isGroupsLoading,
          onGroupTap: { groupId in
            store.send(.view(.groupTapped(groupId)))
          },
          onGroupInvite: { groupId in
            store.send(.view(.groupInviteTapped(groupId)))
          },
          onGroupSettings: { groupId in
            store.send(.view(.groupContextSettingsTapped(groupId)))
          },
          onCreateGroup: {
            store.send(.view(.createGroup))
          },
          onJoinGroup: {
            store.send(.view(.joinGroup))
          },
          onSortSettings: {
            store.send(.view(.sortSettingsTapped))
          },
          onCreateSchedule: { groupId in
            store.send(.view(.contextCreateScheduleTapped(groupId)))
          }
        )

        Divider()

        // 필터 세그먼트
        filterSegment
          .padding(.top, 8)

        // 일정 리스트 (스와이프 지원)
        if store.isOnboardingMode {
          ScrollView {
            onboardingCardsView
          }
          .refreshable {
            store.send(.view(.refreshTriggered))
          }
        } else if isLoadingState {
          // .idle 또는 .loading 상태
          ScrollView {
            loadingView
          }
        } else if let error = currentError {
          ScrollView {
            errorView(error: error)
          }
          .refreshable {
            store.send(.view(.refreshTriggered))
          }
        } else if store.filteredSchedules.isEmpty {
          ScrollView {
            emptyFilteredView
          }
          .refreshable {
            store.send(.view(.refreshTriggered))
          }
        } else {
          scheduleListView
        }
      }
      .overlay(alignment: .bottomTrailing) {
        fabButton
      }
    }

    // MARK: - Group Header

    private var defaultMode: ScheduleMode {
      let saved = UserDefaults.standard.string(forKey: AppConstants.UserDefaults.defaultScheduleTabMode) ?? "group"
      return saved == "own" ? .personal : .group
    }

    @ViewBuilder
    private var groupHeaderSection: some View {
      ScheduleTabHeader(
        selectedMode: .group,
        defaultMode: defaultMode
      ) { mode in
        if mode == .personal {
          store.send(.view(.switchToPersonalMode))
        }
      }
    }

    // MARK: - FAB

    @ViewBuilder
    private var fabButton: some View {
      if !store.isOnboardingMode {
        Menu {
          Button {
            store.send(.view(.createNewSchedule))
          } label: {
            Label(LocalizedStrings.GroupMain.createSchedule, systemImage: "calendar.badge.plus")
          }

          Button {
            store.send(.view(.groupSettingsTapped))
          } label: {
            Label(LocalizedStrings.GroupMain.groupSettings, systemImage: "gearshape")
          }
        } label: {
          ZStack {
            Circle()
              .fill(Color.pmindigo.n500)
              .frame(width: 56, height: 56)
              .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)

            Image(systemName: "plus")
              .font(.system(size: 24, weight: .semibold))
              .foregroundStyle(.white)
          }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
      }
    }

    @ViewBuilder
    private var loadingView: some View {
      LazyVStack(spacing: 12) {
        ForEach(0..<3, id: \.self) { _ in
          ScheduleCardSkeleton()
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 48) // 섹션 헤더 높이만큼
    }

    @ViewBuilder
    private func errorView(error: Error) -> some View {
      VStack(spacing: 16) {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 40))
          .foregroundStyle(.secondary)

        Text((error as? GroupClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError)
          .font(.subheadline)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)

        Button(LocalizedStrings.GroupMain.retry) {
          store.send(.view(.refreshTriggered))
        }
        .buttonStyle(.bordered)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 60)
      .padding(.horizontal, 24)
    }


    // MARK: - Onboarding Cards

    @ViewBuilder
    private var onboardingCardsView: some View {
      LazyVStack(spacing: 12) {
        ForEach(GroupMain.OnboardingCard.allCases) { card in
          OnboardingCardView(card: card) {
            handleOnboardingCardTap(card)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 8)
      .padding(.bottom, 100)
    }

    private func handleOnboardingCardTap(_ card: GroupMain.OnboardingCard) {
      switch card {
      case .createGroup:
        store.send(.view(.createGroup))
      case .joinGroup:
        store.send(.view(.joinGroup))
      }
    }

    @ViewBuilder
    private var filterSegment: some View {
      CategoryFilterBar(
        selection: Binding(
          get: { store.selectedFilter },
          set: { store.send(.view(.filterChanged($0))) }
        ),
        counts: store.filterCounts
      )
    }

    @ViewBuilder
    private var scheduleListView: some View {
      let sections = store.groupedFilteredSchedules
      let animationKey = sections.flatMap { section in
        [String(Int(section.day.timeIntervalSince1970))] + section.schedules.map(\.id)
      }

      ScrollViewReader { proxy in
        List {
          ForEach(sections, id: \.day) { section in
            Section {
              ForEach(section.schedules, id: \.id) { schedule in
                scheduleRowView(for: schedule)
                  .id(schedule.id)
              }
            } header: {
              dateSectionHeader(section.title)
            }
            .listSectionSeparator(.hidden)
          }

          // FAB 공간 확보
          Color.clear
            .frame(height: 80)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .refreshable {
          store.send(.view(.refreshTriggered))
        }
        .animation(.snappy, value: animationKey)
        .onChange(of: store.highlightedScheduleId) { _, newValue in
          if let scheduleId = newValue {
            withAnimation(.easeInOut(duration: 0.3)) {
              proxy.scrollTo(scheduleId, anchor: .center)
            }
          }
        }
      }
    }

    @ViewBuilder
    private func dateSectionHeader(_ date: String) -> some View {
      HStack(spacing: 12) {
        Text(date)
          .font(.system(size: 18, weight: .bold))
          .foregroundStyle(.primary)
          .textCase(nil)

        Rectangle()
          .fill(Color.primary.opacity(0.1))
          .frame(height: 1)
      }
      .padding(.top, 8)
      .padding(.bottom, 8)
    }

    @ViewBuilder
    private func scheduleRowView(for schedule: ScheduleModel) -> some View {
      let scheduleId = schedule.id
      let userId = store.currentUser.userId
      let myVoteStatus = schedule.myVoteStatus(userId: userId)

      ScheduleCard(
        schedule: schedule,
        currentUserId: userId,
        groupMembers: store.currentGroupMembers,
        respondingState: store.proposalResponding[scheduleId] ?? .idle,
        isLive: store.liveActivityScheduleId == scheduleId,
        weather: store.weatherByScheduleId[scheduleId],
        conflicts: (store.conflictsByScheduleId[scheduleId] ?? []).map { conflict in
          ConflictInfo(
            title: conflict.title,
            overlapMinutes: conflict.overlapMinutes,
            gapMinutes: conflict.gapMinutes,
            startAt: conflict.startAt,
            endAt: conflict.endAt,
            emoji: conflict.emoji,
            severity: conflict.severity == .confirmed ? .confirmed : .pending
          )
        },
        isCheckingConflicts: store.conflictCheckingIds.contains(scheduleId),
        onTap: {
          store.send(.view(.scheduleTapped(schedule)))
        },
        onAccept: {
          store.send(.view(.proposalAccepted(scheduleId)))
        },
        onReject: {
          store.send(.view(.proposalRejected(scheduleId)))
        },
        onEdit: {
          store.send(.view(.scheduleEditTapped(schedule)))
        },
        onDelete: {
          store.send(.view(.scheduleDeleteRequested(scheduleId)))
        },
        onChangeResponse: { status in
          store.send(.view(.responseChanged(scheduleId, status)))
        },
        onShare: schedule.isPast ? nil : {
          store.send(.view(.scheduleShared(scheduleId)))
        },
        onDirections: {
          store.send(.view(.directionsTapped(scheduleId)))
        }
      )
      .contentShape(Rectangle())
      .onTapGesture {
        store.send(.view(.scheduleTapped(schedule)))
      }
      .modifier(ShakeEffect(
        isShaking: store.highlightedScheduleId == scheduleId || store.isNeedResponseShaking,
        onComplete: {
          if store.highlightedScheduleId == scheduleId {
            store.send(.view(.clearHighlightedSchedule))
          }
        }
      ))
      .listRowBackground(Color.clear)
      .listRowSeparator(.hidden)
      .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
      .swipeActions(edge: .leading, allowsFullSwipe: true) {
        // 수락 / 되돌리기 (과거 일정, 흔들기 애니메이션 중 제외)
        if !schedule.isPast && !store.isNeedResponseShaking {
          if myVoteStatus == .accepted {
            Button {
              store.send(.view(.responseChanged(scheduleId, .pending)))
            } label: {
              Label(LocalizedStrings.GroupMain.undo, systemImage: "arrow.uturn.backward.circle.fill")
            }
            .tint(.blue)
          } else {
            Button {
              store.send(.view(.proposalAccepted(scheduleId)))
            } label: {
              Label(LocalizedStrings.GroupMain.accept, systemImage: "checkmark.circle.fill")
            }
            .tint(.green)
          }
        }
      }
      .swipeActions(edge: .trailing, allowsFullSwipe: true) {
        // 거절 / 되돌리기 (과거 일정, 흔들기 애니메이션 중 제외)
        if !schedule.isPast && !store.isNeedResponseShaking {
          if myVoteStatus == .declined {
            Button {
              store.send(.view(.responseChanged(scheduleId, .pending)))
            } label: {
              Label(LocalizedStrings.GroupMain.undo, systemImage: "arrow.uturn.backward.circle.fill")
            }
            .tint(.blue)
          } else {
            Button {
              store.send(.view(.proposalRejected(scheduleId)))
            } label: {
              Label(LocalizedStrings.GroupMain.reject, systemImage: "xmark.circle.fill")
            }
            .tint(.red)
          }
        }
      }
    }

    @ViewBuilder
    private var emptyFilteredView: some View {
      VStack(spacing: 0) {
        Spacer()
          .frame(height: 120)

        VStack(spacing: 16) {
          // 이모지 아이콘
          Text(emptyFilterEmoji)
            .font(.system(size: 47))

          // Description (2줄)
          Text(emptyFilterDescription)
            .font(.system(size: 16))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(6)
        }

        Spacer()
      }
      .frame(maxWidth: .infinity)
    }

    private var emptyFilterEmoji: String {
      switch store.selectedFilter {
      case .needResponse: return "📨"
      case .responded: return "⏰"
      case .confirmed: return "✅"
      case .all: return "📬"
      case .past: return "🕐"
      }
    }

    private var emptyFilterDescription: String {
      switch store.selectedFilter {
      case .needResponse:
        return LocalizedStrings.GroupMain.emptyNeedResponse
      case .responded:
        return LocalizedStrings.GroupMain.emptyResponded
      case .confirmed:
        return LocalizedStrings.GroupMain.emptyConfirmed
      case .all:
        return LocalizedStrings.GroupMain.emptyAll
      case .past:
        return LocalizedStrings.GroupMain.emptyPast
      }
    }

    /// 로딩 상태 (과거 필터는 별도 상태 사용)
    private var isLoadingState: Bool {
      if store.selectedFilter == .past {
        return !store.pastSchedulesState.isLoaded && store.pastSchedulesState.error == nil
      }
      return !store.schedulesState.isLoaded && store.schedulesState.error == nil
    }

    /// 현재 에러 (과거 필터는 별도 상태 사용)
    private var currentError: Error? {
      if store.selectedFilter == .past {
        return store.pastSchedulesState.error
      }
      return store.schedulesState.error
    }


    // MARK: - Empty Group View

    @ViewBuilder
    private var groupDetailEmptyView: some View {
      ScrollView {
        // 헤더
        groupHeaderSection
          .padding(.horizontal, 16)
          .padding(.top, 8)

        // 그룹 가로 바 (빈 상태에서도 생성/참여 버튼 제공)
        GroupHorizontalBar(
          groups: store.groupBarItems,
          isLoading: store.isGroupsLoading,
          onGroupTap: { groupId in
            store.send(.view(.groupTapped(groupId)))
          },
          onGroupInvite: { groupId in
            store.send(.view(.groupInviteTapped(groupId)))
          },
          onGroupSettings: { groupId in
            store.send(.view(.groupContextSettingsTapped(groupId)))
          },
          onCreateGroup: {
            store.send(.view(.createGroup))
          },
          onJoinGroup: {
            store.send(.view(.joinGroup))
          },
          onSortSettings: {
            store.send(.view(.sortSettingsTapped))
          },
          onCreateSchedule: { groupId in
            store.send(.view(.contextCreateScheduleTapped(groupId)))
          }
        )

        Divider()

        VStack(spacing: 0) {
          // 필터 (비활성 상태로 유지)
          filterSegment
            .padding(.vertical, 8)
            .disabled(true)
            .opacity(0.5)

          // 빈 상태 컨텐츠
          VStack(spacing: 0) {
            Spacer()
              .frame(height: 120)

            VStack(spacing: 16) {
              // 이모지 아이콘
              Text("👥")
                .font(.system(size: 47))

              // Description (2줄)
              Text(LocalizedStrings.GroupMain.noGroupsDescription)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
            }

            Spacer()
          }
          .frame(maxWidth: .infinity)
        }
      }
    }

  }
}

// MARK: - State Extensions

private extension GroupMain.Feature.State {

  /// 속한 그룹이 없는 경우
  private var hasNoGroups: Bool {
    allGroupSummaries?.isEmpty == true && currentGroup == nil
  }

  /// 빈 그룹 화면 표시 여부 (온보딩 모드로 대체되어 항상 false)
  var shouldShowEmptyGroupView: Bool {
    false  // 온보딩 모드에서 groupDetailView 재사용
  }

  /// 특정 일정의 응답 상태 조회
  func respondingState(for scheduleId: String) -> GroupMain.RespondingState {
    proposalResponding[scheduleId] ?? .idle
  }
}

// MARK: - Onboarding Card View

private struct OnboardingCardView: View {
  let card: GroupMain.OnboardingCard
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 14) {
        // 헤더
        HStack(spacing: 10) {
          // 아이콘
          iconView
            .frame(width: 32, height: 32)

          Text(card.title)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.primary)

          Spacer()

          // 화살표
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.tertiary)
        }

        Divider()

        // 설명
        Text(card.subtitle)
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .lineLimit(2)
      }
      .padding(16)
      .contentShape(Rectangle())
      .adaptiveGlassCard()
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var iconView: some View {
    if card == .createGroup {
      ResourceKitAsset.fingerSchedule.swiftUIImage
        .resizable()
        .scaledToFit()
    } else {
      ZStack {
        Circle()
          .fill(card.color.opacity(0.15))

        Image(systemName: card.icon)
          .font(.system(size: 16))
          .foregroundStyle(card.color)
      }
    }
  }
}


// MARK: - SortSettingsSheetContent

/// 시트 내부에서 Store를 생성하여 애니메이션 문제 해결
private struct SortSettingsSheetContent: View {
  let initialState: GroupSortSettings.Feature.State
  let onOptionChanged: (GroupSortOption) -> Void
  let onDismiss: () -> Void

  var body: some View {
    GroupSortSettings.RootView(
      store: Store(initialState: initialState) {
        GroupSortSettings.Feature()
      },
      onConfirm: { option in
        onOptionChanged(option)
      },
      onCancel: {
        onDismiss()
      }
    )
  }
}

// MARK: - Shake Effect

/// 좌우로 흔들리는 애니메이션 효과 (배경 힌트 포함)
private struct ShakeEffect: ViewModifier {
  let isShaking: Bool
  let delay: Double
  let onComplete: (() -> Void)?
  @State private var shakeOffset: CGFloat = 0
  @State private var hasStartedShake: Bool = false
  @State private var showBackground: Bool = false

  init(isShaking: Bool, delay: Double = 0.5, onComplete: (() -> Void)? = nil) {
    self.isShaking = isShaking
    self.delay = delay
    self.onComplete = onComplete
  }

  func body(content: Content) -> some View {
    ZStack {
      // 배경 힌트 레이어 (흔들기 시작 후에만 표시)
      if showBackground {
        swipeHintBackground
      }

      // 실제 컨텐츠
      content
        .offset(x: shakeOffset)
    }
    .onChange(of: isShaking) { _, newValue in
      if newValue && !hasStartedShake {
        // 스크롤 완료 후 흔들기 시작
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          hasStartedShake = true
          showBackground = true
          performShake()
        }
      } else if !newValue {
        hasStartedShake = false
        showBackground = false
        shakeOffset = 0
      }
    }
    .onAppear {
      if isShaking && !hasStartedShake {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
          hasStartedShake = true
          showBackground = true
          performShake()
        }
      }
    }
  }

  private var swipeHintBackground: some View {
    ZStack {
      // Leading - 수락 (오른쪽으로 밀었을 때만 표시)
      if shakeOffset > 0 {
        HStack {
          let progress = clamp((shakeOffset - 8) / 40)
          swipeHintBubble(
            title: LocalizedStrings.GroupMain.accept,
            systemImage: "checkmark.circle.fill",
            fillColor: .green,
            progress: progress
          )
          .opacity(progress)
          .scaleEffect(0.3 + progress * 0.7)
          .offset(x: -4)

          Spacer()
        }
        .padding(.leading, 0)
      }

      // Trailing - 거절 (왼쪽으로 밀었을 때만 표시)
      if shakeOffset < 0 {
        HStack {
          Spacer()

          let progress = clamp((abs(shakeOffset) - 8) / 40)
          swipeHintBubble(
            title: LocalizedStrings.GroupMain.reject,
            systemImage: "xmark.circle.fill",
            fillColor: .red,
            progress: progress
          )
          .opacity(progress)
          .scaleEffect(0.3 + progress * 0.7)
          .offset(x: 4)
        }
        .padding(.trailing, 0)
      }
    }
    .frame(maxWidth: .infinity)
    .frame(height: 100)
  }

  private func swipeHintBubble(
    title: String,
    systemImage: String,
    fillColor: Color,
    progress: CGFloat
  ) -> some View {
    VStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(fillColor)
          .frame(width: 48, height: 48)

        Image(systemName: systemImage)
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.white)
      }

      Text(title)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
    }
  }

  private func clamp(_ value: CGFloat) -> CGFloat {
    min(max(value, 0), 1)
  }

  private func performShake() {
    let duration = 0.3
    let shakeDistance: CGFloat = 50

    // 0 → 50 → -50 → 0
    withAnimation(.easeInOut(duration: duration)) {
      shakeOffset = shakeDistance
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
      withAnimation(.easeInOut(duration: duration)) {
        shakeOffset = -shakeDistance
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + duration * 2) {
      withAnimation(.easeInOut(duration: duration)) {
        shakeOffset = 0
      }
    }
    // 애니메이션 완료 후 콜백 호출
    DispatchQueue.main.asyncAfter(deadline: .now() + duration * 3) {
      showBackground = false
      onComplete?()
    }
  }
}
