//
//  PolicyViewFeature.swift
//  ProfileFeature
//
//  Created by Claude on 2026-01-28.
//

import ComposableArchitecture
import SwiftUI
import SafariServices

// MARK: - Feature Namespace

/// PolicyView Feature 컴포넌트를 위한 Namespace
public enum PolicyView {}

// MARK: - Feature Implementation

extension PolicyView {

  @Reducer
  public struct Feature {
    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      public let policyType: PolicyType
      public let url: URL

      public enum PolicyType: String {
        case privacyPolicy = "개인정보처리방침"
        case termsOfService = "이용약관"
      }

      public init(policyType: PolicyType, url: URL) {
        self.policyType = policyType
        self.url = url
      }
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case onAppear
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.onAppear):
          return .none
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
      SafariView(url: store.url)
        .navigationTitle(store.policyType.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
          store.send(.view(.onAppear))
        }
    }
  }

  // MARK: - Safari View Wrapper

  private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
      let config = SFSafariViewController.Configuration()
      config.entersReaderIfAvailable = true
      let controller = SFSafariViewController(url: url, configuration: config)
      controller.preferredControlTintColor = UIColor(Color.pmindigo.n500)
      return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
  }
}
