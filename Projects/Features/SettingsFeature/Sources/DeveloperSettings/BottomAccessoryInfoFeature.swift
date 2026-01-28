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
    public struct State: Equatable {
      var isEnabled: Bool

      public init() {
        self.isEnabled = UserDefaults.standard.bool(forKey: "dev.livePromise.enabled")
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
          UserDefaults.standard.set(isEnabled, forKey: "dev.livePromise.enabled")
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
      List {
        Section {
          Toggle("LivePromise 표시", isOn: $store.isEnabled.sending(\.view.toggleChanged))
        } footer: {
          Text("TabBar 하단에 실시간 약속 추적 바를 표시합니다.")
        }

        Section {
          HStack {
            Text("현재 API 모드")
            Spacer()
            Text(currentModeName)
              .foregroundStyle(.secondary)
          }

          HStack {
            Text("iOS 버전")
            Spacer()
            Text(UIDevice.current.systemVersion)
              .foregroundStyle(.secondary)
          }
        } header: {
          Text("디바이스 정보")
        }
      }
      .navigationTitle("LivePromise 설정")
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
