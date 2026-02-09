//
//  CalendarSyncPromise.swift
//  PromisoShared
//
//  캘린더 동기화용 약속 모델
//

import Foundation
import CryptoKit

/// 캘린더 동기화용 약속 정보 (최소 데이터)
public struct CalendarSyncPromise: Equatable, Sendable, Codable {
  public let id: String
  public let title: String
  public let emoji: String
  public let startAt: Date
  public let endAt: Date?
  public let location: String?
  public let groupId: String

  public init(
    id: String,
    title: String,
    emoji: String,
    startAt: Date,
    endAt: Date?,
    location: String?,
    groupId: String
  ) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.startAt = startAt
    self.endAt = endAt
    self.location = location
    self.groupId = groupId
  }

  /// 캘린더 이벤트 제목 (이모지 + 제목)
  public var calendarTitle: String {
    "\(emoji) \(title)"
  }

  /// 콘텐츠 해시 (변경 감지용)
  /// title, location, startAt, endAt을 조합하여 SHA256 해시 생성
  public var contentHash: String {
    // UTC 기준 timestamp 사용 (타임존 불일치 방지)
    let startTimestamp = Int(startAt.timeIntervalSince1970)
    let endTimestamp = endAt.map { Int($0.timeIntervalSince1970) } ?? 0

    let content = "\(title)|\(location ?? "")|\(startTimestamp)|\(endTimestamp)"
    let data = Data(content.utf8)
    let hash = SHA256.hash(data: data)

    // 앞 8자만 사용 (32bit, 충분한 유니크성)
    return hash.prefix(4).map { String(format: "%02x", $0) }.joined()
  }
}

// MARK: - Promiso Calendar Event (EventKit에서 파싱된 이벤트)

/// EventKit에서 파싱된 Promiso 이벤트 정보
public struct PromisoCalendarEvent: Equatable, Sendable {
  public let eventIdentifier: String
  public let promiseId: String
  public let contentHash: String
  public let userNotes: String?
  public let isPersonal: Bool

  public init(
    eventIdentifier: String,
    promiseId: String,
    contentHash: String,
    userNotes: String?,
    isPersonal: Bool = false
  ) {
    self.eventIdentifier = eventIdentifier
    self.promiseId = promiseId
    self.contentHash = contentHash
    self.userNotes = userNotes
    self.isPersonal = isPersonal
  }
}

// MARK: - Promiso Calendar URL Utilities

public enum PromisoCalendarTag {
  /// URL 스킴: promiso://promise/{promiseId}?hash={contentHash}
  /// 개인 일정: promiso://personal/{eventId}?hash={contentHash}
  public static let scheme = "promiso"
  public static let promiseHost = "promise"
  public static let personalHost = "personal"

  /// URL에서 Promiso 정보 파싱 (약속 + 개인 일정 모두 지원)
  public static func parse(from url: URL?) -> (id: String, contentHash: String, isPersonal: Bool)? {
    guard let url,
          url.scheme == scheme,
          let host = url.host,
          host == promiseHost || host == personalHost else {
      return nil
    }

    let id = url.lastPathComponent
    guard !id.isEmpty && id != "/" else { return nil }

    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let hashItem = components.queryItems?.first(where: { $0.name == "hash" }),
          let contentHash = hashItem.value,
          !contentHash.isEmpty else {
      return nil
    }

    return (id, contentHash, host == personalHost)
  }

  /// 그룹 약속 URL 생성
  public static func createURL(promiseId: String, contentHash: String) -> URL? {
    createURL(id: promiseId, host: promiseHost, contentHash: contentHash)
  }

  /// 개인 일정 URL 생성
  public static func createPersonalURL(eventId: String, contentHash: String) -> URL? {
    createURL(id: eventId, host: personalHost, contentHash: contentHash)
  }

  private static func createURL(id: String, host: String, contentHash: String) -> URL? {
    var components = URLComponents()
    components.scheme = scheme
    components.host = host
    components.path = "/\(id)"
    components.queryItems = [URLQueryItem(name: "hash", value: contentHash)]
    return components.url
  }
}
