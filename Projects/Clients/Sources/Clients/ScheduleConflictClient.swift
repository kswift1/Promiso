//
//  ScheduleConflictClient.swift
//  Clients
//
//  TCA Dependency Client for Schedule Conflict detection
//

import ComposableArchitecture
import FirebaseFunctions
import Foundation
import PromisoShared

// MARK: - Client

/// 일정 충돌 감지 클라이언트
/// PromiseClient + PersonalEventClient를 조합하여 충돌을 판정
@DependencyClient
public struct ScheduleConflictClient: Sendable {
  /// 일정 충돌 확인
  /// - Parameters:
  ///   - userId: 현재 사용자 ID
  ///   - startAt: 새 약속/일정 시작 시간
  ///   - endAt: 새 약속/일정 종료 시간 (nil이면 startAt과 동일)
  ///   - excludeIds: 충돌 결과에서 제외할 일정 ID (편집 시 자기 자신 제외)
  ///   - minGapMinutes: 충돌로 감지할 최소 여유 시간 (분). 0이면 겹치는 일정만 감지
  /// - Returns: 겹치는 일정 목록
  public var checkConflicts: @Sendable (
    _ userId: String,
    _ startAt: Date,
    _ endAt: Date?,
    _ excludeIds: Set<String>,
    _ minGapMinutes: Int
  ) async throws -> [ScheduleConflict]
}

// MARK: - Test & Preview Values

extension ScheduleConflictClient: TestDependencyKey {
  public static let testValue = Self()

  public static let previewValue = Self(
    checkConflicts: { _, _, _, _, _ in
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

// MARK: - Cloud Function Response

private let conflictCheckISO8601Formatter: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter
}()

private struct CheckConflictsResponse: Decodable {
  let conflicts: [ConflictItem]
}

private struct ConflictItem: Decodable {
  let id: String
  let source: String
  let severity: String
  let title: String
  let emoji: String?
  let startAt: String
  let endAt: String?
  let overlapMinutes: Int
  let gapMinutes: Int
}

// MARK: - Live Implementation

extension ScheduleConflictClient: DependencyKey {
  public static let liveValue = ScheduleConflictClient(
    checkConflicts: { _, startAt, endAt, excludeIds, minGapMinutes in
      let functions = DefaultFunctionsProvider().functions
      let iso8601Formatter = conflictCheckISO8601Formatter

      AppLogger.general.info("[ConflictCheck] Cloud Function 충돌 체크 시작")

      var params: [String: Any] = [
        "startAt": iso8601Formatter.string(from: startAt),
      ]
      if let endAt {
        params["endAt"] = iso8601Formatter.string(from: endAt)
      }
      if !excludeIds.isEmpty {
        params["excludeIds"] = Array(excludeIds)
      }
      params["minGapMinutes"] = minGapMinutes

      let result = try await functions.httpsCallable("checkScheduleConflicts").call(params)

      do {
        let data = try JSONSerialization.data(withJSONObject: result.data)
        let response = try JSONDecoder().decode(CheckConflictsResponse.self, from: data)

        let conflicts = response.conflicts.compactMap { item -> ScheduleConflict? in
          let source: ScheduleConflict.Source = item.source == "promise" ? .promise : .personalEvent
          let severity: ScheduleConflict.Severity = item.severity == "confirmed" ? .confirmed : .pending
          guard let itemStartAt = iso8601Formatter.date(from: item.startAt) else {
            AppLogger.general.error("[ConflictCheck] 서버 응답 파싱 실패 - startAt: \(item.startAt)")
            return nil
          }
          let itemEndAt = item.endAt.flatMap { iso8601Formatter.date(from: $0) }

          return ScheduleConflict(
            id: item.id,
            source: source,
            severity: severity,
            title: item.title,
            emoji: item.emoji,
            startAt: itemStartAt,
            endAt: itemEndAt,
            overlapMinutes: item.overlapMinutes,
            gapMinutes: item.gapMinutes
          )
        }

        AppLogger.general.info("[ConflictCheck] 결과 - 충돌 \(conflicts.count)건 감지")
        return conflicts
      } catch {
        AppLogger.general.error("[ConflictCheck] 응답 파싱 실패")
        AppLogger.general.error("[ConflictCheck] error: \(error)")
        throw error
      }
    }
  )
}
