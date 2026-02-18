import ComposableArchitecture
import Foundation
import UIKit
import KakaoSDKShare
import KakaoSDKCommon
import KakaoSDKTemplate

// MARK: - Share Result

public enum KakaoShareResult: Equatable, Sendable {
  /// 카카오톡 앱으로 공유 성공
  case shared
  /// 카카오톡 미설치 → 웹 브라우저로 공유
  case webShared
  /// 모두 실패 → iOS 기본 공유 시트로 전환 필요
  case fallbackToSystem
}

// MARK: - Client

@DependencyClient
public struct KakaoShareClient: Sendable {
  /// 카카오톡 설치 여부 확인
  public var isKakaoTalkAvailable: @Sendable () -> Bool = { false }

  /// 그룹 초대 카카오톡 공유
  public var shareGroupInvite: @Sendable (
    _ groupName: String,
    _ inviteCode: String,
    _ memberCount: Int,
    _ maxMembers: Int
  ) async -> KakaoShareResult = { _, _, _, _ in .fallbackToSystem }

  /// 약속 카카오톡 공유
  public var sharePromise: @Sendable (
    _ title: String,
    _ emoji: String,
    _ dateText: String,
    _ timeText: String,
    _ locationName: String?,
    _ address: String?,
    _ promiseId: String,
    _ groupId: String
  ) async -> KakaoShareResult = { _, _, _, _, _, _, _, _ in .fallbackToSystem }
}

// MARK: - Deeplink Config Helper

private enum KakaoDeeplinkConfig {
  static var scheme: String {
    Bundle.main.object(forInfoDictionaryKey: "DEEPLINK_SCHEME") as? String ?? "promiso"
  }

  static var webHost: String {
    Bundle.main.object(forInfoDictionaryKey: "DEEPLINK_WEB_HOST") as? String ?? "promiso.app"
  }
}

// MARK: - Live Implementation

extension KakaoShareClient: DependencyKey {
  public static let liveValue = Self(
    isKakaoTalkAvailable: {
      ShareApi.isKakaoTalkSharingAvailable()
    },
    shareGroupInvite: { groupName, inviteCode, memberCount, maxMembers in
      let scheme = KakaoDeeplinkConfig.scheme
      let webHost = KakaoDeeplinkConfig.webHost

      let feedTemplate = FeedTemplate(
        content: Content(
          title: "🎉 \(groupName) 그룹에 초대합니다!",
          description: "👥 \(memberCount)/\(maxMembers)명 참여 중\n초대 코드: \(inviteCode)",
          link: Link(
            webUrl: URL(string: "https://\(webHost)/invite/\(inviteCode)"),
            mobileWebUrl: URL(string: "https://\(webHost)/invite/\(inviteCode)"),
            iosExecutionParams: ["scheme": "\(scheme)://join/\(inviteCode)"]
          )
        ),
        buttons: [
          Button(
            title: "그룹 참여하기",
            link: Link(
              webUrl: URL(string: "https://\(webHost)/invite/\(inviteCode)"),
              mobileWebUrl: URL(string: "https://\(webHost)/invite/\(inviteCode)"),
              iosExecutionParams: ["scheme": "\(scheme)://join/\(inviteCode)"]
            )
          )
        ]
      )

      return await shareDefaultTemplate(templatable: feedTemplate)
    },
    sharePromise: { title, emoji, dateText, timeText, locationName, address, promiseId, groupId in
      let scheme = KakaoDeeplinkConfig.scheme
      let webHost = KakaoDeeplinkConfig.webHost

      let promiseLink = Link(
        webUrl: URL(string: "https://\(webHost)/promise/\(promiseId)/\(groupId)"),
        mobileWebUrl: URL(string: "https://\(webHost)/promise/\(promiseId)/\(groupId)"),
        iosExecutionParams: ["scheme": "\(scheme)://promise/\(promiseId)/\(groupId)"]
      )

      let descriptionText = "📅 \(dateText) \(timeText)" + (locationName.map { "\n📍 \($0)" } ?? "")

      let buttons = [
        Button(title: "약속 보기", link: promiseLink)
      ]

      // 위치 정보가 있으면 LocationTemplate, 없으면 FeedTemplate
      if let address, !address.isEmpty {
        let locationTemplate = LocationTemplate(
          address: address,
          addressTitle: locationName,
          content: Content(
            title: "\(emoji) \(title)",
            description: descriptionText,
            link: promiseLink
          ),
          buttons: buttons
        )

        return await shareDefaultTemplate(templatable: locationTemplate)
      } else {
        let feedTemplate = FeedTemplate(
          content: Content(
            title: "\(emoji) \(title)",
            description: descriptionText,
            link: promiseLink
          ),
          buttons: buttons
        )

        return await shareDefaultTemplate(templatable: feedTemplate)
      }
    }
  )
}

// MARK: - Share Helper

/// 기본 템플릿 (FeedTemplate, LocationTemplate 등) 공유
private func shareDefaultTemplate(
  templatable: Templatable
) async -> KakaoShareResult {
  // 1. 카카오톡 설치 → 앱으로 공유
  if ShareApi.isKakaoTalkSharingAvailable() {
    let result = await withCheckedContinuation { continuation in
      ShareApi.shared.shareDefault(
        templatable: templatable
      ) { sharingResult, error in
        if let error {
          continuation.resume(returning: Result<URL, Error>.failure(error))
        } else if let url = sharingResult?.url {
          continuation.resume(returning: .success(url))
        } else {
          continuation.resume(returning: .failure(SdkError(reason: .Unknown)))
        }
      }
    }

    switch result {
    case .success(let url):
      await MainActor.run {
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
      }
      return .shared
    case .failure:
      break
    }
  }

  // 2. 카카오톡 미설치 → 웹 URL 생성
  if let webUrl = ShareApi.shared.makeDefaultUrl(templatable: templatable) {
    await MainActor.run {
      UIApplication.shared.open(webUrl, options: [:], completionHandler: nil)
    }
    return .webShared
  }

  // 3. 모두 실패 → 시스템 공유 시트로 전환
  return .fallbackToSystem
}

// MARK: - Test & Preview Values

extension KakaoShareClient: TestDependencyKey {
  public static let testValue = Self(
    isKakaoTalkAvailable: unimplemented("\(Self.self).isKakaoTalkAvailable", placeholder: false),
    shareGroupInvite: unimplemented("\(Self.self).shareGroupInvite", placeholder: .fallbackToSystem),
    sharePromise: unimplemented("\(Self.self).sharePromise", placeholder: .fallbackToSystem)
  )

  public static let previewValue = Self(
    isKakaoTalkAvailable: { true },
    shareGroupInvite: { _, _, _, _ in .shared },
    sharePromise: { _, _, _, _, _, _, _, _ in .shared }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var kakaoShareClient: KakaoShareClient {
    get { self[KakaoShareClient.self] }
    set { self[KakaoShareClient.self] = newValue }
  }
}
