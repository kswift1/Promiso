// MARK: - DeveloperSettingsFeature.swift
// 개발자 설정 화면 Feature (#if DEBUG 전용)

import ComposableArchitecture
import PromisoShared
import SwiftUI

// MARK: - Feature Namespace

/// 개발자 설정 Feature 컴포넌트를 위한 Namespace
public enum DeveloperSettings {}

// MARK: - Feature Implementation

extension DeveloperSettings {

  // MARK: - Reducer

  @Reducer
  public struct Feature {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      @Presents var liveActivityTest: LiveActivityTest.Feature.State?
      @Presents var bottomAccessoryInfo: BottomAccessoryInfo.Feature.State?

      public init() {}
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case liveActivityTest(PresentationAction<LiveActivityTest.Feature.Action>)
      case bottomAccessoryInfo(PresentationAction<BottomAccessoryInfo.Feature.Action>)

      @CasePathable
      public enum View: Sendable {
        case liveActivityTestTapped
        case bottomAccessoryInfoTapped
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .liveActivityTestTapped:
            state.liveActivityTest = LiveActivityTest.Feature.State()
            return .none

          case .bottomAccessoryInfoTapped:
            state.bottomAccessoryInfo = BottomAccessoryInfo.Feature.State()
            return .none
          }

        case .liveActivityTest, .bottomAccessoryInfo:
          return .none
        }
      }
      .ifLet(\.$liveActivityTest, action: \.liveActivityTest) {
        LiveActivityTest.Feature()
      }
      .ifLet(\.$bottomAccessoryInfo, action: \.bottomAccessoryInfo) {
        BottomAccessoryInfo.Feature()
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
          Button {
            store.send(.view(.liveActivityTestTapped))
          } label: {
            HStack {
              Image(systemName: "waveform")
                .foregroundStyle(.purple)
                .frame(width: 28)
              Text("LiveActivity 테스트")
              Spacer()
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
          }
          .foregroundStyle(.primary)

          Button {
            store.send(.view(.bottomAccessoryInfoTapped))
          } label: {
            HStack {
              Image(systemName: "rectangle.bottomhalf.inset.filled")
                .foregroundStyle(.blue)
                .frame(width: 28)
              Text("LivePromise 설정")
              Spacer()
              Text(isLivePromiseEnabled ? "켜짐" : "꺼짐")
                .font(.caption)
                .foregroundStyle(isLivePromiseEnabled ? .green : .secondary)
              Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
            }
          }
          .foregroundStyle(.primary)
        } header: {
          Text("UI 테스트")
        }

        Section {
          HStack {
            Text("iOS 버전")
            Spacer()
            Text(UIDevice.current.systemVersion)
              .foregroundStyle(.secondary)
          }

          HStack {
            Text("앱 버전")
            Spacer()
            Text("\(AppConstants.App.version) (\(AppConstants.App.buildNumber))")
              .foregroundStyle(.secondary)
          }
        } header: {
          Text("디바이스 정보")
        }
      }
      .navigationTitle("개발자 설정")
      .navigationBarTitleDisplayMode(.inline)
      .navigationDestination(
        item: $store.scope(state: \.liveActivityTest, action: \.liveActivityTest)
      ) { store in
        LiveActivityTest.RootView(store: store)
      }
      .navigationDestination(
        item: $store.scope(state: \.bottomAccessoryInfo, action: \.bottomAccessoryInfo)
      ) { store in
        BottomAccessoryInfo.RootView(store: store)
      }
    }

    private var isLivePromiseEnabled: Bool {
      UserDefaults.standard.bool(forKey: "dev.livePromise.enabled")
    }
  }
}
