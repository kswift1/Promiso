// MARK: - OnboardingStartView.swift
// 온보딩 완료 → 그룹 만들기 / 초대코드 / 개인 약속

import ComposableArchitecture
import PromisoShared
import SwiftUI

extension AppEntry.OnboardingStart {
  public struct View: SwiftUI.View {
    let store: StoreOf<AppEntry.OnboardingStart>

    public init(store: StoreOf<AppEntry.OnboardingStart>) {
      self.store = store
    }

    @SwiftUI.State private var showEmoji: Bool = false
    @SwiftUI.State private var showTitle: Bool = false
    @SwiftUI.State private var showPrimary: Bool = false
    @SwiftUI.State private var showSecondary: Bool = false
    @SwiftUI.State private var showTertiary: Bool = false
    @SwiftUI.State private var showFooter: Bool = false
    @SwiftUI.State private var emojiScale: CGFloat = 0.3

    public var body: some SwiftUI.View {
      VStack(spacing: 0) {
        Spacer()

        // 이모지 + 타이틀
        VStack(spacing: 20) {
          if showEmoji {
            Text("🎉")
              .font(.system(size: 72))
              .scaleEffect(emojiScale)
              .transition(.opacity)
          }

          if showTitle {
            VStack(spacing: 10) {
              Text("준비 완료!")
                .font(.largeTitle.bold())
                .foregroundStyle(Color.pmtext.primary)

              Text("이번 주에 만날 친구,\n누가 떠올라요?")
                .font(.title3)
                .foregroundStyle(Color.pmtext.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

              Text("그 약속, 카톡 대신 한 번에 잡아보세요")
                .font(.subheadline)
                .foregroundStyle(Color.pmtext.secondary.opacity(0.8))
                .padding(.top, 4)
            }
            .transition(.opacity.combined(with: .offset(y: 12)))
          }
        }

        Spacer()

        // CTA 영역
        VStack(spacing: 14) {
          // Primary: 그룹 만들기
          if showPrimary {
            GlassActionButton(
              title: "그룹 만들기",
              leadingSystemImage: "person.2.fill",
              isPrimary: true,
              action: { store.send(.view(.createGroupTapped)) }
            )
            .transition(.opacity.combined(with: .offset(y: 16)))
          }

          // Secondary: 초대코드
          if showSecondary {
            Button {
              store.send(.view(.enterInviteCodeTapped))
            } label: {
              HStack(spacing: 8) {
                Image(systemName: "link")
                  .font(.system(size: 15, weight: .semibold))
                Text("초대코드가 있어요")
                  .font(.callout.weight(.semibold))
              }
              .foregroundStyle(Color.pmindigo.n500)
              .frame(maxWidth: .infinity)
              .frame(height: 48)
              .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .fill(Color.pmindigo.n500.opacity(0.08))
              }
              .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                  .strokeBorder(Color.pmindigo.n500.opacity(0.2), lineWidth: 1)
              }
            }
            .transition(.opacity.combined(with: .offset(y: 12)))
          }

          // Tertiary: 개인 약속
          if showTertiary {
            Button {
              store.send(.view(.personalScheduleTapped))
            } label: {
              Text("괜찮아요")
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.pmtext.secondary)
            }
            .padding(.top, 2)
            .transition(.opacity)
          }

          // 안내 문구
          if showFooter {
            Text("나중에 홈에서도 언제든 할 수 있어요")
              .font(.caption)
              .foregroundStyle(Color.pmtext.secondary.opacity(0.6))
              .padding(.top, 2)
              .transition(.opacity)
          }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, UIScreen.main.bounds.height < 700 ? 24 : 40)
      }
      .auroraBackground()
      .onAppear {
        Task {
          await runAnimationSequence()
        }
      }
    }

    // MARK: - Animation Sequence

    private func runAnimationSequence() async {
      // 이모지 등장 + 바운스
      try? await Task.sleep(for: .seconds(0.3))
      withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
        showEmoji = true
        emojiScale = 1.0
      }

      // 타이틀 등장
      try? await Task.sleep(for: .seconds(0.35))
      withAnimation(.easeOut(duration: 0.45)) {
        showTitle = true
      }

      // Primary 버튼
      try? await Task.sleep(for: .seconds(0.4))
      withAnimation(.easeOut(duration: 0.35)) {
        showPrimary = true
      }

      // Secondary 버튼
      try? await Task.sleep(for: .seconds(0.15))
      withAnimation(.easeOut(duration: 0.3)) {
        showSecondary = true
      }

      // Tertiary + Footer
      try? await Task.sleep(for: .seconds(0.15))
      withAnimation(.easeOut(duration: 0.3)) {
        showTertiary = true
        showFooter = true
      }
    }
  }
}
