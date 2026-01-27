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
      /// 24시간 형식 사용 여부
      public var use24HourFormat: Bool

      public init() {
        // UserDefaults에서 초기값 로드
        self.use24HourFormat = UserDefaults.standard.bool(forKey: "use24HourFormat")
        // 기본값이 false인 경우 true로 설정 (처음 실행 시)
        if !UserDefaults.standard.bool(forKey: "use24HourFormatInitialized") {
          self.use24HourFormat = true
          UserDefaults.standard.set(true, forKey: "use24HourFormat")
          UserDefaults.standard.set(true, forKey: "use24HourFormatInitialized")
        }
      }
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)

      @CasePathable
      public enum View: Equatable, Sendable {
        case onAppear
        case use24HourFormatToggled(Bool)
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            // KoreanDateFormatters 동기화
            KoreanDateFormatters.use24HourFormat = state.use24HourFormat
            return .none

          case .use24HourFormatToggled(let value):
            state.use24HourFormat = value
            // UserDefaults에 저장
            UserDefaults.standard.set(value, forKey: "use24HourFormat")
            // KoreanDateFormatters 업데이트
            KoreanDateFormatters.use24HourFormat = value
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
        // MARK: - 시간 표시 설정
        Section {
          Toggle(isOn: Binding(
            get: { store.use24HourFormat },
            set: { store.send(.view(.use24HourFormatToggled($0))) }
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
          Text("앱 전체에서 사용되는 시간 표시 형식을 설정합니다.")
        }
      }
      .navigationTitle("앱 설정")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
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
