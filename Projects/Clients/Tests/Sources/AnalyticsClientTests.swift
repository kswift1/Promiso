import ComposableArchitecture
import FirebaseAnalytics
import PromisoShared
import Testing
@testable import Clients

@Suite("AnalyticsClient 테스트")
struct AnalyticsClientTests {
  @Test("타입드 공유 이벤트가 raw Firebase payload로 변환된다")
  func typedEvent_mapsToRawPayload() {
    let loggedName = LockIsolated<String?>(nil)
    let loggedParameters = LockIsolated<[String: Any]?>(nil)

    let client = AnalyticsClient(
      logEvent: { name, parameters in
        loggedName.setValue(name)
        loggedParameters.setValue(parameters)
      },
      setUserID: { _ in },
      setUserProperty: { _, _ in }
    )

    client.log(
      .groupInviteLinkShared(
        groupID: "group-1",
        groupName: "Promiso Team",
        shareMethod: .kakao,
        scheduleCount: 3
      )
    )

    #expect(loggedName.value == AnalyticsClient.EventName.groupInviteLinkShared)
    #expect(loggedParameters.value?[AnalyticsClient.ParameterKey.groupID] as? String == "group-1")
    #expect(loggedParameters.value?[AnalyticsClient.ParameterKey.groupName] as? String == "Promiso Team")
    #expect(loggedParameters.value?[AnalyticsClient.ParameterKey.shareMethod] as? String == "kakao")
    #expect(loggedParameters.value?[AnalyticsClient.ParameterKey.scheduleCount] as? Int == 3)
  }

  @Test("screen helper가 Firebase screen_view 이벤트를 사용한다")
  func logScreen_usesScreenViewEvent() {
    let loggedName = LockIsolated<String?>(nil)
    let loggedParameters = LockIsolated<[String: Any]?>(nil)

    let client = AnalyticsClient(
      logEvent: { name, parameters in
        loggedName.setValue(name)
        loggedParameters.setValue(parameters)
      },
      setUserID: { _ in },
      setUserProperty: { _, _ in }
    )

    client.logScreen(
      .scheduleDetail,
      additionalParameters: [
        AnalyticsClient.ParameterKey.scheduleID: .string("schedule-1")
      ]
    )

    #expect(loggedName.value == AnalyticsEventScreenView)
    #expect(loggedParameters.value?[AnalyticsClient.ParameterKey.screenName] as? String == AnalyticsClient.ScreenName.scheduleDetail.rawValue)
    #expect(loggedParameters.value?[AnalyticsClient.ParameterKey.screenClass] as? String == "ScheduleDetailView")
    #expect(loggedParameters.value?[AnalyticsClient.ParameterKey.scheduleID] as? String == "schedule-1")
  }

  @Test("sanitizeParameters가 길이를 제한하고 지원하지 않는 값을 제거한다")
  func sanitizeParameters_normalizesValues() {
    let longKey = String(repeating: "k", count: 50)
    let longValue = String(repeating: "v", count: 150)

    let sanitized = AnalyticsClient.sanitizeParameters(
      [
        longKey: longValue,
        "bool_value": true,
        "double_value": 1.5,
        "unsupported": URL(string: "https://promiso.app") as Any
      ]
    )

    #expect((sanitized?[String(repeating: "k", count: 40)] as? String)?.count == 100)
    #expect(sanitized?["bool_value"] as? Bool == true)
    #expect(sanitized?["double_value"] as? Double == 1.5)
    #expect(sanitized?["unsupported"] == nil)
  }

  @Test("유저 프로퍼티 helper가 세그먼트용 값으로 정규화한다")
  func userPropertyHelpers_normalizeValues() {
    let userProperties = LockIsolated<[String: String]>([:])

    let client = AnalyticsClient(
      logEvent: { _, _ in },
      setUserID: { _ in },
      setUserProperty: { value, key in
        if let value {
          userProperties.withValue { $0[key] = value }
        }
      }
    )

    let groups = [
      UserGroupInfo(id: "group-1", name: "첫 그룹"),
      UserGroupInfo(
        id: "group-2",
        name: "둘째 그룹",
        notifications: GroupNotificationSettings(calendarSync: false)
      ),
      UserGroupInfo(id: "group-3", name: "셋째 그룹"),
      UserGroupInfo(id: "group-4", name: "넷째 그룹"),
      UserGroupInfo(id: "group-5", name: "다섯째 그룹")
    ]

    client.setSubscriptionTier(.lifetime)
    client.setNotificationPermissionStatus(.provisional)
    client.setGroupMembershipProperties(groups)
    client.setCalendarSyncEnabled(personalEnabled: false, groups: groups)

    #expect(userProperties.value[AnalyticsClient.UserPropertyKey.subscriptionTier.rawValue] == "pro")
    #expect(userProperties.value[AnalyticsClient.UserPropertyKey.notificationPermissionStatus.rawValue] == "provisional")
    #expect(userProperties.value[AnalyticsClient.UserPropertyKey.hasGroup.rawValue] == "true")
    #expect(userProperties.value[AnalyticsClient.UserPropertyKey.groupCountBucket.rawValue] == "5_plus")
    #expect(userProperties.value[AnalyticsClient.UserPropertyKey.calendarSyncEnabled.rawValue] == "true")
  }
}
