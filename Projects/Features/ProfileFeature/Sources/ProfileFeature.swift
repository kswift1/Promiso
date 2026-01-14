// MARK: - ProfileFeature.swift
// TCA 1.22.2를 사용한 Profile Feature의 완전한 구현

import ComposableArchitecture
import SwiftUI
import PromisoShared
import Clients
import ResourceKit

// MARK: - Feature Namespace

/// Profile Feature 컴포넌트를 위한 Namespace
public enum Profile {}

// MARK: - Feature Implementation

extension Profile {

  // MARK: - Reducer

  @Reducer
  public struct Feature {
    @Dependency(\.authClient) var authClient
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 현재 사용자 정보
      var currentUser: UserPrivateModel?
      /// 로그아웃 확인 알림 표시 여부
      var showLogoutAlert: Bool = false
      /// 로딩 상태
      var isLoading: Bool = false

      public init(currentUser: UserPrivateModel? = nil) {
        self.currentUser = currentUser
      }
    }

    // MARK: - Action

    public enum Action: Equatable, Sendable {
      // MARK: View Actions
      case view(ViewAction)
      // MARK: Internal Actions
      case _internal(InternalAction)
      // MARK: Delegate Actions
      case delegate(DelegateAction)

      public enum ViewAction: Equatable, Sendable {
        case onAppear
        case logoutButtonTapped
        case logoutConfirmed
        case logoutCancelled
        case editProfileTapped
        case settingsTapped
      }

      public enum InternalAction: Equatable, Sendable {
        case logoutCompleted
        case logoutFailed
      }

      public enum DelegateAction: Equatable, Sendable {
        case logoutRequested
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(.onAppear):
          return .none

        case .view(.logoutButtonTapped):
          state.showLogoutAlert = true
          return .run { _ in
            await hapticFeedback.buttonTap()
          }

        case .view(.logoutConfirmed):
          state.showLogoutAlert = false
          state.isLoading = true
          return .run { send in
            do {
              try await authClient.logout()
              await send(._internal(.logoutCompleted))
            } catch {
              await send(._internal(.logoutFailed))
            }
          }

        case .view(.logoutCancelled):
          state.showLogoutAlert = false
          return .none

        case .view(.editProfileTapped):
          return .run { _ in
            await hapticFeedback.buttonTap()
          }

        case .view(.settingsTapped):
          return .run { _ in
            await hapticFeedback.buttonTap()
          }

        case ._internal(.logoutCompleted):
          state.isLoading = false
          return .send(.delegate(.logoutRequested))

        case ._internal(.logoutFailed):
          state.isLoading = false
          return .none

        case .delegate:
          return .none
        }
      }
    }
  }

  // MARK: - Root View

  public struct RootView: View {
    let store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    // MARK: - Body

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          // Profile Header
          profileHeaderSection

          // Account Info Section
          accountInfoSection

          // Settings Section
          settingsSection

          // Logout Button
          logoutSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
      }
      .background(Color(UIColor.systemGroupedBackground))
      .navigationTitle("프로필")
      .navigationBarTitleDisplayMode(.large)
      .alert(
        "로그아웃",
        isPresented: Binding(
          get: { store.showLogoutAlert },
          set: { newValue in
            if !newValue {
              store.send(.view(.logoutCancelled))
            }
          }
        )
      ) {
        Button("취소", role: .cancel) {
          store.send(.view(.logoutCancelled))
        }
        Button("로그아웃", role: .destructive) {
          store.send(.view(.logoutConfirmed))
        }
      } message: {
        Text("정말 로그아웃 하시겠어요?")
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Profile Header Section

    @ViewBuilder
    private var profileHeaderSection: some View {
      VStack(spacing: 16) {
        // Avatar
        ProfileAvatarView(
          profileImageUrl: store.currentUser?.profileImageUrl,
          displayName: store.currentUser?.displayName ?? "사용자",
          isCurrentUser: true,
          size: 100,
          borderWidth: 3
        )

        // Name & Nickname
        VStack(spacing: 4) {
          Text(store.currentUser?.nickname ?? "닉네임 없음")
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(Color(UIColor.label))

          Text(store.currentUser?.name ?? "이름 없음")
            .font(.subheadline)
            .foregroundColor(Color(UIColor.secondaryLabel))
        }

        // Edit Profile Button
        Button {
          store.send(.view(.editProfileTapped))
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "pencil")
              .font(.subheadline)
            Text("프로필 수정")
              .font(.subheadline)
              .fontWeight(.medium)
          }
          .foregroundColor(Color.pmindigo.n500)
          .padding(.horizontal, 16)
          .padding(.vertical, 8)
        }
        .adaptiveGlassSecondaryButton()
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 24)
      .adaptiveGlassCard()
    }

    // MARK: - Account Info Section

    @ViewBuilder
    private var accountInfoSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("계정 정보")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(Color(UIColor.label))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          // Email
          ProfileInfoRow(
            icon: "envelope.fill",
            title: "이메일",
            value: store.currentUser?.email ?? "-"
          )

          Divider()
            .padding(.leading, 44)

          // Provider
          ProfileInfoRow(
            icon: providerIcon,
            title: "로그인 방식",
            value: providerDisplayName
          )

          Divider()
            .padding(.leading, 44)

          // Join Date
          ProfileInfoRow(
            icon: "calendar",
            title: "가입일",
            value: formattedJoinDate
          )
        }
        .adaptiveGlassCard()
      }
    }

    private var providerIcon: String {
      switch store.currentUser?.provider {
      case "google": return "g.circle.fill"
      case "apple": return "apple.logo"
      default: return "person.circle.fill"
      }
    }

    private var providerDisplayName: String {
      switch store.currentUser?.provider {
      case "google": return "Google"
      case "apple": return "Apple"
      default: return "알 수 없음"
      }
    }

    private var formattedJoinDate: String {
      guard let date = store.currentUser?.metadata.createdAt else { return "-" }
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy년 M월 d일"
      formatter.locale = Locale(identifier: "ko_KR")
      return formatter.string(from: date)
    }

    // MARK: - Settings Section

    @ViewBuilder
    private var settingsSection: some View {
      VStack(alignment: .leading, spacing: 12) {
        Text("설정")
          .font(.headline)
          .fontWeight(.semibold)
          .foregroundColor(Color(UIColor.label))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          SettingsRow(
            icon: "bell.fill",
            title: "알림 설정",
            action: { store.send(.view(.settingsTapped)) }
          )

          Divider()
            .padding(.leading, 44)

          SettingsRow(
            icon: "lock.fill",
            title: "개인정보 처리방침",
            action: { store.send(.view(.settingsTapped)) }
          )

          Divider()
            .padding(.leading, 44)

          SettingsRow(
            icon: "doc.text.fill",
            title: "서비스 이용약관",
            action: { store.send(.view(.settingsTapped)) }
          )

          Divider()
            .padding(.leading, 44)

          SettingsRow(
            icon: "info.circle.fill",
            title: "앱 정보",
            subtitle: "버전 1.0.0",
            action: { store.send(.view(.settingsTapped)) }
          )
        }
        .adaptiveGlassCard()
      }
    }

    // MARK: - Logout Section

    @ViewBuilder
    private var logoutSection: some View {
      Button {
        store.send(.view(.logoutButtonTapped))
      } label: {
        HStack {
          Image(systemName: "rectangle.portrait.and.arrow.right")
            .font(.body)
          Text("로그아웃")
            .font(.body)
            .fontWeight(.medium)
        }
        .foregroundColor(.red)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
      }
      .adaptiveGlassDestructiveButton()
      .disabled(store.isLoading)
      .opacity(store.isLoading ? 0.6 : 1)
    }
  }
}

// MARK: - Supporting Views

private struct ProfileInfoRow: View {
  let icon: String
  let title: String
  let value: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.body)
        .foregroundColor(Color.pmindigo.n500)
        .frame(width: 24, height: 24)

      Text(title)
        .font(.body)
        .foregroundColor(Color(UIColor.label))

      Spacer()

      Text(value)
        .font(.body)
        .foregroundColor(Color(UIColor.secondaryLabel))
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

private struct SettingsRow: View {
  let icon: String
  let title: String
  var subtitle: String? = nil
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.body)
          .foregroundColor(Color.pmindigo.n500)
          .frame(width: 24, height: 24)

        Text(title)
          .font(.body)
          .foregroundColor(Color(UIColor.label))

        Spacer()

        if let subtitle {
          Text(subtitle)
            .font(.subheadline)
            .foregroundColor(Color(UIColor.tertiaryLabel))
        }

        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundColor(Color(UIColor.tertiaryLabel))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }
  }
}

// MARK: - Glass Effect Modifiers

extension View {
  @ViewBuilder
  func adaptiveGlassCard() -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    } else {
      self
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
  }

  @ViewBuilder
  func adaptiveGlassSecondaryButton() -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(
          .regular.tint(Color.pmindigo.n500.opacity(0.14)).interactive(),
          in: .rect(cornerRadius: 10)
        )
    } else {
      self
        .background(Color.pmindigo.n500.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
    }
  }

  @ViewBuilder
  func adaptiveGlassDestructiveButton() -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(
          .regular.tint(Color.red.opacity(0.12)).interactive(),
          in: .rect(cornerRadius: 14)
        )
    } else {
      self
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
    }
  }
}