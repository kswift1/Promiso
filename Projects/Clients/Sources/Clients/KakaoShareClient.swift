import ComposableArchitecture
import PromisoShared
import Foundation
import UIKit
import KakaoSDKShare
import KakaoSDKCommon
@preconcurrency import KakaoSDKTemplate

// MARK: - Share Result

public enum KakaoShareResult: Equatable, Sendable {
  /// 카카오톡 앱으로 공유 성공
  case shared
  /// 카카오톡 미설치 → 웹 브라우저로 공유
  case webShared
  /// 모두 실패 → iOS 기본 공유 시트로 전환 필요
  case fallbackToSystem
}

// MARK: - Schedule Share Info

public struct ScheduleShareInfo: Equatable, Sendable {
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
    _ upcomingSchedules: [ScheduleShareInfo]
  ) async -> KakaoShareResult = { _, _, _, _, _, _, _ in .fallbackToSystem }

  /// 일정 카카오톡 공유
  public var shareSchedule: @Sendable (
    _ title: String,
    _ emoji: String,
    _ dateText: String,
    _ timeText: String,
    _ locationName: String?,
    _ address: String?,
    _ scheduleId: String,
    _ groupId: String,
    _ scheduleDescription: String?,
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

}

// MARK: - Live Implementation

extension KakaoShareClient: DependencyKey {
  public static let liveValue = Self(
    isKakaoTalkAvailable: {
      ShareApi.isKakaoTalkSharingAvailable()
    },
    shareGroupInvite: { groupName, inviteCode, memberCount, maxMembers, groupImageUrl, inviterName, upcomingSchedules in
      let webHost = KakaoDeeplinkConfig.webHost

      let inviteLink = Link(
        webUrl: URL(string: "https://\(webHost)/invite/\(inviteCode)"),
        mobileWebUrl: URL(string: "https://\(webHost)/invite/\(inviteCode)"),
        iosExecutionParams: ["path": "join/\(inviteCode)"]
      )

      let mainImageURL = groupImageUrl.flatMap { URL(string: $0) }

      let templatable: Templatable

      // 일정 있음: FeedTemplate + ItemContent (첫 번째 일정)
      if let firstSchedule = upcomingSchedules.first {
        let locationText = firstSchedule.locationName.map { " · \($0)" } ?? ""
        let scheduleImageURL = firstSchedule.imageUrl.flatMap { URL(string: $0) }

        templatable = FeedTemplate(
          content: Content(
            title: LocalizedStrings.KakaoShare.groupInviteTitle(inviterName, groupName),
            imageUrl: mainImageURL,
            description: LocalizedStrings.KakaoShare.groupInviteDescription,
            link: inviteLink
          ),
          itemContent: ItemContent(
            profileText: LocalizedStrings.KakaoShare.upcomingSchedule,
            titleImageText: "\(firstSchedule.emoji) \(firstSchedule.title)",
            titleImageUrl: scheduleImageURL,
            titleImageCategory: "\(firstSchedule.dateText) \(firstSchedule.timeText)\(locationText)"
          ),
          buttons: [
            Button(title: LocalizedStrings.KakaoShare.joinButton, link: inviteLink)
          ]
        )

      // 일정 없음: FeedTemplate (기본 초대)
      } else {
        templatable = FeedTemplate(
          content: Content(
            title: LocalizedStrings.KakaoShare.groupInviteTitle(inviterName, groupName),
            imageUrl: mainImageURL,
            description: LocalizedStrings.KakaoShare.groupInviteDescription,
            link: inviteLink
          ),
          buttons: [
            Button(title: LocalizedStrings.KakaoShare.joinButton, link: inviteLink)
          ]
        )
      }

      return await shareDefaultTemplate(templatable: templatable)
    },
    shareSchedule: { title, emoji, dateText, timeText, locationName, address, scheduleId, groupId, scheduleDescription, imageUrl in
      let webHost = KakaoDeeplinkConfig.webHost

      let scheduleLink = Link(
        webUrl: URL(string: "https://\(webHost)/promise/\(scheduleId)/\(groupId)"),
        mobileWebUrl: URL(string: "https://\(webHost)/promise/\(scheduleId)/\(groupId)"),
        iosExecutionParams: ["path": "promise/\(scheduleId)/\(groupId)"]
      )

      let imageURL = imageUrl.flatMap { URL(string: $0) }

      // Line 1: 일정 + 장소
      var line1 = "\(dateText) \(timeText)"
      if let locationName {
        line1 += " · \(locationName)"
      }

      // Line 2: 일정 내용
      let descriptionText: String
      if let scheduleDescription, !scheduleDescription.isEmpty {
        descriptionText = line1 + "\n" + scheduleDescription
      } else {
        descriptionText = line1
      }

      let buttons = [
        Button(title: LocalizedStrings.KakaoShare.scheduleCheckButton, link: scheduleLink)
      ]

      // 위치 정보가 있으면 LocationTemplate, 없으면 FeedTemplate
      if let address, !address.isEmpty {
        let locationTemplate = LocationTemplate(
          address: address,
          addressTitle: locationName,
          content: Content(
            title: LocalizedStrings.KakaoShare.scheduleTitle(emoji, title),
            imageUrl: imageURL,
            description: descriptionText,
            link: scheduleLink
          ),
          buttons: buttons
        )

        return await shareDefaultTemplate(templatable: locationTemplate)
      } else {
        let feedTemplate = FeedTemplate(
          content: Content(
            title: LocalizedStrings.KakaoShare.scheduleTitle(emoji, title),
            imageUrl: imageURL,
            description: descriptionText,
            link: scheduleLink
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
      DispatchQueue.main.async {
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
    shareSchedule: unimplemented("\(Self.self).shareSchedule", placeholder: .fallbackToSystem)
  )

  public static let previewValue = Self(
    isKakaoTalkAvailable: { true },
    shareGroupInvite: { _, _, _, _, _, _, _ in .shared },
    shareSchedule: { _, _, _, _, _, _, _, _, _, _ in .shared }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var kakaoShareClient: KakaoShareClient {
    get { self[KakaoShareClient.self] }
    set { self[KakaoShareClient.self] = newValue }
  }
}
