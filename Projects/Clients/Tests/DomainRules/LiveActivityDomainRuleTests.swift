//
//  LiveActivityDomainRuleTests.swift
//  PromisoShared
//
//  Layer 1: 도메인 규칙 안전망 테스트
//
//  ## 목적
//  - 도메인 규칙(.ai/domain-rules/liveactivity.md)이 코드에 올바르게 반영되었는지 검증
//

import Foundation
import Testing
@testable import PromisoShared

// MARK: - 제약 조건 (L1~L3)

@Suite("LiveActivity 제약 조건 도메인 규칙")
struct LiveActivityConstraintRuleTests {

  // MARK: - [L3] trackPosition 범위 0.05~0.95

  @Test("[L3] 거의 도착 시 최대 0.95")
  func l3_almostArrived_clampedToMax() {
    let participant = ParticipantState(
      id: "1",
      name: "테스트",
      estimatedArrivalMinutes: 1
    )
    let position = participant.trackPosition(trackingDurationMinutes: 30)
    #expect(position <= 0.95)
  }

  @Test("[L3] 막 출발 시 최소 0.05")
  func l3_justStarted_clampedToMin() {
    let participant = ParticipantState(
      id: "1",
      name: "테스트",
      estimatedArrivalMinutes: 29
    )
    let position = participant.trackPosition(trackingDurationMinutes: 30)
    #expect(position >= 0.05)
  }

  // MARK: - [L8] ETA 의미: nil=대기, 0=도착, >0=남은분

  @Test("[L8] ETA nil이면 대기 상태 (position 0.0)")
  func l8_nilETA_isWaiting() {
    let participant = ParticipantState(
      id: "1",
      name: "테스트",
      estimatedArrivalMinutes: nil
    )
    let position = participant.trackPosition(trackingDurationMinutes: 30)
    #expect(position == 0.0)
  }

  @Test("[L8] ETA 0이면 도착 (position 1.0)")
  func l8_zeroETA_isArrived() {
    let participant = ParticipantState(
      id: "1",
      name: "테스트",
      estimatedArrivalMinutes: 0
    )
    let position = participant.trackPosition(trackingDurationMinutes: 30)
    #expect(position == 1.0)
  }

  @Test("[L9] ETA > 0이면 이동 중")
  func l9_positiveETA_isMoving() {
    let participant = ParticipantState(
      id: "1",
      name: "테스트",
      estimatedArrivalMinutes: 15
    )
    let position = participant.trackPosition(trackingDurationMinutes: 30)
    #expect(position > 0.0 && position < 1.0)
  }
}

// MARK: - 동작 규칙 (L5~L6)

@Suite("LiveActivity 동작 도메인 규칙")
struct LiveActivityBehaviorRuleTests {

  // MARK: - [L5] 기본 추적 시간 30분

  @Test("[L5] PromiseActivityAttributes 기본 trackingDurationMinutes = 30")
  func l5_defaultTrackingDuration_is30() {
    let attrs = PromiseActivityAttributes(
      promiseId: "test",
      currentUserId: "user",
      emoji: "📌",
      title: "테스트",
      location: nil,
      scheduledTime: Date()
    )
    #expect(attrs.trackingDurationMinutes == 30)
  }
}
