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

// MARK: - Promise Share Info

public struct PromiseShareInfo: Equatable, Sendable {
  public let title: String
  public let emoji: String
  public let dateText: String
  public let timeText: String
  public let locationName: String?
  public let imageUrl: String?

  public init(
    title: String,
    emoji: String,
    dateText: String,
    timeText: String,
    locationName: String?,
    imageUrl: String? = nil
  ) {
    self.title = title
    self.emoji = emoji
    self.dateText = dateText
    self.timeText = timeText
    self.locationName = locationName
    self.imageUrl = imageUrl
  }
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
    _ maxMembers: Int,
    _ groupImageUrl: String?,
    _ inviterName: String,
    _ upcomingPromises: [PromiseShareInfo]
  ) async -> KakaoShareResult = { _, _, _, _, _, _, _ in .fallbackToSystem }

  /// 약속 카카오톡 공유
  public var sharePromise: @Sendable (
    _ title: String,
    _ emoji: String,
    _ dateText: String,
    _ timeText: String,
    _ locationName: String?,
    _ address: String?,
    _ promiseId: String,
    _ groupId: String,
    _ promiseDescription: String?,
    _ imageUrl: String?
  ) async -> KakaoShareResult = { _, _, _, _, _, _, _, _, _, _ in .fallbackToSystem }
}

// MARK: - Deeplink Config Helper

private enum KakaoDeeplinkConfig {
  static var scheme: String {
    Bundle.main.object(forInfoDictionaryKey: "DEEPLINK_SCHEME") as? String ?? "promiso"
  }

  static var webHost: String {
    Bundle.main.object(forInfoDictionaryKey: "DEEPLINK_WEB_HOST") as? String ?? "promiso.app"
  }

  static let fallbackImageURL = URL(
    string: "https://firebasestorage.googleapis.com/v0/b/promiso-prod.firebasestorage.app/o/app_config%2Finvite_image.png?alt=media&token=428a4a85-4060-48aa-a175-96440bf4d6fa"
  )
}

// MARK: - Live Implementation

extension KakaoShareClient: DependencyKey {
  public static let liveValue = Self(
    isKakaoTalkAvailable: {
      ShareApi.isKakaoTalkSharingAvailable()
    },
    shareGroupInvite: { groupName, inviteCode, memberCount, maxMembers, groupImageUrl, inviterName, upcomingPromises in
      let webHost = KakaoDeeplinkConfig.webHost

      let inviteLink = Link(
        webUrl: URL(string: "https://\(webHost)/invite/\(inviteCode)"),
        mobileWebUrl: URL(string: "https://\(webHost)/invite/\(inviteCode)"),
        iosExecutionParams: ["path": "join/\(inviteCode)"]
      )

      let mainImageURL = groupImageUrl.flatMap { URL(string: $0) }
        ?? KakaoDeeplinkConfig.fallbackImageURL

      let templatable: Templatable

      // 약속 있음: FeedTemplate + ItemContent (첫 번째 약속)
      if let firstPromise = upcomingPromises.first {
        let locationText = firstPromise.locationName.map { " · \($0)" } ?? ""
        let promiseImageURL = firstPromise.imageUrl.flatMap { URL(string: $0) }

        templatable = FeedTemplate(
          content: Content(
            title: "\(inviterName)님이 \(groupName) 그룹에 초대했어요 👋",
            imageUrl: mainImageURL,
            description: "참여하고 약속을 함께 관리해보세요",
            link: inviteLink
          ),
          itemContent: ItemContent(
            profileText: "다가오는 약속",
            titleImageText: "\(firstPromise.emoji) \(firstPromise.title)",
            titleImageUrl: promiseImageURL,
            titleImageCategory: "\(firstPromise.dateText) \(firstPromise.timeText)\(locationText)"
          ),
          buttons: [
            Button(title: "참여하기", link: inviteLink)
          ]
        )

      // 약속 없음: FeedTemplate (기본 초대)
      } else {
        templatable = FeedTemplate(
          content: Content(
            title: "\(inviterName)님이 \(groupName) 그룹에 초대했어요 👋",
            imageUrl: mainImageURL,
            description: "참여하고 약속을 함께 관리해보세요",
            link: inviteLink
          ),
          buttons: [
            Button(title: "참여하기", link: inviteLink)
          ]
        )
      }

      return await shareDefaultTemplate(templatable: templatable)
    },
    sharePromise: { title, emoji, dateText, timeText, locationName, address, promiseId, groupId, promiseDescription, imageUrl in
      let webHost = KakaoDeeplinkConfig.webHost

      let promiseLink = Link(
        webUrl: URL(string: "https://\(webHost)/promise/\(promiseId)/\(groupId)"),
        mobileWebUrl: URL(string: "https://\(webHost)/promise/\(promiseId)/\(groupId)"),
        iosExecutionParams: ["path": "promise/\(promiseId)/\(groupId)"]
      )

      let imageURL = imageUrl.flatMap { URL(string: $0) }
        ?? KakaoDeeplinkConfig.fallbackImageURL

      // Line 1: 일정 + 장소
      var line1 = "\(dateText) \(timeText)"
      if let locationName {
        line1 += " · \(locationName)"
      }

      // Line 2: 약속 내용
      let descriptionText: String
      if let promiseDescription, !promiseDescription.isEmpty {
        descriptionText = line1 + "\n" + promiseDescription
      } else {
        descriptionText = line1
      }

      let buttons = [
        Button(title: "약속 확인하기", link: promiseLink)
      ]

      // 위치 정보가 있으면 LocationTemplate, 없으면 FeedTemplate
      if let address, !address.isEmpty {
        let locationTemplate = LocationTemplate(
          address: address,
          addressTitle: locationName,
          content: Content(
            title: "\(emoji) \(title) — 약속을 확인해보세요",
            imageUrl: imageURL,
            description: descriptionText,
            link: promiseLink
          ),
          buttons: buttons
        )

        return await shareDefaultTemplate(templatable: locationTemplate)
      } else {
        let feedTemplate = FeedTemplate(
          content: Content(
            title: "\(emoji) \(title) — 약속을 확인해보세요",
            imageUrl: imageURL,
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
    shareGroupInvite: { _, _, _, _, _, _, _ in .shared },
    sharePromise: { _, _, _, _, _, _, _, _, _, _ in .shared }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var kakaoShareClient: KakaoShareClient {
    get { self[KakaoShareClient.self] }
    set { self[KakaoShareClient.self] = newValue }
  }
}
