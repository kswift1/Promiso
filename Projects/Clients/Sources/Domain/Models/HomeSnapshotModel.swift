//
//  HomeSnapshotModel.swift
//  Clients
//
//  홈화면 스냅샷 모델
//  Firestore의 users/{uid}/cache/homeSnapshot 문서를 iOS 모델로 표현
//

import Foundation

// MARK: - Home Snapshot Document

/// 홈화면 스냅샷 문서
///
/// Firestore 경로: `users/{uid}/cache/homeSnapshot`
///
/// - Note: 서버에서 약속 생성/수정/삭제 시 자동으로 갱신됨
/// - SeeAlso: `homeSnapshotTrigger.ts`
public struct HomeSnapshotDocument: Codable, Equatable, Sendable {
  /// 오늘 확정된 약속 목록 (최대 5개)
  public let todayPromises: [SnapshotPromise]

  /// 응답 필요 약속 목록 (최대 5개)
  public let pendingPromises: [SnapshotPromise]

  /// 다가오는 약속 목록 - 오늘 제외 (최대 10개)
  public let upcomingPromises: [SnapshotPromise]

  /// 그룹별 요약 정보
  public let groups: [HomeSnapshotGroup]

  /// 메타데이터
  public let meta: HomeSnapshotMeta

  public init(
    todayPromises: [SnapshotPromise] = [],
    pendingPromises: [SnapshotPromise] = [],
    upcomingPromises: [SnapshotPromise] = [],
    groups: [HomeSnapshotGroup] = [],
    meta: HomeSnapshotMeta = .empty
  ) {
    self.todayPromises = todayPromises
    self.pendingPromises = pendingPromises
    self.upcomingPromises = upcomingPromises
    self.groups = groups
    self.meta = meta
  }

  /// 빈 스냅샷
  public static let empty = HomeSnapshotDocument()
}

// MARK: - Snapshot Promise

/// 스냅샷용 약속 데이터
///
/// - Note: Widget과 Home에서 공통으로 사용
public struct SnapshotPromise: Codable, Equatable, Sendable, Identifiable {
  /// 약속 ID
  public let id: String

  /// 약속 제목
  public let title: String

  /// 이모지
  public let emoji: String

  /// 시작 시간 (ISO 8601)
  public let startAt: String

  /// 종료 시간 (ISO 8601, 선택)
  public let endAt: String?

  /// 장소명 (선택)
  public let location: String?

  /// 그룹 ID
  public let groupId: String

  /// 그룹 이름 (선택)
  public let groupName: String?

  /// 그룹 이미지 URL (선택)
  public let groupImageUrl: String?

  /// 확정 여부 (acceptedCount >= minimumParticipants)
  public let isConfirmed: Bool

  /// 최소 참가 인원
  public let minimumParticipants: Int

  /// 투표 정보 (참가/불참 사용자 ID 목록)
  public let votes: SnapshotVotes

  /// 내 투표 상태
  public let myVoteStatus: SnapshotVoteStatus

  /// 투표 마감 시간 (ISO 8601, 선택)
  public let votingDeadline: String?

  public init(
    id: String,
    title: String,
    emoji: String = "📅",
    startAt: String,
    endAt: String? = nil,
    location: String? = nil,
    groupId: String,
    groupName: String? = nil,
    groupImageUrl: String? = nil,
    isConfirmed: Bool,
    minimumParticipants: Int = 2,
    votes: SnapshotVotes,
    myVoteStatus: SnapshotVoteStatus,
    votingDeadline: String? = nil
  ) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.startAt = startAt
    self.endAt = endAt
    self.location = location
    self.groupId = groupId
    self.groupName = groupName
    self.groupImageUrl = groupImageUrl
    self.isConfirmed = isConfirmed
    self.minimumParticipants = minimumParticipants
    self.votes = votes
    self.myVoteStatus = myVoteStatus
    self.votingDeadline = votingDeadline
  }

  /// 참가자 수 (accepted.count) - computed property
  public var participantCount: Int {
    votes.accepted.count
  }
}

// MARK: - Snapshot Votes

/// 스냅샷 투표 정보
public struct SnapshotVotes: Codable, Equatable, Sendable {
  /// 참가 확정 사용자 ID 목록
  public let accepted: [String]

  /// 불참 사용자 ID 목록
  public let declined: [String]

  public init(accepted: [String] = [], declined: [String] = []) {
    self.accepted = accepted
    self.declined = declined
  }

  /// 빈 투표 정보
  public static let empty = SnapshotVotes()
}

// MARK: - SnapshotPromise Computed Properties

extension SnapshotPromise {
  /// ISO8601 DateFormatter (재사용으로 성능 최적화)
  private static let isoFormatter = ISO8601DateFormatter()

  /// 시작 시간 (Date)
  public var startAtDate: Date {
    Self.isoFormatter.date(from: startAt) ?? Date()
  }

  /// 종료 시간 (Date, 선택)
  public var endAtDate: Date? {
    guard let endAt else { return nil }
    return Self.isoFormatter.date(from: endAt)
  }

  /// 투표 마감 시간 (Date, 선택)
  public var votingDeadlineDate: Date? {
    guard let votingDeadline else { return nil }
    return Self.isoFormatter.date(from: votingDeadline)
  }

  /// 투표 마감 여부
  public var isVotingClosed: Bool {
    guard let deadline = votingDeadlineDate else { return false }
    return deadline < Date()
  }

  /// 오늘 약속인지 확인
  public var isToday: Bool {
    Calendar.current.isDateInToday(startAtDate)
  }

  /// 과거 약속인지 확인
  public var isPast: Bool {
    startAtDate < Date()
  }

  /// 진행 중인 약속인지 확인
  public var isOngoing: Bool {
    let now = Date()
    guard let endAt = endAtDate else {
      // 종료 시간 없으면 시작 후 2시간까지 진행 중으로 판단
      let defaultEndAt = startAtDate.addingTimeInterval(2 * 60 * 60)
      return startAtDate <= now && now < defaultEndAt
    }
    return startAtDate <= now && now < endAt
  }

  /// 실시간 공유 가능 여부 (확정 + 시작 30분 전 ~ 종료)
  public var isRealtimeShareable: Bool {
    guard isConfirmed else { return false }
    let now = Date()
    let shareStartTime = startAtDate.addingTimeInterval(-30 * 60)
    let endTime = endAtDate ?? startAtDate.addingTimeInterval(2 * 60 * 60)
    return now >= shareStartTime && now < endTime
  }
}

// MARK: - Snapshot Vote Status

/// 투표 상태
public enum SnapshotVoteStatus: String, Codable, Sendable {
  /// 투표 전 (응답 필요)
  case pending
  /// 참석 투표 완료
  case voted
  /// 불참 투표 완료
  case declined
}

// MARK: - Home Snapshot Group

/// 홈화면 그룹 요약 정보
public struct HomeSnapshotGroup: Codable, Equatable, Sendable, Identifiable {
  /// 그룹 ID
  public let id: String

  /// 그룹 이름
  public let name: String

  /// 그룹 이모지 (선택)
  public let emoji: String?

  /// 그룹 이미지 URL (선택)
  public let imageUrl: String?

  /// 다음 약속 (선택)
  public let nextPromise: SnapshotPromise?

  public init(
    id: String,
    name: String,
    emoji: String? = nil,
    imageUrl: String? = nil,
    nextPromise: SnapshotPromise? = nil
  ) {
    self.id = id
    self.name = name
    self.emoji = emoji
    self.imageUrl = imageUrl
    self.nextPromise = nextPromise
  }
}

// MARK: - Home Snapshot Meta

/// 홈화면 스냅샷 메타데이터
public struct HomeSnapshotMeta: Codable, Equatable, Sendable {
  /// 오늘 약속 총 개수
  public let todayCount: Int

  /// 응답 필요 약속 총 개수
  public let pendingCount: Int

  /// 다가오는 약속 총 개수
  public let upcomingCount: Int

  /// 마지막 업데이트 시간 (ISO 8601)
  public let updatedAt: String

  /// 스냅샷 버전
  public let version: Int

  public init(
    todayCount: Int = 0,
    pendingCount: Int = 0,
    upcomingCount: Int = 0,
    updatedAt: String = "",
    version: Int = 1
  ) {
    self.todayCount = todayCount
    self.pendingCount = pendingCount
    self.upcomingCount = upcomingCount
    self.updatedAt = updatedAt
    self.version = version
  }

  /// 빈 메타데이터
  public static let empty = HomeSnapshotMeta()
}

// MARK: - SnapshotPromise to PromiseModel Conversion

extension SnapshotPromise {
  /// SnapshotPromise를 PromiseModel로 변환
  ///
  /// - Note: 스냅샷에 없는 필드들은 기본값 또는 추론된 값으로 설정됨
  /// - Parameter currentUserId: 현재 사용자 ID (사용하지 않음, API 호환성 유지)
  /// - Returns: PromiseModel
  public func toPromiseModel(currentUserId: String) -> PromiseModel {
    // 스냅샷의 votes를 그대로 사용
    let promiseVotes = PromiseVotesModel(
      accepted: votes.accepted,
      declined: votes.declined,
      until: votingDeadlineDate ?? Date().addingTimeInterval(86400)
    )

    // group 구성
    let group: GroupModel? = {
      guard let groupName else { return nil }
      return GroupModel(
        id: groupId,
        name: groupName,
        imageUrl: groupImageUrl,
        maxMembers: 0,
        inviteCode: "",
        createdBy: ""
      )
    }()

    return PromiseModel(
      id: id,
      title: title,
      emoji: emoji,
      description: nil,
      hostId: "",
      groupId: groupId,
      group: group,
      minimumParticipants: minimumParticipants,
      votes: promiseVotes,
      startAt: startAtDate,
      endAt: endAtDate,
      location: location != nil ? LocationInfoModel(name: location!) : nil,
      trackingStartMinutesBefore: nil,
      createdAt: Date(),
      updatedAt: Date()
    )
  }
}

// MARK: - Array Extension

extension Array where Element == SnapshotPromise {
  /// SnapshotPromise 배열을 PromiseModel 배열로 변환
  public func toPromiseModels(currentUserId: String) -> [PromiseModel] {
    map { $0.toPromiseModel(currentUserId: currentUserId) }
  }
}
