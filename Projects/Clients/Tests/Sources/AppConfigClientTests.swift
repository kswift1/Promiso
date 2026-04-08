import Foundation
import Testing
import PromisoShared

@Suite("AppConfigClient")
struct AppConfigClientTests {
  @Test("서버 app-config 응답을 디코딩하고 AppConstants 캐시에 반영한다")
  func appConfigDecodingAndCacheUpdate() async throws {
    let payload = """
      {
        "data": {
          "forceUpdateVersion": "1.2.3",
          "recommendedVersion": "1.3.0",
          "appStoreURL": "https://example.com/app",
          "privacyPolicyURL": "https://example.com/privacy",
          "termsOfServiceURL": "https://example.com/terms",
          "supportEmail": "help@example.com",
          "notionFAQDatabaseId": "faq-123"
        }
      }
      """.data(using: .utf8)!

    struct APIResponse: Decodable {
      let data: AppConfigModel
    }

    let response = try JSONDecoder().decode(APIResponse.self, from: payload)

    await AppConstants.App.updateConfig(response.data)

    #expect(response.data.forceUpdateVersion == "1.2.3")
    #expect(response.data.appStoreURL == "https://example.com/app")
    #expect(AppConstants.App.appStoreURL.absoluteString == "https://example.com/app")
    #expect(AppConstants.App.supportEmail == "help@example.com")

    await AppConstants.App.updateConfig(.defaultConfig)
  }
}
