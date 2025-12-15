// MARK: - AuthFeature.swift

import AuthenticationServices
import Clients
import ComposableArchitecture
import Dependencies
import Foundation
import SwiftUI
import CryptoKit
import GoogleSignIn
import GoogleSignInSwift
import Shared

// MARK: - Feature Namespace

public enum Auth {}

// MARK: - Core Feature Implementation

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
    
    public enum Internal: Sendable {
      case appleAuthorizationResult(Result<ASAuthorization, Error>)
      case authResponse(Result<ServiceTokenBundle?, AuthClientError>)
    }
    
    public enum Delegate: Equatable {
      case loggedIn
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
                await send(.delegate(.loggedIn))
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
              state.errorMessage = "로그인 요청에 실패했습니다. 다시 시도해주세요."
              return .none
            }
            return .run { send in
              do {
                let bundle = try await authClient.signInWithApple(authorization, nonce)
                await send(.delegate(.loggedIn))
                await send(.internal(.authResponse(.success(bundle))))
              } catch {
                let clientError = (error as? AuthClientError) ?? .unknown
                await send(.internal(.authResponse(.failure(clientError))))
              }
            }
            
          case .appleAuthorizationResult(.failure(let error)):
            state.isLoading = false
            state.pendingAppleLoginNonce = nil
            state.errorMessage = error.localizedDescription
            return .none
            
          case .authResponse(.success):
            state.isLoading = false
            state.pendingAppleLoginNonce = nil
            return .none
            
          case .authResponse(.failure(let error)):
            state.isLoading = false
            state.pendingAppleLoginNonce = nil
            state.errorMessage = error.localizedDescription
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
                    text: "약속을",
                    font: .system(size: 48, weight: .black),
                    style: AnyShapeStyle(Color.pmtext.primary)
                  ),
                  .init(
                    text: "더 특별하게.",
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
                    text: "소중한 순간들을",
                    font: .system(size: 18, weight: .medium),
                    style: AnyShapeStyle(Color.pmtext.secondary)
                  ),
                  .init(
                    text: "Promiso와 함께하세요.",
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
  
  // MARK: - MultiLineTypingView
  
  struct MultiLineTypingView: View {
    let animated: Bool
    var typingAnimationCompleted: () -> Void
    
    @State private var currentLine = 0
    
    struct LineStyle {
      let text: String
      let font: Font
      let style: AnyShapeStyle
    }
    
    private let lines: [LineStyle] = [
      .init(
        text: "약속을",
        font: .system(size: 48, weight: .black),
        style: AnyShapeStyle(Color.pmtext.primary)
      ),
      .init(
        text: "더 특별하게.",
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
        text: "소중한 순간들을",
        font: .system(size: 18, weight: .medium),
        style: AnyShapeStyle(Color.pmtext.secondary)
      ),
      .init(
        text: "Promiso와 함께하세요.",
        font: .system(size: 18, weight: .medium),
        style: AnyShapeStyle(Color.pmtext.secondary)
      )
    ]
    
    var body: some View {
      VStack(alignment: .leading, spacing: 0) {
        if animated {
          ForEach(0..<currentLine + 1, id: \.self) { index in
            if index < lines.count {
              let line = lines[index]
              
              if index == currentLine {
                TypewriterText(
                  text: line.text,
                  font: line.font,
                  style: line.style,
                  animated: animated
                ) {
                  if index < lines.count - 1 {
                    let extraDelay: Double = (index == 1) ? 1.0 : 0.3
                    DispatchQueue.main.asyncAfter(deadline: .now() + extraDelay) {
                      currentLine += 1
                    }
                  } else {
                    typingAnimationCompleted()
                  }
                }
                .padding(.bottom, spacingForLine(index))
              } else {
                Text(line.text)
                  .font(line.font)
                  .foregroundStyle(line.style)
                  .padding(.bottom, spacingForLine(index))
              }
            }
          }
        } else {
          ForEach(0..<lines.count, id: \.self) { index in
            Text(lines[index].text)
              .font(lines[index].font)
              .foregroundStyle(lines[index].style)
              .padding(.bottom, spacingForLine(index))
          }
        }
      }
      .onAppear {
        if !animated {
          typingAnimationCompleted()
        }
      }
    }
    
    private func spacingForLine(_ index: Int) -> CGFloat {
      switch index {
      case 0: return 4
      case 1: return 24
      case 2: return 4
      default: return 0
      }
    }
  }
  
  // MARK: - TypewriterText
  
  struct TypewriterText: View {
    let text: String
    let speed: Double = 0.05
    let font: Font
    let style: AnyShapeStyle
    let animated: Bool
    var onComplete: () -> Void
    
    @State private var displayedText = ""
    @State private var showCursor = true
    
    var body: some View {
      HStack(spacing: 0) {
        Text(displayedText)
          .font(font)
          .foregroundStyle(style)
        
        if animated && displayedText.count < text.count {
          Text("|")
            .font(font)
            .foregroundStyle(style)
            .opacity(showCursor ? 1 : 0)
            .animation(
              .easeInOut(duration: 0.5)
              .repeatForever(autoreverses: true),
              value: showCursor
            )
        }
      }
      .onAppear {
        if animated {
          showCursor = true
          typeText()
        } else {
          displayedText = text
          onComplete()
        }
      }
    }
    
    private func typeText() {
      displayedText = ""
      for (index, character) in text.enumerated() {
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * speed) {
          displayedText.append(character)
          
          if index == text.count - 1 {
            onComplete()
          }
        }
      }
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
            Text("Apple로 계속하기")
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
            Image("googleLogo")
              .resizable()
              .frame(width: 20, height: 20)
            Text("Google로 계속하기")
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
