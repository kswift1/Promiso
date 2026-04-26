import ActivityKit
import Foundation

// MARK: - Schedule Activity Attributes

/// 라이브액티비티의 고정 속성 (Activity 생성 시 설정, 이후 변경 불가)
public struct ScheduleActivityAttributes: ActivityAttributes, Equatable, Sendable {

  // MARK: - Attributes (고정 정보)

  /// LiveActivity 추적 시간 (분) - 일정 N분 전부터 시작
  public let trackingDurationMinutes: Int

  /// 일정 고유 ID
  public let scheduleId: String

  /// 현재 사용자 ID
  public let currentUserId: String

  /// 일정 이모지
  public let emoji: String

  /// 일정 제목
  public let title: String

  /// 일정 장소명 (예: "강남역 11번 출구")
  public let location: String?

  /// 장소 위도
  public let latitude: Double?

  /// 장소 경도
  public let longitude: Double?

  /// 일정 시간
  public let scheduledTime: Date

  /// 호스트 ID
  public let hostId: String

  /// 호스트 이름
  public let hostName: String?

  /// iOS 18 Broadcast 채널 ID (Apple이 생성)
  public let channelId: String

  /// 그룹 이름
  public let groupName: String?

  /// 그룹 이미지 URL
  public let groupImageUrl: String?

  // MARK: - CodingKeys

  private enum CodingKeys: String, CodingKey {
    case trackingDurationMinutes
    case scheduleId
    case currentUserId
    case emoji
    case title
    case location
    case latitude
    case longitude
    case scheduledTime
    case hostId
    case hostName
    case channelId
    case groupName
    case groupImageUrl
  }

  // MARK: - Initializer

  public init(
    scheduleId: String,
    currentUserId: String,
    emoji: String,
    title: String,
    location: String?,
    latitude: Double? = nil,
    longitude: Double? = nil,
    scheduledTime: Date,
    trackingDurationMinutes: Int = 30,
    hostId: String = "",
    hostName: String? = nil,
    channelId: String = "",
    groupName: String? = nil,
    groupImageUrl: String? = nil
  ) {
    self.scheduleId = scheduleId
    self.currentUserId = currentUserId
    self.emoji = emoji
    self.title = title
    self.location = location
    self.latitude = latitude
    self.longitude = longitude
    self.scheduledTime = scheduledTime
    self.trackingDurationMinutes = trackingDurationMinutes
    self.hostId = hostId
    self.hostName = hostName
    self.channelId = channelId
    self.groupName = groupName
    self.groupImageUrl = groupImageUrl
  }

  // MARK: - Decodable (Unix timestamp → Date 변환)

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)

    self.trackingDurationMinutes = try container.decode(Int.self, forKey: .trackingDurationMinutes)
    self.scheduleId = try container.decode(String.self, forKey: .scheduleId)
    self.currentUserId = try container.decode(String.self, forKey: .currentUserId)
    self.emoji = try container.decode(String.self, forKey: .emoji)
    self.title = try container.decode(String.self, forKey: .title)
    self.location = try container.decodeIfPresent(String.self, forKey: .location)
    self.latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
    self.longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
    self.hostId = try container.decodeIfPresent(String.self, forKey: .hostId) ?? ""
    self.hostName = try container.decodeIfPresent(String.self, forKey: .hostName)
    self.channelId = try container.decodeIfPresent(String.self, forKey: .channelId) ?? ""
    self.groupName = try container.decodeIfPresent(String.self, forKey: .groupName)
    self.groupImageUrl = try container.decodeIfPresent(String.self, forKey: .groupImageUrl)

    // scheduledTime: Unix timestamp (1970년 기준 초) → Date 변환
    let timestamp = try container.decode(Double.self, forKey: .scheduledTime)
    self.scheduledTime = Date(timeIntervalSince1970: timestamp)
  }

  // MARK: - Encodable (Date → Unix timestamp 변환)

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)

    try container.encode(trackingDurationMinutes, forKey: .trackingDurationMinutes)
    try container.encode(scheduleId, forKey: .scheduleId)
    try container.encode(currentUserId, forKey: .currentUserId)
    try container.encode(emoji, forKey: .emoji)
    try container.encode(title, forKey: .title)
    try container.encodeIfPresent(location, forKey: .location)
    try container.encodeIfPresent(latitude, forKey: .latitude)
    try container.encodeIfPresent(longitude, forKey: .longitude)
    try container.encode(hostId, forKey: .hostId)
    try container.encodeIfPresent(hostName, forKey: .hostName)
    try container.encode(channelId, forKey: .channelId)
    try container.encodeIfPresent(groupName, forKey: .groupName)
    try container.encodeIfPresent(groupImageUrl, forKey: .groupImageUrl)

    // Date → Unix timestamp (1970년 기준 초) 변환
    try container.encode(scheduledTime.timeIntervalSince1970, forKey: .scheduledTime)
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
  /// App Group Suite 이름 (환경별로 다름)
  public static var suiteName: String {
    // Bundle ID에서 환경 구분: com.promiso.dev.* → dev, com.promiso.stage.* → stage
    let bundleId = Bundle.main.bundleIdentifier ?? ""
    if bundleId.contains(".dev") {
      return "group.com.promiso.dev.shared"
    } else if bundleId.contains(".stage") {
      return "group.com.promiso.stage.shared"
    } else {
      return "group.com.promiso.shared"
    }
  }

  /// ETA 업데이트 저장 키
  public static let etaUpdateKey = "liveActivity.etaUpdate"

  /// Access token fallback 저장 키 (Widget에서 인증용)
  public static let authTokenKey = "firebase.auth.idToken"

  /// Access token fallback 만료 시간 저장 키
  public static let authTokenExpiryKey = "firebase.auth.tokenExpiry"

  /// Widget 전용 Long-lived Token 저장 키 (30일 유효)
  public static let widgetTokenKey = "widget.auth.token"

  /// Widget Token 만료 시간 저장 키
  public static let widgetTokenExpiryKey = "widget.auth.tokenExpiry"

  /// Widget Token 발급에 사용한 디바이스 ID 저장 키
  public static let widgetDeviceIdKey = "widget.auth.deviceId"

  /// Firebase Emulator Host 저장 키 (개발 환경용)
  public static let emulatorHostKey = "firebase.emulator.host"

  /// APNs 환경 저장 키 (Widget에서 백엔드 호출 시 사용)
  public static let apnsEnvironmentKey = "apns.environment"

  /// Rust API Base URL 저장 키 (Widget에서 Cloud Run 호출 시 사용)
  public static let rustApiBaseUrlKey = "rust.api.baseUrl"

  /// Rust API Base URL
  public static var rustAPIBaseURL: String {
    if let savedURL = UserDefaults(suiteName: suiteName)?.string(forKey: rustApiBaseUrlKey),
       !savedURL.isEmpty {
      return savedURL
    }

    let bundleId = Bundle.main.bundleIdentifier ?? ""
    if bundleId.contains(".dev") {
      return AppConstants.Network.devRustAPIURLString
    }
    if bundleId.contains(".stage") {
      return AppConstants.Network.stageRustAPIURLString
    }
    return AppConstants.Network.prodRustAPIURLString
  }
}

/// 도착 예상 시간 업데이트 정보
public struct ETAUpdate: Codable, Equatable, Sendable {
  /// 일정 ID
  public let scheduleId: String

  /// 사용자 ID
  public let userId: String

  /// 도착 예상 시간 (분) - 0이면 도착
  public let estimatedMinutes: Int

  /// 업데이트 시간
  public let timestamp: Date

  public init(scheduleId: String, userId: String, estimatedMinutes: Int, timestamp: Date) {
    self.scheduleId = scheduleId
    self.userId = userId
    self.estimatedMinutes = estimatedMinutes
    self.timestamp = timestamp
  }
}
