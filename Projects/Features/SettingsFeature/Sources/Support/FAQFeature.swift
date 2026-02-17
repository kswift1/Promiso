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
      public var selectedCategory: String? = nil  // nil = 전체

      /// 사용 가능한 카테고리 목록
      public var availableCategories: [String] {
        let categories = Set(faqs.compactMap(\.category))
        return categories.sorted()
      }

      /// 선택된 카테고리로 필터링된 FAQ
      public var filteredFAQs: [FAQModel] {
        guard let category = selectedCategory else {
          return faqs
        }
        return faqs.filter { $0.category == category }
      }

      public init() {}
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case onAppear
      case faqTapped(String)
      case retryTapped
      case categorySelected(String?)  // nil = 전체
    }

    @CasePathable
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
            } catch let faqError as FAQClientError {
              await send(.internal(.faqsLoadFailed(faqError.localizedMessage)))
            } catch {
              await send(.internal(.faqsLoadFailed(LocalizedStrings.Error.unknownError)))
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
          return .send(.view(.onAppear))

        case .view(.categorySelected(let category)):
          state.selectedCategory = category
          // 필터 변경해도 모두 펼침 유지 (변경 후 filteredFAQs 사용)
          let filteredIds = state.filteredFAQs.map(\.id)
          state.expandedFAQIds.formUnion(filteredIds)
          return .run { _ in
            await hapticFeedback.selection()
          }

        case .internal(.faqsLoaded(let faqs)):
          state.isLoading = false
          state.faqs = faqs
          // 기본으로 모든 FAQ 펼침
          state.expandedFAQIds = Set(faqs.map(\.id))
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
      .navigationTitle(LocalizedStrings.SettingsStrings.faqTitle)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - FAQ List View

    private var faqListView: some View {
      ScrollView {
        VStack(spacing: 16) {
          // 카테고리 필터
          categoryFilterView
            .padding(.horizontal, 16)

          // FAQ 목록
          LazyVStack(spacing: 12) {
            ForEach(store.filteredFAQs) { faq in
              faqRow(faq: faq)
                .adaptiveGlassCard()
            }
          }
          .padding(.horizontal, 16)
        }
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
    }

    // MARK: - Category Filter View

    private var categoryFilterView: some View {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          // 전체 버튼
          categoryChip(title: LocalizedStrings.SettingsStrings.faqAll, isSelected: store.selectedCategory == nil) {
            store.send(.view(.categorySelected(nil)), animation: .easeInOut(duration: 0.3))
          }

          // 각 카테고리 버튼
          ForEach(store.availableCategories, id: \.self) { category in
            categoryChip(
              title: category,
              isSelected: store.selectedCategory == category
            ) {
              store.send(.view(.categorySelected(category)), animation: .easeInOut(duration: 0.3))
            }
          }
        }
      }
    }

    private func categoryChip(
      title: String,
      isSelected: Bool,
      action: @escaping () -> Void
    ) -> some View {
      Button(action: action) {
        Text(title)
          .font(.subheadline)
          .fontWeight(isSelected ? .semibold : .regular)
          .foregroundStyle(isSelected ? Color.white : Color.pmtext.primary)
          .padding(.horizontal, 14)
          .padding(.vertical, 8)
          .background {
            if isSelected {
              Capsule()
                .fill(Color.pmindigo.n500)
            } else {
              Capsule()
                .fill(Color.pmgray.n100.opacity(0.5))
            }
          }
      }
      .buttonStyle(.plain)
      .animation(.easeInOut(duration: 0.2), value: isSelected)
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

            Image(systemName: "chevron.down")
              .font(.caption)
              .foregroundStyle(Color.pmgray.n400)
              .rotationEffect(.degrees(isExpanded ? -180 : 0))
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 14)

          // 답변
          if isExpanded {
            Divider()
              .padding(.leading, 44)

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
            .padding(.vertical, 14)
          }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }

    // MARK: - Loading View

    private var loadingView: some View {
      VStack(spacing: 16) {
        ProgressView()
          .scaleEffect(1.2)
        Text(LocalizedStrings.SettingsStrings.faqLoading)
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
          Text(LocalizedStrings.SettingsStrings.faqRetry)
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

        Text(LocalizedStrings.SettingsStrings.faqEmpty)
          .font(.body)
          .foregroundStyle(Color.pmtext.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }
}

// MARK: - FAQClientError Localization

extension FAQClientError {
  var localizedMessage: String {
    switch self {
    case .fetchFailed(_, _): return LocalizedStrings.Error.faqFetchFailed
    case .decodingFailed(_): return LocalizedStrings.Error.faqDecodingFailed
    case .invalidConfiguration: return LocalizedStrings.Error.faqInvalidConfiguration
    }
  }
}
