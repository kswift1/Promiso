// MARK: - OnboardingIntroView.swift

import ComposableArchitecture
import PromisoShared
import ResourceKit
import SwiftUI

extension AppEntry.OnboardingIntro {
  public struct View: SwiftUI.View {
    @Bindable var store: StoreOf<AppEntry.OnboardingIntro>

    public init(store: StoreOf<AppEntry.OnboardingIntro>) {
      self.store = store
    }

    public var body: some SwiftUI.View {
      VStack(spacing: 0) {
        // 현재 화면 콘텐츠
        screenContent
          .frame(maxWidth: .infinity, maxHeight: .infinity)

        // 하단: 페이지 인디케이터 + CTA
        bottomSection
      }
      .auroraBackground()
      .animation(.easeInOut(duration: 0.4), value: store.currentScreen)
    }

    // MARK: - Screen Content

    @ViewBuilder
    private var screenContent: some SwiftUI.View {
      Group {
        switch store.currentScreen {
        case .cinematicHero:
          CinematicHeroView(
            onAnimationComplete: { store.send(.view(.screenAnimationCompleted)) }
          )
        case .problemEmpathy:
          ProblemEmpathyView(
            onAnimationComplete: { store.send(.view(.screenAnimationCompleted)) }
          )
        case .benefitVote:
          BenefitVoteView(
            onAnimationComplete: { store.send(.view(.screenAnimationCompleted)) }
          )
        case .benefitHome:
          BenefitHomeView(
            onAnimationComplete: { store.send(.view(.screenAnimationCompleted)) }
          )
        case .benefitLive:
          BenefitLiveView(
            onAnimationComplete: { store.send(.view(.screenAnimationCompleted)) },
            onInteractionComplete: { store.send(.view(.screenInteractionCompleted)) }
          )
        }
      }
      .id(store.currentScreen)
      .transition(.asymmetric(
        insertion: .move(edge: store.isGoingBack ? .leading : .trailing).combined(with: .opacity),
        removal: .move(edge: store.isGoingBack ? .trailing : .leading).combined(with: .opacity)
      ))
    }

    // MARK: - Bottom Section

    private var bottomSection: some SwiftUI.View {
      VStack(spacing: 20) {
        PagingIndicator(
          count: store.screenCount,
          progress: store.screenProgress,
          activeColor: Color.pmindigo.n500
        )

        HStack(spacing: 12) {
          // 뒤로가기 버튼 (첫 화면이 아닐 때, 다음 버튼과 함께 표시)
          if !store.isFirstScreen && store.isAnimationComplete {
            Button {
              store.send(.view(.backTapped))
            } label: {
              Image(systemName: "chevron.left")
                .font(.pmSubheadlineSemibold)
                .foregroundStyle(Color.pmtext.secondary)
                .frame(width: 48, height: 48)
                .background {
                  Circle()
                    .fill(.ultraThinMaterial)
                }
            }
            .transition(.scale.combined(with: .opacity))
          }

          GlassActionButton(
            title: store.isLastScreen ? LocalizedStrings.Onboarding.start : LocalizedStrings.Common.next,
            leadingSystemImage: store.isLastScreen ? "arrow.right" : nil,
            isPrimary: true,
            isVisible: store.isAnimationComplete,
            action: { store.send(.view(.nextTapped)) }
          )
        }
        .animation(.easeInOut(duration: 0.25), value: store.isFirstScreen)
      }
      .padding(.horizontal, 24)
      .padding(.bottom, UIScreen.main.bounds.height < 700 ? 24 : 40)
    }

  }
}
