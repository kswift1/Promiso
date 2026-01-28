//
//  NotificationSettingsFeature.swift
//  ProfileFeature
//
//  Created by Claude on 2026-01-28.
//

import ComposableArchitecture
import SwiftUI
import Clients
import PromisoShared

// MARK: - Feature Namespace

/// NotificationSettings Feature 컴포넌트를 위한 Namespace
public enum NotificationSettings {}

// MARK: - Feature Implementation

extension NotificationSettings {

  @Reducer
  public struct Feature {
    public init() {}

    // MARK: - Dependencies

    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.hapticFeedback) var hapticFeedback

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 현재 사용자 ID
      public let currentUserId: String
      /// 알림 활성화 여부
      public var notificationEnabled: Bool
      /// 시스템 알림 권한 상태
      public var systemAuthStatus: NotificationAuthorizationStatus = .notDetermined
      /// 업데이트 중 여부
      public var isUpdating: Bool = false
      /// 에러 메시지
      public var errorMessage: String?

      public init(
        currentUserId: String,
        notificationEnabled: Bool,
        systemAuthStatus: NotificationAuthorizationStatus = .notDetermined
      ) {
        self.currentUserId = currentUserId
        self.notificationEnabled = notificationEnabled
        self.systemAuthStatus = systemAuthStatus
      }
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case onAppear
      case notificationToggled(Bool)
      case openSystemSettings
      case dismissError
    }

    public enum Internal: Equatable, Sendable {
      case systemAuthStatusReceived(NotificationAuthorizationStatus)
      case settingsFetched(Bool)
      case updateNotificationSuccess
      case updateNotificationFailed(String)
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {

        // MARK: - View Actions

        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            // 시스템 알림 권한 상태 확인 및 사용자 설정 로드
            let userId = state.currentUserId
            return .run { send in
              async let status = notificationClient.getAuthorizationStatus()
              async let settings = try? userSettingsClient.fetchSettings(userId)

              await send(.internal(.systemAuthStatusReceived(status)))
              if let settings = await settings {
                await send(.internal(.settingsFetched(settings.notificationEnabled)))
              }
            }

          case .notificationToggled(let enabled):
            state.notificationEnabled = enabled
            state.isUpdating = true
            let userId = state.currentUserId
            return .run { send in
              await hapticFeedback.selection()
              do {
                try await userSettingsClient.updateNotificationEnabled(userId, enabled)
                await send(.internal(.updateNotificationSuccess))
              } catch {
                await send(.internal(.updateNotificationFailed(error.localizedDescription)))
              }
            }

          case .openSystemSettings:
            return .run { _ in
              await hapticFeedback.selection()
              await notificationClient.openNotificationSettings()
            }

          case .dismissError:
            state.errorMessage = nil
            return .none
          }

        // MARK: - Internal Actions

        case .internal(let internalAction):
          switch internalAction {
          case .systemAuthStatusReceived(let status):
            state.systemAuthStatus = status
            return .none

          case .settingsFetched(let enabled):
            state.notificationEnabled = enabled
            return .none

          case .updateNotificationSuccess:
            state.isUpdating = false
            return .run { _ in
              await hapticFeedback.success()
            }

          case .updateNotificationFailed(let errorMessage):
            state.isUpdating = false
            state.errorMessage = errorMessage
            state.notificationEnabled = !state.notificationEnabled // 롤백
            return .run { _ in
              await hapticFeedback.error()
            }
          }
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      List {
        Section {
          // 시스템 권한 거부 경고
          if store.systemAuthStatus == .denied {
            VStack(alignment: .leading, spacing: 12) {
              HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                  .foregroundStyle(Color.pmerror.n500)

                Text("시스템 알림 권한이 거부되었습니다")
                  .font(.caption)
                  .foregroundStyle(Color.pmtext.secondary)
              }

              Button {
                store.send(.view(.openSystemSettings))
              } label: {
                Text("시스템 설정 열기")
                  .font(.subheadline)
                  .fontWeight(.medium)
                  .foregroundStyle(Color.pmindigo.n500)
              }
            }
            .padding(.vertical, 8)
          }

          // 알림 토글
          Toggle(isOn: Binding(
            get: { store.notificationEnabled },
            set: { store.send(.view(.notificationToggled($0))) }
          )) {
            VStack(alignment: .leading, spacing: 4) {
              Text("알림 받기")
                .font(.body)
                .foregroundStyle(Color.pmtext.primary)

              Text("Promiso의 모든 알림을 받습니다")
                .font(.caption)
                .foregroundStyle(Color.pmtext.secondary)
            }
          }
          .disabled(store.systemAuthStatus != .authorized || store.isUpdating)
          .tint(Color.pmindigo.n500)
        } header: {
          Text("전체 알림 설정")
        } footer: {
          Text("개별 그룹의 알림 설정은 각 그룹 설정에서 변경할 수 있습니다.")
        }
      }
      .navigationTitle("알림 설정")
      .navigationBarTitleDisplayMode(.inline)
      .alert(
        "알림 설정 오류",
        isPresented: Binding(
          get: { store.errorMessage != nil },
          set: { if !$0 { store.send(.view(.dismissError)) } }
        ),
        presenting: store.errorMessage
      ) { _ in
        Button("확인") {
          store.send(.view(.dismissError))
        }
      } message: { message in
        Text(message)
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
    }
  }
}
