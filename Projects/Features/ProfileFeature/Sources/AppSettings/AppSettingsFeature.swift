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

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 24시간 형식 사용 여부 (@Shared로 앱 전체 공유, 기본값: 12시간)
      @Shared(.appStorage(AppConstants.UserDefaults.use24HourFormat)) public var use24HourFormat: Bool = false

      public init() {}
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)

      @CasePathable
      public enum View: Equatable, Sendable {
        case use24HourFormatChanged(Bool)
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
          }
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    private let store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      List {
        // MARK: - 시간 표시 설정
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
          Text("시간 표시")
        } footer: {
          Text("앱 전체에서 사용되는 시간 표시 형식을 설정합니다.\n앱을 재시작하면 적용됩니다.")
        }
      }
      .navigationTitle("앱 설정")
      .navigationBarTitleDisplayMode(.inline)
    }
  }
}

// MARK: - Preview

#Preview("App Settings") {
  NavigationStack {
    AppSettings.RootView(
      store: Store(initialState: AppSettings.Feature.State()) {
        AppSettings.Feature()
      }
    )
  }
}
