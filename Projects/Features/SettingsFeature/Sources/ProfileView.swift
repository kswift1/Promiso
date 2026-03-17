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
    @State private var currentBenefitIndex = 0
    @State private var benefitTimer: Timer?

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    // MARK: - Pro Benefit Rotation

    private let proBenefits: [(icon: String, text: String)] = [
      ("🕐", "출발 시간 자동 계산"),
      ("🌤️", "약속 날씨 미리 확인"),
      ("⚠️", "겹치는 일정 미리 알림"),
      ("📋", "오늘 일정 한 번에 정리")
    ]

    private func startBenefitRotation() {
      guard benefitTimer == nil else { return }
      benefitTimer = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { _ in
        withAnimation(.easeInOut(duration: 0.4)) {
          currentBenefitIndex = (currentBenefitIndex + 1) % proBenefits.count
        }
      }
    }

    private func stopBenefitRotation() {
      benefitTimer?.invalidate()
      benefitTimer = nil
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
          profileHeaderRow

          // MARK: - 프로 플랜 섹션 (미가입자만 표시)
          if !store.subscriptionStatus.isPro {
            Button {
              store.send(.view(.proPlanTapped))
            } label: {
              VStack(alignment: .leading, spacing: 8) {
                // 1줄: ProBadge + 서브카피 + chevron
                HStack(spacing: 8) {
                  ProBadge()
                  Text("일정 그 이후를 챙겨드려요")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                  Spacer()
                  Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.pmgray.n400)
                }

                // 2줄: 순환 혜택
                HStack(spacing: 6) {
                  Text(proBenefits[currentBenefitIndex].icon)
                    .font(.system(size: 14))

                  Text(proBenefits[currentBenefitIndex].text)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.pmtext.primary)
                }
                .id(currentBenefitIndex)
                .transition(.asymmetric(
                  insertion: .opacity.combined(with: .move(edge: .bottom)),
                  removal: .opacity.combined(with: .move(edge: .top))
                ))
                .clipped()
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 14)
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .adaptiveGlassCard()
            .onAppear { startBenefitRotation() }
            .onDisappear { stopBenefitRotation() }
          }

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
                store.send(.view(.tabSettingsTapped))
              } label: {
                HStack(spacing: 16) {
                  Image(systemName: "square.grid.2x2.fill")
                    .font(.body)
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 24, height: 24)

                  Text(LocalizedStrings.SettingsStrings.tabSettingsMenu)
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
                store.send(.view(.conflictThresholdSettingsTapped))
              } label: {
                HStack(spacing: 16) {
                  Image(systemName: "exclamationmark.triangle")
                    .font(.body)
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 24, height: 24)

                  Text(LocalizedStrings.SettingsStrings.conflictDetectionTitle)
                    .font(.body)
                    .foregroundStyle(Color.pmtext.primary)

                  ProBadge()

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
                store.send(.view(.briefingSettingsTapped))
              } label: {
                HStack(spacing: 16) {
                  Image(systemName: "sparkles")
                    .font(.body)
                    .foregroundStyle(Color.pmindigo.n500)
                    .frame(width: 24, height: 24)

                  Text(LocalizedStrings.SettingsStrings.briefingSettingsTitle)
                    .font(.body)
                    .foregroundStyle(Color.pmtext.primary)

                  ProBadge()

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

          // MARK: - 쿠폰 섹션 (비구독자만 노출 — C-12, C-13)
          if !store.subscriptionStatus.isPro {
            Button {
              store.send(.view(.couponTapped))
            } label: {
              HStack(spacing: 16) {
                Image(systemName: "ticket.fill")
                  .font(.body)
                  .foregroundStyle(Color.pmindigo.n500)
                  .frame(width: 24, height: 24)

                Text("쿠폰 코드 입력")
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
      .toolbarBackground(.hidden, for: .navigationBar)
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
      .sheet(
        isPresented: Binding(
          get: { store.showCouponSheet },
          set: { if !$0 { store.send(.view(.couponSheetDismissed)) } }
        )
      ) {
        Settings.CouponRedeemSheet(store: store)
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
      VStack(spacing: 0) {
        // 프로필 영역 → 계정 정보
        Button {
          store.send(.view(.accountInfoTapped))
        } label: {
          HStack(spacing: 16) {
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

            Text(store.currentUser.nickname)
              .font(.title3)
              .fontWeight(.semibold)
              .foregroundStyle(Color.pmtext.primary)

            Spacer()

            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundStyle(Color.pmgray.n400)
          }
          .padding(.vertical, 16)
          .padding(.horizontal, 16)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        // 플랜 정보 영역 → Pro 관리 (가입자만)
        if store.subscriptionStatus.isPro {
          Divider()
            .background(Color.white.opacity(0.12))

          Button {
            store.send(.view(.proPlanTapped))
          } label: {
            HStack(spacing: 8) {
              ProBadge()

              if let planName = store.subscriptionStatus.planDisplayName {
                Text(LocalizedStrings.ProPlan.activePlan(planName))
                  .font(.subheadline)
                  .foregroundStyle(Color.pmindigo.n500)
              }

              Spacer()

              Text(LocalizedStrings.ProPlan.manageAction)
                .font(.caption)
                .foregroundStyle(Color.pmgray.n400)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
      .adaptiveGlassCard()
    }

    // MARK: - Helpers

    /// 앱 버전 정보
    private var appVersion: String {
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
  }
}

// MARK: - Coupon Redeem Sheet

extension Settings {
  struct CouponRedeemSheet: View {
    @Bindable var store: StoreOf<Feature>
    @FocusState private var isFocused: Bool

    var body: some View {
      NavigationStack {
        VStack(spacing: 24) {
          VStack(spacing: 8) {
            Image(systemName: "ticket.fill")
              .font(.system(size: 40))
              .foregroundStyle(Color.pmindigo.n500)

            Text("쿠폰 코드 입력")
              .font(.title2)
              .fontWeight(.bold)

            Text("Pro 플랜 체험 쿠폰 코드를 입력해주세요")
              .font(.subheadline)
              .foregroundStyle(.secondary)
          }
          .padding(.top, 20)

          TextField("쿠폰 코드", text: Binding(
            get: { store.couponCode },
            set: { store.send(.view(.couponCodeChanged($0))) }
          ))
          .textFieldStyle(.roundedBorder)
          .textInputAutocapitalization(.characters)
          .autocorrectionDisabled()
          .focused($isFocused)
          .padding(.horizontal, 20)

          if let message = store.couponResultMessage {
            Text(message)
              .font(.subheadline)
              .foregroundStyle(store.couponResultIsSuccess ? Color.pmsuccess.n500 : Color.pmerror.n500)
              .multilineTextAlignment(.center)
              .padding(.horizontal, 20)
          }

          Button {
            store.send(.view(.redeemCouponTapped))
          } label: {
            if store.isRedeemingCoupon {
              ProgressView()
                .tint(.white)
            } else {
              Text("적용하기")
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(Color.pmindigo.n500)
          .disabled(
            store.couponCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || store.isRedeemingCoupon
          )
          .padding(.horizontal, 20)

          Spacer()
        }
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("닫기") {
              store.send(.view(.couponSheetDismissed))
            }
          }
        }
      }
      .presentationDetents([.medium])
      .onAppear { isFocused = true }
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
