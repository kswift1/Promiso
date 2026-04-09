//
//  ScheduleConflictClient.swift
//  Clients
//
//  TCA Dependency Client for Schedule Conflict detection
//

import ComposableArchitecture
import Foundation
import PromisoShared

// MARK: - Client

/// 일정 충돌 감지 클라이언트
/// ScheduleClient + PersonalEventClient를 조합하여 충돌을 판정
@DependencyClient
public struct ScheduleConflictClient: Sendable {
  /// 일정 충돌 확인
  /// - Parameters:
  ///   - userId: 현재 사용자 ID
  ///   - startAt: 새 일정/일정 시작 시간
  ///   - endAt: 새 일정/일정 종료 시간 (nil이면 startAt과 동일)
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

// MARK: - Rust API DTOs

private let conflictCheckISO8601Formatter: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter
}()

private struct CheckConflictsBody: Encodable {
  let startAt: Date
  let endAt: Date?
  let excludeIds: [String]?
  let minGapMinutes: Int
  let timezone: String
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
      let rustClient = RustAPIClient()

      AppLogger.general.info("[ConflictCheck] Rust 충돌 체크 시작")

      let response: [ConflictItem] = try await rustClient.post(
        "/api/v1/schedules/check-conflicts",
        body: CheckConflictsBody(
          startAt: startAt,
          endAt: endAt,
          excludeIds: excludeIds.isEmpty ? nil : Array(excludeIds),
          minGapMinutes: minGapMinutes,
          timezone: TimeZone.current.identifier
        )
      )

      do {
        let conflicts = try response.map { item -> ScheduleConflict in
          let source: ScheduleConflict.Source
          switch item.source {
          case "schedule":
            source = .schedule
          case "personalEvent":
            source = .personalEvent
          default:
            throw RustAPIError.invalidResponse
          }

          let severity: ScheduleConflict.Severity
          switch item.severity {
          case "confirmed":
            severity = .confirmed
          case "pending":
            severity = .pending
          default:
            throw RustAPIError.invalidResponse
          }

          guard let itemStartAt = parseConflictDate(item.startAt) else {
            throw RustAPIError.invalidResponse
          }
          let itemEndAt = item.endAt.flatMap(parseConflictDate)

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

private func parseConflictDate(_ string: String) -> Date? {
  if let date = conflictCheckISO8601Formatter.date(from: string) {
    return date
  }

  let standardFormatter = ISO8601DateFormatter()
  standardFormatter.formatOptions = [.withInternetDateTime]
  return standardFormatter.date(from: string)
}
