//
//  AccountInfoView.swift
//  ProfileFeature
//
//  Created by Claude on 2026-01-15.
//

import SwiftUI
import ComposableArchitecture
import ResourceKit
import PromisoShared

// MARK: - AccountInfo Namespace

public enum AccountInfo {}

// MARK: - Feature

extension AccountInfo {

  @Reducer
  public struct Feature {
    public init() {}

    @ObservableState
    public struct State {
      public var currentUser: UserPrivateModel

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
      }
    }

    public enum Action: Sendable {
      case onAppear
    }

    public var body: some ReducerOf<Self> {
      Reduce { _, action in
        switch action {
        case .onAppear:
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

    // MARK: - Computed Properties

    /// 로그인 방식 표시 텍스트
    private var providerDisplayName: String {
      switch store.currentUser.provider.lowercased() {
      case "apple":
        return "Apple"
      case "google":
        return "Google"
      default:
        return store.currentUser.provider
      }
    }

    /// 로그인 방식 아이콘 뷰
    @ViewBuilder
    private var providerIconView: some View {
      switch store.currentUser.provider.lowercased() {
      case "apple":
        Image(systemName: "apple.logo")
          .font(.caption)
          .foregroundStyle(Color.pmtext.primary)
      case "google":
        Image("googleLogo")
          .resizable()
          .scaledToFit()
          .frame(width: 14, height: 14)
      default:
        Image(systemName: "person.circle.fill")
          .font(.caption)
          .foregroundStyle(Color.pmtext.primary)
      }
    }

    /// 가입일 포맷팅
    private var formattedCreatedAt: String {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "ko_KR")
      formatter.dateFormat = "yyyy년 M월 d일"
      return formatter.string(from: store.currentUser.metadata.createdAt)
    }

    // MARK: - Body

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          accountInfoCard
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
      }
      .auroraBackground()
      .navigationTitle("계정 정보")
      .navigationBarTitleDisplayMode(.large)
      .onAppear {
        store.send(.onAppear)
      }
    }

    // MARK: - Account Info Card

    private var accountInfoCard: some View {
      VStack(spacing: 0) {
        // 이메일
        accountInfoRow(
          icon: "envelope.fill",
          title: "이메일",
          value: store.currentUser.email
        )

        Divider()
          .padding(.leading, 56)

        // 로그인 방식
        accountInfoRowWithIcon(
          icon: "key.fill",
          title: "로그인 방식",
          value: providerDisplayName,
          valueIconView: providerIconView
        )

        Divider()
          .padding(.leading, 56)

        // 가입일
        accountInfoRow(
          icon: "calendar",
          title: "가입일",
          value: formattedCreatedAt
        )
      }
      .adaptiveGlassBackground()
    }

    // MARK: - Helper Views

    private func accountInfoRow(
      icon: String,
      title: String,
      value: String
    ) -> some View {
      HStack(spacing: 16) {
        Image(systemName: icon)
          .font(.body)
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 24, height: 24)

        Text(title)
          .font(.body)
          .foregroundStyle(Color.pmtext.secondary)

        Spacer()

        Text(value)
          .font(.body)
          .foregroundStyle(Color.pmtext.primary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }

    private func accountInfoRowWithIcon(
      icon: String,
      title: String,
      value: String,
      valueIconView: some View
    ) -> some View {
      HStack(spacing: 16) {
        Image(systemName: icon)
          .font(.body)
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 24, height: 24)

        Text(title)
          .font(.body)
          .foregroundStyle(Color.pmtext.secondary)

        Spacer()

        HStack(spacing: 6) {
          valueIconView
          Text(value)
            .font(.body)
            .foregroundStyle(Color.pmtext.primary)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
  }
}

// MARK: - Glass Effect Extension

private extension View {
  @ViewBuilder
  func adaptiveGlassBackground() -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    } else {
      self
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
  }
}

// MARK: - Preview

#Preview("Account Info") {
  NavigationStack {
    AccountInfo.RootView(
      store: Store(initialState: AccountInfo.Feature.State(currentUser: .exampleUser)) {
        AccountInfo.Feature()
      }
    )
  }
}
