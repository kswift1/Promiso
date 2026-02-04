//
//  AppInfoFeature.swift
//  SettingsFeature
//
//  Created by Claude on 2026-01-28.
//

import ComposableArchitecture
import SwiftUI
import PromisoShared

// MARK: - Feature Namespace

/// AppInfo Feature 컴포넌트를 위한 Namespace
public enum AppInfo {}

// MARK: - Feature Implementation

extension AppInfo {

  @Reducer
  public struct Feature {

    // MARK: - Dependencies

    @Dependency(\.openURL) private var openURL

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      public let appVersion: String
      public let environment: AppEnvironment?

      public init() {
        let info = Bundle.main.infoDictionary
        self.appVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        self.environment = AppEnvironment.current
      }
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case onAppear
      case linkTapped(String)
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.onAppear):
          return .none

        case .view(.linkTapped(let urlString)):
          guard let url = URL(string: urlString) else { return .none }
          return .run { _ in
            await openURL(url)
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
      ScrollView {
        VStack(spacing: 16) {
          // 버전 정보 섹션
          VStack(spacing: 0) {
            infoRow(icon: "tag.fill", label: "앱 버전", value: store.appVersion)

            // Dev/Stage 환경에서만 환경 정보 표시
            if let environment = store.environment {
              Divider()
                .background(Color.white.opacity(0.12))

              infoRow(
                icon: "flask.fill",
                label: "환경",
                value: environment.displayName,
                valueColor: environment.color
              )
            }
          }
          .adaptiveGlassCard()

          // 추가 정보 섹션
          VStack(alignment: .leading, spacing: 10) {
            Text("추가 정보")
              .font(.system(size: 16, weight: .semibold))
              .padding(.horizontal, 4)

            VStack(spacing: 0) {
              linkRow(
                icon: "book.fill",
                title: "오픈소스 라이선스",
                url: "https://github.com/kswift1/Promiso/blob/main/LICENSES.md"
              )

              Divider()
                .background(Color.white.opacity(0.12))

              linkRow(
                icon: "globe",
                title: "GitHub",
                url: "https://github.com/kswift1/Promiso"
              )
            }
            .adaptiveGlassCard()
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle("앱 정보")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Helper Views

    private func infoRow(
      icon: String,
      label: String,
      value: String,
      valueColor: Color = Color.pmtext.primary
    ) -> some View {
      HStack(spacing: 16) {
        Image(systemName: icon)
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 24, height: 24)

        Text(label)
          .foregroundStyle(Color.pmtext.secondary)

        Spacer()

        Text(value)
          .foregroundStyle(valueColor)
          .font(.subheadline)
          .fontWeight(valueColor != Color.pmtext.primary ? .medium : .regular)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }

    private func linkRow(icon: String, title: String, url: String) -> some View {
      Button {
        store.send(.view(.linkTapped(url)))
      } label: {
        HStack(spacing: 16) {
          Image(systemName: icon)
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24, height: 24)

          Text(title)
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
}

// MARK: - App Environment

/// 앱 환경 (Release는 nil로 처리하여 표시하지 않음)
public enum AppEnvironment: Equatable, Sendable {
  case dev
  case stage

  /// 현재 환경 (Release면 nil 반환)
  public static var current: AppEnvironment? {
    // Bundle ID로 환경 감지
    // com.promiso.dev → Dev
    // com.promiso.stage → Stage
    // com.promiso → Release (nil)
    guard let bundleId = Bundle.main.bundleIdentifier else {
      return nil
    }

    if bundleId.hasSuffix(".dev") {
      return .dev
    } else if bundleId.hasSuffix(".stage") {
      return .stage
    } else {
      // Release 환경에서는 nil 반환 (표시하지 않음)
      return nil
    }
  }

  public var displayName: String {
    switch self {
    case .dev: return "Development"
    case .stage: return "Staging"
    }
  }

  public var color: Color {
    switch self {
    case .dev: return .orange
    case .stage: return .purple
    }
  }
}
