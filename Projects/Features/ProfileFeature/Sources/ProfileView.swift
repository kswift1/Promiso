//
//  ProfileView.swift
//  ProfileFeature
//
//  Created by Claude on 2026-01-15.
//

import SwiftUI
import ComposableArchitecture
import ResourceKit
import PromisoShared

// MARK: - Profile View

extension Profile {

  /// Profile 화면의 메인 View
  /// .auroraBackground()와 Glass Effect 카드를 사용한 디자인
  public struct ProfileView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    // MARK: - Body

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          // 프로필 헤더 섹션
          profileHeaderSection

          // 설정 메뉴 섹션 (계정 정보 포함)
          settingsMenuSection

          // 로그아웃 버튼
          logoutButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
      }
      .auroraBackground()
      .navigationTitle("프로필")
      .navigationBarTitleDisplayMode(.large)
      .sheet(
        isPresented: Binding(
          get: { store.isEditingProfile },
          set: { if !$0 { store.send(.view(.cancelEditTapped)) } }
        )
      ) {
        Profile.ProfileEditView(store: store)
      }
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
        Text("정말 로그아웃 하시겠습니까?")
      }
      .overlay {
        if store.isLoading {
          loadingOverlay
        }
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
      ZStack {
        Color.black.opacity(0.3)
          .ignoresSafeArea()

        VStack(spacing: 16) {
          ProgressView()
            .scaleEffect(1.2)
            .tint(.white)

          Text("로그아웃 중...")
            .font(.body)
            .foregroundStyle(.white)
        }
        .padding(32)
        .adaptiveGlassBackground()
      }
    }

    // MARK: - Profile Header Section

    private var profileHeaderSection: some View {
      VStack(spacing: 16) {
        // 프로필 아바타 (100px)
        ProfileAvatarView(
          profileImageUrl: store.currentUser.profileImageUrl,
          displayName: store.currentUser.nickname,
          isCurrentUser: true,
          size: 100,
          borderWidth: 3
        )

        // 닉네임
        Text(store.currentUser.nickname)
          .font(.title2)
          .fontWeight(.bold)
          .foregroundStyle(Color.pmtext.primary)
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 24)
      .adaptiveGlassBackground()
    }

    // MARK: - Settings Menu Section

    private var settingsMenuSection: some View {
      VStack(spacing: 0) {
        // 계정 정보
        settingsMenuRow(
          icon: "person.text.rectangle.fill",
          title: "계정 정보",
          action: { store.send(.view(.accountInfoTapped)) }
        )

        Divider()
          .padding(.leading, 56)

        // 프로필 편집
        settingsMenuRow(
          icon: "person.crop.circle.fill",
          title: "프로필 편집",
          action: { store.send(.view(.editProfileTapped)) }
        )

        Divider()
          .padding(.leading, 56)

        // 알림 설정
        settingsMenuRow(
          icon: "bell.fill",
          title: "알림 설정",
          action: { store.send(.view(.notificationSettingsTapped)) }
        )

        Divider()
          .padding(.leading, 56)

        // 개인정보처리방침
        settingsMenuRow(
          icon: "hand.raised.fill",
          title: "개인정보처리방침",
          action: { store.send(.view(.privacyPolicyTapped)) }
        )

        Divider()
          .padding(.leading, 56)

        // 이용약관
        settingsMenuRow(
          icon: "doc.text.fill",
          title: "이용약관",
          action: { store.send(.view(.termsOfServiceTapped)) }
        )

        Divider()
          .padding(.leading, 56)

        // 앱 정보
        settingsMenuRow(
          icon: "info.circle.fill",
          title: "앱 정보",
          showVersion: true,
          action: { store.send(.view(.appInfoTapped)) }
        )
      }
      .adaptiveGlassBackground()
    }

    private func settingsMenuRow(
      icon: String,
      title: String,
      showVersion: Bool = false,
      action: @escaping () -> Void
    ) -> some View {
      Button(action: action) {
        HStack(spacing: 16) {
          Image(systemName: icon)
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24, height: 24)

          Text(title)
            .font(.body)
            .foregroundStyle(Color.pmtext.primary)

          Spacer()

          if showVersion {
            Text(appVersion)
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary)
          }

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

    /// 앱 버전 정보
    private var appVersion: String {
      let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
      let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
      return "\(version) (\(build))"
    }

    // MARK: - Logout Button

    private var logoutButton: some View {
      Button {
        store.send(.view(.logoutTapped))
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "rectangle.portrait.and.arrow.right")
            .font(.body.weight(.medium))

          Text("로그아웃")
            .font(.body.weight(.semibold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(
          Color.pmerror.n500,
          in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .shadow(color: Color.pmerror.n500.opacity(0.3), radius: 12, y: 6)
      }
      .buttonStyle(.plain)
      .disabled(store.isLoading)
      .opacity(store.isLoading ? 0.6 : 1)
      .padding(.top, 8)
    }
  }
}

// MARK: - Glass Effect Modifier Extension (Local)

private extension View {
  /// 카드 배경용 Glass Effect
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

#Preview("Profile View") {
  NavigationStack {
    Profile.ProfileView(
      store: Store(initialState: Profile.Feature.State()) {
        Profile.Feature()
      }
    )
  }
}

#Preview("Profile View - Loading") {
  NavigationStack {
    Profile.ProfileView(
      store: Store(initialState: Profile.Feature.State(isLoading: true)) {
        Profile.Feature()
      }
    )
  }
}
