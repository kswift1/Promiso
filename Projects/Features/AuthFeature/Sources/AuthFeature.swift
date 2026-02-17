import AuthenticationServices
import Clients
import ExternalDependency
import Foundation
import SwiftUI
import CryptoKit
import GoogleSignIn
import GoogleSignInSwift
import PromisoShared
import ResourceKit

// MARK: - Feature Namespace

public enum Auth {}

// MARK: - Feature Implementation

extension Auth {
  
  // MARK: - Reducer
  
  @Reducer
  public struct Feature {
    
    @Dependency(\.authClient) private var authClient: AuthClient
    
    public init() {}
    
    // MARK: - State
    
    @ObservableState
    public struct State: Equatable {
      public var isLoading: Bool = false
      public var errorMessage: String?
      public var pendingAppleLoginNonce: String?
      
      public init() {}
    }
    
    // MARK: - Action
    
    public enum Action {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
    }
    
    public enum View: Sendable {
      case appleLoginTapped
      case googleLoginTapped
    }
    
    @CasePathable
    public enum Internal: Sendable {
      case appleAuthorizationResult(Result<ASAuthorization, Error>)
      case authResponse(Result<ServiceTokenBundle?, AuthClientError>)
    }
    
    @CasePathable
    public enum Delegate: Equatable {
      /// 로그인 성공 (providerProfileImageURL: Provider에서 제공한 프로필 이미지 URL)
      case loggedIn(providerProfileImageURL: URL?)
    }
    
    // MARK: - Reducer Body
    
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
          
        case .view(let viewAction):
          switch viewAction {
          case .appleLoginTapped:
            state.isLoading = true
            state.errorMessage = nil
            let nonce = Self.randomNonceString()
            state.pendingAppleLoginNonce = nonce
            return .none
            
          case .googleLoginTapped:
            state.isLoading = true
            state.errorMessage = nil
            return .run { send in
              do {
                let bundle = try await authClient.signInWithGoogle()
                await send(.internal(.authResponse(.success(bundle))))
                await send(.delegate(.loggedIn(providerProfileImageURL: bundle.profileImageURL)))
              } catch {
                let clientError = (error as? AuthClientError) ?? .unknown
                await send(.internal(.authResponse(.failure(clientError))))
              }
            }
          }
          
        case .internal(let internalAction):
          switch internalAction {
          case .appleAuthorizationResult(.success(let authorization)):
            guard let nonce = state.pendingAppleLoginNonce else {
              state.isLoading = false
              state.errorMessage = LocalizedStrings.Auth.loginRequestFailed
              return .none
            }
            return .run { send in
              do {
                let bundle = try await authClient.signInWithApple(authorization, nonce)
                // Apple은 프로필 이미지를 제공하지 않음
                await send(.delegate(.loggedIn(providerProfileImageURL: nil)))
                await send(.internal(.authResponse(.success(bundle))))
              } catch {
                let clientError = (error as? AuthClientError) ?? .unknown
                await send(.internal(.authResponse(.failure(clientError))))
              }
            }
            
          case .appleAuthorizationResult(.failure):
            state.isLoading = false
            state.pendingAppleLoginNonce = nil
            state.errorMessage = LocalizedStrings.Error.authInvalidAppleCredential
            return .none

          case .authResponse(.success):
            state.isLoading = false
            state.pendingAppleLoginNonce = nil
            return .none

          case .authResponse(.failure(let error)):
            state.isLoading = false
            state.pendingAppleLoginNonce = nil
            state.errorMessage = error.localizedMessage
            return .none
          }
          
        case .delegate:
          return .none
        }
      }
    }
    
    // MARK: - Helper Functions (Static)
    
    static func randomNonceString(length: Int = 32) -> String {
      precondition(length > 0)
      var randomBytes = [UInt8](repeating: 0, count: length)
      let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
      if errorCode != errSecSuccess {
        fatalError(
          "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
        )
      }
      
      let charset: [Character] =
      Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
      
      let nonce = randomBytes.map { byte in
        charset[Int(byte) % charset.count]
      }
      
      return String(nonce)
    }
    
    static func sha256(_ input: String) -> String {
      let inputData = Data(input.utf8)
      let hashedData = SHA256.hash(data: inputData)
      let hashString = hashedData.compactMap {
        String(format: "%02x", $0)
      }.joined()
      
      return hashString
    }
  }
  
  // MARK: - Root View
  
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    let animated: Bool
    
    @State private var appleCoordinator: AppleSignInCoordinator?
    
    @State private var indicatorProgress: CGFloat = 0
    @State private var showTyping: Bool = false
    @State private var showLoginSheet: Bool = false
    
    public init(
      store: StoreOf<Feature>,
      animated: Bool = true
    ) {
      self.store = store
      self.animated = animated
    }
    
    public var body: some View {
      ZStack(alignment: .bottom) {
        VStack(alignment: .leading, spacing: 0) {
          
          VStack(alignment: .leading, spacing: 16) {
            // 인디케이터 바
            RoundedRectangle(cornerRadius: 2)
              .fill(
                LinearGradient(
                  colors: [
                    Color.pmbrand.primary,
                    Color.pmbrand.secondary
                  ],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .frame(width: 40, height: 4)
              .scaleEffect(x: indicatorProgress, y: 1, anchor: .leading)
              .opacity(indicatorProgress == 0 ? 0 : 1)
            
            if showTyping {
              TypewriterLinesView(
                animated: animated,
                lines: [
                  .init(
                    text: LocalizedStrings.Auth.heroPromisesWord,
                    font: .system(size: 48, weight: .black),
                    style: AnyShapeStyle(Color.pmtext.primary)
                  ),
                  .init(
                    text: LocalizedStrings.Auth.heroMoreSpecial,
                    font: .system(size: 48, weight: .black),
                    style: AnyShapeStyle(
                      LinearGradient(
                        colors: [
                          Color.pmindigo.n600,
                          Color.pmpurple.n600
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                      )
                    )
                  ),
                  .init(
                    text: LocalizedStrings.Auth.heroPreciousMoments,
                    font: .system(size: 18, weight: .medium),
                    style: AnyShapeStyle(Color.pmtext.secondary)
                  ),
                  .init(
                    text: LocalizedStrings.Auth.heroWithPromiso,
                    font: .system(size: 18, weight: .medium),
                    style: AnyShapeStyle(Color.pmtext.secondary)
                  )
                ],
                typingAnimationCompleted: {
                  if animated {
                    Task {
                      try? await Task.sleep(for: .seconds(1))
                      withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                        showLoginSheet = true
                      }
                    }
                  } else {
                    showLoginSheet = true
                  }
                },
                lineSpacingProvider: { index in
                  switch index {
                  case 0: return 4
                  case 1: return 24
                  case 2: return 4
                  default: return 0
                  }
                },
                typingSpeed: 0.05,
                lineDelayProvider: { line in
                  return line == 1 ? 1.0 : 0.3
                }
              )
            }
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 24)
          .padding(.top, 80)
          
          Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) {
          if showLoginSheet {
            LoginSheetView(
              onAppleLogin: {
                store.send(.view(.appleLoginTapped))
              },
              onGoogleLogin: {
                store.send(.view(.googleLoginTapped))
              }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(
              animated ? .spring(response: 0.55, dampingFraction: 0.85) : nil,
              value: showLoginSheet
            )
          }
        }
      }
      .auroraBackground()
      .task {
        if animated {
          try? await Task.sleep(for: .seconds(1.5))
          
          withAnimation(.easeOut(duration: 0.6)) {
            indicatorProgress = 1
          }
          
          try? await Task.sleep(for: .seconds(1))
          showTyping = true
        } else {
          indicatorProgress = 1
          showTyping = true
        }
      }
      .onChange(of: store.pendingAppleLoginNonce) { _, newNonce in
        if let nonce = newNonce {
          presentAppleLogin(nonce: nonce)
        }
      }
    }
    
    // MARK: - Apple Login Presentation
    
    private func presentAppleLogin(nonce: String) {
      let hashedNonce = Feature.sha256(nonce)
      
      let appleIDProvider = ASAuthorizationAppleIDProvider()
      let request = appleIDProvider.createRequest()
      request.requestedScopes = [.fullName, .email]
      request.nonce = hashedNonce
      
      let authorizationController = ASAuthorizationController(authorizationRequests: [request])
      
      if appleCoordinator == nil {
        appleCoordinator = AppleSignInCoordinator()
      }
      let coordinator = appleCoordinator!
      coordinator.onComplete = { result in
        store.send(.internal(.appleAuthorizationResult(result)))
      }
      
      authorizationController.delegate = coordinator
      authorizationController.presentationContextProvider = coordinator
      authorizationController.performRequests()
    }
  }

  // MARK: - LoginSheetView
  
  struct LoginSheetView: View {
    let onAppleLogin: () -> Void
    let onGoogleLogin: () -> Void
    
    var body: some View {
      VStack(spacing: 20) {
        Text("CONTINUE WITH")
          .font(.system(size: 14, weight: .medium))
          .tracking(2)
          .foregroundColor(.secondary)
        
        // Apple 버튼
        Button(action: onAppleLogin) {
          HStack(spacing: 12) {
            Image(systemName: "apple.logo")
              .font(.system(size: 20, weight: .medium))
            Text(LocalizedStrings.Auth.continueWithApple)
              .font(.system(size: 16, weight: .semibold))
          }
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
        }
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        
        // Google 버튼
        Button(action: onGoogleLogin) {
          HStack(spacing: 12) {
            ResourceKitAsset.googleLogo.swiftUIImage
              .resizable()
              .frame(width: 20, height: 20)
            Text(LocalizedStrings.Auth.continueWithGoogle)
              .font(.system(size: 16, weight: .semibold))
          }
          .foregroundColor(.primary)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
        }
        .background(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(Color(.systemBackground))
            .opacity(0.9)
        )
        .overlay(
          RoundedRectangle(cornerRadius: 16, style: .continuous)
            .stroke(Color.pmgray.n200, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 28)
      .frame(maxWidth: .infinity)
      .background(loginSheetBackground)
      .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: -10)
      .padding(.horizontal, 16)
      .padding(.bottom, 40)
    }
    
    @ViewBuilder
    private var loginSheetBackground: some View {
      if #available(iOS 26.0, *) {
        Color.clear
          .glassEffect(
            .regular
              .tint(.white.opacity(0.1)),
            in: .rect(cornerRadius: 36)
          )
      } else {
        ZStack {
          RoundedRectangle(cornerRadius: 36, style: .continuous)
            .fill(.ultraThinMaterial)
          
          RoundedRectangle(cornerRadius: 36, style: .continuous)
            .fill(
              LinearGradient(
                colors: [
                  Color.white.opacity(0.25),
                  Color.white.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
          
          RoundedRectangle(cornerRadius: 36, style: .continuous)
            .strokeBorder(
              LinearGradient(
                colors: [
                  Color.white.opacity(0.4),
                  Color.white.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1
            )
        }
      }
    }
  }
  
  // MARK: - Apple Sign In Coordinator (Internal)
  
  private class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    var onComplete: ((Result<ASAuthorization, Error>) -> Void)?
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
      guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let window = windowScene.windows.first else {
        fatalError("No window found")
      }
      return window
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
      onComplete?(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
      onComplete?(.failure(error))
    }
  }
  
  // MARK: - Previews
  
  #Preview("With Animation") {
    Auth.RootView(
      store: Store(initialState: Feature.State()) {
        Feature()
      },
      animated: true
    )
  }
  
  #Preview("Without Animation") {
    Auth.RootView(
      store: Store(initialState: Feature.State()) {
        Feature()
      },
      animated: false
    )
  }
  
  #Preview("Dark Mode") {
    Auth.RootView(
      store: Store(initialState: Feature.State()) {
        Feature()
      },
      animated: true
    )
    .preferredColorScheme(.dark)
  }
  
  #Preview("Light Mode") {
    Auth.RootView(
      store: Store(initialState: Feature.State()) {
        Feature()
      },
      animated: true
    )
    .preferredColorScheme(.light)
  }
}

// MARK: - AuthClientError Localization

extension AuthClientError {
  var localizedMessage: String {
    switch self {
    case .invalidCredentials: return LocalizedStrings.Error.authInvalidCredentials
    case .alreadyExists: return LocalizedStrings.Error.authAlreadyExists
    case .network: return LocalizedStrings.Error.authNetwork
    case .invalidAppleCredential: return LocalizedStrings.Error.authInvalidAppleCredential
    case .missingIdentityToken: return LocalizedStrings.Error.authMissingIdentityToken
    case .providerUnavailable: return LocalizedStrings.Error.authProviderUnavailable
    case .isGroupHost: return LocalizedStrings.Error.authIsGroupHost
    case .unknown: return LocalizedStrings.Error.unknownError
    }
  }
}
