//
//  PlatfromAuthProvider.swift
//  Clients
//
//  Created by 김성원 on 11/27/25.
//
import AuthenticationServices
import Foundation

public enum AuthProvider: Equatable {
  case apple
  case kakao
  case google
}

public protocol PlatformAuthProviding {
  func signInWithApple(_ authorization: ASAuthorization) async throws -> AuthTokenBundle
  // placeholders for future platforms
  func signInWithKakao() async throws -> AuthTokenBundle
  func signInWithGoogle() async throws -> AuthTokenBundle
}

public struct PlatformAuthProvider: PlatformAuthProviding, Sendable {
  public init() {}
  
  public func signInWithApple(_ authorization: ASAuthorization) async throws -> AuthTokenBundle {
    guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
      throw AuthClientError.invalidAppleCredential
    }
    guard let identityToken = appleIDCredential.identityToken,
          let tokenString = String(data: identityToken, encoding: .utf8) else {
      throw AuthClientError.missingIdentityToken
    }
    
    return AuthTokenBundle(
      provider: .apple,
      identityToken: tokenString,
      userIdentifier: appleIDCredential.user
    )
  }
  
  public func signInWithKakao() async throws -> AuthTokenBundle {
    throw AuthClientError.providerUnavailable
  }
  
  public func signInWithGoogle() async throws -> AuthTokenBundle {
    throw AuthClientError.providerUnavailable
  }
}
