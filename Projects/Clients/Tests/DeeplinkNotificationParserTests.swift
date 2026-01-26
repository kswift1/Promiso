//
//  DeeplinkNotificationParserTests.swift
//  Clients
//
//  푸시 알림 payload 파싱 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Clients/DeeplinkClient.swift`
//  - `DeeplinkClient.parseNotification(_:)`
//
//  ## 관련 가이드
//  - `.ai/DEEPLINK_GUIDE.md`의 NotificationType 매핑
//

import Testing
@testable import Clients

@Suite("푸시 알림 딥링크 파싱 테스트")
struct DeeplinkNotificationParserTests {

  private let parser = DeeplinkClient.liveValue.parseNotification

  @Test("promise 관련 타입은 promiseId+groupId 필요")
  func parse_promiseTypes_requirePromiseAndGroup() {
    let types = [
      "promise_invitation",
      "promise_reminder",
      "promise_confirmed",
      "promise_cancelled",
      "promise_updated",
      "attendance_response",
    ]

    for type in types {
      let result = parser([
        "type": type,
        "promiseId": "p1",
        "groupId": "g1",
      ])
      #expect(result == .promise(promiseId: "p1", groupId: "g1"))

      let missingPromise = parser([
        "type": type,
        "groupId": "g1",
      ])
      #expect(missingPromise == nil)
    }
  }

  @Test("group 관련 타입은 groupId 필요")
  func parse_groupTypes_requireGroupOnly() {
    let types = [
      "group_invitation",
      "group_update",
    ]

    for type in types {
      let result = parser([
        "type": type,
        "groupId": "g1",
      ])
      #expect(result == .group(groupId: "g1"))

      let missingGroup = parser([
        "type": type,
      ])
      #expect(missingGroup == nil)
    }
  }

  @Test("system 타입은 딥링크 없음")
  func parse_system_returnsNil() {
    let result = parser([
      "type": "system",
    ])
    #expect(result == nil)
  }
}
