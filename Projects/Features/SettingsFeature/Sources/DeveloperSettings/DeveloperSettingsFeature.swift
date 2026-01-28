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

    @Dependency(\.userSettingsClient) private var userSettingsClient
    @Dependency(\.hapticFeedback) private var hapticFeedback

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      public let currentUserId: String
      public var plan: UserPlan
      public var isUpdatingPlan: Bool = false
      public var errorMessage: String?

      @Presents var liveActivityTest: LiveActivityTest.Feature.State?
      @Presents var bottomAccessoryInfo: BottomAccessoryInfo.Feature.State?

      public init(
        currentUserId: String,
        plan: UserPlan = .free
      ) {
        self.currentUserId = currentUserId
        self.plan = plan
      }
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case liveActivityTest(PresentationAction<LiveActivityTest.Feature.Action>)
      case bottomAccessoryInfo(PresentationAction<BottomAccessoryInfo.Feature.Action>)

      @CasePathable
      public enum View: Sendable {
        case onAppear
        case planSelected(UserPlan)
        case dismissError
        case liveActivityTestTapped
        case bottomAccessoryInfoTapped
      }

      public enum Internal: Sendable {
        case settingsResponse(Result<UserSettings, Error>)
        case updatePlanResponse(Result<UserPlan, Error>)
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            let currentUserId = state.currentUserId
            return .run { [userSettingsClient] send in
              do {
                let settings = try await userSettingsClient.fetchSettings(currentUserId)
                await send(.internal(.settingsResponse(.success(settings))))
              } catch {
                await send(.internal(.settingsResponse(.failure(error))))
              }
            }

          case .planSelected(let plan):
            guard plan != state.plan else { return .none }
            let currentUserId = state.currentUserId
            state.isUpdatingPlan = true
            state.errorMessage = nil
            return .run { [userSettingsClient, hapticFeedback] send in
              await hapticFeedback.selection()
              do {
                try await userSettingsClient.updatePlan(currentUserId, plan)
                await send(.internal(.updatePlanResponse(.success(plan))))
              } catch {
                await send(.internal(.updatePlanResponse(.failure(error))))
              }
            }

          case .dismissError:
            state.errorMessage = nil
            return .none

          case .liveActivityTestTapped:
            state.liveActivityTest = LiveActivityTest.Feature.State()
            return .none

          case .bottomAccessoryInfoTapped:
            state.bottomAccessoryInfo = BottomAccessoryInfo.Feature.State()
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .settingsResponse(.success(let settings)):
            state.plan = settings.plan
            return .none

          case .settingsResponse(.failure(let error)):
            state.errorMessage = error.localizedDescription
            return .none

          case .updatePlanResponse(.success(let plan)):
            state.plan = plan
            state.isUpdatingPlan = false
            return .run { [hapticFeedback] _ in
              await hapticFeedback.success()
            }

          case .updatePlanResponse(.failure(let error)):
            state.isUpdatingPlan = false
            state.errorMessage = error.localizedDescription
            return .run { [hapticFeedback] _ in
              await hapticFeedback.error()
            }
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
          planRow(title: "무료 플랜", plan: .free)
          planRow(title: "프로 플랜", plan: .pro)
        } header: {
          Text("관리자")
        } footer: {
          Text("프로 플랜에서 그룹별 알림 종류를 선택할 수 있어요.")
        }

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
      .onAppear { store.send(.view(.onAppear)) }
      .alert("오류", isPresented: Binding(
        get: { store.errorMessage != nil },
        set: { if !$0 { store.send(.view(.dismissError)) } }
      )) {
        Button("확인") { store.send(.view(.dismissError)) }
      } message: {
        Text(store.errorMessage ?? "알 수 없는 오류가 발생했습니다.")
      }
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

    private func planRow(title: String, plan: UserPlan) -> some View {
      Button {
        store.send(.view(.planSelected(plan)))
      } label: {
        HStack {
          Text(title)
          Spacer()
          if store.plan == plan {
            Image(systemName: "checkmark.circle.fill")
              .foregroundStyle(.green)
          }
        }
      }
      .disabled(store.isUpdatingPlan)
    }
  }
}
