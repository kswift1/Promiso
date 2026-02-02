//
//  PromiseClient.swift
//  Clients
//
//  TCA Dependency Client for Promise operations
//  Acts as an adapter between Feature layer and Shared layer
//

import ComposableArchitecture
import Foundation
import Combine
import PromisoShared

// MARK: - Error

/// 약속 API 에러
public enum PromiseClientError: Error, Equatable {
  case networkError
  case unauthorized
  case notFound
  case serverError
  case invalidData(String?)
  case groupNotFound
  case notGroupMember
  case unknown(String?)

  public var localizedDescription: String {
    switch self {
    case .networkError:
      return "네트워크 연결을 확인해주세요"
    case .unauthorized:
      return "로그인이 필요합니다"
    case .notFound:
      return "약속을 찾을 수 없습니다"
    case .serverError:
      return "서버 오류가 발생했습니다"
    case .invalidData(let message):
      return message ?? "잘못된 데이터입니다"
    case .groupNotFound:
      return "그룹을 찾을 수 없습니다"
    case .notGroupMember:
      return "그룹 멤버만 약속을 만들 수 있습니다"
    case .unknown(let message):
      return message ?? "알 수 없는 오류가 발생했습니다"
    }
  }

  /// NSError를 PromiseClientError로 변환
  init(from error: Error) {
    let nsError = error as NSError
    let message = nsError.localizedDescription

    guard nsError.domain == "FIRFunctionsErrorDomain" else {
      self = .networkError
      return
    }

    switch nsError.code {
    case 16: self = .unauthorized
    case 3, 9: self = .invalidData(message)
    case 5: self = .groupNotFound
    case 7: self = .notGroupMember
    case 13: self = .serverError
    default: self = .unknown(message)
    }
  }
}

// MARK: - Client

/// TCA용 약속 클라이언트
/// Feature 레이어에 최적화된 API 제공
@DependencyClient
public struct PromiseClient: Sendable {
  /// 약속 생성
  public var createPromise: @Sendable (_ promise: PromiseModel) async throws -> String = { _ in "" }

  /// 약속 수정
  public var updatePromise: @Sendable (_ promise: PromiseModel) async throws -> Void

  /// 약속 삭제
  public var deletePromise: @Sendable (_ promiseId: String) async throws -> Void

  /// 약속 조회
  public var getPromise: @Sendable (_ promiseId: String) async throws -> PromiseModel?

  /// 오늘의 약속 조회 (사용자가 속한 그룹들의 약속)
  public var getTodayPromises: @Sendable (_ groupIds: [String]) async throws -> [PromiseModel]

  /// 다가오는 약속 조회 (사용자가 속한 그룹들의 약속)
  public var getUpcomingPromises: @Sendable (_ groupIds: [String], _ limit: Int) async throws -> [PromiseModel]

  /// 그룹의 활성 약속 조회
  public var getActivePromises: @Sendable (_ groupId: String, _ limit: Int) async throws -> [PromiseModel]

  /// 그룹의 과거 약속 조회 (커서 기반 페이징)
  public var getPastPromises: @Sendable (_ groupId: String, _ limit: Int, _ lastStartAt: Date?) async throws -> [PromiseModel]

  /// 그룹의 활성 약속 개수 조회
  public var getActivePromiseCount: @Sendable (_ groupId: String) async throws -> Int

  /// 날짜 범위로 약속 조회 (캘린더용, 사용자가 속한 그룹들의 약속)
  public var getPromisesByDateRange: @Sendable (
    _ groupIds: [String],
    _ startDate: Date,
    _ endDate: Date
  ) async throws -> [PromiseModel]

  /// 홈화면 스냅샷 조회 (캐시된 데이터)
  public var getHomeSnapshot: @Sendable () async throws -> HomeSnapshotDocument

  /// 홈화면 스냅샷 갱신 (Firebase Functions 호출)
  /// 하루 첫 진입 시 또는 Pull-to-refresh 시 호출
  public var refreshHomeSnapshot: @Sendable () async throws -> HomeSnapshotDocument

  /// 그룹의 활성 약속 실시간 구독
  public var subscribeToPromises: @Sendable (_ groupId: String, _ limit: Int) -> AsyncStream<[PromiseModel]> = { _, _ in AsyncStream { _ in } }

  /// 약속 응답
  public var respondPromise: @Sendable (_ promiseId: String, _ status: PromiseAttendanceStatus) async throws -> Void

  // MARK: - Calendar Sync

  /// 캘린더 동기화용 확정 약속 조회 (미래 약속만)
  public var getConfirmedPromisesForCalendar: @Sendable () async throws -> [CalendarSyncPromise]

  // MARK: - Live Activity

  /// LiveActivity 시작 요청 (백엔드에서 Push to Start APNs 전송)
  public var startLiveActivity: @Sendable (_ promiseId: String) async throws -> Void

  /// ETA 업데이트 요청 (백엔드에서 APNs 브로드캐스트)
  /// Firestore 없이 클라이언트에서 전달한 데이터로 Broadcast만 전송
  public var updateETA: @Sendable (
    _ channelId: String,
    _ participants: [ParticipantState],
    _ trackingDurationMinutes: Int
  ) async throws -> Void

  // endLiveActivity 제거됨 - APNs dismissal-date로 auto-dismiss 처리

  // registerLiveActivityToken 제거됨 - iOS 18 Broadcast 방식으로 전환
  // Broadcast는 채널 기반이므로 개별 토큰 관리 불필요
}

// MARK: - Test & Preview Values

extension PromiseClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    createPromise: { _ in
      try await Task.sleep(for: .seconds(1))
      return UUID().uuidString
    },
    updatePromise: { _ in
      try await Task.sleep(for: .seconds(1))
    },
    deletePromise: { _ in
      try await Task.sleep(for: .seconds(0.5))
    },
    getPromise: { _ in
      try await Task.sleep(for: .seconds(0.5))
      return nil
    },
    getTodayPromises: { _ in
      try await Task.sleep(for: .seconds(1))
      return []
    },
    getUpcomingPromises: { _, _ in
      try await Task.sleep(for: .seconds(1))
      return []
    },
    getActivePromises: { _, _ in
      try await Task.sleep(for: .seconds(1))
      return PromiseModel.examples
    },
    getPastPromises: { _, _, _ in
      try await Task.sleep(for: .seconds(1))
      return []
    },
    getActivePromiseCount: { _ in
      try await Task.sleep(for: .seconds(0.3))
      return 3
    },
    getPromisesByDateRange: { _, _, _ in
      try await Task.sleep(for: .seconds(0.5))
      return PromiseModel.examples
    },
    getHomeSnapshot: {
      try await Task.sleep(for: .seconds(0.3))
      return .empty
    },
    refreshHomeSnapshot: {
      try await Task.sleep(for: .seconds(0.5))
      return .empty
    },
    subscribeToPromises: { _, _ in
      AsyncStream { continuation in
        Task {
          try? await Task.sleep(for: .seconds(0.5))
          continuation.yield(PromiseModel.examples)
        }
      }
    },
    respondPromise: { _, _ in
      try await Task.sleep(for: .seconds(0.3))
    },
    getConfirmedPromisesForCalendar: {
      try await Task.sleep(for: .seconds(0.3))
      return []
    },
    startLiveActivity: { _ in
      try await Task.sleep(for: .seconds(0.5))
    },
    updateETA: { _, _, _  in
      try await Task.sleep(for: .seconds(0.3))
    }
    // endLiveActivity 제거됨 - APNs dismissal-date로 auto-dismiss 처리
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var promiseClient: PromiseClient {
    get { self[PromiseClient.self] }
    set { self[PromiseClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension PromiseClient: DependencyKey {
  public static let liveValue: PromiseClient = {
    let dataSource: PromiseRemoteDataSourceProtocol = PromiseRemoteDataSource()

    return PromiseClient(
      createPromise: { promise in
        guard !promise.groupId.isEmpty else {
          throw PromiseClientError.invalidData(nil)
        }

        do {
          return try await dataSource.createPromise(promise)
        } catch {
          throw PromiseClientError(from: error)
        }
      },
      updatePromise: { promise in
        try await dataSource.updatePromise(promise)
      },
      deletePromise: { promiseId in
        try await dataSource.deletePromise(id: promiseId)
      },
      getPromise: { promiseId in
        try await dataSource.getPromise(id: promiseId)
      },
      getTodayPromises: { groupIds in
        try await dataSource.getTodayPromises(groupIds: groupIds)
      },
      getUpcomingPromises: { groupIds, limit in
        try await dataSource.getUpcomingPromises(groupIds: groupIds, limit: limit)
      },
      getActivePromises: { groupId, limit in
        try await dataSource.getActivePromises(groupId: groupId, limit: limit)
      },
      getPastPromises: { groupId, limit, lastStartAt in
        try await dataSource.getPastPromises(groupId: groupId, limit: limit, lastStartAt: lastStartAt)
      },
      getActivePromiseCount: { groupId in
        try await dataSource.getActivePromiseCount(groupId: groupId)
      },
      getPromisesByDateRange: { groupIds, startDate, endDate in
        try await dataSource.getPromisesByDateRange(groupIds: groupIds, startDate: startDate, endDate: endDate)
      },
      getHomeSnapshot: {
        try await dataSource.getHomeSnapshot()
      },
      refreshHomeSnapshot: {
        try await dataSource.refreshHomeSnapshot()
      },
      subscribeToPromises: { groupId, limit in
        dataSource.subscribeToActivePromises(groupId: groupId, limit: limit)
      },
      respondPromise: { promiseId, status in
        try await dataSource.respondToPromise(
          promiseId: promiseId,
          status: status.rawValue
        )
      },
      getConfirmedPromisesForCalendar: {
        try await dataSource.getConfirmedPromisesForCalendar()
      },
      startLiveActivity: { promiseId in
        try await dataSource.startLiveActivity(promiseId: promiseId)
      },
      updateETA: { channelId, participants, trackingDurationMinutes in
        try await dataSource.updateETA(
          channelId: channelId,
          participants: participants,
          trackingDurationMinutes: trackingDurationMinutes
        )
      }
      // endLiveActivity 제거됨 - APNs dismissal-date로 auto-dismiss 처리
    )
  }()
}

// MARK: - Example Data

extension PromiseModel {
  /// Preview용 현재 유저 ID
  public static let previewCurrentUserId = "preview-user"

  /// 다양한 상태의 약속 예시 (그룹 탭 UI 테스트용)
  public static let examples: [PromiseModel] = [
    // 1. 응답 필요 (needResponse) - 미응답 상태
    PromiseModel(
      id: "promise-need-response-1",
      title: "주말 러닝",
      emoji: "🏃",
      description: "한강에서 5km 뛰어요!",
      hostId: "user123",
      groupId: "g1",
      minimumParticipants: 2,
      votes: PromiseVotesModel(
        accepted: ["user123"],  // 호스트만 수락
        declined: [],
        until: Date().addingTimeInterval(86400)  // 내일까지
      ),
      startAt: Date().addingTimeInterval(172800),  // 2일 후
      location: LocationInfoModel(name: "여의도 한강공원")
    ),
    // 2. 응답 필요 (needResponse) - 급한 마감
    PromiseModel(
      id: "promise-need-response-2",
      title: "긴급 회식",
      emoji: "🍻",
      description: "오늘 저녁 회식입니다",
      hostId: "user456",
      groupId: "g1",
      minimumParticipants: 3,
      votes: PromiseVotesModel(
        accepted: ["user456", "user789"],
        declined: [],
        until: Date().addingTimeInterval(3600)  // 1시간 후 마감
      ),
      startAt: Date().addingTimeInterval(21600),  // 6시간 후
      location: LocationInfoModel(name: "강남역 고기집")
    ),
    // 3. 확정됨 (confirmed) - 오늘 약속
    PromiseModel(
      id: "promise-confirmed-1",
      title: "점심 약속",
      emoji: "🍜",
      description: "맛있는 라멘 먹으러 가요",
      hostId: "preview-user",
      groupId: "g1",
      minimumParticipants: 2,
      votes: PromiseVotesModel(
        accepted: ["preview-user", "user123", "user456"],
        declined: [],
        until: Date().addingTimeInterval(-3600)  // 이미 마감
      ),
      startAt: Date().addingTimeInterval(7200),  // 2시간 후
      location: LocationInfoModel(name: "이치란 라멘")
    ),
    // 4. 확정됨 (confirmed) - 내일 약속
    PromiseModel(
      id: "promise-confirmed-2",
      title: "영화 보기",
      emoji: "🎬",
      description: "신작 영화 같이 봐요",
      hostId: "user789",
      groupId: "g2",
      minimumParticipants: 2,
      votes: PromiseVotesModel(
        accepted: ["preview-user", "user789"],
        declined: ["user123"],
        until: Date().addingTimeInterval(-7200)
      ),
      startAt: Date().addingTimeInterval(108000),  // 30시간 후
      location: LocationInfoModel(name: "CGV 용산")
    ),
    // 5. 응답 완료 (responded) - 대기 중
    PromiseModel(
      id: "promise-responded-1",
      title: "독서 모임",
      emoji: "📚",
      description: "이번 달 책 토론해요",
      hostId: "user123",
      groupId: "g3",
      minimumParticipants: 4,
      votes: PromiseVotesModel(
        accepted: ["preview-user", "user123"],  // 2명만 수락, 4명 필요
        declined: [],
        until: Date().addingTimeInterval(172800)
      ),
      startAt: Date().addingTimeInterval(259200),  // 3일 후
      location: LocationInfoModel(name: "교보문고 카페")
    )
  ]

  /// 그룹별 약속 필터링 (Preview용)
  public static func examples(for groupId: String) -> [PromiseModel] {
    examples.filter { $0.groupId == groupId }
  }

  /// 응답 필요 약속만 필터링 (Preview용)
  public static func needResponseExamples(currentUserId: String = previewCurrentUserId) -> [PromiseModel] {
    examples.filter { $0.responseStatus(currentUserId: currentUserId) == .needResponse }
  }

  /// 확정된 약속만 필터링 (Preview용)
  public static var confirmedExamples: [PromiseModel] {
    examples.filter { $0.isConfirmed }
  }
}
