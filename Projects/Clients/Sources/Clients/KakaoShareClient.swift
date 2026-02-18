import ComposableArchitecture
import Foundation
import UIKit
import KakaoSDKShare
import KakaoSDKCommon

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
    _ promiseId: String,
    _ groupId: String
  ) async -> KakaoShareResult = { _, _, _, _, _, _, _ in .fallbackToSystem }
}

// MARK: - Template ID Helper

private enum KakaoTemplateConfig {
  static var groupInviteTemplateId: Int64 {
    guard let idString = Bundle.main.object(forInfoDictionaryKey: "KAKAO_GROUP_INVITE_TEMPLATE_ID") as? String,
          let id = Int64(idString) else {
      return 0
    }
    return id
  }

  static var promiseShareTemplateId: Int64 {
    guard let idString = Bundle.main.object(forInfoDictionaryKey: "KAKAO_PROMISE_SHARE_TEMPLATE_ID") as? String,
          let id = Int64(idString) else {
      return 0
    }
    return id
  }
}

// MARK: - Live Implementation

extension KakaoShareClient: DependencyKey {
  public static let liveValue = Self(
    isKakaoTalkAvailable: {
      ShareApi.isKakaoTalkSharingAvailable()
    },
    shareGroupInvite: { groupName, inviteCode, memberCount, maxMembers in
      let templateId = KakaoTemplateConfig.groupInviteTemplateId
      guard templateId > 0 else { return .fallbackToSystem }

      let templateArgs = [
        "GROUP_NAME": groupName,
        "INVITE_CODE": inviteCode,
        "MEMBER_COUNT": "\(memberCount)",
        "MAX_MEMBERS": "\(maxMembers)",
      ]

      return await shareCustomTemplate(templateId: templateId, templateArgs: templateArgs)
    },
    sharePromise: { title, emoji, dateText, timeText, locationName, promiseId, groupId in
      let templateId = KakaoTemplateConfig.promiseShareTemplateId
      guard templateId > 0 else { return .fallbackToSystem }

      var templateArgs = [
        "TITLE": title,
        "EMOJI": emoji,
        "DATE": dateText,
        "TIME": timeText,
        "PROMISE_ID": promiseId,
        "GROUP_ID": groupId,
      ]
      if let locationName {
        templateArgs["LOCATION"] = locationName
      }

      return await shareCustomTemplate(templateId: templateId, templateArgs: templateArgs)
    }
  )
}

// MARK: - Share Helper

private func shareCustomTemplate(
  templateId: Int64,
  templateArgs: [String: String]
) async -> KakaoShareResult {
  // 1. 카카오톡 설치 → 앱으로 공유
  if ShareApi.isKakaoTalkSharingAvailable() {
    let result = await withCheckedContinuation { continuation in
      ShareApi.shared.shareCustom(
        templateId: templateId,
        templateArgs: templateArgs
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
  if let webUrl = ShareApi.shared.makeCustomUrl(
    templateId: templateId,
    templateArgs: templateArgs
  ) {
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
    sharePromise: { _, _, _, _, _, _, _ in .shared }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var kakaoShareClient: KakaoShareClient {
    get { self[KakaoShareClient.self] }
    set { self[KakaoShareClient.self] = newValue }
  }
}
