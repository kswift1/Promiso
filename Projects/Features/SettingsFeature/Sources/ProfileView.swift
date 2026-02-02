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

extension Settings {

  /// Profile 화면의 메인 View
  /// .auroraBackground()와 Glass Effect 카드를 사용한 디자인
  public struct ProfileView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    // MARK: - Body

    public var body: some View {
      List {
        // MARK: - 프로필 섹션
        Section {
          Button {
            store.send(.view(.accountInfoTapped))
          } label: {
            profileHeaderRow
          }
          .buttonStyle(.plain)
          .listRowInsets(EdgeInsets())
          .listRowBackground(Color.clear)
        }

        // MARK: - 표시 섹션
        Section {
          HStack(spacing: 12) {
            Image(systemName: "clock")
              .font(.body)
              .foregroundStyle(Color.pmindigo.n500)
              .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 2) {
              Text("24시간 형식")
                .font(.body)
                .foregroundStyle(Color.pmtext.primary)

              Text(store.use24HourFormat ? "예: 14:30" : "예: 오후 2:30")
                .font(.caption)
                .foregroundStyle(Color.pmtext.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
              get: { store.use24HourFormat },
              set: { store.send(.view(.use24HourFormatChanged($0))) }
            ))
            .labelsHidden()
            .tint(Color.pmindigo.n500)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
          .adaptiveGlassBackground()
          .listRowBackground(Color.clear)
          .listRowInsets(EdgeInsets())
        } header: {
          Text("표시")
        } footer: {
          Text("앱 전체에서 사용되는 시간 표시 형식을 설정합니다.\n앱을 재시작하면 적용됩니다.")
        }

        // MARK: - 알림 섹션
        Section {
          menuRow(
            icon: "bell.fill",
            title: "알림 설정",
            action: { store.send(.view(.notificationSettingsTapped)) }
          )
        } header: {
          Text("알림")
        }

        // MARK: - 정보 섹션
        Section {
          menuRow(
            icon: "hand.raised.fill",
            title: "개인정보처리방침",
            action: { store.send(.view(.privacyPolicyTapped)) }
          )

          menuRow(
            icon: "doc.text.fill",
            title: "이용약관",
            action: { store.send(.view(.termsOfServiceTapped)) }
          )

          menuRow(
            icon: "info.circle.fill",
            title: "앱 정보",
            action: { store.send(.view(.appInfoTapped)) }
          )
        } header: {
          Text("정보")
        }

        // MARK: - 개발자 섹션 (DEBUG only)
        #if DEBUG
        Section {
          menuRow(
            icon: "hammer.fill",
            title: "개발자 설정",
            action: { store.send(.view(.developerSettingsTapped)) }
          )
        } header: {
          Text("개발자")
        }
        #endif
      }
      .scrollContentBackground(.hidden)
      .background(Color.clear)
      .auroraBackground()
      .navigationTitle("설정")
      .navigationBarTitleDisplayMode(.large)
      .sheet(
        isPresented: Binding(
          get: { store.isEditingProfile },
          set: { if !$0 { store.send(.view(.cancelEditTapped)) } }
        )
      ) {
        Settings.ProfileEditView(store: store)
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

    // MARK: - Profile Header Row

    private var profileHeaderRow: some View {
      HStack(spacing: 16) {
        // 프로필 아바타 (60px)
        ProfileAvatarView(
          profileImageUrl: store.currentUser.profileImageUrl,
          displayName: store.currentUser.nickname,
          isCurrentUser: true,
          size: 60,
          borderWidth: 2,
          onTap: {
            store.send(.view(.profileImageTapped))
          }
        )

        // 닉네임
        VStack(alignment: .leading, spacing: 4) {
          Text(store.currentUser.nickname)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundStyle(Color.pmtext.primary)
        }

        Spacer()

        // 네비게이션 화살표
        Image(systemName: "chevron.right")
          .font(.caption)
          .foregroundStyle(Color.pmgray.n400)
      }
      .padding(.vertical, 16)
      .padding(.horizontal, 16)
      .contentShape(Rectangle())
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
      .adaptiveGlassBackground()
      .listRowBackground(Color.clear)
      .listRowInsets(EdgeInsets())
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
    Settings.ProfileView(
      store: Store(initialState: Settings.Feature.State(currentUser: Shared(value: .exampleUser))) {
        Settings.Feature()
      }
    )
  }
}

#Preview("Profile View - Loading") {
  NavigationStack {
    Settings.ProfileView(
      store: Store(initialState: Settings.Feature.State(currentUser: Shared(value: .exampleUser), isLoading: true)) {
        Settings.Feature()
      }
    )
  }
}
