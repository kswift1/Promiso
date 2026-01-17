import Foundation

// MARK: - DeeplinkURLParser

/// 딥링크 URL 파싱 담당
///
/// 지원하는 URL 형식:
/// - `promiso://join/{inviteCode}` → 초대 코드로 그룹 참여
/// - `promiso://group/{groupId}` → 그룹 상세 화면
/// - `promiso://promise/{promiseId}/{groupId}` → 약속 상세 화면
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

  /// promiso://promise/{promiseId}/{groupId}
  static func parsePromise(from url: URL) -> DeeplinkDestination? {
    let components = Array(url.pathComponents.dropFirst())
    guard components.count >= 2 else {
      return nil
    }
    let promiseId = components[0]
    let groupId = components[1]
    return .promise(promiseId: promiseId, groupId: groupId)
  }
}
