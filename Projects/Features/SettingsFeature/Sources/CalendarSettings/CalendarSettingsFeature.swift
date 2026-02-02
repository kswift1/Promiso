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
      case requestAccessTapped
      case openSettingsTapped
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

        case .view(.requestAccessTapped):
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

        case .view(.openSettingsTapped):
          return .run { _ in
            await hapticFeedback.selection()
            await eventKitClient.openSettings()
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

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      List {
        // 권한 상태 섹션
        Section {
          VStack(spacing: 0) {
            HStack(spacing: 16) {
              Image(systemName: "calendar")
                .font(.body)
                .foregroundStyle(Color.pmindigo.n500)
                .frame(width: 24, height: 24)

              VStack(alignment: .leading, spacing: 4) {
                Text("캘린더 접근")
                  .font(.body)
                  .foregroundStyle(Color.pmtext.primary)

                Text(store.authorizationStatus.description)
                  .font(.caption)
                  .foregroundStyle(store.authorizationStatus.statusColor)
              }

              Spacer()

              statusBadge
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
          }
          .adaptiveGlassBackground()
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets())
        } header: {
          Text("권한 상태")
        } footer: {
          Text("캘린더 권한을 허용하면 약속과 함께 캘린더 일정을 확인할 수 있습니다.")
        }

        // 권한 요청/설정 섹션
        if store.authorizationStatus != .fullAccess && store.authorizationStatus != .authorized {
          Section {
            VStack(spacing: 0) {
              if store.authorizationStatus == .notDetermined {
                // 권한 요청 버튼
                Button {
                  store.send(.view(.requestAccessTapped))
                } label: {
                  HStack(spacing: 16) {
                    Image(systemName: "lock.open.fill")
                      .font(.body)
                      .foregroundStyle(Color.pmindigo.n500)
                      .frame(width: 24, height: 24)

                    Text("캘린더 권한 요청")
                      .font(.body)
                      .foregroundStyle(Color.pmtext.primary)

                    Spacer()

                    if store.isRequestingAccess {
                      ProgressView()
                        .scaleEffect(0.8)
                    } else {
                      Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.pmgray.n400)
                    }
                  }
                  .padding(.horizontal, 16)
                  .padding(.vertical, 14)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(store.isRequestingAccess)
              } else {
                // 설정으로 이동 버튼
                Button {
                  store.send(.view(.openSettingsTapped))
                } label: {
                  HStack(spacing: 16) {
                    Image(systemName: "gear")
                      .font(.body)
                      .foregroundStyle(Color.pmindigo.n500)
                      .frame(width: 24, height: 24)

                    Text("설정에서 권한 변경")
                      .font(.body)
                      .foregroundStyle(Color.pmtext.primary)

                    Spacer()

                    Image(systemName: "arrow.up.forward")
                      .font(.caption)
                      .foregroundStyle(Color.pmgray.n400)
                  }
                  .padding(.horizontal, 16)
                  .padding(.vertical, 14)
                  .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
              }
            }
            .adaptiveGlassBackground()
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
          }
        }

        // 권한 설명 섹션
        Section {
          VStack(alignment: .leading, spacing: 12) {
            permissionRow(
              icon: "eye",
              title: "읽기 권한",
              description: "캘린더 일정을 조회하여 약속과 함께 표시합니다.",
              isGranted: store.authorizationStatus.canReadEvents
            )

            Divider()

            permissionRow(
              icon: "pencil",
              title: "쓰기 권한",
              description: "약속을 캘린더에 추가할 수 있습니다.",
              isGranted: store.authorizationStatus.canWriteEvents
            )
          }
          .padding(16)
          .adaptiveGlassBackground()
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets())
        } header: {
          Text("권한 상세")
        }
      }
      .scrollContentBackground(.hidden)
      .background(Color.clear)
      .auroraBackground()
      .navigationTitle("캘린더 설정")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private var statusBadge: some View {
      let status = store.authorizationStatus
      Text(status.shortDescription)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(status.badgeTextColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(status.badgeBackgroundColor, in: Capsule())
    }

    private func permissionRow(
      icon: String,
      title: String,
      description: String,
      isGranted: Bool
    ) -> some View {
      HStack(alignment: .top, spacing: 12) {
        Image(systemName: icon)
          .font(.body)
          .foregroundStyle(isGranted ? Color.pmindigo.n500 : Color.pmgray.n400)
          .frame(width: 24, height: 24)

        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(title)
              .font(.subheadline)
              .fontWeight(.medium)
              .foregroundStyle(Color.pmtext.primary)

            Spacer()

            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
              .foregroundStyle(isGranted ? Color.green : Color.pmgray.n400)
          }

          Text(description)
            .font(.caption)
            .foregroundStyle(Color.pmtext.secondary)
        }
      }
    }
  }
}

// MARK: - CalendarAuthorizationStatus Extensions

extension CalendarAuthorizationStatus {
  var description: String {
    switch self {
    case .notDetermined:
      return "아직 권한을 요청하지 않았습니다"
    case .restricted:
      return "기기 설정에 의해 제한됨"
    case .denied:
      return "권한이 거부됨"
    case .fullAccess:
      return "모든 권한 허용됨"
    case .writeOnly:
      return "쓰기 권한만 허용됨"
    case .authorized:
      return "권한 허용됨"
    }
  }

  var shortDescription: String {
    switch self {
    case .notDetermined:
      return "미설정"
    case .restricted:
      return "제한됨"
    case .denied:
      return "거부됨"
    case .fullAccess, .authorized:
      return "허용됨"
    case .writeOnly:
      return "쓰기만"
    }
  }

  var statusColor: Color {
    switch self {
    case .notDetermined:
      return Color.pmtext.secondary
    case .restricted, .denied:
      return .orange
    case .fullAccess, .authorized:
      return .green
    case .writeOnly:
      return .blue
    }
  }

  var badgeTextColor: Color {
    switch self {
    case .notDetermined:
      return Color.pmtext.secondary
    case .restricted, .denied:
      return .orange
    case .fullAccess, .authorized:
      return .green
    case .writeOnly:
      return .blue
    }
  }

  var badgeBackgroundColor: Color {
    switch self {
    case .notDetermined:
      return Color.pmgray.n200
    case .restricted, .denied:
      return Color.orange.opacity(0.15)
    case .fullAccess, .authorized:
      return Color.green.opacity(0.15)
    case .writeOnly:
      return Color.blue.opacity(0.15)
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
