// MARK: - AuthFeature.swift
// TCA 1.22.2를 사용한 Auth Feature의 완전한 구현
// State, Action, Reducer, View를 모두 포함한 단일 모듈

import AuthenticationServices
import Clients
import ComposableArchitecture
import Dependencies
import Foundation
import SwiftUI
import CryptoKit


import GoogleSignIn
import GoogleSignInSwift

// MARK: - Feature Namespace

/// Auth Feature 컴포넌트를 위한 Namespace
/// 조직적 구조를 제공하고 다른 Feature들과의 naming conflict를 방지
public enum Auth {}

// MARK: - Core Feature Implementation

extension Auth {
  
  // MARK: - Reducer
  
  /// Auth Feature state management를 위한 Main reducer
  /// Feature의 모든 business logic과 side effect를 처리
  ///
  /// SwiftUI integration을 위해 @ObservableState와 함께 TCA 1.22.2 Reducer protocol을 준수
  @Reducer
  public struct Feature {
    
    @Dependency(\.authClient) private var authClient: AuthClient
    
    public init() {}
    
    // MARK: - State
    
    /// Auth Feature의 완전한 state를 나타냄
    /// 예측 가능성을 유지하기 위해 모든 state 변경은 Action을 통해 처리되어야 함
    ///
    /// @ObservableState는 추가 wrapper 없이 직접적인 SwiftUI integration을 가능하게 함
    @ObservableState
    public struct State: Equatable {
      public var isLoading: Bool = false
      public var errorMessage: String?
      public var currentNonce: String?
      
      public init() {}
    }
    
    // MARK: - Action
    
    /// Auth Feature 내에서 발생할 수 있는 모든 가능한 action
    /// 각 action은 고유한 user intent나 system event를 나타내야 함
    public enum Action {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
    }
    
    public enum View: Sendable {
      case googleLoginTapped
    }
    
    public enum Internal: Sendable {
      case appleLoginNoncePrepared(String)
      case appleLoginCompleted(Result<ASAuthorization, Error>)
      case authResponse(Result<ServiceTokenBundle?, AuthClientError>)
    }
    
    public enum Delegate: Equatable {
      case loggedIn(ServiceTokenBundle?)
    }
    
    // MARK: - Reducer Body
    
    /// business logic을 구현하는 Main reducer body
    /// 모든 action에 대한 state transition과 side effect를 처리
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
          
        case .view(let viewAction):
          switch viewAction {
          case .googleLoginTapped:
            state.isLoading = true
            state.errorMessage = nil
            return .run { send in
              do {
                let bundle = try await authClient.signInWithGoogle()
                await send(.internal(.authResponse(.success(bundle))))
                await send(.delegate(.loggedIn(bundle)))
              } catch {
                let clientError = (error as? AuthClientError) ?? .unknown
                await send(.internal(.authResponse(.failure(clientError))))
              }
            }
            
          }
          
        case .internal(let internalAction):
          switch internalAction {
          case .appleLoginNoncePrepared(let nonce):
            state.currentNonce = nonce
            return .none
            
          case .appleLoginCompleted(.success(let authorization)):
            guard let nonce = state.currentNonce else {
              state.errorMessage = "로그인 요청에 실패했습니다. 다시 시도해주세요."
              return .none
            }
            state.isLoading = true
            state.errorMessage = nil
            return .run { send in
              do {
                let bundle = try await authClient.signInWithApple(authorization, nonce)
                await send(.delegate(.loggedIn(bundle)))
                await send(.internal(.authResponse(.success(bundle))))
              } catch {
                let clientError = (error as? AuthClientError) ?? .unknown
                await send(.internal(.authResponse(.failure(clientError))))
              }
            }
            
          case .appleLoginCompleted(.failure(let error)):
            state.isLoading = false
            state.errorMessage = error.localizedDescription
            return .none
            
          case .authResponse(.success):
            state.isLoading = false
            return .none
            
          case .authResponse(.failure(let error)):
            state.isLoading = false
            state.errorMessage = error.localizedDescription
            return .none
          }
          
        case .delegate:
          return .none
        }
      }
    }
  }
  
  // MARK: - Root View
  
  /// Auth Feature를 위한 Main view implementation
  /// 적절한 accessibility와 state handling을 통해 SwiftUI best practice를 따름
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    
    public init(store: StoreOf<Feature>) {
      self.store = store
    }
    
    // MARK: - Body
    
    public var body: some View {
      VStack(alignment: .leading, spacing: 16) {
        Text("로그인")
          .font(.title2.bold())
        
        if let errorMessage = store.errorMessage {
          Text(errorMessage)
            .foregroundColor(.red)
            .font(.footnote)
        }
        
        Button {
          store.send(.view(.googleLoginTapped))
        } label: {
          Text("Google로 시작하기")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.blue)
        .foregroundColor(.white)
        .disabled(store.isLoading)
        
        SignInWithAppleButton(
          .signIn,
          onRequest: { request in
            let nonce = randomNonceString()
            store.send(.internal(.appleLoginNoncePrepared(nonce)))
            request.requestedScopes = [.fullName, .email]
            request.nonce = sha256(nonce)
          },
          onCompletion: { result in
            switch result {
            case .success(let authorization):
              store.send(.internal(.appleLoginCompleted(.success(authorization))))
            case .failure(let error):
              store.send(.internal(.appleLoginCompleted(.failure(error))))
            }
          }
        )
        .signInWithAppleButtonStyle(.black)
        .frame(height: 50)
        .cornerRadius(10)
        .padding(.top, 4)
        
        Spacer()
      }
      .padding()
    }
    
    private func randomNonceString(length: Int = 32) -> String {
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
        // Pick a random character from the set, wrapping around if needed.
        charset[Int(byte) % charset.count]
      }
      
      return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
      let inputData = Data(input.utf8)
      let hashedData = SHA256.hash(data: inputData)
      let hashString = hashedData.compactMap {
        String(format: "%02x", $0)
      }.joined()
      
      return hashString
    }
  }
}

// MARK: - Error Types
// Feature별 Error type이 필요한 경우 여기에 추가
// 예시:
// public enum AuthError: Error, Equatable, LocalizedError {
//   case networkError
//   case dataError
//   case custom(String)
// }
