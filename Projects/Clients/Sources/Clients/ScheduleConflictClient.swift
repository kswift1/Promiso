//
//  ScheduleConflictClient.swift
//  Clients
//
//  TCA Dependency Client for Schedule Conflict detection
//

import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Constants

private enum ConflictCheckConstants {
  /// 겹침 검사를 위한 하한 버퍼 (12시간)
  /// 최대 12시간 전에 시작해서 아직 진행 중인 일정을 포착
  static let lookbackInterval: TimeInterval = 12 * 3600

  /// endAt이 nil일 때 기본 지속 시간 (2시간, P18)
  static let defaultDuration: TimeInterval = 7200
}

// MARK: - Client

/// 일정 충돌 감지 클라이언트
/// PromiseClient + PersonalEventClient를 조합하여 충돌을 판정
@DependencyClient
public struct ScheduleConflictClient: Sendable {
  /// 일정 충돌 확인
  /// - Parameters:
  ///   - userId: 현재 사용자 ID
  ///   - startAt: 새 약속/일정 시작 시간
  ///   - endAt: 새 약속/일정 종료 시간 (nil이면 startAt + 2h)
  /// - Returns: 겹치는 일정 목록
  public var checkConflicts: @Sendable (
    _ userId: String,
    _ startAt: Date,
    _ endAt: Date?
  ) async throws -> [ScheduleConflict]
}

// MARK: - Test & Preview Values

extension ScheduleConflictClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    checkConflicts: { _, _, _ in
      try await Task.sleep(for: .seconds(0.3))
      return []
    }
  )
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var scheduleConflictClient: ScheduleConflictClient {
    get { self[ScheduleConflictClient.self] }
    set { self[ScheduleConflictClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension ScheduleConflictClient: DependencyKey {
  public static let liveValue: ScheduleConflictClient = {
    @Dependency(\.promiseClient) var promiseClient
    @Dependency(\.personalEventClient) var personalEventClient

    return ScheduleConflictClient(
      checkConflicts: { userId, startAt, endAt in
        let newEffectiveEnd = endAt ?? startAt.addingTimeInterval(ConflictCheckConstants.defaultDuration)
        let rangeStart = startAt.addingTimeInterval(-ConflictCheckConstants.lookbackInterval)
        let rangeEnd = newEffectiveEnd

        AppLogger.general.info("[ConflictCheck] 충돌 체크 시작 - userId: \(userId), startAt: \(startAt), endAt: \(String(describing: endAt)), rangeStart: \(rangeStart), rangeEnd: \(rangeEnd)")

        // 병렬 조회: 수락한 그룹 약속 + 개인 일정
        async let acceptedPromises = promiseClient.getAcceptedPromisesByDateRange(
          userId, rangeStart, rangeEnd
        )
        async let personalEvents = personalEventClient.getEventsByDateRange(
          rangeStart, rangeEnd
        )

        var conflicts: [ScheduleConflict] = []

        // 그룹 약속 겹침 판정
        for promise in try await acceptedPromises {
          let existEnd = promise.endAt ?? promise.startAt.addingTimeInterval(ConflictCheckConstants.defaultDuration)
          guard promise.startAt < newEffectiveEnd && existEnd > startAt else { continue }

          let overlapStart = max(promise.startAt, startAt)
          let overlapEnd = min(existEnd, newEffectiveEnd)
          let overlapMinutes = max(0, Int(overlapEnd.timeIntervalSince(overlapStart) / 60))

          conflicts.append(ScheduleConflict(
            id: promise.id,
            source: .promise,
            severity: promise.isConfirmed ? .confirmed : .pending,
            title: promise.title,
            emoji: promise.emoji,
            startAt: promise.startAt,
            endAt: promise.endAt,
            overlapMinutes: overlapMinutes
          ))
        }

        // 개인 일정 겹침 판정
        for event in try await personalEvents {
          let existEnd = event.endAt ?? event.startAt.addingTimeInterval(ConflictCheckConstants.defaultDuration)
          guard event.startAt < newEffectiveEnd && existEnd > startAt else { continue }

          let overlapStart = max(event.startAt, startAt)
          let overlapEnd = min(existEnd, newEffectiveEnd)
          let overlapMinutes = max(0, Int(overlapEnd.timeIntervalSince(overlapStart) / 60))

          conflicts.append(ScheduleConflict(
            id: event.id,
            source: .personalEvent,
            severity: .confirmed,
            title: event.title,
            emoji: event.emoji,
            startAt: event.startAt,
            endAt: event.endAt,
            overlapMinutes: overlapMinutes
          ))
        }

        AppLogger.general.info("[ConflictCheck] 결과 - 충돌 \(conflicts.count)건 감지")
        for conflict in conflicts {
          AppLogger.general.debug("[ConflictCheck]  - \(conflict.source == .promise ? "약속" : "개인") '\(conflict.title)' \(conflict.overlapMinutes)분 겹침 (\(conflict.severity == .confirmed ? "확정" : "미확정"))")
        }

        // 겹침 시간 내림차순 정렬
        return conflicts.sorted { $0.overlapMinutes > $1.overlapMinutes }
      }
    )
  }()
}
