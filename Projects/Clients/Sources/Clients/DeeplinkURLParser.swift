import Foundation

// MARK: - DeeplinkURLParser

/// 딥링크 URL 파싱 담당
///
/// 지원하는 URL 형식:
/// - `promiso://join/{inviteCode}` → 초대 코드로 그룹 참여
/// - `promiso://group/{groupId}` → 그룹 상세 화면
/// - `promiso://promise/{promiseId}/{groupId}` → 약속 상세 화면
/// - `promiso://promise/{promiseId}/eta` → LiveActivity ETA 변경 시트
/// - `promiso://live/{promiseId}` → LivePromise 상세 화면 (ETA 시트 없이)
/// - `promiso://create` → 약속 만들기 화면 (Widget용, 그룹 있을 때만)
/// - `promiso://personalEvent/{eventId}` → 개인 일정 (Widget용, 개인 모드 탭으로 이동 + 상세 push)
///
/// - SeeAlso: `.ai/DEEPLINK_GUIDE.md`
public enum DeeplinkURLParser {

  /// URL을 파싱하여 DeeplinkDestination으로 변환
  /// - Parameter url: 딥링크 URL (예: promiso://join/ABC123)
  /// - Returns: 파싱된 목적지 (파싱 실패 시 nil)
  public static func parse(_ url: URL) -> DeeplinkDestination? {
    guard url.scheme == "promiso" else { return nil }

    switch url.host {
    case "join":
      return parseJoinGroup(from: url)

    case "group":
      return parseGroup(from: url)

    case "promise":
      return parsePromise(from: url)

    case "live":
      return parseLivePromise(from: url)

    case "create":
      return .create

    case "personalEvent":
      return parsePersonalEvent(from: url)

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

  /// promiso://promise/{promiseId}/{groupId} 또는 promiso://promise/{promiseId}/eta
  static func parsePromise(from url: URL) -> DeeplinkDestination? {
    let components = Array(url.pathComponents.dropFirst())
    guard components.count >= 2 else {
      return nil
    }
    let promiseId = components[0]
    let secondComponent = components[1]

    // /eta suffix인 경우 LiveActivity ETA 변경 시트
    if secondComponent == "eta" {
      return .liveActivityETA(promiseId: promiseId)
    }

    // 그 외는 groupId로 처리
    return .promise(promiseId: promiseId, groupId: secondComponent)
  }

  /// promiso://live/{promiseId}
  static func parseLivePromise(from url: URL) -> DeeplinkDestination? {
    guard let promiseId = url.pathComponents.dropFirst().first else {
      return nil
    }
    return .livePromise(promiseId: promiseId)
  }

  /// promiso://personalEvent/{eventId}
  static func parsePersonalEvent(from url: URL) -> DeeplinkDestination? {
    guard let eventId = url.pathComponents.dropFirst().first else {
      return nil
    }
    return .personalEvent(eventId: eventId)
  }
}
