//
//  LegalInfoFeature.swift
//  SettingsFeature
//
//  Created by Claude on 2026-02-02.
//

import ComposableArchitecture
import SwiftUI
import PromisoShared

// MARK: - Feature Namespace

/// LegalInfo Feature 컴포넌트를 위한 Namespace
public enum LegalInfo {}

// MARK: - Feature Implementation

extension LegalInfo {

  @Reducer
  public struct Feature {

    // MARK: - Dependencies

    @Dependency(\.hapticFeedback) private var hapticFeedback

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      public init() {}
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
      case delegate(Delegate)
    }

    @CasePathable
    public enum View: Equatable, Sendable {
      case onAppear
      case privacyPolicyTapped
      case termsOfServiceTapped
    }

    public enum Delegate: Equatable, Sendable {
      case navigateToPolicy(PolicyView.Feature.State.PolicyType, URL)
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.onAppear):
          return .none

        case .view(.privacyPolicyTapped):
          return .run { send in
            await hapticFeedback.selection()
            await send(.delegate(.navigateToPolicy(
              PolicyView.Feature.State.PolicyType.privacyPolicy,
              AppConstants.App.privacyPolicyURL
            )))
          }

        case .view(.termsOfServiceTapped):
          return .run { send in
            await hapticFeedback.selection()
            await send(.delegate(.navigateToPolicy(
              PolicyView.Feature.State.PolicyType.termsOfService,
              AppConstants.App.termsOfServiceURL
            )))
          }

        case .delegate:
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
      List {
        Section {
          VStack(spacing: 0) {
            Button {
              store.send(.view(.privacyPolicyTapped))
            } label: {
              HStack(spacing: 16) {
                Image(systemName: "hand.raised.fill")
                  .font(.body)
                  .foregroundStyle(Color.pmindigo.n500)
                  .frame(width: 24, height: 24)

                Text("개인정보처리방침")
                  .font(.body)
                  .foregroundStyle(Color.pmtext.primary)

                Spacer()

                Image(systemName: "chevron.right")
                  .font(.caption)
                  .foregroundStyle(Color.pmgray.n400)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 14)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()
              .padding(.leading, 56)

            Button {
              store.send(.view(.termsOfServiceTapped))
            } label: {
              HStack(spacing: 16) {
                Image(systemName: "doc.text.fill")
                  .font(.body)
                  .foregroundStyle(Color.pmindigo.n500)
                  .frame(width: 24, height: 24)

                Text("이용약관")
                  .font(.body)
                  .foregroundStyle(Color.pmtext.primary)

                Spacer()

                Image(systemName: "chevron.right")
                  .font(.caption)
                  .foregroundStyle(Color.pmgray.n400)
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 14)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }
          .adaptiveGlassBackground()
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets())
        }
      }
      .scrollContentBackground(.hidden)
      .background(Color.clear)
      .auroraBackground()
      .navigationTitle("약관 및 정책")
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }
  }
}
