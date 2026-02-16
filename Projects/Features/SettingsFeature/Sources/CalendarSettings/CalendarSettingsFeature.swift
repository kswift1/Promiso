//
//  CalendarSettingsFeature.swift
//  SettingsFeature
//
//  Created by Claude on 2026-02-02.
//

import Clients
import ComposableArchitecture
import PromisoShared
import SwiftUI

// MARK: - Feature Namespace

/// CalendarSettings Feature 컴포넌트를 위한 Namespace
public enum CalendarSettings {}

// MARK: - Feature Implementation

extension CalendarSettings {

  @Reducer
  public struct Feature {

    // MARK: - Dependencies

    @Dependency(\.eventKitClient) private var eventKitClient
    @Dependency(\.groupClient) private var groupClient
    @Dependency(\.hapticFeedback) private var hapticFeedback
    @Dependency(\.calendarSyncClient) private var calendarSyncClient

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      public var authorizationStatus: CalendarAuthorizationStatus
      public var isRequestingAccess: Bool
      public var groups: [UserGroupInfo]
      public var updatingGroupIds: Set<String>
      public var personalCalendarSyncEnabled: Bool
      public var toastMessage: ToastMessage?

      public init() {
        self.authorizationStatus = .notDetermined
        self.isRequestingAccess = false
        self.groups = []
        self.updatingGroupIds = []
        self.personalCalendarSyncEnabled = UserDefaults.standard.bool(
          forKey: AppConstants.UserDefaults.personalCalendarSync
        )
        self.toastMessage = nil
      }
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case onAppear
      case onSceneActive
      case calendarToggleTapped
      case groupCalendarSyncToggled(groupId: String, enabled: Bool)
      case personalCalendarSyncToggled(Bool)
      case toastDismissed
    }

    @CasePathable
    public enum Internal: Equatable, Sendable {
      case authorizationStatusUpdated(CalendarAuthorizationStatus)
      case accessRequestCompleted(Bool)
      case groupsUpdated([UserGroupInfo])
      case groupSettingsUpdateCompleted(groupId: String, success: Bool, previousValue: Bool?)
      case personalSyncCompleted
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.onAppear):
          let status = eventKitClient.authorizationStatus()
          state.authorizationStatus = status
          return .run { send in
            do {
              let groups = try await groupClient.fetchGroupSummaries()
              await send(.internal(.groupsUpdated(groups)))
            } catch {
              // 그룹 로딩 실패 시 빈 배열 유지
            }
          }

        case .view(.onSceneActive):
          let status = eventKitClient.authorizationStatus()
          state.authorizationStatus = status
          return .run { send in
            do {
              let groups = try await groupClient.fetchGroupSummaries()
              await send(.internal(.groupsUpdated(groups)))
            } catch {
              // 그룹 로딩 실패 시 기존 상태 유지
            }
          }

        case .view(.calendarToggleTapped):
          let status = state.authorizationStatus
          if status == .notDetermined {
            state.isRequestingAccess = true
            return .run { send in
              await hapticFeedback.medium()
              do {
                let granted = try await eventKitClient.requestAccess()
                await send(.internal(.accessRequestCompleted(granted)))
              } catch {
                await send(.internal(.accessRequestCompleted(false)))
              }
            }
          } else {
            return .run { _ in
              await hapticFeedback.selection()
              await eventKitClient.openSettings()
            }
          }

        case .view(.personalCalendarSyncToggled(let enabled)):
          state.personalCalendarSyncEnabled = enabled
          UserDefaults.standard.set(enabled, forKey: AppConstants.UserDefaults.personalCalendarSync)
          return .run { [calendarSyncClient] send in
            await hapticFeedback.selection()
            if enabled {
              _ = try? await calendarSyncClient.syncPersonalEvents(true)
            }
            await send(.internal(.personalSyncCompleted))
          }

        case .view(.groupCalendarSyncToggled(let groupId, let enabled)):
          guard let groupIndex = state.groups.firstIndex(where: { $0.id == groupId }) else {
            return .none
          }

          state.updatingGroupIds.insert(groupId)

          // 로컬 상태 즉시 업데이트 (Optimistic Update)
          let previousValue = state.groups[groupIndex].notifications?.calendarSync ?? true
          var updatedGroup = state.groups[groupIndex]
          var settings = updatedGroup.notifications ?? GroupNotificationSettings()
          settings.calendarSync = enabled
          updatedGroup = UserGroupInfo(
            id: updatedGroup.id,
            name: updatedGroup.name,
            role: updatedGroup.role,
            joinedAt: updatedGroup.joinedAt,
            notifications: settings,
            hasNewActivity: updatedGroup.hasNewActivity,
            imageUrl: updatedGroup.imageUrl
          )
          state.groups[groupIndex] = updatedGroup

          return .run { send in
            await hapticFeedback.selection()
            do {
              try await groupClient.updateGroupNotificationSettings(groupId, settings)
              await send(.internal(.groupSettingsUpdateCompleted(groupId: groupId, success: true, previousValue: nil)))
            } catch {
              // 실패 시 이전 값으로 롤백
              await send(.internal(.groupSettingsUpdateCompleted(groupId: groupId, success: false, previousValue: previousValue)))
            }
          }

        case .view(.toastDismissed):
          state.toastMessage = nil
          return .none

        case .internal(.authorizationStatusUpdated(let status)):
          state.authorizationStatus = status
          return .none

        case .internal(.accessRequestCompleted(let granted)):
          state.isRequestingAccess = false
          let status = eventKitClient.authorizationStatus()
          state.authorizationStatus = status
          if !granted {
            state.toastMessage = ToastMessage(
              type: .warning,
              title: "캘린더 접근 권한이 거부되었어요",
              subtitle: "설정에서 권한을 변경할 수 있어요.",
              position: .top
            )
          }
          return .run { _ in
            if granted {
              await hapticFeedback.success()
            } else {
              await hapticFeedback.error()
            }
          }

        case .internal(.groupsUpdated(let groups)):
          state.groups = groups
          return .none

        case .internal(.groupSettingsUpdateCompleted(let groupId, let success, let previousValue)):
          state.updatingGroupIds.remove(groupId)

          // 실패 시 이전 값으로 롤백
          if !success, let previousValue,
             let groupIndex = state.groups.firstIndex(where: { $0.id == groupId }) {
            var updatedGroup = state.groups[groupIndex]
            var settings = updatedGroup.notifications ?? GroupNotificationSettings()
            settings.calendarSync = previousValue
            updatedGroup = UserGroupInfo(
              id: updatedGroup.id,
              name: updatedGroup.name,
              role: updatedGroup.role,
              joinedAt: updatedGroup.joinedAt,
              notifications: settings,
              hasNewActivity: updatedGroup.hasNewActivity,
              imageUrl: updatedGroup.imageUrl
            )
            state.groups[groupIndex] = updatedGroup
          }
          if !success {
            state.toastMessage = ToastMessage(
              type: .error,
              title: "그룹 캘린더 동기화 저장에 실패했어요",
              position: .top
            )
          }

          return .run { _ in
            if success {
              await hapticFeedback.success()
            } else {
              await hapticFeedback.error()
            }
          }

        case .internal(.personalSyncCompleted):
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
          calendarAccessSection
          permissionDetailSection

          if store.authorizationStatus.canWriteEvents {
            personalSyncSection
          }

          if store.authorizationStatus.canWriteEvents && !store.groups.isEmpty {
            groupSyncSection
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle("캘린더 설정")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
      .onChange(of: scenePhase) { _, newPhase in
        if newPhase == .active {
          store.send(.view(.onSceneActive))
        }
      }
      .toast(Binding(
        get: { store.toastMessage },
        set: { _ in store.send(.view(.toastDismissed)) }
      ))
    }

    // MARK: - Calendar Access Section

    private var calendarAccessSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("캘린더 접근")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          Button {
            store.send(.view(.calendarToggleTapped))
          } label: {
            HStack(spacing: 12) {
              Image(systemName: "calendar")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.pmindigo.n500)

              Text("캘린더 연동")
                .foregroundStyle(.primary)

              Spacer()

              if store.isRequestingAccess {
                ProgressView()
                  .scaleEffect(0.8)
              } else {
                Toggle("", isOn: .constant(store.authorizationStatus.isAuthorized))
                  .labelsHidden()
                  .tint(Color.pmindigo.n500)
                  .allowsHitTesting(false)
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .disabled(store.isRequestingAccess)
        }
        .adaptiveGlassCard()

        if store.authorizationStatus == .denied {
          Label("시스템 설정에서 캘린더 접근을 허용해주세요", systemImage: "exclamationmark.triangle")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmerror.n500)
            .padding(.horizontal, 4)
        } else if store.authorizationStatus == .restricted {
          Label("기기 설정에 의해 캘린더 접근이 제한되어 있습니다", systemImage: "exclamationmark.triangle")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmwarning.n500)
            .padding(.horizontal, 4)
        }
      }
    }

    // MARK: - Permission Detail Section

    private var permissionDetailSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("권한 상세")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          permissionRow(
            icon: "eye",
            title: "읽기",
            description: "달력 앱의 일정을 불러와 약속과 함께 표시합니다.",
            isGranted: store.authorizationStatus.canReadEvents
          )

          Divider()
            .background(Color.white.opacity(0.12))

          permissionRow(
            icon: "pencil",
            title: "쓰기",
            description: "확정된 약속을 달력 앱에 추가합니다.",
            isGranted: store.authorizationStatus.canWriteEvents
          )
        }
        .adaptiveGlassCard()

        Text("캘린더 권한을 허용하면 약속과 기존 일정을 함께 확인할 수 있습니다.")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    // MARK: - Personal Sync Section

    private var personalSyncSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("개인 일정")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          HStack(spacing: 12) {
            Image(systemName: "person.fill")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(Color.pmindigo.n500)
              .frame(width: 24)

            Text("개인 일정 동기화")
              .foregroundStyle(.primary)

            Spacer()

            Toggle("", isOn: Binding(
              get: { store.personalCalendarSyncEnabled },
              set: { store.send(.view(.personalCalendarSyncToggled($0))) }
            ))
            .labelsHidden()
            .tint(Color.pmindigo.n500)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
        }
        .adaptiveGlassCard()

        Text("개인 일정을 달력 앱에 자동으로 추가합니다.")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    // MARK: - Group Sync Section

    private var groupSyncSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("그룹별 쓰기 권한")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          ForEach(Array(store.groups.enumerated()), id: \.element.id) { index, group in
            if index > 0 {
              Divider()
                .background(Color.white.opacity(0.12))
            }

            groupSyncRow(group: group)
          }
        }
        .adaptiveGlassCard()

        Text("그룹별로 확정된 약속을 달력 앱에 추가할지 설정합니다.")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.horizontal, 4)
      }
    }

    // MARK: - Group Sync Row

    private func groupSyncRow(group: UserGroupInfo) -> some View {
      let isEnabled = group.notifications?.calendarSync ?? true
      let isUpdating = store.updatingGroupIds.contains(group.id)

      return HStack(spacing: 12) {
        // 그룹 이미지
        GroupThumbnailView(
          imageUrl: group.imageUrl,
          name: group.name,
          size: 36
        )

        Text(group.name)
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(Color.pmtext.primary)
          .lineLimit(1)

        Spacer()

        if isUpdating {
          ProgressView()
            .scaleEffect(0.8)
        } else {
          Toggle("", isOn: Binding(
            get: { isEnabled },
            set: { newValue in
              store.send(.view(.groupCalendarSyncToggled(groupId: group.id, enabled: newValue)))
            }
          ))
          .labelsHidden()
          .tint(Color.pmindigo.n500)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }

    // MARK: - Permission Row

    private func permissionRow(
      icon: String,
      title: String,
      description: String,
      isGranted: Bool
    ) -> some View {
      HStack(alignment: .center, spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(isGranted ? Color.pmindigo.n500 : Color.pmgray.n400)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(Color.pmtext.primary)

          Text(description)
            .font(.caption)
            .foregroundStyle(Color.pmtext.secondary)
        }

        Spacer()

        Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle")
          .font(.system(size: 18))
          .foregroundStyle(isGranted ? Color.pmindigo.n500 : Color.pmgray.n400)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
  }
}

// MARK: - CalendarAuthorizationStatus Extensions

extension CalendarAuthorizationStatus {
  var isAuthorized: Bool {
    switch self {
    case .fullAccess, .authorized, .writeOnly:
      return true
    default:
      return false
    }
  }

  var canWriteEvents: Bool {
    switch self {
    case .fullAccess, .writeOnly, .authorized:
      return true
    default:
      return false
    }
  }
}
