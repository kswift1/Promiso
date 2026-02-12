//
//  NotificationDomainRuleTests.swift
//  Clients
//
//  Layer 1: 도메인 규칙 안전망 테스트
//
//  ## 목적
//  - 도메인 규칙(.ai/domain-rules/notification.md)이 코드에 올바르게 반영되었는지 검증
//  - 알림 설정, 필터, 카테고리 등 순수 모델 불변조건 검증
//

import Foundation
import Testing
@testable import Clients
@testable import PromisoShared

// MARK: - 알림 설정 (N1~N2)

@Suite("Notification 설정 도메인 규칙")
struct NotificationSettingsRuleTests {

  // MARK: - [N1] 그룹별 카테고리별 on/off (8종)

  @Test("[N1] 약속 알림 기본 설정은 6종")
  func n1_defaultPromise_hasSixKeys() {
    let defaults = GroupNotificationPreferences.defaultPromise
    #expect(defaults.count == 6)
  }

  @Test("[N1] 약속 알림 키: invitation, reminder, confirmed, cancelled, updated, attendanceResponse")
  func n1_defaultPromise_hasExpectedKeys() {
    let defaults = GroupNotificationPreferences.defaultPromise
    let expectedKeys: Set<String> = [
      "invitation", "reminder", "confirmed",
      "cancelled", "updated", "attendanceResponse",
    ]
    #expect(Set(defaults.keys) == expectedKeys)
  }

  @Test("[N1] 그룹 알림 기본 설정은 1종")
  func n1_defaultGroup_hasOneKey() {
    let defaults = GroupNotificationPreferences.defaultGroup
    #expect(defaults.count == 1)
    #expect(defaults["update"] != nil)
  }

  @Test("[N1] GroupNotificationPreferenceKey는 5종")
  func n1_preferenceKey_hasFiveCases() {
    let allCases = GroupNotificationPreferenceKey.allCases
    #expect(allCases.count == 5)
  }

  @Test("[N1] PreferenceKey 카테고리 매핑 (promise 4개, group 1개)")
  func n1_preferenceKey_categoryMapping() {
    let promiseKeys = GroupNotificationPreferenceKey.allCases.filter { $0.category == .promise }
    let groupKeys = GroupNotificationPreferenceKey.allCases.filter { $0.category == .group }
    #expect(promiseKeys.count == 4)
    #expect(groupKeys.count == 1)
  }

  // MARK: - [N2] 기본 설정: 모든 알림 ON

  @Test("[N2] 기본 생성 시 enabled = true")
  func n2_defaultSettings_enabledIsTrue() {
    let settings = GroupNotificationSettings()
    #expect(settings.enabled == true)
  }

  @Test("[N2] 기본 생성 시 약속 알림 모두 true")
  func n2_defaultSettings_allPromiseTrue() {
    let settings = GroupNotificationSettings()
    for (_, value) in settings.promise {
      #expect(value == true)
    }
  }

  @Test("[N2] 기본 생성 시 그룹 알림 모두 true")
  func n2_defaultSettings_allGroupTrue() {
    let settings = GroupNotificationSettings()
    for (_, value) in settings.group {
      #expect(value == true)
    }
  }

  @Test("[N2] 기본 생성 시 calendarSync = true")
  func n2_defaultSettings_calendarSyncTrue() {
    let settings = GroupNotificationSettings()
    #expect(settings.calendarSync == true)
  }

  @Test("[N2] value(for:) 기본값은 모두 true")
  func n2_valueForKey_allDefaultTrue() {
    let settings = GroupNotificationSettings()
    for key in GroupNotificationPreferenceKey.allCases {
      #expect(settings.value(for: key) == true)
    }
  }
}

// MARK: - 알림 필터 (N12)

@Suite("Notification 필터 도메인 규칙")
struct NotificationFilterRuleTests {

  // MARK: - [N12] 알림 필터: all, unread (2종)

  @Test("[N12] NotificationFilter는 2종 (all, unread)")
  func n12_filter_hasTwoCases() {
    let allCases = NotificationFilter.allCases
    #expect(allCases.count == 2)
  }

  @Test("[N12] all 필터 rawValue는 '전체'")
  func n12_allFilter_rawValue() {
    #expect(NotificationFilter.all.rawValue == "전체")
  }

  @Test("[N12] unread 필터 rawValue는 '안 읽음'")
  func n12_unreadFilter_rawValue() {
    #expect(NotificationFilter.unread.rawValue == "안 읽음")
  }
}

// MARK: - 알림 카테고리

@Suite("NotificationCategory 도메인 규칙")
struct NotificationCategoryRuleTests {

  @Test("NotificationCategory는 9종")
  func category_hasNineCases() {
    #expect(NotificationCategory.allCases.count == 9)
  }

  @Test("약속 관련 카테고리 딥링크는 promise 타입")
  func category_promiseDeeplink_returnsPromiseType() {
    let categories: [NotificationCategory] = [
      .promiseInvitation, .promiseReminder, .promiseConfirmed,
      .promiseCancelled, .promiseUpdated, .attendanceResponse,
    ]
    for category in categories {
      let deeplink = category.deeplink(promiseId: "p1", groupId: "g1")
      if case .promise = deeplink {
        // OK
      } else {
        Issue.record("Expected .promise for \(category)")
      }
    }
  }

  @Test("그룹 관련 카테고리 딥링크는 group 타입")
  func category_groupDeeplink_returnsGroupType() {
    let categories: [NotificationCategory] = [.groupInvitation, .groupUpdate]
    for category in categories {
      let deeplink = category.deeplink(promiseId: nil, groupId: "g1")
      if case .group = deeplink {
        // OK
      } else {
        Issue.record("Expected .group for \(category)")
      }
    }
  }

  @Test("system 카테고리 딥링크는 none")
  func category_systemDeeplink_returnsNone() {
    let deeplink = NotificationCategory.system.deeplink(promiseId: nil, groupId: nil)
    if case .none = deeplink {
      // OK
    } else {
      Issue.record("Expected .none for system")
    }
  }
}
