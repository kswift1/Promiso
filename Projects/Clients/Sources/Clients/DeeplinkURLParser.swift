import Foundation
import PromisoShared

// MARK: - DeeplinkURLParser

/// 딥링크 URL 파싱 담당
///
/// 지원하는 URL 형식 ({scheme}은 환경별로 다름: promiso-dev, promiso-stage, promiso):
/// - `{scheme}://join/{inviteCode}` → 초대 코드로 그룹 참여
/// - `{scheme}://group/{groupId}` → 그룹 상세 화면
/// - `{scheme}://schedule/{scheduleId}/{groupId}` → 일정 상세 화면
/// - `{scheme}://schedule/{scheduleId}/eta` → LiveActivity ETA 변경 시트
/// - `{scheme}://promise/{scheduleId}/{groupId}` → 레거시 일정 상세 화면
/// - `{scheme}://promise/{scheduleId}/eta` → 레거시 LiveActivity ETA 변경 시트
/// - `{scheme}://live/{scheduleId}` → LiveSchedule 상세 화면 (ETA 시트 없이)
/// - `{scheme}://vote/{scheduleId}` → 투표 일정 상세 화면 (VoteLiveActivity 탭 시)
/// - `{scheme}://create` → 일정 만들기 화면 (Widget용, 그룹 있을 때만)
/// - `{scheme}://personalEvent/{eventId}` → 개인 일정 (Widget용, 개인 모드 탭으로 이동 + 상세 push)
/// - `{scheme}://extractSchedule` → Share Extension 일정 추출 (개인 일정 생성 폼)
///
/// 카카오톡 공유 URL 형식:
/// - `kakao{APP_KEY}://kakaolink?path=join/{inviteCode}` → 초대 코드로 그룹 참여
/// - `kakao{APP_KEY}://kakaolink?path=schedule/{scheduleId}/{groupId}` → 일정 상세 화면
/// - `kakao{APP_KEY}://kakaolink?path=promise/{scheduleId}/{groupId}` → 레거시 일정 상세 화면
///
/// - SeeAlso: `.ai/DEEPLINK_GUIDE.md`
public enum DeeplinkURLParser {

  /// URL을 파싱하여 DeeplinkDestination으로 변환
  /// - Parameter url: 딥링크 URL (예: promiso://join/ABC123)
  /// - Returns: 파싱된 목적지 (파싱 실패 시 nil)
  public static func parse(_ url: URL) -> DeeplinkDestination? {
    // 카카오톡 공유 URL 처리 (kakao{APP_KEY}://kakaolink?path=...)
    if url.scheme?.hasPrefix("kakao") == true, url.host == "kakaolink" {
      return parseKakaoLink(from: url)
    }

    guard url.scheme == AppConstants.Deeplink.scheme else { return nil }

    switch url.host {
    case "join":
      return parseJoinGroup(from: url)

    case "group":
      return parseGroup(from: url)

    case "schedule":
      return parseSchedule(from: url)

    case "live":
      return parseLiveSchedule(from: url)

    case "vote":
      return parseVoteSchedule(from: url)

    case "create":
      return .create

    case "personalEvent":
      return parsePersonalEvent(from: url)

    case "pro":
      return .proPlan

    case "extractSchedule":
      return .extractSchedule

    default:
      return nil
    }
  }
}

// MARK: - Kakao Link Parser

private extension DeeplinkURLParser {

  /// kakao{APP_KEY}://kakaolink?path=join/{inviteCode}
  /// → promiso-dev://join/{inviteCode} 와 동일하게 처리
  static func parseKakaoLink(from url: URL) -> DeeplinkDestination? {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let path = components.queryItems?.first(where: { $0.name == "path" })?.value else {
      return nil
    }

    // path를 "/" 기준으로 분리: "join/ABC123" → ["join", "ABC123"]
    let segments = path.split(separator: "/").map(String.init)
    guard let action = segments.first else { return nil }

    switch action {
    case "join":
      guard segments.count >= 2 else { return nil }
      return .joinGroup(inviteCode: segments[1])

    case "schedule", "promise":
      guard segments.count >= 3 else { return nil }
      let scheduleId = segments[1]
      let groupId = segments[2]
      return .schedule(scheduleId: scheduleId, groupId: groupId)

    case "group":
      guard segments.count >= 2 else { return nil }
      return .group(groupId: segments[1])

    default:
      return nil
    }
  }
}

// MARK: - Private Parsers

private extension DeeplinkURLParser {

  /// promiso://join/{inviteCode}
  static func parseJoinGroup(from url: URL) -> DeeplinkDestination? {
    guard let inviteCode = url.pathComponents.dropFirst().first else {
      return nil
    }
    return .joinGroup(inviteCode: inviteCode)
  }

  /// promiso://group/{groupId}
  static func parseGroup(from url: URL) -> DeeplinkDestination? {
    guard let groupId = url.pathComponents.dropFirst().first else {
      return nil
    }
    return .group(groupId: groupId)
  }

  /// promiso://schedule/{scheduleId}/{groupId} 또는 promiso://schedule/{scheduleId}/eta
  static func parseSchedule(from url: URL) -> DeeplinkDestination? {
    let components = Array(url.pathComponents.dropFirst())
    guard components.count >= 2 else {
      return nil
    }
    let scheduleId = components[0]
    let secondComponent = components[1]

    // /eta suffix인 경우 LiveActivity ETA 변경 시트
    if secondComponent == "eta" {
      return .liveActivityETA(scheduleId: scheduleId)
    }

    // 그 외는 groupId로 처리
    return .schedule(scheduleId: scheduleId, groupId: secondComponent)
  }

  /// promiso://live/{scheduleId}
  static func parseLiveSchedule(from url: URL) -> DeeplinkDestination? {
    guard let scheduleId = url.pathComponents.dropFirst().first else {
      return nil
    }
    return .liveSchedule(scheduleId: scheduleId)
  }

  /// promiso://vote/{scheduleId}
  static func parseVoteSchedule(from url: URL) -> DeeplinkDestination? {
    guard let scheduleId = url.pathComponents.dropFirst().first else {
      return nil
    }
    return .vote(scheduleId: scheduleId)
  }

  /// promiso://personalEvent/{eventId}
  static func parsePersonalEvent(from url: URL) -> DeeplinkDestination? {
    guard let eventId = url.pathComponents.dropFirst().first else {
      return nil
    }
    return .personalEvent(eventId: eventId)
  }
}
