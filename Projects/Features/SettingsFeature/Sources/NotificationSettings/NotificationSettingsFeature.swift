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
    @Dependency(\.hapticFeedback) var hapticFeedback

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 시스템 알림 권한 상태
      public var systemAuthStatus: NotificationAuthorizationStatus = .notDetermined

      public init(
        systemAuthStatus: NotificationAuthorizationStatus = .notDetermined
      ) {
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
      case openSystemSettings
    }

    public enum Internal: Equatable, Sendable {
      case systemAuthStatusReceived(NotificationAuthorizationStatus)
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {

        // MARK: - View Actions

        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            // 시스템 알림 권한 상태 확인
            return .run { send in
              let status = await notificationClient.getAuthorizationStatus()
              await send(.internal(.systemAuthStatusReceived(status)))
            }

          case .openSystemSettings:
            return .run { _ in
              await hapticFeedback.selection()
              await notificationClient.openNotificationSettings()
            }
          }

        // MARK: - Internal Actions

        case .internal(let internalAction):
          switch internalAction {
          case .systemAuthStatusReceived(let status):
            state.systemAuthStatus = status
            return .none
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
          // 시스템 권한 상태 표시
          HStack(spacing: 12) {
            Image(systemName: statusIcon)
              .font(.title2)
              .foregroundStyle(statusColor)
              .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
              Text("시스템 알림 권한")
                .font(.body)
                .foregroundStyle(Color.pmtext.primary)

              Text(statusText)
                .font(.caption)
                .foregroundStyle(Color.pmtext.secondary)
            }

            Spacer()
          }
          .padding(.vertical, 4)

          // 시스템 설정 열기 버튼
          Button {
            store.send(.view(.openSystemSettings))
          } label: {
            HStack {
              Text("시스템 설정 열기")
                .font(.body)
                .foregroundStyle(Color.pmindigo.n500)

              Spacer()

              Image(systemName: "arrow.up.right")
                .font(.caption)
                .foregroundStyle(Color.pmindigo.n500)
            }
            .contentShape(Rectangle())
          }
        } header: {
          Text("알림 권한")
        } footer: {
          Text("개별 그룹의 알림 설정은 각 그룹 설정에서 변경할 수 있습니다.")
        }
      }
      .scrollContentBackground(.hidden)
      .background(Color.clear)
      .auroraBackground()
      .navigationTitle("알림 설정")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Helpers

    private var statusIcon: String {
      switch store.systemAuthStatus {
      case .authorized:
        return "checkmark.circle.fill"
      case .denied:
        return "xmark.circle.fill"
      case .notDetermined:
        return "questionmark.circle.fill"
      case .provisional, .ephemeral:
        return "bell.badge.fill"
      @unknown default:
        return "bell.slash.fill"
      }
    }

    private var statusColor: Color {
      switch store.systemAuthStatus {
      case .authorized:
        return Color.pmsuccess.n500
      case .denied:
        return Color.pmerror.n500
      case .notDetermined:
        return Color.pmtext.secondary
      case .provisional, .ephemeral:
        return Color.pmwarning.n500
      @unknown default:
        return Color.pmtext.secondary
      }
    }

    private var statusText: String {
      switch store.systemAuthStatus {
      case .authorized:
        return "알림이 허용되었습니다"
      case .denied:
        return "알림이 거부되었습니다. 시스템 설정에서 변경할 수 있습니다."
      case .notDetermined:
        return "알림 권한을 설정해주세요"
      case .provisional:
        return "임시 알림 권한이 부여되었습니다"
      case .ephemeral:
        return "임시 알림 권한이 부여되었습니다"
      @unknown default:
        return "알림 권한 상태를 확인할 수 없습니다"
      }
    }
  }
}
