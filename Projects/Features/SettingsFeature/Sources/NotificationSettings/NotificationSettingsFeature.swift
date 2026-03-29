//
//  NotificationSettingsFeature.swift
//  SettingsFeature
//

import ComposableArchitecture
import SwiftUI
import Clients
import PromisoShared
import ResourceKit
import UIKit

// MARK: - Feature Namespace

public enum NotificationSettings {}

// MARK: - Feature Implementation

extension NotificationSettings {

  @Reducer
  public struct Feature {
    public init() {}

    // MARK: - Dependencies

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.userProfileClient) var userProfileClient
    @Dependency(\.hapticFeedback) var hapticFeedback
    @Dependency(\.analyticsClient) var analyticsClient

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {
      public let currentUserId: String
      public var systemAuthStatus: NotificationAuthorizationStatus = .notDetermined
      public var groups: [UserGroupInfo] = []
      public var isLoadingGroups: Bool = false

      public init(
        currentUserId: String,
        systemAuthStatus: NotificationAuthorizationStatus = .notDetermined
      ) {
        self.currentUserId = currentUserId
        self.systemAuthStatus = systemAuthStatus
      }

      var isSystemNotificationEnabled: Bool {
        switch systemAuthStatus {
        case .authorized, .provisional, .ephemeral:
          return true
        default:
          return false
        }
      }
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case onAppear
      case onSceneActive
      case systemNotificationToggleTapped
      case groupTapped(UserGroupInfo)
    }

    @CasePathable
    public enum Internal: Equatable, Sendable {
      case systemAuthStatusReceived(NotificationAuthorizationStatus)
      case groupsLoaded([UserGroupInfo])
    }

    public enum Delegate: Equatable, Sendable {
      case navigateToGroupDetail(UserGroupInfo, isSystemNotificationEnabled: Bool)
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {

        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            state.isLoadingGroups = true
            return .run { send in
              let status = await notificationClient.getAuthorizationStatus()
              await send(.internal(.systemAuthStatusReceived(status)))

              do {
                let user = try await userProfileClient.getPrivateProfile(.me)
                await send(.internal(.groupsLoaded(user.groups)))
              } catch {
                await send(.internal(.groupsLoaded([])))
              }
            }

          case .onSceneActive:
            return .run { send in
              let status = await notificationClient.getAuthorizationStatus()
              await send(.internal(.systemAuthStatusReceived(status)))
            }

          case .systemNotificationToggleTapped:
            return .run { _ in
              await hapticFeedback.selection()
              await notificationClient.openNotificationSettings()
            }

          case .groupTapped(let group):
            return .run { [isEnabled = state.isSystemNotificationEnabled] send in
              await hapticFeedback.selection()
              await send(.delegate(.navigateToGroupDetail(group, isSystemNotificationEnabled: isEnabled)))
            }
          }

        case .internal(let internalAction):
          switch internalAction {
          case .systemAuthStatusReceived(let status):
            state.systemAuthStatus = status
            analyticsClient.setNotificationPermissionStatus(status)
            return .none

          case .groupsLoaded(let groups):
            state.groups = groups.sorted { ($0.joinedAt ?? .distantPast) > ($1.joinedAt ?? .distantPast) }
            state.isLoadingGroups = false
            return .none
          }

        case .delegate:
          return .none
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          appNotificationSection
          groupNotificationSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.notificationSettingsTitle)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
      .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .active {
          store.send(.view(.onSceneActive))
        }
      }
    }

    // MARK: - App Notification Section

    private var appNotificationSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.appPushNotifications)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          Button {
            store.send(.view(.systemNotificationToggleTapped))
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "bell.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.pmindigo.n500)

              Text(LocalizedStrings.SettingsStrings.allowNotifications)
                .foregroundStyle(.primary)

              Spacer()

              Toggle("", isOn: .constant(store.isSystemNotificationEnabled))
                .labelsHidden()
                .tint(Color.pmindigo.n500)
                .allowsHitTesting(false)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
        .adaptiveGlassCard()

        if store.systemAuthStatus == .denied {
          Label(LocalizedStrings.SettingsStrings.enableNotificationsInSettings, systemImage: "exclamationmark.triangle")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmerror.n500)
            .padding(.horizontal, 4)
        }
      }
    }

    // MARK: - Group Notification Section

    private var groupNotificationSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.groupNotifications)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        if store.isLoadingGroups {
          HStack {
            Spacer()
            ProgressView()
            Spacer()
          }
          .padding(.vertical, 24)
          .adaptiveGlassCard()
        } else if store.groups.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "person.3")
              .font(.system(size: 32))
              .foregroundStyle(Color.pmtext.secondary)
            Text(LocalizedStrings.SettingsStrings.noGroupsJoined)
              .font(.subheadline)
              .foregroundStyle(Color.pmtext.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 24)
          .adaptiveGlassCard()
        } else {
          VStack(spacing: 0) {
            ForEach(Array(store.groups.enumerated()), id: \.element.id) { index, group in
              groupRow(group: group)

              if index < store.groups.count - 1 {
                Divider()
                  .background(Color.white.opacity(0.12))
              }
            }
          }
          .adaptiveGlassCard()
        }
      }
    }

    // MARK: - Group Row

    private func groupRow(group: UserGroupInfo) -> some View {
      let isGroupEnabled = group.notifications?.enabled ?? true
      let isDisabled = !store.isSystemNotificationEnabled

      return Button {
        store.send(.view(.groupTapped(group)))
      } label: {
        HStack(spacing: 12) {
          GroupThumbnailView(
            imageUrl: group.imageUrl,
            name: group.name,
            size: 40
          )

          Text(group.name)
            .font(.body)
            .foregroundStyle(isDisabled ? Color.pmtext.secondary : Color.pmtext.primary)
            .lineLimit(1)

          Spacer()

          // 알림 상태 표시
          if isGroupEnabled && !isDisabled {
            Image(systemName: "bell.fill")
              .font(.system(size: 14))
              .foregroundStyle(Color.pmindigo.n500)
          } else {
            Image(systemName: "bell.slash")
              .font(.system(size: 14))
              .foregroundStyle(Color.pmtext.secondary)
          }

          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(isDisabled)
    }
  }
}

// MARK: - Group Notification Detail Feature

public enum GroupNotificationDetail {}

extension GroupNotificationDetail {

  @Reducer
  public struct Feature {
    public init() {}

    @Dependency(\.groupClient) var groupClient
    @Dependency(\.hapticFeedback) var hapticFeedback

    @ObservableState
    public struct State: Equatable, Sendable {
      public var group: UserGroupInfo
      public var isSystemNotificationEnabled: Bool
      public var toastMessage: ToastMessage?

      public init(group: UserGroupInfo, isSystemNotificationEnabled: Bool) {
        self.group = group
        self.isSystemNotificationEnabled = isSystemNotificationEnabled
        self.toastMessage = nil
      }

      var isGroupEnabled: Bool {
        group.notifications?.enabled ?? true
      }
    }

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case groupNotificationToggled(Bool)
      case preferenceToggled(GroupNotificationPreferenceKey, Bool)
      case toastDismissed
    }

    @CasePathable
    public enum Internal: Equatable, Sendable {
      case updateSucceeded
      case updateFailed(GroupNotificationSettings, String)
    }

    public enum Delegate: Equatable, Sendable {
      case settingsUpdated(groupId: String, settings: GroupNotificationSettings)
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .groupNotificationToggled(let enabled):
            let previousSettings = state.group.notifications ?? GroupNotificationSettings()
            var updatedSettings = previousSettings
            updatedSettings.enabled = enabled
            let nextSettings = updatedSettings
            state.group = state.group.withNotifications(nextSettings)
            let groupId = state.group.id

            return .run { [groupClient] send in
              await hapticFeedback.selection()
              do {
                try await groupClient.updateGroupNotificationSettings(groupId, nextSettings)
                await send(.internal(.updateSucceeded))
                await send(.delegate(.settingsUpdated(groupId: groupId, settings: nextSettings)))
              } catch {
                await send(.internal(.updateFailed(previousSettings, (error as? NotificationClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError)))
              }
            }

          case .preferenceToggled(let key, let enabled):
            let previousSettings = state.group.notifications ?? GroupNotificationSettings()
            var updatedSettings = previousSettings
            updatedSettings.setValue(enabled, for: key)
            let nextSettings = updatedSettings
            state.group = state.group.withNotifications(nextSettings)
            let groupId = state.group.id

            return .run { [groupClient] send in
              await hapticFeedback.selection()
              do {
                try await groupClient.updateGroupNotificationSettings(groupId, nextSettings)
                await send(.internal(.updateSucceeded))
                await send(.delegate(.settingsUpdated(groupId: groupId, settings: nextSettings)))
              } catch {
                await send(.internal(.updateFailed(previousSettings, (error as? NotificationClientError)?.localizedMessage ?? LocalizedStrings.Error.unknownError)))
              }
            }

          case .toastDismissed:
            state.toastMessage = nil
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .updateSucceeded:
            return .run { _ in await hapticFeedback.success() }

          case .updateFailed(let previousSettings, let message):
            state.group = state.group.withNotifications(previousSettings)
            state.toastMessage = ToastMessage(
              type: .error,
              title: LocalizedStrings.Error.notificationSettingSaveFailed,
              subtitle: message,
              position: .top
            )
            return .run { _ in await hapticFeedback.error() }
          }

        case .delegate:
          return .none
        }
      }
    }
  }

  // MARK: - Detail View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @State private var activeTooltip: NotificationTooltip?

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          // 그룹 알림 ON/OFF
          groupToggleSection

          // 세부 설정 (그룹 알림 ON일 때만)
          if store.isGroupEnabled {
            detailSettingsSection
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .animation(.spring(duration: 0.3, bounce: 0.1), value: store.isGroupEnabled)
      }
      .auroraBackground()
      .navigationTitle(store.group.name)
      .navigationBarTitleDisplayMode(.inline)
      .toast(Binding(
        get: { store.toastMessage },
        set: { _ in store.send(.view(.toastDismissed)) }
      ))
    }

    private var groupToggleSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.groupNotificationToggle)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        HStack(spacing: 12) {
          GroupThumbnailView(
            imageUrl: store.group.imageUrl,
            name: store.group.name,
            size: 48
          )

          VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
              Text(LocalizedStrings.SettingsStrings.receiveNotifications)
                .font(.body)
                .foregroundStyle(.primary)

              tooltipButton(for: .groupNotifications)
            }

            Text(store.isGroupEnabled ? LocalizedStrings.SettingsStrings.thisGroupNotificationsOn : LocalizedStrings.SettingsStrings.thisGroupNotificationsOff)
              .font(.caption)
              .foregroundStyle(.secondary)
          }

          Spacer()

          Toggle("", isOn: Binding(
            get: { store.isGroupEnabled },
            set: { store.send(.view(.groupNotificationToggled($0))) }
          ))
          .labelsHidden()
          .tint(Color.pmindigo.n500)
          .disabled(!store.isSystemNotificationEnabled)
        }
        .padding(16)
        .adaptiveGlassCard()
      }
    }

    private var detailSettingsSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text(LocalizedStrings.SettingsStrings.notificationTypes)
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          ForEach(Array(GroupNotificationPreferenceKey.allCases.enumerated()), id: \.element) { index, key in
            preferenceRow(key: key)

            if index < GroupNotificationPreferenceKey.allCases.count - 1 {
              Divider()
                .background(Color.white.opacity(0.12))
            }
          }
        }
        .adaptiveGlassCard()
      }
      .transition(.opacity.combined(with: .scale(scale: 0.98, anchor: .top)))
    }

    private func preferenceRow(key: GroupNotificationPreferenceKey) -> some View {
      let isEnabled = store.group.notifications?.value(for: key) ?? true

      return HStack(alignment: .center, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(key.title)
              .font(.body)
              .foregroundStyle(.primary)

            tooltipButton(for: .preference(key))
          }

          if let subtitle = key.subtitle {
            Text(subtitle)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        Toggle("", isOn: Binding(
          get: { isEnabled },
          set: { store.send(.view(.preferenceToggled(key, $0))) }
        ))
        .labelsHidden()
        .tint(Color.pmindigo.n500)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }

    private func tooltipButton(for tooltip: NotificationTooltip) -> some View {
      Button {
        activeTooltip = tooltip
      } label: {
        Image(systemName: "info.circle")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)
      }
      .buttonStyle(.plain)
      .popover(
        isPresented: Binding(
          get: { activeTooltip == tooltip },
          set: { if !$0 { activeTooltip = nil } }
        ),
        arrowEdge: .top
      ) {
        NotificationInfoPopover(tooltip: tooltip)
      }
    }
  }
}

// MARK: - UserGroupInfo Extension

extension UserGroupInfo {
  func withNotifications(_ notifications: GroupNotificationSettings) -> UserGroupInfo {
    UserGroupInfo(
      id: id,
      name: name,
      role: role,
      joinedAt: joinedAt,
      notifications: notifications,
      hasNewActivity: hasNewActivity,
      imageUrl: imageUrl
    )
  }
}

// MARK: - Notification Tooltip

private enum NotificationTooltip: Identifiable, Equatable {
  case groupNotifications
  case preference(GroupNotificationPreferenceKey)

  var id: String {
    switch self {
    case .groupNotifications:
      return "groupNotifications"
    case .preference(let key):
      return "preference.\(key.rawValue)"
    }
  }

  var title: String {
    switch self {
    case .groupNotifications:
      return LocalizedStrings.SettingsStrings.groupNotificationToggle
    case .preference(let key):
      return key.title
    }
  }

  var subtitle: String {
    switch self {
    case .groupNotifications:
      return LocalizedStrings.SettingsStrings.groupNotificationMustBeOn
    case .preference(let key):
      return key.subtitle ?? LocalizedStrings.SettingsStrings.notificationCanToggle
    }
  }

  var previewTitle: String {
    switch self {
    case .groupNotifications:
      return LocalizedStrings.SettingsStrings.newScheduleArrived
    case .preference(let key):
      switch key {
      case .scheduleInvitation:
        return LocalizedStrings.SettingsStrings.newScheduleArrived
      case .scheduleConfirmed:
        return LocalizedStrings.SettingsStrings.scheduleConfirmedTitle
      case .scheduleCancelled:
        return LocalizedStrings.SettingsStrings.scheduleCancelledTitle
      case .scheduleUpdated:
        return LocalizedStrings.SettingsStrings.scheduleUpdatedTitle
      case .groupUpdate:
        return LocalizedStrings.SettingsStrings.newMemberJoinedTitle
      }
    }
  }

  var previewBody: String {
    switch self {
    case .groupNotifications:
      return LocalizedStrings.SettingsStrings.scheduleInvitationBody
    case .preference(let key):
      switch key {
      case .scheduleInvitation:
        return LocalizedStrings.SettingsStrings.scheduleInvitationBody
      case .scheduleConfirmed:
        return LocalizedStrings.SettingsStrings.scheduleConfirmedBody
      case .scheduleCancelled:
        return LocalizedStrings.SettingsStrings.scheduleCancelledBody
      case .scheduleUpdated:
        return LocalizedStrings.SettingsStrings.scheduleUpdatedBody
      case .groupUpdate:
        return LocalizedStrings.SettingsStrings.newMemberJoinedBody
      }
    }
  }
}

// MARK: - Notification Info Popover

private struct NotificationInfoPopover: View {
  let tooltip: NotificationTooltip
  @State private var animateNotification: Bool = false
  @State private var loopContinues: Bool = true

  var body: some View {
    VStack(spacing: 16) {
      VStack(spacing: 4) {
        Text(tooltip.title)
          .font(.system(size: 17, weight: .bold))
          .foregroundColor(.primary)

        Text(tooltip.subtitle)
          .font(.system(size: 13))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }

      notificationPreview(title: tooltip.previewTitle, body: tooltip.previewBody)
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(Color(.secondarySystemBackground).opacity(0.6))
    )
    .frame(width: UIScreen.main.bounds.width - 40)
    .presentationCompactAdaptation(.popover)
    .onDisappear {
      loopContinues = false
    }
  }

  private func notificationPreview(title: String, body: String) -> some View {
    HStack(alignment: .center, spacing: 8) {
      ResourceKitAsset.notificationLogo.swiftUIImage
        .resizable()
        .scaledToFit()
        .frame(width: 40, height: 40)
        .clipShape(.rect(cornerRadius: 10))

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Promiso")
            .font(.callout)
            .fontWeight(.medium)
            .lineLimit(1)

          Spacer(minLength: 0)

          Text(LocalizedStrings.SettingsStrings.now)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.gray)
        }

        Text(title)
          .font(.callout)
          .fontWeight(.medium)
          .lineLimit(1)

        Text(body)
          .font(.caption2)
          .fontWeight(.medium)
          .foregroundStyle(.gray)
          .lineLimit(2)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(.rect(cornerRadius: 20))
    .shadow(color: .gray.opacity(0.3), radius: 2)
    .padding(.horizontal, 12)
    .offset(y: animateNotification ? 0 : -80)
    .clipped()
    .onAppear {
      Task {
        await loopAnimation()
      }
    }
  }

  private func loopAnimation() async {
    try? await Task.sleep(for: .seconds(0.35))

    withAnimation(.smooth(duration: 0.6)) {
      animateNotification = true
    }

    try? await Task.sleep(for: .seconds(2.8))

    withAnimation(.smooth(duration: 0.6)) {
      animateNotification = false
    }

    guard loopContinues else { return }
    try? await Task.sleep(for: .seconds(0.9))
    await loopAnimation()
  }
}

// MARK: - NotificationClientError Localization

extension NotificationClientError {
  var localizedMessage: String {
    switch self {
    case .authenticationRequired: return LocalizedStrings.Error.notificationAuthRequired
    case .tokenNotFound: return LocalizedStrings.Error.notificationTokenNotFound
    case .saveFailed: return LocalizedStrings.Error.notificationSaveFailed
    case .deleteFailed: return LocalizedStrings.Error.notificationDeleteFailed
    }
  }
}
