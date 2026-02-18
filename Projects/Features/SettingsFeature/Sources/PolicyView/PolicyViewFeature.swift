//
//  PolicyViewFeature.swift
//  SettingsFeature
//
//  Created by Claude on 2026-01-28.
//

import ComposableArchitecture
import SwiftUI
import WebKit

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
      public var isLoading: Bool

      public enum PolicyType: Equatable, Sendable {
        case privacyPolicy
        case termsOfService

        public var title: String {
          switch self {
          case .privacyPolicy:
            return LocalizedStrings.SettingsStrings.privacyPolicyTitle
          case .termsOfService:
            return LocalizedStrings.SettingsStrings.termsOfServiceTitle
          }
        }
      }

      public init(policyType: PolicyType, url: URL) {
        self.policyType = policyType
        self.url = url
        self.isLoading = true
      }
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case onAppear
      case webViewLoaded
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.onAppear):
          return .none

        case .view(.webViewLoaded):
          state.isLoading = false
          return .none
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
      ZStack {
        PolicyWebView(
          url: store.url,
          onLoaded: { store.send(.view(.webViewLoaded)) }
        )
        .ignoresSafeArea(edges: .bottom)

        if store.isLoading {
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.clear)
        }
      }
      .navigationTitle(store.policyType.title)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }
  }

  // MARK: - Policy WebView

  private struct PolicyWebView: UIViewRepresentable {
    let url: URL
    let onLoaded: () -> Void

    func makeCoordinator() -> Coordinator {
      Coordinator(onLoaded: onLoaded)
    }

    func makeUIView(context: Context) -> WKWebView {
      let config = WKWebViewConfiguration()
      let webView = WKWebView(frame: .zero, configuration: config)
      webView.navigationDelegate = context.coordinator
      webView.isOpaque = false
      webView.backgroundColor = .clear
      webView.scrollView.backgroundColor = .clear
      webView.scrollView.showsHorizontalScrollIndicator = false

      // Notion 페이지 로드
      let request = URLRequest(url: url)
      webView.load(request)

      return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
      let onLoaded: () -> Void

      init(onLoaded: @escaping () -> Void) {
        self.onLoaded = onLoaded
      }

      func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Notion 페이지 스타일 조정 (불필요한 UI 숨기기)
        let hideNotionUI = """
          (function() {
            // Notion 상단 바 숨기기
            var topbar = document.querySelector('.notion-topbar');
            if (topbar) topbar.style.display = 'none';

            // Notion 사이드바 숨기기
            var sidebar = document.querySelector('.notion-sidebar');
            if (sidebar) sidebar.style.display = 'none';

            // 여백 조정
            var frame = document.querySelector('.notion-frame');
            if (frame) frame.style.paddingTop = '0px';

            // 페이지 콘텐츠만 보이게
            var page = document.querySelector('.notion-page-content');
            if (page) page.style.paddingTop = '20px';
          })();
        """
        webView.evaluateJavaScript(hideNotionUI, completionHandler: nil)

        onLoaded()
      }

      func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onLoaded()
      }
    }
  }
}
