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

  public init(
    eventIdentifier: String,
    promiseId: String,
    contentHash: String,
    userNotes: String?
  ) {
    self.eventIdentifier = eventIdentifier
    self.promiseId = promiseId
    self.contentHash = contentHash
    self.userNotes = userNotes
  }
}

// MARK: - Promiso Tag Utilities

public enum PromisoCalendarTag {
  /// 태그 정규식 패턴: [Promiso:promiseId:contentHash]
  public static let pattern = "\\[Promiso:([^:]+):([^\\]]+)\\]"

  /// notes에서 Promiso 태그 파싱
  public static func parse(from notes: String?) -> (promiseId: String, contentHash: String)? {
    guard let notes else { return nil }

    guard let regex = try? NSRegularExpression(pattern: pattern),
          let match = regex.firstMatch(
            in: notes,
            range: NSRange(notes.startIndex..., in: notes)
          ) else {
      return nil
    }

    guard let promiseIdRange = Range(match.range(at: 1), in: notes),
          let hashRange = Range(match.range(at: 2), in: notes) else {
      return nil
    }

    return (String(notes[promiseIdRange]), String(notes[hashRange]))
  }

  /// Promiso 태그 생성
  public static func createTag(promiseId: String, contentHash: String) -> String {
    "[Promiso:\(promiseId):\(contentHash)]"
  }

  /// notes에 Promiso 태그 추가/업데이트 (기존 사용자 메모 보존)
  public static func updateNotes(existingNotes: String?, promiseId: String, contentHash: String) -> String {
    let tag = createTag(promiseId: promiseId, contentHash: contentHash)

    guard let existingNotes, !existingNotes.isEmpty else {
      return tag
    }

    // 기존 태그가 있으면 교체
    if let regex = try? NSRegularExpression(pattern: pattern) {
      let range = NSRange(existingNotes.startIndex..., in: existingNotes)
      if regex.firstMatch(in: existingNotes, range: range) != nil {
        let updated = regex.stringByReplacingMatches(
          in: existingNotes,
          range: range,
          withTemplate: tag
        )
        return updated
      }
    }

    // 기존 태그 없으면 끝에 추가
    return "\(existingNotes)\n\n\(tag)"
  }

  /// notes에서 Promiso 태그 제거하고 사용자 메모만 반환
  public static func extractUserNotes(from notes: String?) -> String? {
    guard let notes else { return nil }

    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return notes
    }

    let range = NSRange(notes.startIndex..., in: notes)
    let cleaned = regex.stringByReplacingMatches(in: notes, range: range, withTemplate: "")
      .trimmingCharacters(in: .whitespacesAndNewlines)

    return cleaned.isEmpty ? nil : cleaned
  }
}
