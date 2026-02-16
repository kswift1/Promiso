//
//  AccountInfoView.swift
//  ProfileFeature
//
//  Created by Claude on 2026-01-15.
//

import Clients
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
    @Dependency(\.hapticFeedback) var hapticFeedback
    @Dependency(\.authClient) var authClient

    public init() {}

    @ObservableState
    public struct State: Equatable {
      public var currentUser: UserPrivateModel
      public var showLogoutAlert: Bool = false
      public var showDeleteAccountAlert: Bool = false
      public var isDeletingAccount: Bool = false
      public var deleteAccountError: String?

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
      }
    }

    public enum Action: Equatable, Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
    }

    public enum View: Equatable, Sendable {
      case onAppear
      case editProfileTapped
      case logoutTapped
      case logoutConfirmed
      case logoutCancelled
      case deleteAccountTapped
      case deleteAccountConfirmed
      case deleteAccountCancelled
      case dismissDeleteAccountError
    }

    public enum Internal: Equatable, Sendable {
      case deleteAccountCompleted
      case deleteAccountFailed(String)
    }

    public enum Delegate: Equatable, Sendable {
      case editProfileRequested
      case logoutRequested
      case deleteAccountRequested
      case didDeleteAccount
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .none

          case .editProfileTapped:
            return .run { send in
              await hapticFeedback.selection()
              await send(.delegate(.editProfileRequested))
            }

          case .logoutTapped:
            state.showLogoutAlert = true
            return .run { _ in
              await hapticFeedback.medium()
            }

          case .logoutConfirmed:
            state.showLogoutAlert = false
            return .send(.delegate(.logoutRequested))

          case .logoutCancelled:
            state.showLogoutAlert = false
            return .none

          case .deleteAccountTapped:
            state.showDeleteAccountAlert = true
            return .run { _ in
              await hapticFeedback.medium()
            }

          case .deleteAccountConfirmed:
            state.showDeleteAccountAlert = false
            state.isDeletingAccount = true
            state.deleteAccountError = nil
            return .run { send in
              do {
                try await authClient.deleteAccount()
                await send(.internal(.deleteAccountCompleted))
              } catch {
                await send(.internal(.deleteAccountFailed(error.localizedDescription)))
              }
            }

          case .deleteAccountCancelled:
            state.showDeleteAccountAlert = false
            return .none

          case .dismissDeleteAccountError:
            state.deleteAccountError = nil
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .deleteAccountCompleted:
            state.isDeletingAccount = false
            return .run { send in
              await hapticFeedback.success()
              await send(.delegate(.didDeleteAccount))
            }

          case .deleteAccountFailed(let error):
            state.isDeletingAccount = false
            state.deleteAccountError = error
            return .run { _ in
              await hapticFeedback.error()
            }
          }

        case .delegate:
          return .none
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    // MARK: - Static Properties

    private static let createdAtFormatter = KoreanDateFormatters.yearMonthDay

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
        ResourceKitAsset.googleLogo.swiftUIImage
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
      Self.createdAtFormatter.string(from: store.currentUser.metadata.createdAt)
    }

    // MARK: - Body

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          // 계정 정보 카드
          accountInfoCard

          // 계정 관리 (로그아웃, 탈퇴)
          accountManagementSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.accountInfo)
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            store.send(.view(.editProfileTapped))
          } label: {
            Text(LocalizedStrings.Common.edit)
              .font(.body)
              .foregroundStyle(Color.pmindigo.n500)
          }
        }
      }
      .alert(
        LocalizedStrings.SettingsStrings.logout,
        isPresented: Binding(
          get: { store.showLogoutAlert },
          set: { if !$0 { store.send(.view(.logoutCancelled)) } }
        )
      ) {
        Button(LocalizedStrings.Common.cancel, role: .cancel) {
          store.send(.view(.logoutCancelled))
        }
        Button(LocalizedStrings.SettingsStrings.logout, role: .destructive) {
          store.send(.view(.logoutConfirmed))
        }
      } message: {
        Text(LocalizedStrings.SettingsStrings.logoutConfirm)
      }
      .alert(
        LocalizedStrings.SettingsStrings.deleteAccountTitle,
        isPresented: Binding(
          get: { store.showDeleteAccountAlert },
          set: { if !$0 { store.send(.view(.deleteAccountCancelled)) } }
        )
      ) {
        Button(LocalizedStrings.Common.cancel, role: .cancel) {
          store.send(.view(.deleteAccountCancelled))
        }
        Button(LocalizedStrings.SettingsStrings.deleteAccount, role: .destructive) {
          store.send(.view(.deleteAccountConfirmed))
        }
      } message: {
        Text(LocalizedStrings.SettingsStrings.deleteAccountConfirm)
      }
      .alert(
        LocalizedStrings.SettingsStrings.deleteAccountFailed,
        isPresented: Binding(
          get: { store.deleteAccountError != nil },
          set: { if !$0 { store.send(.view(.dismissDeleteAccountError)) } }
        )
      ) {
        Button(LocalizedStrings.Common.confirm) {
          store.send(.view(.dismissDeleteAccountError))
        }
      } message: {
        if let error = store.deleteAccountError {
          Text(error)
        }
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Account Management Section

    private var accountManagementSection: some View {
      VStack(spacing: 0) {
        // 로그아웃
        Button {
          store.send(.view(.logoutTapped))
        } label: {
          HStack(spacing: 16) {
            Image(systemName: "rectangle.portrait.and.arrow.right")
              .font(.body)
              .foregroundStyle(Color.pmindigo.n500)
              .frame(width: 24, height: 24)

            Text(LocalizedStrings.SettingsStrings.logout)
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Spacer()
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        Divider()
          .padding(.leading, 56)

        // 탈퇴하기
        Button {
          store.send(.view(.deleteAccountTapped))
        } label: {
          HStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.minus")
              .font(.body)
              .foregroundStyle(Color.pmerror.n500)
              .frame(width: 24, height: 24)

            Text(LocalizedStrings.SettingsStrings.deleteAccount)
              .font(.body)
              .foregroundStyle(Color.pmerror.n500)

            Spacer()

            if store.isDeletingAccount {
              ProgressView()
                .scaleEffect(0.8)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(store.isDeletingAccount)
      }
      .adaptiveGlassBackground()
    }

    // MARK: - Account Info Card

    private var accountInfoCard: some View {
      VStack(spacing: 0) {
        // 이메일
        accountInfoRow(
          icon: "envelope.fill",
          title: LocalizedStrings.SettingsStrings.email,
          value: store.currentUser.email
        )

        Divider()
          .padding(.leading, 56)

        // 로그인 방식
        accountInfoRowWithIcon(
          icon: "key.fill",
          title: LocalizedStrings.SettingsStrings.loginMethod,
          value: providerDisplayName,
          valueIconView: providerIconView
        )

        Divider()
          .padding(.leading, 56)

        // 가입일
        accountInfoRow(
          icon: "calendar",
          title: LocalizedStrings.SettingsStrings.joinDate,
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
