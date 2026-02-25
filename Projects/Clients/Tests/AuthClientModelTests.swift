//
//  AuthClientModelTests.swift
//  Clients
//
//  Auth 관련 모델 테스트 (FirebaseUserSnapshot, ServiceTokenBundle, ProviderTokenBundle 등)
//
//  ## 테스트 대상
//  - `Clients/Sources/Clients/AuthClient.swift`
//
//  ## 테스트 목적
//  - FirebaseUserSnapshot 초기화 및 프로퍼티 검증
//  - ServiceTokenBundle 초기화 및 profileImageURL 우선순위 검증
//  - ProviderTokenBundle 초기화 검증
//  - AuthProvider identifier 검증
//  - AuthClientError errorDescription 검증
//  - String.providerTypeIdentifier 확장 검증
//

import Foundation
import Testing
@testable import Clients

// MARK: - FirebaseUserSnapshot 테스트

@Suite("FirebaseUserSnapshot 모델 테스트")
struct FirebaseUserSnapshotTests {

  @Test("모든 필드를 포함한 초기화 검증")
  func fullInitialization_setsAllProperties() {
    let photoURL = URL(string: "https://example.com/photo.jpg")!
    let creationDate = Date(timeIntervalSince1970: 1_700_000_000)
    let lastSignInDate = Date(timeIntervalSince1970: 1_700_100_000)

    let snapshot = FirebaseUserSnapshot(
      uid: "uid-123",
      email: "test@example.com",
      displayName: "Test User",
      photoURL: photoURL,
      creationDate: creationDate,
      lastSignInDate: lastSignInDate,
      providerId: "google.com",
      providerUid: "google-uid-456",
      providerType: "google"
    )

    #expect(snapshot.uid == "uid-123")
    #expect(snapshot.email == "test@example.com")
    #expect(snapshot.displayName == "Test User")
    #expect(snapshot.photoURL == photoURL)
    #expect(snapshot.creationDate == creationDate)
    #expect(snapshot.lastSignInDate == lastSignInDate)
    #expect(snapshot.providerId == "google.com")
    #expect(snapshot.providerUid == "google-uid-456")
    #expect(snapshot.providerType == "google")
  }

  @Test("선택적 필드 nil로 초기화 검증")
  func minimalInitialization_setsOptionalFieldsToNil() {
    let snapshot = FirebaseUserSnapshot(
      uid: "uid-456",
      email: nil,
      displayName: nil,
      photoURL: nil
    )

    #expect(snapshot.uid == "uid-456")
    #expect(snapshot.email == nil)
    #expect(snapshot.displayName == nil)
    #expect(snapshot.photoURL == nil)
    #expect(snapshot.creationDate == nil)
    #expect(snapshot.lastSignInDate == nil)
    #expect(snapshot.providerId == nil)
    #expect(snapshot.providerUid == nil)
    #expect(snapshot.providerType == nil)
  }

  @Test("Equatable 동작 검증 - 동일한 스냅샷")
  func equatable_sameValues_areEqual() {
    let snapshot1 = FirebaseUserSnapshot(
      uid: "uid-1",
      email: "a@b.com",
      displayName: "User",
      photoURL: nil
    )
    let snapshot2 = FirebaseUserSnapshot(
      uid: "uid-1",
      email: "a@b.com",
      displayName: "User",
      photoURL: nil
    )
    #expect(snapshot1 == snapshot2)
  }

  @Test("Equatable 동작 검증 - 다른 스냅샷")
  func equatable_differentValues_areNotEqual() {
    let snapshot1 = FirebaseUserSnapshot(
      uid: "uid-1",
      email: "a@b.com",
      displayName: "User",
      photoURL: nil
    )
    let snapshot2 = FirebaseUserSnapshot(
      uid: "uid-2",
      email: "a@b.com",
      displayName: "User",
      photoURL: nil
    )
    #expect(snapshot1 != snapshot2)
  }
}

// MARK: - ServiceTokenBundle 테스트

@Suite("ServiceTokenBundle 모델 테스트")
struct ServiceTokenBundleTests {

  @Test("Firebase photoURL이 있으면 profileImageURL이 Firebase URL 반환")
  func profileImageURL_firebasePhotoExists_returnsFirebaseURL() {
    let firebasePhotoURL = URL(string: "https://firebase.com/photo.jpg")!
    let providerPhotoURL = URL(string: "https://google.com/photo.jpg")!

    let firebaseUser = FirebaseUserSnapshot(
      uid: "uid-1",
      email: nil,
      displayName: nil,
      photoURL: firebasePhotoURL
    )

    let providerBundle = ProviderTokenBundle(
      provider: .google,
      identityToken: "id-token",
      accessToken: "access-token",
      userIdentifier: "google-uid",
      profileImageURL: providerPhotoURL
    )

    let bundle = ServiceTokenBundle(
      firebaseUser: firebaseUser,
      providerTokenBundle: providerBundle,
      isNewUser: false
    )

    #expect(bundle.profileImageURL == firebasePhotoURL)
  }

  @Test("Firebase photoURL이 nil이면 Provider profileImageURL 반환")
  func profileImageURL_firebasePhotoNil_returnsProviderURL() {
    let providerPhotoURL = URL(string: "https://google.com/photo.jpg")!

    let firebaseUser = FirebaseUserSnapshot(
      uid: "uid-1",
      email: nil,
      displayName: nil,
      photoURL: nil
    )

    let providerBundle = ProviderTokenBundle(
      provider: .google,
      identityToken: nil,
      accessToken: nil,
      userIdentifier: "google-uid",
      profileImageURL: providerPhotoURL
    )

    let bundle = ServiceTokenBundle(
      firebaseUser: firebaseUser,
      providerTokenBundle: providerBundle,
      isNewUser: false
    )

    #expect(bundle.profileImageURL == providerPhotoURL)
  }

  @Test("firebaseUser가 nil이면 Provider profileImageURL 반환")
  func profileImageURL_firebaseUserNil_returnsProviderURL() {
    let providerPhotoURL = URL(string: "https://google.com/photo.jpg")!

    let providerBundle = ProviderTokenBundle(
      provider: .google,
      identityToken: nil,
      accessToken: nil,
      userIdentifier: "google-uid",
      profileImageURL: providerPhotoURL
    )

    let bundle = ServiceTokenBundle(
      firebaseUser: nil,
      providerTokenBundle: providerBundle,
      isNewUser: true
    )

    #expect(bundle.profileImageURL == providerPhotoURL)
    #expect(bundle.isNewUser == true)
  }

  @Test("isNewUser 기본값은 false")
  func isNewUser_defaultIsFalse() {
    let providerBundle = ProviderTokenBundle(
      provider: .apple,
      identityToken: nil,
      accessToken: nil,
      userIdentifier: "apple-uid"
    )

    let bundle = ServiceTokenBundle(
      firebaseUser: nil,
      providerTokenBundle: providerBundle
    )

    #expect(bundle.isNewUser == false)
  }
}

// MARK: - AuthProvider 테스트

@Suite("AuthProvider 테스트")
struct AuthProviderTests {

  @Test("AuthProvider identifier 검증")
  func identifier_returnsCorrectString() {
    #expect(AuthProvider.apple.identifier == "apple")
    #expect(AuthProvider.google.identifier == "google")
  }
}

// MARK: - String.providerTypeIdentifier 테스트

@Suite("String.providerTypeIdentifier 확장 테스트")
struct ProviderTypeIdentifierTests {

  @Test("google.com은 google로 변환")
  func googleDotCom_returnsGoogle() {
    #expect("google.com".providerTypeIdentifier == "google")
  }

  @Test("apple.com은 apple로 변환")
  func appleDotCom_returnsApple() {
    #expect("apple.com".providerTypeIdentifier == "apple")
  }

  @Test("알 수 없는 provider는 원본 문자열 반환")
  func unknownProvider_returnsOriginalString() {
    #expect("facebook.com".providerTypeIdentifier == "facebook.com")
    #expect("password".providerTypeIdentifier == "password")
  }
}

