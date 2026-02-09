// MARK: - DeveloperSettingsFeature.swift
// 개발자 설정 화면 Feature (#if DEBUG 전용)

import ComposableArchitecture
import Clients
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

    @Dependency(\.hapticFeedback) private var hapticFeedback

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
        case crashTestTapped
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

          case .crashTestTapped:
            // Crashlytics 테스트를 위한 의도적 크래시
            fatalError("🧪 Crashlytics Test Crash - This is intentional for testing Firebase Crashlytics")
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
      ScrollView {
        VStack(spacing: 16) {
          // UI 테스트 섹션
          VStack(alignment: .leading, spacing: 10) {
            Text("UI 테스트")
              .font(.system(size: 16, weight: .semibold))
              .padding(.horizontal, 4)

            VStack(spacing: 0) {
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
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .foregroundStyle(.primary)

              Divider()
                .background(Color.white.opacity(0.12))

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
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .foregroundStyle(.primary)

              Divider()
                .background(Color.white.opacity(0.12))

              Button {
                store.send(.view(.crashTestTapped))
              } label: {
                HStack {
                  Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .frame(width: 28)
                  Text("Crashlytics 테스트")
                  Spacer()
                  Text("크래시 발생")
                    .font(.caption)
                    .foregroundStyle(.red)
                  Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              .foregroundStyle(.primary)
            }
            .adaptiveGlassCard()
          }

          // 디바이스 정보 섹션
          VStack(alignment: .leading, spacing: 10) {
            Text("디바이스 정보")
              .font(.system(size: 16, weight: .semibold))
              .padding(.horizontal, 4)

            VStack(spacing: 0) {
              HStack {
                Text("iOS 버전")
                Spacer()
                Text(UIDevice.current.systemVersion)
                  .foregroundStyle(.secondary)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 14)

              Divider()
                .background(Color.white.opacity(0.12))

              HStack {
                Text("앱 버전")
                Spacer()
                Text("\(AppConstants.App.version) (\(AppConstants.App.buildNumber))")
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
