import ActivityKit
import Foundation

// MARK: - Promise Activity Attributes

/// 라이브액티비티의 고정 속성 (Activity 생성 시 설정, 이후 변경 불가)
public struct PromiseActivityAttributes: ActivityAttributes, Equatable {

  // MARK: - Attributes (고정 정보)

  /// LiveActivity 추적 시간 (분) - 약속 N분 전부터 시작
  public let trackingDurationMinutes: Int

  /// 약속 고유 ID
  public let promiseId: String

  /// 현재 사용자 ID
  public let currentUserId: String

  /// 약속 이모지
  public let emoji: String

  /// 약속 제목
  public let title: String

  /// 약속 장소명 (예: "강남역 11번 출구")
  public let location: String?

  /// 약속 시간
  public let scheduledTime: Date

  /// 호스트 ID
  public let hostId: String

  /// 호스트 이름
  public let hostName: String?

  // MARK: - Initializer

  public init(
    promiseId: String,
    currentUserId: String,
    emoji: String,
    title: String,
    location: String?,
    scheduledTime: Date,
    trackingDurationMinutes: Int = 30,
    hostId: String = "",
    hostName: String? = nil
  ) {
    self.promiseId = promiseId
    self.currentUserId = currentUserId
    self.emoji = emoji
    self.title = title
    self.location = location
    self.scheduledTime = scheduledTime
    self.trackingDurationMinutes = trackingDurationMinutes
    self.hostId = hostId
    self.hostName = hostName
  }

  // MARK: - Content State (동적 정보)

  /// 라이브액티비티의 동적 상태 (실시간 업데이트 가능)
  public struct ContentState: Codable, Hashable, Sendable {

    /// LiveActivity 추적 시간 (분)
    public let trackingDurationMinutes: Int

    /// 참가자들의 현재 상태
    public let participants: [ParticipantState]

    public init(
      trackingDurationMinutes: Int = 30,
      participants: [ParticipantState]
    ) {
      self.trackingDurationMinutes = trackingDurationMinutes
      self.participants = participants
    }

    // MARK: - Update Methods

    /// 특정 참가자의 도착 예상 시간을 업데이트한 새 ContentState 반환
    public func updating(participantId: String, estimatedArrivalMinutes: Int?) -> ContentState {
      let updatedParticipants = participants.map { participant in
        if participant.id == participantId {
          return ParticipantState(
            id: participant.id,
            name: participant.name,
            estimatedArrivalMinutes: estimatedArrivalMinutes
          )
        }
        return participant
      }
      return ContentState(
        trackingDurationMinutes: trackingDurationMinutes,
        participants: updatedParticipants
      )
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

  /// 도착 예상 시간 (분)
  /// - nil: 아직 입력 안함 (대기)
  /// - 0: 도착 완료
  /// - 5, 10, 15, 30: N분 뒤 도착 예상
  public var estimatedArrivalMinutes: Int?

  public init(
    id: String,
    name: String,
    estimatedArrivalMinutes: Int? = nil
  ) {
    self.id = id
    self.name = name
    self.estimatedArrivalMinutes = estimatedArrivalMinutes
  }

  /// 레이싱 트랙에서의 위치 계산 (0.0 ~ 1.0)
  /// - Parameter trackingDurationMinutes: LiveActivity 추적 시간 (분)
  /// - Returns: 트랙 상 위치 (0.0 = 출발, 1.0 = 도착)
  public func trackPosition(trackingDurationMinutes: Int) -> Double {
    guard let eta = estimatedArrivalMinutes else { return 0.0 }  // 대기 상태
    if eta == 0 { return 1.0 }  // 도착
    let progress = Double(trackingDurationMinutes - eta) / Double(trackingDurationMinutes)
    return min(max(progress, 0.05), 0.95)
  }

  /// 진행률 (0.0 ~ 1.0)
  /// - Parameter trackingDurationMinutes: LiveActivity 추적 시간 (분)
  public func progress(trackingDurationMinutes: Int) -> Double {
    trackPosition(trackingDurationMinutes: trackingDurationMinutes)
  }

  /// 도착 예상 시간을 변경한 새 ParticipantState 반환
  public func with(estimatedArrivalMinutes: Int?) -> ParticipantState {
    ParticipantState(
      id: id,
      name: name,
      estimatedArrivalMinutes: estimatedArrivalMinutes
    )
  }
}


// MARK: - Intent Models (App & Widget 통신용)

/// App Group UserDefaults 키
public enum LiveActivityIntentKey {
  /// App Group Suite 이름
  public static let suiteName = "group.com.promiso.shared"

  /// ETA 업데이트 저장 키
  public static let etaUpdateKey = "liveActivity.etaUpdate"

  /// Firebase Project ID (Widget에서 HTTP 호출용)
  public static let firebaseProjectId = "promiso-7a534"

  /// Firebase Auth ID Token 저장 키 (Widget에서 인증용)
  public static let authTokenKey = "firebase.auth.idToken"

  /// Firebase Auth Token 만료 시간 저장 키
  public static let authTokenExpiryKey = "firebase.auth.tokenExpiry"

  /// Firebase Emulator Host 저장 키 (개발 환경용)
  public static let emulatorHostKey = "firebase.emulator.host"
}

/// 도착 예상 시간 업데이트 정보
public struct ETAUpdate: Codable, Equatable, Sendable {
  /// 약속 ID
  public let promiseId: String

  /// 사용자 ID
  public let userId: String

  /// 도착 예상 시간 (분) - 0이면 도착
  public let estimatedMinutes: Int

  /// 업데이트 시간
  public let timestamp: Date

  public init(promiseId: String, userId: String, estimatedMinutes: Int, timestamp: Date) {
    self.promiseId = promiseId
    self.userId = userId
    self.estimatedMinutes = estimatedMinutes
    self.timestamp = timestamp
  }
}
