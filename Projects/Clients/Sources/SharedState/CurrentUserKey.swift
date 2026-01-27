import ComposableArchitecture
import PromisoShared

// MARK: - CurrentUser SharedKey

/// 현재 로그인한 사용자 정보를 앱 전역에서 공유하기 위한 키
///
/// 사용법:
/// ```swift
/// @Shared(.currentUser) var currentUser: UserPrivateModel?
/// ```
extension SharedKey where Self == InMemoryKey<UserPrivateModel?> {
  public static var currentUser: Self { .inMemory("currentUser") }
}
