//
//  FAQFeature.swift
//  SettingsFeature
//
//  Created by Claude on 2026-02-04.
//

import Clients
import ComposableArchitecture
import PromisoShared
import SwiftUI

// MARK: - Feature Namespace

/// FAQ Feature 컴포넌트를 위한 Namespace
public enum FAQ {}

// MARK: - Feature Implementation

extension FAQ {

  @Reducer
  public struct Feature {

    // MARK: - Dependencies

    @Dependency(\.faqClient) private var faqClient
    @Dependency(\.hapticFeedback) private var hapticFeedback

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      public var faqs: [FAQModel] = []
      public var isLoading: Bool = false
      public var errorMessage: String?
      public var expandedFAQIds: Set<String> = []

      public init() {}
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case onAppear
      case faqTapped(String)
      case retryTapped
    }

    public enum Internal: Equatable, Sendable {
      case faqsLoaded([FAQModel])
      case faqsLoadFailed(String)
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.onAppear):
          guard state.faqs.isEmpty else { return .none }
          state.isLoading = true
          state.errorMessage = nil
          return .run { send in
            do {
              let faqs = try await faqClient.fetchFAQs()
              await send(.internal(.faqsLoaded(faqs)))
            } catch {
              await send(.internal(.faqsLoadFailed(error.localizedDescription)))
            }
          }

        case .view(.faqTapped(let id)):
          if state.expandedFAQIds.contains(id) {
            state.expandedFAQIds.remove(id)
          } else {
            state.expandedFAQIds.insert(id)
          }
          return .run { _ in
            await hapticFeedback.selection()
          }

        case .view(.retryTapped):
          state.isLoading = true
          state.errorMessage = nil
          return .run { send in
            do {
              let faqs = try await faqClient.fetchFAQs()
              await send(.internal(.faqsLoaded(faqs)))
            } catch {
              await send(.internal(.faqsLoadFailed(error.localizedDescription)))
            }
          }

        case .internal(.faqsLoaded(let faqs)):
          state.isLoading = false
          state.faqs = faqs
          return .none

        case .internal(.faqsLoadFailed(let message)):
          state.isLoading = false
          state.errorMessage = message
          return .run { _ in
            await hapticFeedback.error()
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
      Group {
        if store.isLoading {
          loadingView
        } else if let errorMessage = store.errorMessage {
          errorView(message: errorMessage)
        } else if store.faqs.isEmpty {
          emptyView
        } else {
          faqListView
        }
      }
      .scrollContentBackground(.hidden)
      .background(Color.clear)
      .auroraBackground()
      .navigationTitle("자주 묻는 질문")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - FAQ List View

    private var faqListView: some View {
      List {
        Section {
          VStack(spacing: 0) {
            ForEach(Array(store.faqs.enumerated()), id: \.element.id) { index, faq in
              VStack(spacing: 0) {
                if index > 0 {
                  Divider()
                    .padding(.leading, 16)
                }
                faqRow(faq: faq)
              }
            }
          }
          .adaptiveGlassBackground()
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets())
        }
      }
    }

    private func faqRow(faq: FAQModel) -> some View {
      let isExpanded = store.expandedFAQIds.contains(faq.id)

      return Button {
        store.send(.view(.faqTapped(faq.id)))
      } label: {
        VStack(alignment: .leading, spacing: 0) {
          // 질문
          HStack(spacing: 12) {
            Text("Q")
              .font(.headline)
              .fontWeight(.bold)
              .foregroundStyle(Color.pmindigo.n500)

            Text(faq.question)
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)
              .multilineTextAlignment(.leading)

            Spacer()

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
              .font(.caption)
              .foregroundStyle(Color.pmgray.n400)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 14)

          // 답변 (펼쳐진 경우)
          if isExpanded {
            HStack(alignment: .top, spacing: 12) {
              Text("A")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundStyle(Color.pmaurora.purple)

              Text(faq.answer)
                .font(.body)
                .foregroundStyle(Color.pmtext.secondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
            .transition(.opacity.combined(with: .move(edge: .top)))
          }
        }
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.2), value: isExpanded)
      }
      .buttonStyle(.plain)
    }

    // MARK: - Loading View

    private var loadingView: some View {
      VStack(spacing: 16) {
        ProgressView()
          .scaleEffect(1.2)
        Text("FAQ를 불러오는 중...")
          .font(.body)
          .foregroundStyle(Color.pmtext.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Error View

    private func errorView(message: String) -> some View {
      VStack(spacing: 16) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.largeTitle)
          .foregroundStyle(Color.pmwarning.n500)

        Text(message)
          .font(.body)
          .foregroundStyle(Color.pmtext.secondary)
          .multilineTextAlignment(.center)

        Button {
          store.send(.view(.retryTapped))
        } label: {
          Text("다시 시도")
            .font(.body)
            .fontWeight(.medium)
            .foregroundStyle(Color.pmindigo.n500)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .adaptiveGlassBackground()
        }
        .buttonStyle(.plain)
      }
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
      VStack(spacing: 16) {
        Image(systemName: "questionmark.circle")
          .font(.largeTitle)
          .foregroundStyle(Color.pmgray.n400)

        Text("등록된 FAQ가 없습니다")
          .font(.body)
          .foregroundStyle(Color.pmtext.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}
