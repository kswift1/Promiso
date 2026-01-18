import ActivityKit
import SwiftUI

// MARK: - Promise Activity Attributes

/// 라이브액티비티의 고정 속성 (Activity 생성 시 설정, 이후 변경 불가)
public struct PromiseActivityAttributes: ActivityAttributes {

  // MARK: - Static Properties

  /// 약속 추적 기본 시간 (30분 = 1800초)
  public static let totalDuration: TimeInterval = 1800

  // MARK: - Attributes (고정 정보)

  /// 약속 고유 ID
  public let promiseId: String

  /// 현재 사용자 ID
  public let currentUserId: String

  /// 약속 제목 (이모지 포함)
  public let title: String

  /// 약속 장소명 (예: "강남역 11번 출구")
  public let location: String?

  /// 약속 시간
  public let scheduledTime: Date

  // MARK: - Initializer

  public init(
    promiseId: String,
    currentUserId: String,
    title: String,
    location: String?,
    scheduledTime: Date
  ) {
    self.promiseId = promiseId
    self.currentUserId = currentUserId
    self.title = title
    self.location = location
    self.scheduledTime = scheduledTime
  }

  // MARK: - Content State (동적 정보)

  /// 라이브액티비티의 동적 상태 (실시간 업데이트 가능)
  public struct ContentState: Codable, Hashable, Sendable {

    /// 약속까지 남은 시간 (초)
    public let remainingSeconds: Int

    /// 참가자들의 현재 상태
    public let participants: [ParticipantState]

    public init(remainingSeconds: Int, participants: [ParticipantState]) {
      self.remainingSeconds = remainingSeconds
      self.participants = participants
    }

    // MARK: - Computed Properties

    /// 기본 진행률 (0.0 ~ 1.0)
    /// - 경과 시간 / 총 시간으로 계산
    public var baseProgress: Double {
      let elapsed = PromiseActivityAttributes.totalDuration - Double(remainingSeconds)
      return min(max(elapsed / PromiseActivityAttributes.totalDuration, 0), 1)
    }

    /// 긴급 상태 여부 (10분 미만 남음)
    public var isUrgent: Bool {
      remainingSeconds < 600
    }

    // MARK: - Update Methods

    /// 특정 참가자의 상태를 업데이트한 새 ContentState 반환
    public func updating(participantId: String, status: ParticipantStatus) -> ContentState {
      let updatedParticipants = participants.map { participant in
        if participant.id == participantId {
          return ParticipantState(id: participant.id, name: participant.name, status: status)
        }
        return participant
      }
      return ContentState(remainingSeconds: remainingSeconds, participants: updatedParticipants)
    }

    /// 남은 시간을 업데이트한 새 ContentState 반환
    public func updating(remainingSeconds: Int) -> ContentState {
      ContentState(remainingSeconds: remainingSeconds, participants: participants)
    }

    // MARK: - Factory Methods

    /// 초기 상태 생성
    /// - Parameters:
    ///   - remainingSeconds: 남은 시간 (초)
    ///   - participantIds: 참가자 ID 목록
    ///   - participantNames: 참가자 이름 목록
    /// - Returns: 모든 참가자가 pending 상태인 초기 ContentState
    public static func initial(
      remainingSeconds: Int,
      participantIds: [String],
      participantNames: [String]
    ) -> ContentState {
      let participants = zip(participantIds, participantNames).map { id, name in
        ParticipantState(id: id, name: name, status: .pending)
      }
      return ContentState(remainingSeconds: remainingSeconds, participants: participants)
    }
  }
}

// MARK: - Participant State

/// 개별 참가자의 상태 정보
public struct ParticipantState: Codable, Hashable, Identifiable, Sendable {

  /// 참가자 고유 ID
  public let id: String

  /// 참가자 표시 이름
  public let name: String

  /// 현재 상태 (대기/출발/지각/도착)
  public var status: ParticipantStatus

  public init(id: String, name: String, status: ParticipantStatus) {
    self.id = id
    self.name = name
    self.status = status
  }

  /// 레이싱 트랙에서의 위치 계산 (0.0 ~ 1.0)
  /// - Parameter baseProgress: 기본 진행률 (시간 기준)
  /// - Returns: 트랙 상 위치 (0.0 = 출발, 1.0 = 도착)
  public func trackPosition(baseProgress: Double) -> Double {
    switch status {
    case .pending:
      return 0.0
    case .departed:
      return min(baseProgress + 0.15, 0.95)
    case .late:
      return max(baseProgress - 0.20, 0.05)
    case .arrived:
      return 1.0
    }
  }

  /// 상태를 변경한 새 ParticipantState 반환
  public func with(status: ParticipantStatus) -> ParticipantState {
    ParticipantState(id: id, name: name, status: status)
  }
}

// MARK: - Participant Status

/// 참가자의 이동 상태
public enum ParticipantStatus: String, Codable, Hashable, Sendable {
  /// 대기 중 (아직 출발 안 함)
  case pending

  /// 출발함 (이동 중)
  case departed

  /// 지각 예상
  case late

  /// 도착 완료
  case arrived

  /// 상태별 표시 색상
  public var color: Color {
    switch self {
    case .pending:  return .gray
    case .departed: return .blue
    case .late:     return .orange
    case .arrived:  return .green
    }
  }

  /// 상태별 이모지
  public var emoji: String {
    switch self {
    case .pending:  return "😴"
    case .departed: return "🏃"
    case .late:     return "😰"
    case .arrived:  return "✅"
    }
  }

  /// 상태별 한글 레이블
  public var label: String {
    switch self {
    case .pending:  return "대기"
    case .departed: return "출발"
    case .late:     return "지각"
    case .arrived:  return "도착"
    }
  }
}

// MARK: - Intent Models (App & Widget 통신용)

/// App Group UserDefaults 키
public enum LiveActivityIntentKey {
  /// App Group Suite 이름
  public static let suiteName = "group.com.promiso.app"

  /// 출발 상태 저장 키
  public static let departureKey = "liveActivity.departure"

  /// 도착 상태 저장 키
  public static let arrivalKey = "liveActivity.arrival"
}

/// 출발 버튼 탭 시 저장되는 정보
public struct DepartureStatus: Codable, Sendable {
  /// 약속 ID
  public let promiseId: String

  /// 사용자 ID
  public let oderId: String

  /// 출발 시간
  public let timestamp: Date

  public init(promiseId: String, oderId: String, timestamp: Date) {
    self.promiseId = promiseId
    self.oderId = oderId
    self.timestamp = timestamp
  }
}

/// 도착 버튼 탭 시 저장되는 정보
public struct ArrivalStatus: Codable, Sendable {
  /// 약속 ID
  public let promiseId: String

  /// 사용자 ID
  public let oderId: String

  /// 도착 시간
  public let timestamp: Date

  public init(promiseId: String, oderId: String, timestamp: Date) {
    self.promiseId = promiseId
    self.oderId = oderId
    self.timestamp = timestamp
  }
}
