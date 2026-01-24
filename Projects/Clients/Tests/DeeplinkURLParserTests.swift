//
//  DeeplinkURLParserTests.swift
//  Clients
//
//  딥링크 URL 파싱 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Clients/DeeplinkURLParser.swift`
//  - `DeeplinkURLParser.parse(_:)` 정적 메서드
//
//  ## 사용처
//  - **AppMain.swift**: `.onOpenURL { }` 에서 URL 수신 시 호출
//  - **DeeplinkClient**: `parseURL` 클로저에서 사용
//  - **AppEntryFeature**: `handleDeeplink(URL)` 액션에서 라우팅 결정
//
//  ## 지원하는 딥링크 URL 형식
//  - `promiso://join/{inviteCode}` → 초대 코드로 그룹 참여
//  - `promiso://group/{groupId}` → 그룹 상세 화면
//  - `promiso://promise/{promiseId}/{groupId}` → 약속 상세 화면
//  - `promiso://promise/{promiseId}/eta` → LiveActivity ETA 변경 시트
//  - `promiso://live/{promiseId}` → LivePromise 상세 화면 (ETA 시트 없이)
//
//  ## 테스트 목적
//  - 각 딥링크 URL 형식이 올바른 DeeplinkDestination으로 파싱되는지 검증
//  - 잘못된 스킴, 호스트, 경로에 대해 nil 반환 검증
//
//  ## 전체 딥링크 플로우 (End-to-End)
//  ```
//  1. URL 수신 (AppMain.onOpenURL)
//       ↓
//  2. AppEntry.handleDeeplink(URL)
//       ↓
//  3. DeeplinkClient.parseURL(url)  ← 이 테스트에서 검증
//       ↓
//  4. DeeplinkDestination 생성
//       ↓
//  5. AppEntry.routeDeeplink(destination)  ← DeeplinkRoutingTests에서 검증
//       ↓
//  6. RootTab Action 전송
//       ↓
//  7. 화면 이동
//  ```
//
//  ## 관련 테스트 파일
//  - `DeeplinkRoutingTests.swift`: 파싱된 딥링크의 라우팅 동작 테스트
//

import Testing
@testable import Clients

@Suite("DeeplinkURLParser 테스트")
struct DeeplinkURLParserTests {

  // MARK: - 스킴 검증
  //
  // promiso:// 스킴만 처리합니다.
  // https://, http:// 등 다른 스킴은 무시합니다.

  @Test("promiso:// 스킴만 처리")
  func parse_invalidScheme_returnsNil() {
    let url = URL(string: "https://example.com/join/ABC")!
    #expect(DeeplinkURLParser.parse(url) == nil)
  }

  @Test("알 수 없는 호스트는 nil 반환")
  func parse_unknownHost_returnsNil() {
    let url = URL(string: "promiso://unknown/path")!
    #expect(DeeplinkURLParser.parse(url) == nil)
  }

  // MARK: - joinGroup 딥링크
  //
  // 그룹 초대 링크에서 사용됩니다.
  // 공유 시트, QR 코드, 카카오톡 공유 등에서 발생합니다.
  // → JoinGroupSheet 표시

  @Test("promiso://join/{inviteCode} 파싱")
  func parse_joinGroup_extractsInviteCode() {
    let url = URL(string: "promiso://join/ABC123")!
    let result = DeeplinkURLParser.parse(url)
    #expect(result == .joinGroup(inviteCode: "ABC123"))
  }

  @Test("join 경로에 코드 없으면 nil")
  func parse_joinGroup_withoutCode_returnsNil() {
    let url = URL(string: "promiso://join")!
    #expect(DeeplinkURLParser.parse(url) == nil)
  }

  // MARK: - group 딥링크
  //
  // 그룹 상세 화면으로 이동합니다.
  // 푸시 알림 탭 시 사용됩니다 (그룹 관련 알림).
  // → GroupMainView 표시

  @Test("promiso://group/{groupId} 파싱")
  func parse_group_extractsGroupId() {
    let url = URL(string: "promiso://group/group123")!
    let result = DeeplinkURLParser.parse(url)
    #expect(result == .group(groupId: "group123"))
  }

  @Test("group 경로에 ID 없으면 nil")
  func parse_group_withoutId_returnsNil() {
    let url = URL(string: "promiso://group")!
    #expect(DeeplinkURLParser.parse(url) == nil)
  }

  // MARK: - promise 딥링크
  //
  // 약속 상세 화면으로 이동합니다.
  // 푸시 알림 탭 시 사용됩니다 (약속 관련 알림).
  // → PromiseDetailView 표시

  @Test("promiso://promise/{promiseId}/{groupId} 파싱")
  func parse_promise_extractsIds() {
    let url = URL(string: "promiso://promise/promise123/group456")!
    let result = DeeplinkURLParser.parse(url)
    #expect(result == .promise(promiseId: "promise123", groupId: "group456"))
  }

  @Test("promise 경로에 groupId 없으면 nil")
  func parse_promise_withoutGroupId_returnsNil() {
    let url = URL(string: "promiso://promise/promise123")!
    #expect(DeeplinkURLParser.parse(url) == nil)
  }

  // MARK: - liveActivityETA 딥링크
  //
  // LiveActivity Widget의 "직접 입력" 버튼에서 사용됩니다.
  // 앱을 열고 ETA 변경 시트를 자동으로 표시합니다.
  // → LivePromiseExpandedView + ETASheet 자동 표시

  @Test("promiso://promise/{promiseId}/eta 파싱")
  func parse_liveActivityETA_extractsPromiseId() {
    let url = URL(string: "promiso://promise/promise789/eta")!
    let result = DeeplinkURLParser.parse(url)
    #expect(result == .liveActivityETA(promiseId: "promise789"))
  }

  // MARK: - livePromise 딥링크
  //
  // LiveActivity 배너 탭 시 사용됩니다.
  // 앱을 열고 LivePromise 상세 화면을 표시합니다 (ETA 시트 없이).
  // → LivePromiseExpandedView 표시

  @Test("promiso://live/{promiseId} 파싱")
  func parse_livePromise_extractsPromiseId() {
    let url = URL(string: "promiso://live/promise999")!
    let result = DeeplinkURLParser.parse(url)
    #expect(result == .livePromise(promiseId: "promise999"))
  }

  @Test("live 경로에 promiseId 없으면 nil")
  func parse_livePromise_withoutId_returnsNil() {
    let url = URL(string: "promiso://live")!
    #expect(DeeplinkURLParser.parse(url) == nil)
  }
}
