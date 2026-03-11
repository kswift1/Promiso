// MARK: - BottomAccessoryInfoFeature.swift
// TabViewBottomAccessory 설정 화면 Feature

import ComposableArchitecture
import PromisoShared
import SwiftUI

// MARK: - Feature Namespace

public enum BottomAccessoryInfo {}

// MARK: - Feature Implementation

extension BottomAccessoryInfo {

  @Reducer
  public struct Feature {
    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      var isEnabled: Bool

      public init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "dev.liveSchedule.enabled")
      }
    }

    @CasePathable
    public enum Action: Sendable {
      case view(View)

      @CasePathable
      public enum View: Sendable {
        case toggleChanged(Bool)
      }
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case let .view(.toggleChanged(isEnabled)):
          state.isEnabled = isEnabled
          UserDefaults.standard.set(isEnabled, forKey: "dev.liveSchedule.enabled")
          return .none
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          // Toggle 섹션
          VStack(alignment: .leading, spacing: 10) {
            Toggle(LocalizedStrings.SettingsStrings.liveScheduleDisplay, isOn: $store.isEnabled.sending(\.view.toggleChanged))
              .padding(.horizontal, 16)
              .padding(.vertical, 14)
              .adaptiveGlassCard()

            Text(LocalizedStrings.SettingsStrings.liveScheduleDescription)
              .font(.system(size: 12))
              .foregroundStyle(Color.pmtext.secondary)
              .padding(.horizontal, 4)
          }

          // 디바이스 정보 섹션
          VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStrings.SettingsStrings.deviceInfo)
              .font(.system(size: 16, weight: .semibold))
              .padding(.horizontal, 4)

            VStack(spacing: 0) {
              HStack {
                Text(LocalizedStrings.SettingsStrings.currentAPIMode)
                Spacer()
                Text(currentModeName)
                  .foregroundStyle(.secondary)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 14)

              Divider()
                .background(Color.white.opacity(0.12))

              HStack {
                Text(LocalizedStrings.SettingsStrings.iosVersion)
                Spacer()
                Text(UIDevice.current.systemVersion)
                  .foregroundStyle(.secondary)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 14)
            }
            .adaptiveGlassCard()
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.liveScheduleSettings)
      .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed Properties

    private var currentModeName: String {
      if #available(iOS 26.1, *) {
        return "BottomAccessory (26.1+)"
      } else if #available(iOS 26.0, *) {
        return "BottomAccessory (26.0)"
      } else {
        return "Overlay"
      }
    }
  }
}
