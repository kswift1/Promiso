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
        // 건너뛰기 (우측 상단)
        skipButton

        // 현재 화면 콘텐츠
        screenContent
          .frame(maxWidth: .infinity, maxHeight: .infinity)

        // 하단: 페이지 인디케이터 + CTA
        bottomSection
      }
      .auroraBackground()
      .animation(.easeInOut(duration: 0.4), value: store.currentScreen)
    }

    // MARK: - Skip Button

    @ViewBuilder
    private var skipButton: some SwiftUI.View {
      HStack {
        Spacer()
        if !store.isLastScreen {
          Button {
            store.send(.view(.skipTapped))
          } label: {
            Text("건너뛰기")
              .font(.callout.weight(.medium))
              .foregroundStyle(Color.pmtext.secondary)
          }
          .padding(.trailing, 24)
        }
      }
      .frame(height: 44)
      .padding(.top, 8)
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
            onAnimationComplete: { store.send(.view(.screenAnimationCompleted)) }
          )
        case .premiumTeaser:
          PremiumTeaserView(
            interestedFeatures: store.interestedPremiumFeatures,
            onToggle: { feature in
              store.send(.view(.premiumInterestToggled(feature)))
            },
            onAnimationComplete: { store.send(.view(.screenAnimationCompleted)) }
          )
        }
      }
      .id(store.currentScreen)
      .transition(.asymmetric(
        insertion: .move(edge: .trailing).combined(with: .opacity),
        removal: .move(edge: .leading).combined(with: .opacity)
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

        GlassActionButton(
          title: store.isLastScreen ? "시작하기" : "다음",
          leadingSystemImage: store.isLastScreen ? "arrow.right" : nil,
          isPrimary: true,
          isVisible: store.isAnimationComplete,
          action: { store.send(.view(.nextTapped)) }
        )
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 40)
    }
  }
}
