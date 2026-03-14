// MARK: - OnboardingIntroView.swift

import AuthenticationServices
import ComposableArchitecture
import CryptoKit
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
        if store.showBottomNavigation {
          bottomSection
        }
      }
      .auroraBackground()
      .animation(.easeInOut(duration: 0.4), value: store.currentScreen)
      .onChange(of: store.pendingAppleLoginNonce) { _, nonce in
        guard let nonce else { return }
        presentAppleLogin(nonce: nonce)
      }
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
        case .benefitConfirm:
          BenefitConfirmView(
            onAnimationComplete: { store.send(.view(.screenAnimationCompleted)) }
          )
        case .benefitHome:
          BenefitHomeView(
            onAnimationComplete: { store.send(.view(.screenAnimationCompleted)) }
          )
        case .benefitPro:
          BenefitProView(
            onAnimationComplete: { store.send(.view(.screenAnimationCompleted)) }
          )
        case .benefitLive:
          BenefitLiveView(
            onAnimationComplete: { store.send(.view(.screenAnimationCompleted)) },
            onInteractionComplete: { store.send(.view(.screenInteractionCompleted)) }
          )
        case .signIn:
          OnboardingSignInView(
            isLoading: store.isAuthLoading,
            errorMessage: store.authError,
            onAppleTapped: { store.send(.view(.signInWithAppleTapped)) },
            onGoogleTapped: { store.send(.view(.signInWithGoogleTapped)) }
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

    // MARK: - Apple Sign-In

    private func presentAppleLogin(nonce: String) {
      let provider = ASAuthorizationAppleIDProvider()
      let request = provider.createRequest()
      request.requestedScopes = [.fullName, .email]
      request.nonce = SHA256.hash(data: Data(nonce.utf8))
        .compactMap { String(format: "%02x", $0) }
        .joined()

      let controller = ASAuthorizationController(authorizationRequests: [request])
      let coordinator = AppleSignInCoordinator(store: store)
      controller.delegate = coordinator
      controller.presentationContextProvider = coordinator
      controller.performRequests()

      // Store coordinator to prevent deallocation
      Self.retainedCoordinator = coordinator
    }

    private static var retainedCoordinator: AppleSignInCoordinator?
  }
}

// MARK: - Apple Sign-In Coordinator

private class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
  let store: StoreOf<AppEntry.OnboardingIntro>

  init(store: StoreOf<AppEntry.OnboardingIntro>) {
    self.store = store
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
    store.send(.view(.appleAuthorizationResult(.success(authorization))))
  }

  func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
    store.send(.view(.appleAuthorizationResult(.failure(error))))
  }

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
          let window = scene.windows.first else {
      return ASPresentationAnchor()
    }
    return window
  }
}
