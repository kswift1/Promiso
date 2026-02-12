//
//  SharedTests.swift
//  PromisoShared
//
//  Shared 모듈 모델 테스트
//
//  ## 테스트 대상
//  - `PromisoShared/Sources/Models/FAQModel.swift`
//  - `PromisoShared/Sources/Models/GroupSortOption.swift`
//  - `PromisoShared/Sources/Models/RespondPromiseResult.swift`
//  - `PromisoShared/Sources/Models/GroupNotificationPreferences.swift`
//  - `PromisoShared/Sources/Common/LoadingState.swift`
//

import Foundation
import Testing
@testable import PromisoShared

// MARK: - FAQModel 테스트

@Suite("FAQModel 테스트")
struct FAQModelTests {

  @Test("기본값으로 초기화")
  func initWithDefaults() {
    let faq = FAQModel(id: "1", question: "질문", answer: "답변")
    #expect(faq.id == "1")
    #expect(faq.question == "질문")
    #expect(faq.answer == "답변")
    #expect(faq.category == nil)
    #expect(faq.order == 0)
    #expect(faq.isActive == true)
  }

  @Test("커스텀 값으로 초기화")
  func initWithCustomValues() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let faq = FAQModel(
      id: "2",
      question: "질문2",
      answer: "답변2",
      category: "그룹",
      order: 5,
      isActive: false,
      createdAt: date
    )
    #expect(faq.id == "2")
    #expect(faq.category == "그룹")
    #expect(faq.order == 5)
    #expect(faq.isActive == false)
    #expect(faq.createdAt == date)
  }

  @Test("Equatable 동작 확인")
  func equatable() {
    let date = Date(timeIntervalSince1970: 1700000000)
    let faq1 = FAQModel(id: "1", question: "Q", answer: "A", createdAt: date)
    let faq2 = FAQModel(id: "1", question: "Q", answer: "A", createdAt: date)
    #expect(faq1 == faq2)
  }

  @Test("서로 다른 FAQ는 같지 않음")
  func notEqual() {
    let faq1 = FAQModel(id: "1", question: "Q1", answer: "A1")
    let faq2 = FAQModel(id: "2", question: "Q2", answer: "A2")
    #expect(faq1 != faq2)
  }

  @Test("examples 배열이 비어있지 않음")
  func examplesNotEmpty() {
    #expect(FAQModel.examples.isNotEmpty)
    #expect(FAQModel.examples.count == 3)
  }

  @Test("Identifiable: id가 식별자로 동작")
  func identifiable() {
    let faq = FAQModel(id: "unique-id", question: "Q", answer: "A")
    #expect(faq.id == "unique-id")
  }
}

// MARK: - GroupSortOption 테스트

@Suite("GroupSortOption 테스트")
struct GroupSortOptionTests {

  @Test("sortType이 올바른 값 반환")
  func sortType_returnsCorrectType() {
    #expect(GroupSortOption.joinedRecent.sortType == .joined)
    #expect(GroupSortOption.joinedOldest.sortType == .joined)
    #expect(GroupSortOption.nameAscending.sortType == .name)
    #expect(GroupSortOption.nameDescending.sortType == .name)
    #expect(GroupSortOption.custom(order: ["a"]).sortType == .custom)
  }

  @Test("isAscending이 올바른 값 반환")
  func isAscending_returnsCorrectDirection() {
    #expect(GroupSortOption.joinedRecent.isAscending == false)
    #expect(GroupSortOption.joinedOldest.isAscending == true)
    #expect(GroupSortOption.nameAscending.isAscending == true)
    #expect(GroupSortOption.nameDescending.isAscending == false)
    #expect(GroupSortOption.custom(order: []).isAscending == true)
  }

  @Test("toggled가 반대 옵션 반환")
  func toggled_returnsOpposite() {
    #expect(GroupSortOption.joinedRecent.toggled == .joinedOldest)
    #expect(GroupSortOption.joinedOldest.toggled == .joinedRecent)
    #expect(GroupSortOption.nameAscending.toggled == .nameDescending)
    #expect(GroupSortOption.nameDescending.toggled == .nameAscending)
  }

  @Test("custom toggled는 동일한 order 유지")
  func customToggled_retainOrder() {
    let order = ["group1", "group2"]
    let option = GroupSortOption.custom(order: order)
    let toggled = option.toggled
    if case .custom(let toggledOrder) = toggled {
      #expect(toggledOrder == order)
    } else {
      Issue.record("toggled가 custom이 아님")
    }
  }

  @Test("customOrder: custom이면 배열 반환, 아니면 빈 배열")
  func customOrder_returnsCorrectValue() {
    let order = ["a", "b", "c"]
    #expect(GroupSortOption.custom(order: order).customOrder == order)
    #expect(GroupSortOption.joinedRecent.customOrder.isEmpty)
    #expect(GroupSortOption.nameAscending.customOrder.isEmpty)
  }

  @Test("SortType의 icon이 빈 문자열이 아님")
  func sortTypeIcon_notEmpty() {
    #expect(GroupSortOption.SortType.joined.icon.isNotEmpty)
    #expect(GroupSortOption.SortType.name.icon.isNotEmpty)
    #expect(GroupSortOption.SortType.custom.icon.isNotEmpty)
  }

  @Test("SortType의 rawValue가 한글")
  func sortTypeRawValue() {
    #expect(GroupSortOption.SortType.joined.rawValue == "가입일")
    #expect(GroupSortOption.SortType.name.rawValue == "가나다")
    #expect(GroupSortOption.SortType.custom.rawValue == "직접 설정")
  }

  @Test("Codable: joinedRecent 인코딩/디코딩")
  func codable_joinedRecent() throws {
    let option = GroupSortOption.joinedRecent
    let data = try JSONEncoder().encode(option)
    let decoded = try JSONDecoder().decode(GroupSortOption.self, from: data)
    #expect(decoded == .joinedRecent)
  }

  @Test("Codable: nameAscending 인코딩/디코딩")
  func codable_nameAscending() throws {
    let option = GroupSortOption.nameAscending
    let data = try JSONEncoder().encode(option)
    let decoded = try JSONDecoder().decode(GroupSortOption.self, from: data)
    #expect(decoded == .nameAscending)
  }

  @Test("Codable: custom 인코딩/디코딩")
  func codable_custom() throws {
    let option = GroupSortOption.custom(order: ["g1", "g2", "g3"])
    let data = try JSONEncoder().encode(option)
    let decoded = try JSONDecoder().decode(GroupSortOption.self, from: data)
    #expect(decoded == option)
  }

  @Test("Codable: 단순 문자열 디코딩 (이전 버전 호환)")
  func codable_legacyStringFormat() throws {
    let json = "\"joinedOldest\""
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(GroupSortOption.self, from: data)
    #expect(decoded == .joinedOldest)
  }

  @Test("Codable: 알 수 없는 문자열은 joinedRecent로 폴백")
  func codable_unknownStringFallback() throws {
    let json = "\"unknownType\""
    let data = json.data(using: .utf8)!
    let decoded = try JSONDecoder().decode(GroupSortOption.self, from: data)
    #expect(decoded == .joinedRecent)
  }

  @Test("write(): joinedRecent Dictionary 변환")
  func write_joinedRecent() {
    let dict = GroupSortOption.joinedRecent.write()
    #expect(dict["type"] as? String == "joinedRecent")
  }

  @Test("write(): custom Dictionary에 order 포함")
  func write_custom() {
    let dict = GroupSortOption.custom(order: ["a", "b"]).write()
    #expect(dict["type"] as? String == "custom")
    #expect(dict["order"] as? [String] == ["a", "b"])
  }

  @Test("read(): Dictionary에서 올바르게 생성")
  func read_fromDictionary() {
    let option = GroupSortOption.read(from: ["type": "nameDescending"])
    #expect(option == .nameDescending)
  }

  @Test("read(): custom Dictionary에서 order 포함하여 생성")
  func read_customFromDictionary() {
    let option = GroupSortOption.read(from: ["type": "custom", "order": ["x", "y"]])
    if case .custom(let order) = option {
      #expect(order == ["x", "y"])
    } else {
      Issue.record("custom이 아님")
    }
  }

  @Test("read(): nil Dictionary는 joinedRecent 기본값")
  func read_nilDictionary() {
    let option = GroupSortOption.read(from: nil)
    #expect(option == .joinedRecent)
  }
}

// MARK: - LoadingState 테스트

@Suite("LoadingState 테스트")
struct LoadingStateTests {

  @Test("idle 상태: isLoading=false, isLoaded=false, isFailed=false")
  func idle_state() {
    let state: LoadingState<String> = .idle
    #expect(state.isLoading == false)
    #expect(state.isLoaded == false)
    #expect(state.isFailed == false)
    #expect(state.value == nil)
    #expect(state.error == nil)
  }

  @Test("loading 상태: isLoading=true")
  func loading_state() {
    let state: LoadingState<String> = .loading
    #expect(state.isLoading == true)
    #expect(state.isLoaded == false)
    #expect(state.isFailed == false)
    #expect(state.value == nil)
  }

  @Test("loaded 상태: isLoaded=true, value에 데이터 포함")
  func loaded_state() {
    let state: LoadingState<String> = .loaded("데이터")
    #expect(state.isLoading == false)
    #expect(state.isLoaded == true)
    #expect(state.isFailed == false)
    #expect(state.value == "데이터")
  }

  @Test("failed 상태: isFailed=true, error 포함")
  func failed_state() {
    let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "테스트 에러"])
    let state: LoadingState<String> = .failed(error)
    #expect(state.isLoading == false)
    #expect(state.isLoaded == false)
    #expect(state.isFailed == true)
    #expect(state.error != nil)
    #expect(state.value == nil)
  }

  @Test("errorMessage: failed 상태에서 에러 메시지 반환")
  func errorMessage_returnDescription() {
    let error = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "네트워크 오류"])
    let state: LoadingState<String> = .failed(error)
    #expect(state.errorMessage == "네트워크 오류")
  }

  @Test("errorMessage: 비실패 상태에서 nil 반환")
  func errorMessage_nilForNonFailed() {
    let idle: LoadingState<String> = .idle
    let loading: LoadingState<String> = .loading
    let loaded: LoadingState<String> = .loaded("ok")
    #expect(idle.errorMessage == nil)
    #expect(loading.errorMessage == nil)
    #expect(loaded.errorMessage == nil)
  }

  @Test("Equatable: 같은 상태끼리 같음")
  func equatable_sameStates() {
    let idle1: LoadingState<Int> = .idle
    let idle2: LoadingState<Int> = .idle
    #expect(idle1 == idle2)

    let loading1: LoadingState<Int> = .loading
    let loading2: LoadingState<Int> = .loading
    #expect(loading1 == loading2)

    let loaded1: LoadingState<Int> = .loaded(42)
    let loaded2: LoadingState<Int> = .loaded(42)
    #expect(loaded1 == loaded2)
  }

  @Test("Equatable: 다른 상태는 같지 않음")
  func equatable_differentStates() {
    let idle: LoadingState<Int> = .idle
    let loading: LoadingState<Int> = .loading
    let loaded: LoadingState<Int> = .loaded(1)
    #expect(idle != loading)
    #expect(idle != loaded)
    #expect(loading != loaded)
  }

  @Test("Equatable: 다른 loaded 값은 같지 않음")
  func equatable_differentValues() {
    let loaded1: LoadingState<Int> = .loaded(1)
    let loaded2: LoadingState<Int> = .loaded(2)
    #expect(loaded1 != loaded2)
  }

  @Test("map: loaded 값을 변환")
  func map_transformsLoadedValue() {
    let state: LoadingState<Int> = .loaded(5)
    let mapped: LoadingState<String> = state.map { "\($0)" }
    #expect(mapped == .loaded("5"))
  }

  @Test("map: idle 상태는 idle 유지")
  func map_idleRemainsIdle() {
    let state: LoadingState<Int> = .idle
    let mapped: LoadingState<String> = state.map { "\($0)" }
    #expect(mapped == LoadingState<String>.idle)
  }

  @Test("map: loading 상태는 loading 유지")
  func map_loadingRemainsLoading() {
    let state: LoadingState<Int> = .loading
    let mapped: LoadingState<String> = state.map { "\($0)" }
    #expect(mapped == LoadingState<String>.loading)
  }

  @Test("map: failed 상태는 에러 유지")
  func map_failedRetainsError() {
    let error = NSError(domain: "test", code: 1, userInfo: nil)
    let state: LoadingState<Int> = .failed(error)
    let mapped: LoadingState<String> = state.map { "\($0)" }
    #expect(mapped.isFailed == true)
  }
}

// MARK: - RespondPromiseResult 테스트

@Suite("RespondPromiseResult 테스트")
struct RespondPromiseResultTests {

  @Test("기본 초기화 (confirmedPromise nil)")
  func initWithoutConfirmedPromise() {
    let result = RespondPromiseResult(
      promiseId: "p1",
      status: "accepted",
      isConfirmed: false
    )
    #expect(result.promiseId == "p1")
    #expect(result.status == "accepted")
    #expect(result.isConfirmed == false)
    #expect(result.confirmedPromise == nil)
  }

  @Test("confirmedPromise 포함 초기화")
  func initWithConfirmedPromise() {
    let promise = CalendarSyncPromise(
      id: "p1",
      title: "테스트",
      emoji: "📅",
      startAt: Date(),
      endAt: nil,
      location: nil,
      groupId: "g1"
    )
    let result = RespondPromiseResult(
      promiseId: "p1",
      status: "accepted",
      isConfirmed: true,
      confirmedPromise: promise
    )
    #expect(result.isConfirmed == true)
    #expect(result.confirmedPromise != nil)
    #expect(result.confirmedPromise?.title == "테스트")
  }

  @Test("Equatable 동작 확인")
  func equatable() {
    let result1 = RespondPromiseResult(
      promiseId: "p1",
      status: "accepted",
      isConfirmed: true
    )
    let result2 = RespondPromiseResult(
      promiseId: "p1",
      status: "accepted",
      isConfirmed: true
    )
    #expect(result1 == result2)
  }
}

// MARK: - GroupNotificationPreferences 테스트

@Suite("GroupNotificationPreferences 테스트")
struct GroupNotificationPreferencesTests {

  @Test("GroupNotificationPreferenceKey category 매핑")
  func preferenceKeyCategory() {
    #expect(GroupNotificationPreferenceKey.promiseInvitation.category == .promise)
    #expect(GroupNotificationPreferenceKey.promiseConfirmed.category == .promise)
    #expect(GroupNotificationPreferenceKey.promiseCancelled.category == .promise)
    #expect(GroupNotificationPreferenceKey.promiseUpdated.category == .promise)
    #expect(GroupNotificationPreferenceKey.groupUpdate.category == .group)
  }

  @Test("GroupNotificationPreferenceKey storageKey 매핑")
  func preferenceKeyStorageKey() {
    #expect(GroupNotificationPreferenceKey.promiseInvitation.storageKey == "invitation")
    #expect(GroupNotificationPreferenceKey.promiseConfirmed.storageKey == "confirmed")
    #expect(GroupNotificationPreferenceKey.promiseCancelled.storageKey == "cancelled")
    #expect(GroupNotificationPreferenceKey.promiseUpdated.storageKey == "updated")
    #expect(GroupNotificationPreferenceKey.groupUpdate.storageKey == "update")
  }

  @Test("GroupNotificationPreferenceKey title이 비어있지 않음")
  func preferenceKeyTitle_notEmpty() {
    for key in GroupNotificationPreferenceKey.allCases {
      #expect(key.title.isNotEmpty)
    }
  }

  @Test("GroupNotificationPreferenceKey subtitle: groupUpdate만 값 있음")
  func preferenceKeySubtitle() {
    #expect(GroupNotificationPreferenceKey.promiseInvitation.subtitle == nil)
    #expect(GroupNotificationPreferenceKey.groupUpdate.subtitle != nil)
  }

  @Test("GroupNotificationSettings 기본값으로 초기화")
  func settingsDefaultInit() {
    let settings = GroupNotificationSettings()
    #expect(settings.enabled == true)
    #expect(settings.calendarSync == true)
    // 기본 promise 설정이 포함되어 있어야 함
    #expect(settings.promise["invitation"] == true)
    #expect(settings.promise["confirmed"] == true)
    #expect(settings.group["update"] == true)
  }

  @Test("GroupNotificationSettings value(for:) 동작")
  func settingsValueForKey() {
    var settings = GroupNotificationSettings()
    #expect(settings.value(for: .promiseInvitation) == true)

    settings.setValue(false, for: .promiseInvitation)
    #expect(settings.value(for: .promiseInvitation) == false)
  }

  @Test("GroupNotificationSettings setValue 동작")
  func settingsSetValue() {
    var settings = GroupNotificationSettings()
    settings.setValue(false, for: .groupUpdate)
    #expect(settings.group["update"] == false)

    settings.setValue(false, for: .promiseCancelled)
    #expect(settings.promise["cancelled"] == false)
  }

  @Test("GroupNotificationSettings asDictionary 변환")
  func settingsAsDictionary() {
    let settings = GroupNotificationSettings()
    let dict = settings.asDictionary
    #expect(dict["enabled"] as? Bool == true)
    #expect(dict["calendarSync"] as? Bool == true)
    #expect(dict["promise"] != nil)
    #expect(dict["group"] != nil)
  }

  @Test("GroupNotificationPreferences mergeDefaults: 기본값과 사용자 설정 병합")
  func mergeDefaults() {
    let defaults: [String: Bool] = ["a": true, "b": true, "c": true]
    let source: [String: Bool] = ["a": false]
    let merged = GroupNotificationPreferences.mergeDefaults(source: source, defaults: defaults)
    #expect(merged["a"] == false)  // 사용자 설정 우선
    #expect(merged["b"] == true)   // 기본값 유지
    #expect(merged["c"] == true)   // 기본값 유지
  }

  @Test("GroupNotificationPreferences value(for:in:): nil settings는 true 반환")
  func value_nilSettingsReturnsDefault() {
    let value = GroupNotificationPreferences.value(for: .promiseInvitation, in: nil)
    #expect(value == true)
  }

  @Test("GroupNotificationSettings Codable 인코딩/디코딩")
  func settingsCodable() throws {
    var settings = GroupNotificationSettings()
    settings.setValue(false, for: .promiseInvitation)
    settings.calendarSync = false

    let data = try JSONEncoder().encode(settings)
    let decoded = try JSONDecoder().decode(GroupNotificationSettings.self, from: data)
    #expect(decoded.value(for: .promiseInvitation) == false)
    #expect(decoded.calendarSync == false)
    #expect(decoded.enabled == true)
  }
}
