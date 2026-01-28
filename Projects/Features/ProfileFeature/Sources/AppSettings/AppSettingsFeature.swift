//
//  AppSettingsFeature.swift
//  ProfileFeature
//
//  Created by Claude on 2026-01-27.
//

import ComposableArchitecture
import SwiftUI
import PromisoShared

// MARK: - Feature Namespace

/// AppSettings Feature 컴포넌트를 위한 Namespace
public enum AppSettings {}

// MARK: - Feature Implementation

extension AppSettings {

  @Reducer
  public struct Feature {
    public init() {}

    // MARK: - Dependencies

    @Dependency(\.hapticFeedback) var hapticFeedback

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 24시간 형식 사용 여부 (@Shared로 앱 전체 공유, 기본값: 12시간)
      @Shared(.appStorage(AppConstants.UserDefaults.use24HourFormat)) public var use24HourFormat: Bool = false
      /// 현재 사용자 ID
      public let currentUserId: String
      /// 네비게이션 경로
      public var path = StackState<Path.State>()

      public init(currentUserId: String) {
        self.currentUserId = currentUserId
      }

      public static func == (lhs: State, rhs: State) -> Bool {
        lhs.use24HourFormat == rhs.use24HourFormat &&
        lhs.currentUserId == rhs.currentUserId &&
        lhs.path == rhs.path
      }
    }

    // MARK: - Path

    @Reducer(state: .equatable)
    public enum Path {
      case notificationSettings(NotificationSettings.Feature)
      case policyView(PolicyView.Feature)
      case appInfo(AppInfo.Feature)
      #if DEBUG
      case developerSettings(DeveloperSettings.Feature)
      #endif
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
      case path(StackActionOf<Path>)

      @CasePathable
      public enum View: Equatable, Sendable {
        case use24HourFormatChanged(Bool)
        case notificationSettingsTapped
        case privacyPolicyTapped
        case termsOfServiceTapped
        case appInfoTapped
        #if DEBUG
        case developerSettingsTapped
        #endif
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .use24HourFormatChanged(let value):
            state.$use24HourFormat.withLock { $0 = value }
            KoreanDateFormatters.use24HourFormat = value
            return .none

          case .notificationSettingsTapped:
            state.path.append(.notificationSettings(
              NotificationSettings.Feature.State(
                currentUserId: state.currentUserId,
                notificationEnabled: true  // Will load actual value in onAppear
              )
            ))
            return .run { _ in await hapticFeedback.selection() }

          case .privacyPolicyTapped:
            state.path.append(.policyView(
              PolicyView.Feature.State(
                policyType: .privacyPolicy,
                url: URL(string: "https://promiso.app/privacy")!
              )
            ))
            return .run { _ in await hapticFeedback.selection() }

          case .termsOfServiceTapped:
            state.path.append(.policyView(
              PolicyView.Feature.State(
                policyType: .termsOfService,
                url: URL(string: "https://promiso.app/terms")!
              )
            ))
            return .run { _ in await hapticFeedback.selection() }

          case .appInfoTapped:
            state.path.append(.appInfo(AppInfo.Feature.State()))
            return .run { _ in await hapticFeedback.selection() }

          #if DEBUG
          case .developerSettingsTapped:
            state.path.append(.developerSettings(
              DeveloperSettings.Feature.State(currentUserId: state.currentUserId)
            ))
            return .run { _ in await hapticFeedback.selection() }
          #endif
          }

        case .path:
          return .none
        }
      }
      .forEach(\.path, action: \.path)
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStackStore(store.scope(state: \.path, action: \.path)) {
        List {
          // MARK: - 표시 설정
          Section {
            Toggle(isOn: Binding(
              get: { store.use24HourFormat },
              set: { store.send(.view(.use24HourFormatChanged($0))) }
            )) {
              HStack(spacing: 12) {
                Image(systemName: "clock")
                  .font(.body)
                  .foregroundStyle(Color.pmindigo.n500)
                  .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                  Text("24시간 형식")
                    .font(.body)
                    .foregroundStyle(Color.pmtext.primary)

                  Text(store.use24HourFormat ? "예: 14:30" : "예: 오후 2:30")
                    .font(.caption)
                    .foregroundStyle(Color.pmtext.secondary)
                }
              }
            }
            .tint(Color.pmindigo.n500)
          } header: {
            Text("표시")
          } footer: {
            Text("앱 전체에서 사용되는 시간 표시 형식을 설정합니다.\n앱을 재시작하면 적용됩니다.")
          }

          // MARK: - 알림 섹션
          Section {
            menuRow(
              icon: "bell.fill",
              title: "알림 설정",
              action: { store.send(.view(.notificationSettingsTapped)) }
            )
          } header: {
            Text("알림")
          }

          // MARK: - 정보 섹션
          Section {
            menuRow(
              icon: "hand.raised.fill",
              title: "개인정보처리방침",
              action: { store.send(.view(.privacyPolicyTapped)) }
            )

            menuRow(
              icon: "doc.text.fill",
              title: "이용약관",
              action: { store.send(.view(.termsOfServiceTapped)) }
            )

            menuRow(
              icon: "info.circle.fill",
              title: "앱 정보",
              action: { store.send(.view(.appInfoTapped)) }
            )
          } header: {
            Text("정보")
          }

          // MARK: - 개발자 섹션 (DEBUG only)
          #if DEBUG
          Section {
            menuRow(
              icon: "hammer.fill",
              title: "개발자 설정",
              action: { store.send(.view(.developerSettingsTapped)) }
            )
          } header: {
            Text("개발자")
          }
          #endif
        }
        .navigationTitle("앱 설정")
        .navigationBarTitleDisplayMode(.inline)
      } destination: { store in
        switch store.case {
        case .notificationSettings(let store):
          NotificationSettings.RootView(store: store)
        case .policyView(let store):
          PolicyView.RootView(store: store)
        case .appInfo(let store):
          AppInfo.RootView(store: store)
        #if DEBUG
        case .developerSettings(let store):
          DeveloperSettings.RootView(store: store)
        #endif
        }
      }
    }

    // MARK: - Helper Views

    private func menuRow(
      icon: String,
      title: String,
      action: @escaping () -> Void
    ) -> some View {
      Button(action: action) {
        HStack(spacing: 16) {
          Image(systemName: icon)
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24, height: 24)

          Text(title)
            .font(.body)
            .foregroundStyle(Color.pmtext.primary)

          Spacer()

          Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(Color.pmgray.n400)
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }
}

// MARK: - Preview

#Preview("App Settings") {
  AppSettings.RootView(
    store: Store(initialState: AppSettings.Feature.State(currentUserId: "test-user-id")) {
      AppSettings.Feature()
    }
  )
}
