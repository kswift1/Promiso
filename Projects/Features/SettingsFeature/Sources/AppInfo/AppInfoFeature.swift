//
//  AppInfoFeature.swift
//  ProfileFeature
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
      public let buildNumber: String
      public let bundleIdentifier: String

      public init() {
        let info = Bundle.main.infoDictionary
        self.appVersion = info?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        self.buildNumber = info?["CFBundleVersion"] as? String ?? "1"
        self.bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.promiso"
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
      List {
        // 버전 정보 섹션
        Section {
          infoRow(icon: "tag.fill", label: "앱 버전", value: store.appVersion)
          infoRow(icon: "hammer.fill", label: "빌드 번호", value: store.buildNumber)
          infoRow(icon: "app.fill", label: "Bundle ID", value: store.bundleIdentifier)
        } header: {
          Text("버전 정보")
        }

        // 추가 정보 섹션
        Section {
          linkRow(
            icon: "book.fill",
            title: "오픈소스 라이선스",
            url: "https://github.com/kswift1/Promiso/blob/main/LICENSES.md"
          )
          linkRow(
            icon: "globe",
            title: "GitHub",
            url: "https://github.com/kswift1/Promiso"
          )
        } header: {
          Text("추가 정보")
        }

        // 푸터
        Section {
          Text("Made with ❤️ by Promiso Team")
            .font(.caption)
            .foregroundStyle(Color.pmtext.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
        }
      }
      .navigationTitle("앱 정보")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Helper Views

    private func infoRow(icon: String, label: String, value: String) -> some View {
      HStack(spacing: 16) {
        Image(systemName: icon)
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 24, height: 24)

        Text(label)
          .foregroundStyle(Color.pmtext.secondary)

        Spacer()

        Text(value)
          .foregroundStyle(Color.pmtext.primary)
          .font(.subheadline)
      }
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
      }
    }
  }
}
