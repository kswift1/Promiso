//
//  ParticipantStateTests.swift
//  PromisoShared
//
//  LiveActivity 참가자 상태 모델 테스트
//
//  ## 테스트 대상
//  - `PromisoShared/Sources/LiveActivity/PromiseActivityAttributes.swift`
//  - `ParticipantState` 구조체
//
//  ## 사용처
//  - **LiveActivity Widget**: Dynamic Island, Lock Screen에서 참가자 위치 표시
//  - **LivePromiseExpandedView**: Racing Track에서 참가자 진행률 시각화
//  - **LivePromiseCompactView**: 참가자 도착 상태 표시
//
//  ## 테스트 목적
//  - trackPosition(): 참가자의 레이싱 트랙 위치 계산 (0.0 ~ 1.0)
//  - progress(): trackPosition과 동일한 진행률 반환
//  - with(): 불변 객체 패턴으로 ETA 업데이트
//

import Testing
@testable import PromisoShared

@Suite("ParticipantState 계산 테스트")
struct ParticipantStateTests {

  // MARK: - trackPosition 테스트
  //
  // trackPosition()은 LiveActivity Widget과 앱 내 Racing Track에서
  // 참가자의 현재 위치를 계산하는 핵심 로직입니다.
  //
  // 계산식: (trackingDurationMinutes - ETA) / trackingDurationMinutes
  // 범위: 0.05 ~ 0.95 (도착 시 1.0, 대기 시 0.0)

  @Test("[L8] 대기 상태(nil ETA)일 때 0.0 반환")
  func trackPosition_whenNilETA_returns0() {
    let participant = ParticipantState(id: "1", name: "테스트", estimatedArrivalMinutes: nil)
    #expect(participant.trackPosition(trackingDurationMinutes: 30) == 0.0)
  }

  @Test("[L8,L9] 도착(ETA 0)일 때 1.0 반환")
  func trackPosition_whenETA0_returns1() {
    let participant = ParticipantState(id: "1", name: "테스트", estimatedArrivalMinutes: 0)
    #expect(participant.trackPosition(trackingDurationMinutes: 30) == 1.0)
  }

  @Test("15분 남았을 때 0.5 반환 (30분 기준)")
  func trackPosition_when15MinRemaining_returns0_5() {
    let participant = ParticipantState(id: "1", name: "테스트", estimatedArrivalMinutes: 15)
    #expect(participant.trackPosition(trackingDurationMinutes: 30) == 0.5)
  }

  @Test("[L3] 위치가 0.05 ~ 0.95 범위로 제한됨")
  func trackPosition_clampsToMinMax() {
    let almostArrived = ParticipantState(id: "1", name: "테스트", estimatedArrivalMinutes: 1)
    let justStarted = ParticipantState(id: "2", name: "테스트2", estimatedArrivalMinutes: 29)

    #expect(almostArrived.trackPosition(trackingDurationMinutes: 30) == 0.95)  // max
    #expect(justStarted.trackPosition(trackingDurationMinutes: 30) >= 0.05)    // min
  }

  // MARK: - progress 테스트
  //
  // progress()는 trackPosition()의 alias로,
  // SwiftUI ProgressView와의 일관성을 위해 제공됩니다.

  @Test("progress가 trackPosition과 동일한 값 반환")
  func progress_returnsTrackPosition() {
    let participant = ParticipantState(id: "1", name: "테스트", estimatedArrivalMinutes: 10)
    let trackingMinutes = 30

    #expect(participant.progress(trackingDurationMinutes: trackingMinutes)
            == participant.trackPosition(trackingDurationMinutes: trackingMinutes))
  }

  // MARK: - with(estimatedArrivalMinutes:) 테스트
  //
  // with()는 불변 객체 패턴으로, ETA 변경 시 새 인스턴스를 반환합니다.
  // ContentState 업데이트 시 사용됩니다.

  @Test("with()가 ETA만 변경된 새 인스턴스 반환")
  func with_returnsNewInstanceWithUpdatedETA() {
    let original = ParticipantState(id: "1", name: "테스트", estimatedArrivalMinutes: 10)
    let updated = original.with(estimatedArrivalMinutes: 5)

    #expect(updated.id == original.id)
    #expect(updated.name == original.name)
    #expect(updated.estimatedArrivalMinutes == 5)
    #expect(original.estimatedArrivalMinutes == 10)  // immutable 확인
  }
}
