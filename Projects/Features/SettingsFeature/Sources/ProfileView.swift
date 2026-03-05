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

    #if DEBUG
    // MARK: - Developer Menu

    /// 개발자 메뉴 활성화 여부 (Dev/Stage 환경에서만 표시)
    private var isDeveloperMenuEnabled: Bool {
      guard let bundleId = Bundle.main.bundleIdentifier else { return false }
      return bundleId.contains(".dev") || bundleId.contains(".stage")
    }
    #endif

    // MARK: - Body

    public var body: some View {
      ScrollView {
        VStack(spacing: 16) {
          // MARK: - 프로필 섹션
          Button {
            store.send(.view(.accountInfoTapped))
          } label: {
            profileHeaderRow
          }
          .buttonStyle(.plain)

          // MARK: - 앱 설정 섹션
          VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStrings.SettingsStrings.appSettings)
              .font(.system(size: 16, weight: .semibold))
              .padding(.horizontal, 4)

            VStack(spacing: 0) {
              Button {
                store.send(.view(.dateTimeSettingsTapped))
              } label: {
                HStack(spacing: 16) {
                  Image(systemName: "clock")
                    .font(.body)
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 24, height: 24)

                  Text(LocalizedStrings.SettingsStrings.dateTimeDisplay)
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
                .background(Color.white.opacity(0.12))

              Button {
                store.send(.view(.themeSettingsTapped))
              } label: {
                HStack(spacing: 16) {
                  Image(systemName: "paintbrush.fill")
                    .font(.body)
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 24, height: 24)

                  Text(LocalizedStrings.SettingsStrings.themeMode)
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
                .background(Color.white.opacity(0.12))

              Button {
                store.send(.view(.languageSettingsTapped))
              } label: {
                HStack(spacing: 16) {
                  Image(systemName: "globe")
                    .font(.body)
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 24, height: 24)

                  Text(LocalizedStrings.SettingsStrings.language)
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
                .background(Color.white.opacity(0.12))

              Button {
                store.send(.view(.notificationSettingsTapped))
              } label: {
                HStack(spacing: 16) {
                  Image(systemName: "bell.fill")
                    .font(.body)
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 24, height: 24)

                  Text(LocalizedStrings.SettingsStrings.notifications)
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
                .background(Color.white.opacity(0.12))

              Button {
                store.send(.view(.calendarSettingsTapped))
              } label: {
                HStack(spacing: 16) {
                  Image(systemName: "calendar")
                    .font(.body)
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 24, height: 24)

                  Text(LocalizedStrings.SettingsStrings.calendarSettings)
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
                .background(Color.white.opacity(0.12))

              Button {
                store.send(.view(.promiseTabModeSettingsTapped))
              } label: {
                HStack(spacing: 16) {
                  Image(systemName: "person.2.fill")
                    .font(.body)
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 24, height: 24)

                  Text(LocalizedStrings.SettingsStrings.promiseTabDefaultMode)
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
                .background(Color.white.opacity(0.12))

              Button {
                store.send(.view(.conflictThresholdSettingsTapped))
              } label: {
                HStack(spacing: 16) {
                  Image(systemName: "exclamationmark.triangle")
                    .font(.body)
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 24, height: 24)

                  Text("일정 충돌 감지")
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
            .adaptiveGlassCard()
          }

          // MARK: - 지원 섹션
          Button {
            store.send(.view(.supportTapped))
          } label: {
            HStack(spacing: 16) {
              Image(systemName: "lifepreserver.fill")
                .font(.body)
                .foregroundStyle(Color.pmindigo.n500)
                .frame(width: 24, height: 24)

              Text(LocalizedStrings.SettingsStrings.support)
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
          .adaptiveGlassCard()

          // MARK: - 정보 섹션
          VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStrings.SettingsStrings.info)
              .font(.system(size: 16, weight: .semibold))
              .padding(.horizontal, 4)

            VStack(spacing: 0) {
              Button {
                store.send(.view(.legalInfoTapped))
              } label: {
                HStack(spacing: 16) {
                  Image(systemName: "doc.text.fill")
                    .font(.body)
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 24, height: 24)

                  Text(LocalizedStrings.SettingsStrings.termsAndPolicies)
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
                .background(Color.white.opacity(0.12))

              Button {
                store.send(.view(.appInfoTapped))
              } label: {
                HStack(spacing: 16) {
                  Image(systemName: "info.circle.fill")
                    .font(.body)
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 24, height: 24)

                  Text(LocalizedStrings.SettingsStrings.appInfo)
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
            .adaptiveGlassCard()
          }

          #if DEBUG
          // MARK: - 개발자 섹션 (Dev/Stage only)
          if isDeveloperMenuEnabled {
            VStack(alignment: .leading, spacing: 10) {
              Text(LocalizedStrings.SettingsStrings.developer)
                .font(.system(size: 16, weight: .semibold))
                .padding(.horizontal, 4)

              Button {
                store.send(.view(.developerSettingsTapped))
              } label: {
                HStack(spacing: 16) {
                  Image(systemName: "hammer.fill")
                    .font(.body)
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 24, height: 24)

                  Text(LocalizedStrings.SettingsStrings.developerSettings)
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
              .adaptiveGlassCard()
            }
          }
          #endif
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.SettingsStrings.title)
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

          Text(LocalizedStrings.SettingsStrings.loggingOut)
            .font(.body)
            .foregroundStyle(.white)
        }
        .padding(32)
        .adaptiveGlassCard()
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
      .adaptiveGlassCard()
    }

    // MARK: - Helpers

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
