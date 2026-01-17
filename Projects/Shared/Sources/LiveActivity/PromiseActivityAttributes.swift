import ActivityKit
import Foundation

// MARK: - Promise Activity Attributes

/// 라이브액티비티 속성 (변하지 않는 값)
public struct PromiseActivityAttributes: ActivityAttributes {
  /// 약속 ID
  public let promiseId: String
  /// 약속 제목
  public let title: String
  /// 이모지
  public let emoji: String
  /// 약속 시작 시간
  public let startAt: Date
  /// 장소명 (옵셔널)
  public let locationName: String?
  /// 그룹 ID
  public let groupId: String
  /// 총 참여 인원
  public let totalParticipants: Int

  public init(
    promiseId: String,
    title: String,
    emoji: String,
    startAt: Date,
    locationName: String?,
    groupId: String,
    totalParticipants: Int
  ) {
    self.promiseId = promiseId
    self.title = title
    self.emoji = emoji
    self.startAt = startAt
    self.locationName = locationName
    self.groupId = groupId
    self.totalParticipants = totalParticipants
  }

  // MARK: - Content State

  /// 실시간 변경되는 상태
  public struct ContentState: Codable, Hashable {
    /// 멤버별 도착 상태
    public let memberStatuses: [MemberArrivalStatus]
    /// 마지막 업데이트 시간
    public let lastUpdatedAt: Date
    /// 종료 여부
    public let isEnded: Bool

    public init(
      memberStatuses: [MemberArrivalStatus],
      lastUpdatedAt: Date = Date(),
      isEnded: Bool = false
    ) {
      self.memberStatuses = memberStatuses
      self.lastUpdatedAt = lastUpdatedAt
      self.isEnded = isEnded
    }

    /// 도착한 인원 수
    public var arrivedCount: Int {
      memberStatuses.filter(\.hasArrived).count
    }

    /// 초기 상태 (모두 미도착)
    public static func initial(memberIds: [String], memberNames: [String]) -> ContentState {
      let statuses = zip(memberIds, memberNames).map { id, name in
        MemberArrivalStatus(memberId: id, memberName: name)
      }
      return ContentState(memberStatuses: statuses, isEnded: false)
    }
  }
}

// MARK: - Member Arrival Status

/// 멤버 도착 상태
public struct MemberArrivalStatus: Codable, Hashable, Identifiable, Sendable {
  public var id: String { memberId }

  /// 멤버 ID
  public let memberId: String
  /// 멤버 이름 (표시용)
  public let memberName: String
  /// 도착 여부
  public let hasArrived: Bool
  /// 도착 시간 (도착한 경우)
  public let arrivedAt: Date?

  public init(
    memberId: String,
    memberName: String,
    hasArrived: Bool = false,
    arrivedAt: Date? = nil
  ) {
    self.memberId = memberId
    self.memberName = memberName
    self.hasArrived = hasArrived
    self.arrivedAt = arrivedAt
  }

  /// 도착 처리된 새 인스턴스 반환
  public func arrived() -> MemberArrivalStatus {
    MemberArrivalStatus(
      memberId: memberId,
      memberName: memberName,
      hasArrived: true,
      arrivedAt: Date()
    )
  }
}

