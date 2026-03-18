import Foundation
import Testing
@testable import PromisoShared

@Suite("AppLanguage 해석 테스트")
struct AppLanguageTests {

  @Test("저장된 언어가 있으면 시스템 언어보다 우선한다")
  func storedLanguageTakesPrecedence() {
    let testDefaults = makeUserDefaults(testName: #function)
    defer { clear(testDefaults) }

    testDefaults.userDefaults.set(AppLanguage.english.rawValue, forKey: AppConstants.UserDefaults.preferredLanguage)

    let resolved = AppLanguage.resolveLanguage(
      userDefaults: testDefaults.userDefaults,
      preferredLocalizations: ["ko"],
      preferredLanguages: ["ko-KR"]
    )

    #expect(resolved == .english)
  }

  @Test("저장된 언어가 없으면 앱 선호 로컬라이제이션으로 초기화한다")
  func initializeUsesPreferredLocalizationsWhenMissing() {
    let testDefaults = makeUserDefaults(testName: #function)
    defer { clear(testDefaults) }

    AppLanguage.initializeIfNeeded(
      userDefaults: testDefaults.userDefaults,
      preferredLocalizations: ["ko"],
      preferredLanguages: ["en-US"]
    )

    #expect(testDefaults.userDefaults.string(forKey: AppConstants.UserDefaults.preferredLanguage) == AppLanguage.korean.rawValue)
  }

  @Test("지원하지 않는 언어면 기본값으로 한국어를 사용한다")
  func fallsBackToKoreanForUnsupportedLanguage() {
    let testDefaults = makeUserDefaults(testName: #function)
    defer { clear(testDefaults) }

    let resolved = AppLanguage.resolveLanguage(
      userDefaults: testDefaults.userDefaults,
      preferredLocalizations: ["ja"],
      preferredLanguages: ["fr-FR"]
    )

    #expect(resolved == .korean)
  }

  private func makeUserDefaults(testName: String) -> TestUserDefaults {
    let suiteName = "AppLanguageTests.\(testName)"
    let userDefaults = UserDefaults(suiteName: suiteName)!
    userDefaults.removePersistentDomain(forName: suiteName)
    return TestUserDefaults(suiteName: suiteName, userDefaults: userDefaults)
  }

  private func clear(_ testDefaults: TestUserDefaults) {
    testDefaults.userDefaults.removePersistentDomain(forName: testDefaults.suiteName)
  }
}

private struct TestUserDefaults {
  let suiteName: String
  let userDefaults: UserDefaults
}
