// MARK: - AuthFeature.swift
// TCA 1.22.2를 사용한 Auth Feature의 완전한 구현
// State, Action, Reducer, View를 모두 포함한 단일 모듈

import Clients
import ComposableArchitecture
import Dependencies
import Foundation
import SwiftUI

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
      public var email: String = ""
      public var password: String = ""
      public var isLoading: Bool = false
      public var errorMessage: String?
      
      public init() {}
    }
    
    // MARK: - Action
    
    /// Auth Feature 내에서 발생할 수 있는 모든 가능한 action
    /// 각 action은 고유한 user intent나 system event를 나타내야 함
    public enum Action {
      case emailChanged(String)
      case passwordChanged(String)
      case loginTapped
      case signupTapped
      case _authResponse(Result<Void, AuthClientError>)
      case delegate(Delegate)
    }
    
    public enum Delegate: Equatable {
      case loggedIn
    }
    
    // MARK: - Reducer Body
    
    /// business logic을 구현하는 Main reducer body
    /// 모든 action에 대한 state transition과 side effect를 처리
    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .emailChanged(let email):
          state.email = email
          return .none
          
        case .passwordChanged(let password):
          state.password = password
          return .none
          
        case .loginTapped:
          state.isLoading = true
          state.errorMessage = nil
          return .run { [email = state.email, password = state.password] send in
            do {
              try await authClient.login(email, password)
              await send(._authResponse(.success(())))
            } catch {
              let clientError = (error as? AuthClientError) ?? .unknown
              await send(._authResponse(.failure(clientError)))
            }
          }
          
        case .signupTapped:
          state.isLoading = true
          state.errorMessage = nil
          return .run { [email = state.email, password = state.password] send in
            do {
              try await authClient.signup(email, password, "", nil)
              await send(._authResponse(.success(())))
            } catch {
              let clientError = (error as? AuthClientError) ?? .unknown
              await send(._authResponse(.failure(clientError)))
            }
          }
          
        case ._authResponse(.success):
          state.isLoading = false
          return .send(.delegate(.loggedIn))
          
        case ._authResponse(.failure(let error)):
          state.isLoading = false
          state.errorMessage = error.localizedDescription
          return .none
          
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
        
        VStack(alignment: .leading, spacing: 12) {
          TextField("이메일", text: $store.email.sending(\.emailChanged))
            .textContentType(.emailAddress)
            .keyboardType(.emailAddress)
            .autocapitalization(.none)
            .disableAutocorrection(true)
            .textFieldStyle(.roundedBorder)
          
          SecureField("비밀번호", text: $store.password.sending(\.passwordChanged))
            .textContentType(.password)
            .textFieldStyle(.roundedBorder)
        }
        
        if let errorMessage = store.errorMessage {
          Text(errorMessage)
            .foregroundColor(.red)
            .font(.footnote)
        }
        
        HStack(spacing: 12) {
          Button {
            store.send(.loginTapped)
          } label: {
            if store.isLoading {
              ProgressView()
                .progressViewStyle(.circular)
                .frame(maxWidth: .infinity)
            } else {
              Text("로그인")
                .frame(maxWidth: .infinity)
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(store.isLoading)
          
          Button {
            store.send(.signupTapped)
          } label: {
            Text("회원가입")
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.bordered)
          .disabled(store.isLoading)
        }
        .padding(.top, 8)
        
        Spacer()
      }
      .padding()
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
