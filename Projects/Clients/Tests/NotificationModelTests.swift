//
//  NotificationModelTests.swift
//  Clients
//
//  NotificationModel 모델 테스트
//
//  ## 테스트 대상
//  - `Clients/Sources/Domain/Models/NotificationModel.swift`
//  - `Clients/Sources/Domain/Models/NotificationModels.swift`
//
//  ## 테스트 목적
//  - NotificationCategory.iconName, iconColorName 매핑 검증
//  - NotificationCategory.deeplink 딥링크 생성 로직 검증
//  - NotificationModel.deeplinkType computed property 검증
//  - NotificationFilter rawValue 검증
//

import Foundation
import Testing
@testable import Clients

// MARK: - NotificationCategory iconName 테스트

@Suite("NotificationCategory iconName 테스트")
struct NotificationCategoryIconTests {

  @Test("promiseInvitation 아이콘은 envelope.fill")
  func promiseInvitation_iconName() {
    #expect(NotificationCategory.promiseInvitation.iconName == "envelope.fill")
  }

  @Test("promiseReminder 아이콘은 bell.fill")
  func promiseReminder_iconName() {
    #expect(NotificationCategory.promiseReminder.iconName == "bell.fill")
  }

  @Test("promiseConfirmed 아이콘은 checkmark.circle.fill")
  func promiseConfirmed_iconName() {
    #expect(NotificationCategory.promiseConfirmed.iconName == "checkmark.circle.fill")
  }

  @Test("promiseCancelled 아이콘은 xmark.circle.fill")
  func promiseCancelled_iconName() {
    #expect(NotificationCategory.promiseCancelled.iconName == "xmark.circle.fill")
  }

  @Test("promiseUpdated 아이콘은 pencil.circle.fill")
  func promiseUpdated_iconName() {
    #expect(NotificationCategory.promiseUpdated.iconName == "pencil.circle.fill")
  }

  @Test("groupInvitation 아이콘은 person.badge.plus.fill")
  func groupInvitation_iconName() {
    #expect(NotificationCategory.groupInvitation.iconName == "person.badge.plus.fill")
  }

  @Test("groupUpdate 아이콘은 person.3.fill")
  func groupUpdate_iconName() {
    #expect(NotificationCategory.groupUpdate.iconName == "person.3.fill")
  }

  @Test("attendanceResponse 아이콘은 hand.raised.fill")
  func attendanceResponse_iconName() {
    #expect(NotificationCategory.attendanceResponse.iconName == "hand.raised.fill")
  }

  @Test("system 아이콘은 info.circle.fill")
  func system_iconName() {
    #expect(NotificationCategory.system.iconName == "info.circle.fill")
  }
}

// MARK: - NotificationCategory iconColorName 테스트

@Suite("NotificationCategory iconColorName 테스트")
struct NotificationCategoryColorTests {

  @Test("각 카테고리별 색상 이름이 올바름")
  func allCategories_haveCorrectColorNames() {
    #expect(NotificationCategory.promiseInvitation.iconColorName == "pmindigo")
    #expect(NotificationCategory.promiseReminder.iconColorName == "pmorange")
    #expect(NotificationCategory.promiseConfirmed.iconColorName == "pmgreen")
    #expect(NotificationCategory.promiseCancelled.iconColorName == "pmred")
    #expect(NotificationCategory.promiseUpdated.iconColorName == "pmblue")
    #expect(NotificationCategory.groupInvitation.iconColorName == "pmpurple")
    #expect(NotificationCategory.groupUpdate.iconColorName == "pmteal")
    #expect(NotificationCategory.attendanceResponse.iconColorName == "pmyellow")
    #expect(NotificationCategory.system.iconColorName == "pmgray")
  }
}

// MARK: - NotificationCategory deeplink 테스트

@Suite("NotificationCategory 딥링크 테스트")
struct NotificationCategoryDeeplinkTests {

  @Test("약속 관련 카테고리는 promise 딥링크 생성")
  func promiseCategories_returnPromiseDeeplink() {
    let promiseCategories: [NotificationCategory] = [
      .promiseInvitation, .promiseReminder, .promiseConfirmed,
      .promiseCancelled, .promiseUpdated, .attendanceResponse
    ]

    for category in promiseCategories {
      let deeplink = category.deeplink(promiseId: "p1", groupId: "g1")
      if case .promise(let pid, let gid) = deeplink {
        #expect(pid == "p1")
        #expect(gid == "g1")
      } else {
        Issue.record("카테고리 \(category)가 promise 딥링크를 반환하지 않음")
      }
    }
  }

  @Test("약속 관련 카테고리에서 promiseId 없으면 none")
  func promiseCategory_withNilPromiseId_returnsNone() {
    let deeplink = NotificationCategory.promiseInvitation.deeplink(promiseId: nil, groupId: "g1")
    if case .none = deeplink {
      // 정상
    } else {
      Issue.record("promiseId가 nil인데 none이 아님")
    }
  }

  @Test("약속 관련 카테고리에서 groupId 없으면 none")
  func promiseCategory_withNilGroupId_returnsNone() {
    let deeplink = NotificationCategory.promiseReminder.deeplink(promiseId: "p1", groupId: nil)
    if case .none = deeplink {
      // 정상
    } else {
      Issue.record("groupId가 nil인데 none이 아님")
    }
  }

  @Test("그룹 관련 카테고리는 group 딥링크 생성")
  func groupCategories_returnGroupDeeplink() {
    let groupCategories: [NotificationCategory] = [.groupInvitation, .groupUpdate]

    for category in groupCategories {
      let deeplink = category.deeplink(promiseId: nil, groupId: "g1")
      if case .group(let gid) = deeplink {
        #expect(gid == "g1")
      } else {
        Issue.record("카테고리 \(category)가 group 딥링크를 반환하지 않음")
      }
    }
  }

  @Test("그룹 관련 카테고리에서 groupId 없으면 none")
  func groupCategory_withNilGroupId_returnsNone() {
    let deeplink = NotificationCategory.groupInvitation.deeplink(promiseId: nil, groupId: nil)
    if case .none = deeplink {
      // 정상
    } else {
      Issue.record("groupId가 nil인데 none이 아님")
    }
  }

  @Test("system 카테고리는 항상 none 딥링크")
  func systemCategory_alwaysReturnsNone() {
    let deeplink = NotificationCategory.system.deeplink(promiseId: "p1", groupId: "g1")
    if case .none = deeplink {
      // 정상
    } else {
      Issue.record("system 카테고리인데 none이 아님")
    }
  }
}

// MARK: - NotificationModel 속성 테스트

@Suite("NotificationModel 속성 테스트")
struct NotificationModelPropertyTests {

  @Test("id는 notificationId와 동일")
  func id_equalsNotificationId() {
    let notification = TestFactories.makeNotification(notificationId: "noti-123")
    #expect(notification.id == "noti-123")
  }

  @Test("deeplinkType이 promiseId, groupId 기반으로 생성됨")
  func deeplinkType_usesPromiseAndGroupId() {
    let notification = TestFactories.makeNotification(
      type: .promiseInvitation,
      promiseId: "promise-1",
      groupId: "group-1"
    )
    if case .promise(let pid, let gid) = notification.deeplinkType {
      #expect(pid == "promise-1")
      #expect(gid == "group-1")
    } else {
      Issue.record("promise 딥링크가 아님")
    }
  }

  @Test("system 타입 알림의 deeplinkType은 none")
  func deeplinkType_forSystemNotification_isNone() {
    let notification = TestFactories.makeNotification(
      type: .system,
      promiseId: "p1",
      groupId: "g1"
    )
    if case .none = notification.deeplinkType {
      // 정상
    } else {
      Issue.record("system 알림의 deeplinkType이 none이 아님")
    }
  }

  @Test("기본 생성 시 isRead는 false")
  func defaultNotification_isReadFalse() {
    let notification = TestFactories.makeNotification()
    #expect(notification.isRead == false)
  }

  @Test("기본 생성 시 readAt은 nil")
  func defaultNotification_readAtNil() {
    let notification = TestFactories.makeNotification()
    #expect(notification.readAt == nil)
  }
}

// MARK: - NotificationCategory rawValue 테스트

@Suite("NotificationCategory rawValue 테스트")
struct NotificationCategoryRawValueTests {

  @Test("각 카테고리의 rawValue가 올바른 snake_case 문자열")
  func rawValues_areCorrectSnakeCase() {
    #expect(NotificationCategory.promiseInvitation.rawValue == "promise_invitation")
    #expect(NotificationCategory.promiseReminder.rawValue == "promise_reminder")
    #expect(NotificationCategory.promiseConfirmed.rawValue == "promise_confirmed")
    #expect(NotificationCategory.promiseCancelled.rawValue == "promise_cancelled")
    #expect(NotificationCategory.promiseUpdated.rawValue == "promise_updated")
    #expect(NotificationCategory.groupInvitation.rawValue == "group_invitation")
    #expect(NotificationCategory.groupUpdate.rawValue == "group_update")
    #expect(NotificationCategory.attendanceResponse.rawValue == "attendance_response")
    #expect(NotificationCategory.system.rawValue == "system")
  }
}

// MARK: - NotificationFilter 테스트

@Suite("NotificationFilter 테스트")
struct NotificationFilterTests {

  @Test("NotificationFilter rawValue 확인")
  func rawValues() {
    #expect(NotificationFilter.all.rawValue == "전체")
    #expect(NotificationFilter.unread.rawValue == "안 읽음")
  }

  @Test("NotificationFilter allCases에 2개 포함")
  func allCases_hasTwo() {
    #expect(NotificationFilter.allCases.count == 2)
  }
}
