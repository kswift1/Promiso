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
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    @ObservableState
    public struct State: Equatable {
      public var currentUser: UserPrivateModel
      public var showLogoutAlert: Bool = false
      public var showDeleteAccountAlert: Bool = false

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
      }
    }

    public enum Action: Equatable, Sendable {
      case view(View)
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
    }

    public enum Delegate: Equatable, Sendable {
      case editProfileRequested
      case logoutRequested
      case deleteAccountRequested
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
            return .send(.delegate(.deleteAccountRequested))

          case .deleteAccountCancelled:
            state.showDeleteAccountAlert = false
            return .none
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

    private static let createdAtFormatter: DateFormatter = {
      let formatter = DateFormatter()
      formatter.locale = Locale(identifier: "ko_KR")
      formatter.dateFormat = "yyyy년 M월 d일"
      return formatter
    }()

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
      Self.createdAtFormatter.string(from: store.currentUser.metadata.createdAt)
    }

    // MARK: - Body

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          // 계정 정보 카드
          accountInfoCard

          // 프로필 편집
          profileEditButton

          // 계정 관리 (로그아웃, 탈퇴)
          accountManagementSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
      }
      .auroraBackground()
      .navigationTitle("계정 정보")
      .navigationBarTitleDisplayMode(.large)
      .alert(
        "로그아웃",
        isPresented: Binding(
          get: { store.showLogoutAlert },
          set: { if !$0 { store.send(.view(.logoutCancelled)) } }
        )
      ) {
        Button("취소", role: .cancel) {
          store.send(.view(.logoutCancelled))
        }
        Button("로그아웃", role: .destructive) {
          store.send(.view(.logoutConfirmed))
        }
      } message: {
        Text("정말 로그아웃 하시겠습니까?")
      }
      .alert(
        "회원 탈퇴",
        isPresented: Binding(
          get: { store.showDeleteAccountAlert },
          set: { if !$0 { store.send(.view(.deleteAccountCancelled)) } }
        )
      ) {
        Button("취소", role: .cancel) {
          store.send(.view(.deleteAccountCancelled))
        }
        Button("탈퇴하기", role: .destructive) {
          store.send(.view(.deleteAccountConfirmed))
        }
      } message: {
        Text("탈퇴 시 모든 데이터가 삭제되며 복구할 수 없습니다.")
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Profile Edit Button

    private var profileEditButton: some View {
      Button {
        store.send(.view(.editProfileTapped))
      } label: {
        HStack(spacing: 16) {
          Image(systemName: "person.crop.circle.fill")
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24, height: 24)

          Text("프로필 편집")
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
      .adaptiveGlassBackground()
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

            Text("로그아웃")
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

            Text("탈퇴하기 (TODO)")
              .font(.body)
              .foregroundStyle(Color.pmerror.n500)

            Spacer()
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
      }
      .adaptiveGlassBackground()
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
