//import Foundation
//
//// MARK: - Core Promise Model (Firebase 직접 통신용)
//public struct CorePromiseModel {
//  // MARK: - 식별 및 기본 정보
//  /// 고유 약속 ID (Firestore document ID)
//  public let id: String
//  /// 시각적 표현용 이모지 (Optional, 추후 AI 자동 생성 고려)
//  public let emoji: String?
//  /// 약속 제목
//  public let title: String
//  /// 약속 설명 (Optional)
//  public let description: String?
//  
//  // MARK: - 확정 조건
//  /// 약속이 확정되기 위한 최소 참가 인원
//  public let minimumParticipants: Int
//  /// 약속 확정 여부 (minimumParticipants 이상 참석 시 true)
//  public let isConfirmed: Bool
//  
//  // MARK: - 참가자 정보
//  /// 제안자(호스트) User ID
//  public let hostId: String
//  /// 소속 그룹 ID
//  public let groupId: String
//  /// 참가자별 상태 맵 (userId → 상태)
//  public let participantStatuses: [String: ParticipantStatus]
//  
//  // MARK: - 시간 정보
//  /// 생성 시각 (Firebase Timestamp seconds)
//  public let createdTime: Double
//  /// 마지막 수정 시각
//  public let updatedTime: Double
//  /// 약속 시작 시각
//  public let startTime: Double
//  /// 약속 종료 시각 (Optional)
//  public let endTime: Double?
//  
//  // MARK: - 상태 및 부가 정보
//  /// 약속 상태 (활성, 취소, 완료)
//  public let status: PromiseStatus
//  /// 위치 정보 (Optional)
//  public let location: LocationInfo?
//  /// Soft delete 여부 (true면 논리 삭제)
//  public let isDeleted: Bool
//  
//  /// 참가자 상태
//  public enum ParticipantStatus: String, Codable {
//    /// 응답 대기
//    case pending = "pending"
//    /// 참석
//    case confirmed = "confirmed"
//    /// 불참
//    case declined = "declined"
//    /// 미정
//    case tentative = "tentative"
//  }
//
//  /// 약속 상태
//  public enum PromiseStatus: String, Codable {
//    /// 활성
//    case active = "active"
//    /// 취소됨
//    case cancelled = "cancelled"
//    /// 완료됨
//    case completed = "completed"
//  }
//
//  /// 위치 정보
//  public struct LocationInfo: Codable {
//    public let name: String
//    public let address: String?
//  }
//}
//
//// MARK: - 참가자 상태 관련 계산 프로퍼티
//extension CorePromiseModel {
//  /// 참석 확정된 참가자 ID 목록
//  public var confirmedParticipantIds: [String] {
//    participantStatuses.compactMap { $0.value == .confirmed ? $0.key : nil }
//  }
//  
//  /// 불참을 선택한 참가자 ID 목록
//  public var declinedParticipantIds: [String] {
//    participantStatuses.compactMap { $0.value == .declined ? $0.key : nil }
//  }
//  
//  /// 응답 대기 중인 참가자 ID 목록
//  public var pendingParticipantIds: [String] {
//    participantStatuses.compactMap { $0.value == .pending ? $0.key : nil }
//  }
//  
//  /// 미정(tentative) 상태 참가자 ID 목록
//  public var tentativeParticipantIds: [String] {
//    participantStatuses.compactMap { $0.value == .tentative ? $0.key : nil }
//  }
//}
//
//// MARK: - Computed Properties Extension
//extension CorePromiseModel {
//  /// 전체 초대된 참가자 수
//  public var totalParticipants: Int {
//    participantStatuses.count
//  }
//  
//  /// 확정된 참가자 수
//  public var confirmedCount: Int {
//    confirmedParticipantIds.count
//  }
//  
//  /// 약속 확정 가능 여부
//  public var canBeConfirmed: Bool {
//    confirmedCount >= minimumParticipants
//  }
//  
//  /// 현재 시간 기준 약속 상태
//  public var timeStatus: TimeStatus {
//    let now = Date().timeIntervalSince1970
//    if now < startTime {
//      return .upcoming
//    } else if let endTime = endTime, now > endTime {
//      return .past
//    } else {
//      return .ongoing
//    }
//  }
//  
//  public enum TimeStatus {
//    /// 예정
//    case upcoming
//    /// 진행중
//    case ongoing
//    /// 종료
//    case past
//  }
//}
//
//// MARK: - Firebase Conversion
//extension CorePromiseModel {
//  /// Firebase 저장용 Dictionary 변환
//  public func toDictionary() -> [String: Any] {
//    var dict: [String: Any] = [
//      // 기본 정보
//      "id": id,
//      "title": title,
//      "host_id": hostId,
//      "group_id": groupId,
//      
//      // 확정 조건
//      "minimum_participants": minimumParticipants,
//      "is_confirmed": isConfirmed,
//      
//      // 참가자 상태
//      "participant_statuses": participantStatuses.mapValues { $0.rawValue },
//      
//      // 시간 정보
//      "created_time": createdTime,
//      "updated_time": updatedTime,
//      "start_time": startTime,
//      
//      // 상태 플래그
//      "status": status.rawValue,
//      "is_deleted": isDeleted
//    ]
//    
//    // MARK: - Optional 필드
//    if let emoji = emoji {
//      dict["emoji"] = emoji
//    }
//    
//    if let description = description {
//      dict["description"] = description
//    }
//    
//    if let endTime = endTime {
//      dict["end_time"] = endTime
//    }
//    
//    if let location = location {
//      dict["location"] = [
//        "name": location.name,
//        "address": location.address ?? ""
//      ]
//    }
//    
//    return dict
//  }
//}
