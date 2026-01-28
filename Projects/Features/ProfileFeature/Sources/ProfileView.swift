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

          // 계정 섹션
          accountSection

          // 알림 섹션
          notificationSection

          // 정보 섹션
          infoSection

          // 개발자 섹션 (DEBUG only)
          #if DEBUG
          developerSection
          #endif
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
      }
      .auroraBackground()
      .navigationTitle("프로필")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button {
            store.send(.view(.appSettingsTapped))
          } label: {
            Image(systemName: "gearshape.fill")
              .font(.body)
              .foregroundStyle(Color.pmindigo.n500)
          }
        }
      }
      .sheet(
        isPresented: Binding(
          get: { store.isEditingProfile },
          set: { if !$0 { store.send(.view(.cancelEditTapped)) } }
        )
      ) {
        Profile.ProfileEditView(store: store)
      }
      .overlay {
        if store.isLoading {
          loadingOverlay
        }
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
      .fullScreenCover(
        isPresented: Binding(
          get: { store.showImageDetail },
          set: { if !$0 { store.send(.view(.imageDetailDismissed)) } }
        )
      ) {
        ImageDetailView(
          imageUrl: store.currentUser.profileImageUrl,
          displayName: store.currentUser.nickname,
          onDismiss: {
            store.send(.view(.imageDetailDismissed))
          }
        )
        .presentationBackground(.black)
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
          borderWidth: 3,
          onTap: {
            store.send(.view(.profileImageTapped))
          }
        )

        // 닉네임
        Text(store.currentUser.nickname)
          .font(.title2)
          .fontWeight(.bold)
          .foregroundStyle(Color.pmtext.primary)

        // 통계
        HStack(spacing: 24) {
          statItem(title: "그룹", count: store.groupCount)

          Divider()
            .frame(height: 40)

          statItem(title: "약속", count: store.promiseCount)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 24)
      .adaptiveGlassBackground()
    }

    // MARK: - Sections

    /// 통계 아이템 (그룹 수, 약속 수)
    private func statItem(title: String, count: Int) -> some View {
      VStack(spacing: 4) {
        Text("\(count)")
          .font(.title3)
          .fontWeight(.semibold)
          .foregroundStyle(Color.pmindigo.n500)

        Text(title)
          .font(.caption)
          .foregroundStyle(Color.pmtext.secondary)
      }
    }

    /// 계정 섹션
    private var accountSection: some View {
      VStack(spacing: 0) {
        menuRow(
          icon: "person.text.rectangle.fill",
          title: "계정 정보",
          action: { store.send(.view(.accountInfoTapped)) }
        )
      }
      .adaptiveGlassBackground()
    }

    /// 알림 섹션
    private var notificationSection: some View {
      VStack(spacing: 0) {
        menuRow(
          icon: "bell.fill",
          title: "알림 설정",
          action: { store.send(.view(.notificationSettingsTapped)) }
        )
      }
      .adaptiveGlassBackground()
    }

    /// 정보 섹션
    private var infoSection: some View {
      VStack(spacing: 0) {
        menuRow(
          icon: "hand.raised.fill",
          title: "개인정보처리방침",
          action: { store.send(.view(.privacyPolicyTapped)) }
        )

        Divider()
          .padding(.leading, 56)

        menuRow(
          icon: "doc.text.fill",
          title: "이용약관",
          action: { store.send(.view(.termsOfServiceTapped)) }
        )

        Divider()
          .padding(.leading, 56)

        menuRow(
          icon: "info.circle.fill",
          title: "앱 정보",
          action: { store.send(.view(.appInfoTapped)) }
        )
      }
      .adaptiveGlassBackground()
    }

    /// 개발자 섹션 (DEBUG only)
    private var developerSection: some View {
      VStack(spacing: 0) {
        menuRow(
          icon: "hammer.fill",
          title: "개발자 설정",
          action: { store.send(.view(.developerSettingsTapped)) }
        )
      }
      .adaptiveGlassBackground()
    }

    // MARK: - Helpers

    private func menuRow(
      icon: String,
      title: String,
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
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
  }
}

// MARK: - Preview

#Preview("Profile View") {
  NavigationStack {
    Profile.ProfileView(
      store: Store(initialState: Profile.Feature.State(currentUser: Shared(value: .exampleUser))) {
        Profile.Feature()
      }
    )
  }
}

#Preview("Profile View - Loading") {
  NavigationStack {
    Profile.ProfileView(
      store: Store(initialState: Profile.Feature.State(currentUser: Shared(value: .exampleUser), isLoading: true)) {
        Profile.Feature()
      }
    )
  }
}
