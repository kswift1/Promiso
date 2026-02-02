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
    @Dependency(\.hapticFeedback) private var hapticFeedback

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      public var authorizationStatus: CalendarAuthorizationStatus
      public var isRequestingAccess: Bool

      public init() {
        self.authorizationStatus = .notDetermined
        self.isRequestingAccess = false
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
      case onSceneActive
      case calendarToggleTapped
    }

    public enum Internal: Equatable, Sendable {
      case authorizationStatusUpdated(CalendarAuthorizationStatus)
      case accessRequestCompleted(Bool)
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.onAppear):
          let status = eventKitClient.authorizationStatus()
          state.authorizationStatus = status
          return .none

        case .view(.onSceneActive):
          let status = eventKitClient.authorizationStatus()
          state.authorizationStatus = status
          return .none

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

        case .internal(.authorizationStatusUpdated(let status)):
          state.authorizationStatus = status
          return .none

        case .internal(.accessRequestCompleted(let granted)):
          state.isRequestingAccess = false
          let status = eventKitClient.authorizationStatus()
          state.authorizationStatus = status
          return .run { _ in
            if granted {
              await hapticFeedback.success()
            } else {
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
    @Environment(\.scenePhase) private var scenePhase

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          calendarAccessSection
          permissionDetailSection
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
            description: "캘린더 일정을 조회하여 약속과 함께 표시합니다.",
            isGranted: store.authorizationStatus.canReadEvents
          )

          Divider()
            .background(Color.white.opacity(0.12))

          permissionRow(
            icon: "pencil",
            title: "쓰기",
            description: "약속이 확정되면 달력 앱에도 자동으로 추가합니다.",
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
