//
//  LivePromiseDataTests.swift
//  RootTabFeature
//
//  LivePromise 공유 데이터 모델 테스트
//
//  ## 테스트 대상
//  - `RootTabFeature/Sources/LivePromise/LivePromiseFeature.swift`
//  - `LivePromise.Data` 구조체 (Feature와 Detail이 @Shared로 공유)
//
//  ## 사용처
//  - **LivePromiseCompactView**: 하단 고정 바에서 도착/이동중 카운트 표시
//  - **LivePromiseExpandedView**: 상세 화면에서 참가자 상태 요약
//  - **RootTabFeature**: LiveActivity 상태와 앱 내 뷰 동기화
//
//  ## 테스트 목적
//  - arrivedCount: 도착한 참가자 수 (ETA == 0)
//  - inTransitCount: 이동 중인 참가자 수 (ETA > 0)
//  - currentUserParticipant: 현재 사용자 참가자 정보 조회
//  - currentUserETA: 현재 사용자의 도착 예상 시간
//

import Testing
import PromisoShared
@testable import RootTabFeature

@Suite("LivePromise.Data 계산 테스트")
struct LivePromiseDataTests {

  // MARK: - arrivedCount 테스트
  //
  // arrivedCount는 CompactView와 ExpandedView에서
  // "N명 도착" 텍스트를 표시할 때 사용됩니다.
  // ETA가 0인 참가자만 카운트합니다.

  @Test("도착한 참가자(ETA 0) 수 계산")
  func arrivedCount_countsParticipantsWithETA0() {
    let data = LivePromise.Data(participants: [
      ParticipantState(id: "1", name: "A", estimatedArrivalMinutes: 0),
      ParticipantState(id: "2", name: "B", estimatedArrivalMinutes: 0),
      ParticipantState(id: "3", name: "C", estimatedArrivalMinutes: 5)
    ])
    #expect(data.arrivedCount == 2)
  }

  @Test("아무도 도착하지 않았을 때 0 반환")
  func arrivedCount_whenNoArrived_returns0() {
    let data = LivePromise.Data(participants: [
      ParticipantState(id: "1", name: "A", estimatedArrivalMinutes: 10),
      ParticipantState(id: "2", name: "B", estimatedArrivalMinutes: nil)
    ])
    #expect(data.arrivedCount == 0)
  }

  // MARK: - inTransitCount 테스트
  //
  // inTransitCount는 "N명 이동중" 텍스트를 표시할 때 사용됩니다.
  // ETA가 양수인 참가자만 카운트합니다 (nil과 0은 제외).

  @Test("이동 중인 참가자(ETA > 0) 수 계산")
  func inTransitCount_countsPositiveETA() {
    let data = LivePromise.Data(participants: [
      ParticipantState(id: "1", name: "A", estimatedArrivalMinutes: 5),
      ParticipantState(id: "2", name: "B", estimatedArrivalMinutes: 10),
      ParticipantState(id: "3", name: "C", estimatedArrivalMinutes: 0),   // 도착
      ParticipantState(id: "4", name: "D", estimatedArrivalMinutes: nil)  // 대기
    ])
    #expect(data.inTransitCount == 2)
  }

  // MARK: - currentUserParticipant 테스트
  //
  // currentUserParticipant는 현재 로그인한 사용자의 참가자 정보를 반환합니다.
  // ETA 변경 버튼 표시 여부, 본인 하이라이트 등에 사용됩니다.

  @Test("현재 사용자 참가자 정보 반환")
  func currentUserParticipant_returnsMatchingId() {
    let data = LivePromise.Data(
      participants: [
        ParticipantState(id: "user1", name: "A", estimatedArrivalMinutes: 5),
        ParticipantState(id: "user2", name: "B", estimatedArrivalMinutes: 10)
      ],
      currentUserId: "user2"
    )
    #expect(data.currentUserParticipant?.id == "user2")
    #expect(data.currentUserParticipant?.name == "B")
  }

  @Test("현재 사용자가 참가자 목록에 없으면 nil 반환")
  func currentUserParticipant_whenNotFound_returnsNil() {
    let data = LivePromise.Data(
      participants: [
        ParticipantState(id: "user1", name: "A", estimatedArrivalMinutes: 5)
      ],
      currentUserId: "unknown"
    )
    #expect(data.currentUserParticipant == nil)
  }

  // MARK: - currentUserETA 테스트
  //
  // currentUserETA는 현재 사용자의 도착 예상 시간을 반환합니다.
  // ETA 변경 시트에서 현재 값을 표시할 때 사용됩니다.

  @Test("현재 사용자 ETA 반환")
  func currentUserETA_returnsParticipantETA() {
    let data = LivePromise.Data(
      participants: [
        ParticipantState(id: "me", name: "나", estimatedArrivalMinutes: 15)
      ],
      currentUserId: "me"
    )
    #expect(data.currentUserETA == 15)
  }
}
