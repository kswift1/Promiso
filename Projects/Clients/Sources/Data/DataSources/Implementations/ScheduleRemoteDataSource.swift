import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import PromisoShared

// MARK: - Firebase Functions 상수

private enum FirebaseFunctionNames {
  static let createSchedule = "createPromise"
  static let respondSchedule = "respondPromise"
  static let updateSchedule = "updatePromise"
  static let deleteSchedule = "deletePromise"
  static let startLiveActivity = "startLiveActivity"
  static let startVoteLiveActivity = "startVoteLiveActivity"
  static let finalizeVote = "finalizeVote"
  static let updateETA = "updateETA"
  static let getConfirmedSchedulesForCalendar = "getConfirmedPromisesForCalendar"
}

// MARK: - Date Formatter 상수

/// ISO8601 DateFormatter (현재 타임존, 쓰기용)
private let iso8601FormatterWithCurrentTimeZone: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.timeZone = TimeZone.current
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter
}()

/// ISO8601 DateFormatter (기본 타임존, 읽기용)
private let iso8601Formatter: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter
}()

/// Schedule 관련 Firestore CRUD 및 쿼리 작업을 담당하는 DataSource
public class ScheduleRemoteDataSource: ScheduleRemoteDataSourceProtocol {
  private let firestore: FirestoreProviding
  private let functions: Functions
  private let collectionName: String
  private var db: Firestore { firestore.db }

  public init(
    firestore: FirestoreProviding = DefaultFirestoreProvider(),
    functions: Functions = DefaultFunctionsProvider().functions,
    collectionName: String = "promises"
  ) {
    self.firestore = firestore
    self.functions = functions
    self.collectionName = collectionName
  }
  
  // MARK: - CRUD Operations

  /// 일정 생성
  /// Firebase Functions의 createSchedule를 호출합니다.
  public func createSchedule(_ schedule: ScheduleModel) async throws -> String {
    var callableData: [String: Any] = [
      "groupId": schedule.groupId,
      "title": schedule.title,
      "startAt": iso8601FormatterWithCurrentTimeZone.string(from: schedule.startAt),
      "minimumParticipants": schedule.minimumParticipants
    ]

    // 선택적 필드 추가
    if let emoji = schedule.emoji, !emoji.isEmpty {
      callableData["emoji"] = emoji
    }

    if let description = schedule.description, !description.isEmpty {
      callableData["description"] = description
    }

    // descriptionBlocks 전송
    if !schedule.descriptionBlocks.isEmpty {
      let encoder = JSONEncoder()
      let data = try encoder.encode(schedule.descriptionBlocks)
      if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        callableData["descriptionBlocks"] = jsonArray
      }
    }

    if let endAt = schedule.endAt {
      callableData["endAt"] = iso8601FormatterWithCurrentTimeZone.string(from: endAt)
    }

    if let location = schedule.location, !location.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      var locationData: [String: Any] = ["name": location.name]
      if let address = location.address {
        locationData["address"] = address
      }
      if let latitude = location.latitude {
        locationData["latitude"] = latitude
      }
      if let longitude = location.longitude {
        locationData["longitude"] = longitude
      }
      callableData["location"] = locationData
    }

    // LiveActivity 예약 시작 시간 추가
    if let trackingMinutes = schedule.trackingStartMinutesBefore {
      callableData["arrivalSharingTime"] = trackingMinutes
    }

    // 이미지 URL 추가
    if !schedule.imageUrls.isEmpty {
      callableData["imageUrls"] = schedule.imageUrls
    }

    // Firebase Functions 호출
    let result = try await functions.httpsCallable(FirebaseFunctionNames.createSchedule).call(callableData)

    guard let data = result.data as? [String: Any],
          let scheduleId = data["promiseId"] as? String else {
      throw NSError(domain: "ScheduleRemoteDataSource", code: -1, userInfo: [
        NSLocalizedDescriptionKey: LocalizedStrings.Error.invalidResponse
      ])
    }

    return scheduleId
  }

  /// 일정 응답 업데이트
  public func respondToSchedule(scheduleId: String, status: String) async throws -> RespondScheduleResult {
    let callableData: [String: Any] = [
      "promiseId": scheduleId,
      "status": status,
    ]

    AppLogger.calendar.debug("🌐 [DataSource] respondSchedule 호출 - scheduleId: \(scheduleId), status: \(status)")

    let result = try await functions.httpsCallable(FirebaseFunctionNames.respondSchedule).call(callableData)

    AppLogger.calendar.debug("🌐 [DataSource] respondSchedule 응답 수신")

    guard let data = result.data as? [String: Any],
          let returnedScheduleId = data["promiseId"] as? String,
          let returnedStatus = data["status"] as? String,
          let isConfirmed = data["isConfirmed"] as? Bool else {
      AppLogger.calendar.error("🌐 [DataSource] respondSchedule 파싱 실패 - data: \(String(describing: result.data))")
      throw NSError(domain: "ScheduleRemoteDataSource", code: -1, userInfo: [
        NSLocalizedDescriptionKey: LocalizedStrings.Error.invalidResponse
      ])
    }

    AppLogger.calendar.debug("🌐 [DataSource] respondSchedule 파싱 - isConfirmed: \(isConfirmed), confirmedSchedule 존재: \(data["confirmedPromise"] != nil)")

    var confirmedSchedule: CalendarSyncSchedule?

    if let scheduleData = data["confirmedPromise"] as? [String: Any],
       let id = scheduleData["id"] as? String,
       let title = scheduleData["title"] as? String,
       let emoji = scheduleData["emoji"] as? String,
       let startAtString = scheduleData["startAt"] as? String,
       let groupId = scheduleData["groupId"] as? String {

      if let startAt = iso8601Formatter.date(from: startAtString) {
        var endAt: Date?
        if let endAtString = scheduleData["endAt"] as? String {
          endAt = iso8601Formatter.date(from: endAtString)
        }

        let location = scheduleData["location"] as? String

        confirmedSchedule = CalendarSyncSchedule(
          id: id,
          title: title,
          emoji: emoji,
          startAt: startAt,
          endAt: endAt,
          location: location,
          groupId: groupId
        )
      }
    }

    return RespondScheduleResult(
      scheduleId: returnedScheduleId,
      status: returnedStatus,
      isConfirmed: isConfirmed,
      confirmedSchedule: confirmedSchedule
    )
  }
  
  /// 일정 업데이트
  /// Firebase Functions의 updateSchedule를 호출합니다.
  public func updateSchedule(_ schedule: ScheduleModel) async throws {
    var callableData: [String: Any] = [
      "promiseId": schedule.id,
      "title": schedule.title,
      "startAt": iso8601FormatterWithCurrentTimeZone.string(from: schedule.startAt),
      "minimumParticipants": schedule.minimumParticipants
    ]

    // 선택적 필드 추가
    if let emoji = schedule.emoji {
      callableData["emoji"] = emoji.isEmpty ? NSNull() : emoji
    }

    if let description = schedule.description {
      callableData["description"] = description.isEmpty ? NSNull() : description
    } else {
      callableData["description"] = NSNull()
    }

    // descriptionBlocks 전송
    if !schedule.descriptionBlocks.isEmpty {
      let encoder = JSONEncoder()
      let data = try encoder.encode(schedule.descriptionBlocks)
      if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
        callableData["descriptionBlocks"] = jsonArray
      }
    } else {
      callableData["descriptionBlocks"] = NSNull()
    }

    if let endAt = schedule.endAt {
      callableData["endAt"] = iso8601FormatterWithCurrentTimeZone.string(from: endAt)
    } else {
      callableData["endAt"] = NSNull()
    }

    // trackingStartMinutesBefore (실시간 공유 시작 시간)
    if let trackingMinutes = schedule.trackingStartMinutesBefore {
      callableData["trackingStartMinutesBefore"] = trackingMinutes
    } else {
      callableData["trackingStartMinutesBefore"] = NSNull()
    }

    // location (장소 정보)
    if let location = schedule.location, !location.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      var locationData: [String: Any] = ["name": location.name]
      if let address = location.address {
        locationData["address"] = address
      }
      if let latitude = location.latitude {
        locationData["latitude"] = latitude
      }
      if let longitude = location.longitude {
        locationData["longitude"] = longitude
      }
      callableData["location"] = locationData
    } else {
      callableData["location"] = NSNull()
    }

    // 이미지 URL
    if !schedule.imageUrls.isEmpty {
      callableData["imageUrls"] = schedule.imageUrls
    } else {
      callableData["imageUrls"] = NSNull()
    }

    // Firebase Functions 호출
    _ = try await functions.httpsCallable(FirebaseFunctionNames.updateSchedule).call(callableData)
  }
  
  /// 일정 삭제 (hard delete)
  /// Firebase Functions의 deleteSchedule를 호출합니다.
  public func deleteSchedule(id: String) async throws {
    let callableData: [String: Any] = [
      "promiseId": id
    ]

    _ = try await functions.httpsCallable(FirebaseFunctionNames.deleteSchedule).call(callableData)
  }
  
  /// 일정 조회
  public func getSchedule(id: String) async throws -> ScheduleModel? {
    let document = try await db.collection(collectionName).document(id).getDocument()
    return try documentSnapshotToSchedule(document)
  }
  
  /// 오늘 일정 조회 (사용자가 속한 그룹들의 일정)
  public func getTodaySchedules(groupIds: [String]) async throws -> [ScheduleModel] {
    guard !groupIds.isEmpty else { return [] }

    let today = Date()
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: today)
    guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }

    // Firestore 'in' 쿼리는 최대 10개까지 지원 - 병렬 처리
    let chunks = groupIds.chunked(into: 10)

    let allSchedules = try await withThrowingTaskGroup(of: [ScheduleModel].self) { group in
      for chunk in chunks {
        group.addTask { [db, collectionName] in
          let query = db.collection(collectionName)
            .whereField("groupId", in: chunk)
            .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("startAt", isLessThan: Timestamp(date: endOfDay))

          let snapshot = try await query.getDocuments()
          return try snapshot.documents.compactMap { try convertDocumentToSchedule($0) }
        }
      }

      var results: [ScheduleModel] = []
      for try await schedules in group {
        results.append(contentsOf: schedules)
      }
      return results
    }

    return allSchedules.sorted { $0.startAt < $1.startAt }
  }

  /// 다가오는 일정 조회 (사용자가 속한 그룹들의 일정)
  ///
  /// 그룹 10개 단위 chunk로 분할해 병렬 조회한다.
  /// 처음에는 chunk 수에 비례한 소량만 읽고,
  /// 필요한 chunk만 단계적으로 확장 조회해 Firestore read를 줄인다.
  public func getUpcomingSchedules(groupIds: [String], limit: Int) async throws -> [ScheduleModel] {
    guard !groupIds.isEmpty, limit > 0 else { return [] }

    let now = Date()
    let chunks = groupIds.chunked(into: 10)
    guard !chunks.isEmpty else { return [] }

    let batchSize = max(1, min(limit, Int(ceil(Double(limit) / Double(chunks.count)))))

    var states = try await withThrowingTaskGroup(of: (Int, UpcomingChunkFetchResult).self) { group in
      for (index, chunk) in chunks.enumerated() {
        group.addTask { [db, collectionName] in
          let result = try await fetchUpcomingChunk(
            db: db,
            collectionName: collectionName,
            groupIds: chunk,
            from: now,
            limit: batchSize
          )
          return (index, result)
        }
      }

      var initialResults: [(Int, UpcomingChunkFetchResult)] = []
      initialResults.reserveCapacity(chunks.count)
      for try await item in group {
        initialResults.append(item)
      }

      return initialResults
        .sorted { $0.0 < $1.0 }
        .map { index, result in
          UpcomingChunkState(
            groupIds: chunks[index],
            schedules: result.schedules,
            nextIndex: 0,
            fetchedLimit: batchSize,
            fetchedDocumentCount: result.fetchedDocumentCount
          )
        }
    }

    var merged: [ScheduleModel] = []
    merged.reserveCapacity(limit)
    var seenIds = Set<String>()
    seenIds.reserveCapacity(limit)

    while merged.count < limit {
      // 현재 버퍼가 소진된 chunk만 단계적으로 확장 조회한다.
      let expansionTargets = states.indices.filter {
        !states[$0].hasNextSchedule && states[$0].canExpand(maxLimit: limit)
      }

      if !expansionTargets.isEmpty {
        let expandedResults = try await withThrowingTaskGroup(
          of: (Int, Int, UpcomingChunkFetchResult).self
        ) { group in
          for index in expansionTargets {
            let nextLimit = min(limit, states[index].fetchedLimit + batchSize)
            let chunk = states[index].groupIds
            group.addTask { [db, collectionName] in
              let result = try await fetchUpcomingChunk(
                db: db,
                collectionName: collectionName,
                groupIds: chunk,
                from: now,
                limit: nextLimit
              )
              return (index, nextLimit, result)
            }
          }

          var results: [(Int, Int, UpcomingChunkFetchResult)] = []
          results.reserveCapacity(expansionTargets.count)
          for try await item in group {
            results.append(item)
          }
          return results
        }

        for (index, requestedLimit, result) in expandedResults {
          states[index].applyFetchResult(result, requestedLimit: requestedLimit)
        }
      }

      guard let selectedIndex = nextUpcomingChunkIndex(states: states) else {
        break
      }

      let nextSchedule = states[selectedIndex].consumeNextSchedule()
      if seenIds.insert(nextSchedule.id).inserted {
        merged.append(nextSchedule)
      }
    }

    return merged
  }
  
  /// 활성 일정 조회
  public func getActiveSchedules(groupId: String, limit: Int) async throws -> [ScheduleModel] {
    let query = db.collection(collectionName)
      .whereField("groupId", isEqualTo: groupId)
      .order(by: "startAt")
      .limit(to: limit)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try convertDocumentToSchedule($0) }
  }

  /// 과거 일정 조회 (startAt < 현재시간, 최신순 정렬, 커서 기반 페이징)
  public func getPastSchedules(groupId: String, limit: Int, lastStartAt: Date?) async throws -> [ScheduleModel] {
    var query = db.collection(collectionName)
      .whereField("groupId", isEqualTo: groupId)
      .whereField("startAt", isLessThan: Timestamp(date: Date()))
      .order(by: "startAt", descending: true)

    // 커서 기반 페이징: lastStartAt 이후 데이터만 조회
    if let lastStartAt {
      query = query.start(after: [Timestamp(date: lastStartAt)])
    }

    query = query.limit(to: limit)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try convertDocumentToSchedule($0) }
  }

  /// 날짜 범위로 일정 조회 (캘린더용, 사용자가 속한 그룹들의 일정)
  public func getSchedulesByDateRange(groupIds: [String], startDate: Date, endDate: Date) async throws -> [ScheduleModel] {
    guard !groupIds.isEmpty else { return [] }

    let chunks = groupIds.chunked(into: 10)

    let allSchedules = try await withThrowingTaskGroup(of: [ScheduleModel].self) { group in
      for chunk in chunks {
        group.addTask { [db, collectionName] in
          let query = db.collection(collectionName)
            .whereField("groupId", in: chunk)
            .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("startAt", isLessThan: Timestamp(date: endDate))

          let snapshot = try await query.getDocuments()
          return try snapshot.documents.compactMap { try convertDocumentToSchedule($0) }
        }
      }

      var results: [ScheduleModel] = []
      for try await schedules in group {
        results.append(contentsOf: schedules)
      }
      return results
    }

    return allSchedules.sorted { $0.startAt < $1.startAt }
  }

  /// 사용자가 수락한 일정을 날짜 범위로 조회 (일정 충돌 감지용)
  /// 인증된 사용자의 UID를 직접 사용하여 보안 강화
  public func getAcceptedSchedulesByDateRange(startDate: Date, endDate: Date) async throws -> [ScheduleModel] {
    guard let userId = Auth.auth().currentUser?.uid else {
      return []
    }

    let query = db.collection(collectionName)
      .whereField("votes.accepted", arrayContains: userId)
      .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startDate))
      .whereField("startAt", isLessThan: Timestamp(date: endDate))
      .order(by: "startAt")
      .limit(to: 50)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try convertDocumentToSchedule($0) }
  }

  /// 그룹의 활성 일정 개수 조회 (Firestore count aggregation 사용)
  /// subscribeToActiveSchedules와 동일한 조건 (startAt >= now)
  /// 과거 여부는 클라이언트에서 isPast로 계산
  public func getActiveScheduleCount(groupId: String) async throws -> Int {
    let query = db.collection(collectionName)
      .whereField("groupId", isEqualTo: groupId)
      .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: Date()))

    let snapshot = try await query.count.getAggregation(source: .server)
    return Int(truncating: snapshot.count)
  }

  /// 활성 일정 실시간 구독 (과거 일정 제외)
  public func subscribeToActiveSchedules(groupId: String, limit: Int) -> AsyncStream<[ScheduleModel]> {
    return AsyncStream { continuation in
      let query = db.collection(collectionName)
        .whereField("groupId", isEqualTo: groupId)
        .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: Calendar.current.startOfDay(for: Date())))
        .order(by: "startAt")
        .limit(to: limit)

      let listener = query.addSnapshotListener { snapshot, error in
        if let error = error {
          AppLogger.general.error("활성 일정 리스너 오류: \(error.localizedDescription)")
          return
        }

        guard let snapshot else { return }

        let schedules = snapshot.documents.compactMap { doc -> ScheduleModel? in
          do {
            return try convertDocumentToSchedule(doc)
          } catch {
            AppLogger.general.error("활성 일정 파싱 실패: \(error.localizedDescription)")
            return nil
          }
        }

        continuation.yield(schedules)
      }

      continuation.onTermination = { _ in
        listener.remove()
      }
    }
  }

  // MARK: - Home

  /// 홈화면용 일정 조회 (다중 그룹, 오늘 이후 일정)
  /// 그룹 10개씩 청킹하여 쿼리 (Firestore in 쿼리 제한)
  public func getHomeSchedules(groupIds: [String], limitPerChunk: Int) async throws -> [ScheduleModel] {
    guard !groupIds.isEmpty else { return [] }

    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: Date())
    let chunks = groupIds.chunked(into: 10)

    let allSchedules = try await withThrowingTaskGroup(of: [ScheduleModel].self) { group in
      for chunk in chunks {
        group.addTask { [db, collectionName] in
          let query = db.collection(collectionName)
            .whereField("groupId", in: chunk)
            .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startOfToday))
            .order(by: "startAt")
            .limit(to: limitPerChunk)

          let snapshot = try await query.getDocuments()
          return try snapshot.documents.compactMap { try convertDocumentToSchedule($0) }
        }
      }

      var results: [ScheduleModel] = []
      for try await schedules in group {
        results.append(contentsOf: schedules)
      }
      return results
    }

    return allSchedules.sorted { $0.startAt < $1.startAt }
  }

  // MARK: - Live Activity

  /// LiveActivity 시작 요청
  /// Firebase Functions의 startLiveActivity를 호출하여 Push to Start APNs 전송
  public func startLiveActivity(scheduleId: String) async throws {
    let callableData: [String: Any] = [
      "promiseId": scheduleId
    ]

    _ = try await functions.httpsCallable(FirebaseFunctionNames.startLiveActivity).call(callableData)
  }

  /// 투표 LiveActivity 시작 요청
  /// Firebase Functions의 startVoteLiveActivity를 호출하여 투표 LiveActivity APNs 전송
  public func startVoteLiveActivity(scheduleId: String) async throws {
    let callableData: [String: Any] = [
      "scheduleId": scheduleId
    ]

    _ = try await functions.httpsCallable(FirebaseFunctionNames.startVoteLiveActivity).call(callableData)
  }

  /// 투표 마감 요청 (호스트 전용)
  /// Firebase Functions의 finalizeVote를 호출하여 투표를 마감하고 일정을 확정합니다
  public func finalizeVote(scheduleId: String) async throws {
    let callableData: [String: Any] = ["scheduleId": scheduleId]
    _ = try await functions.httpsCallable(FirebaseFunctionNames.finalizeVote).call(callableData)
  }

  /// ETA 업데이트 요청
  /// Firebase Functions의 updateETA를 호출하여 모든 참가자에게 APNs 브로드캐스트
  /// Firestore 없이 클라이언트에서 전달한 데이터로 Broadcast만 전송
  public func updateETA(
    scheduleId: String,
    channelId: String,
    participants: [ParticipantState],
    trackingDurationMinutes: Int
  ) async throws {
    // participants를 서버 형식으로 변환
    let participantsData: [[String: Any]] = participants.map { p in
      var dict: [String: Any] = [
        "id": p.id,
        "name": p.name
      ]
      if let eta = p.estimatedArrivalMinutes {
        dict["estimatedArrivalMinutes"] = eta
      } else {
        dict["estimatedArrivalMinutes"] = NSNull()
      }
      return dict
    }

    let callableData: [String: Any] = [
      "promiseId": scheduleId,
      "channelId": channelId,
      "participants": participantsData,
      "trackingDurationMinutes": trackingDurationMinutes
    ]

    _ = try await functions.httpsCallable(FirebaseFunctionNames.updateETA).call(callableData)
  }

  // endLiveActivity 제거됨 - APNs dismissal-date로 auto-dismiss 처리
  // registerLiveActivityToken 제거됨 - iOS 18 Broadcast 방식으로 전환

  // MARK: - Calendar Sync

  /// 캘린더 동기화용 확정 일정 조회
  /// Firebase Functions를 통해 미래의 확정된 일정만 조회
  public func getConfirmedSchedulesForCalendar() async throws -> [CalendarSyncSchedule] {
    let result = try await functions
      .httpsCallable(FirebaseFunctionNames.getConfirmedSchedulesForCalendar)
      .call()

    guard let data = result.data as? [String: Any],
          let schedulesData = data["promises"] as? [[String: Any]] else {
      return []
    }

    return schedulesData.compactMap { dict -> CalendarSyncSchedule? in
      guard let id = dict["id"] as? String,
            let title = dict["title"] as? String,
            let emoji = dict["emoji"] as? String,
            let startAtString = dict["startAt"] as? String,
            let startAt = iso8601Formatter.date(from: startAtString),
            let groupId = dict["groupId"] as? String else {
        return nil
      }

      var endAt: Date?
      if let endAtString = dict["endAt"] as? String {
        endAt = iso8601Formatter.date(from: endAtString)
      }

      let location = dict["location"] as? String

      return CalendarSyncSchedule(
        id: id,
        title: title,
        emoji: emoji,
        startAt: startAt,
        endAt: endAt,
        location: location,
        groupId: groupId
      )
    }
  }

  // MARK: - Helper Methods

  private func nextUpcomingChunkIndex(states: [UpcomingChunkState]) -> Int? {
    var selectedIndex: Int?

    for index in states.indices where states[index].hasNextSchedule {
      guard let currentSelected = selectedIndex else {
        selectedIndex = index
        continue
      }

      guard let candidate = states[index].nextSchedule,
            let selected = states[currentSelected].nextSchedule else {
        continue
      }

      if candidate.startAt < selected.startAt
        || (candidate.startAt == selected.startAt && candidate.id < selected.id) {
        selectedIndex = index
      }
    }

    return selectedIndex
  }

  private func documentSnapshotToSchedule(_ document: DocumentSnapshot) throws -> ScheduleModel? {
    guard document.exists else { return nil }
    let dto = try document.data(as: ScheduleDTO.self)
    return ScheduleModel(dto: dto, id: document.documentID)
  }
}

private struct UpcomingChunkFetchResult {
  let schedules: [ScheduleModel]
  let fetchedDocumentCount: Int
}

private struct UpcomingChunkState {
  let groupIds: [String]
  var schedules: [ScheduleModel]
  var nextIndex: Int
  var fetchedLimit: Int
  var fetchedDocumentCount: Int

  var hasNextSchedule: Bool {
    nextIndex < schedules.count
  }

  var nextSchedule: ScheduleModel? {
    guard hasNextSchedule else { return nil }
    return schedules[nextIndex]
  }

  mutating func consumeNextSchedule() -> ScheduleModel {
    let schedule = schedules[nextIndex]
    nextIndex += 1
    return schedule
  }

  func canExpand(maxLimit: Int) -> Bool {
    fetchedLimit < maxLimit && fetchedDocumentCount >= fetchedLimit
  }

  mutating func applyFetchResult(_ result: UpcomingChunkFetchResult, requestedLimit: Int) {
    schedules = result.schedules
    fetchedLimit = requestedLimit
    fetchedDocumentCount = result.fetchedDocumentCount
    if nextIndex > schedules.count {
      nextIndex = schedules.count
    }
  }
}

private func fetchUpcomingChunk(
  db: Firestore,
  collectionName: String,
  groupIds: [String],
  from: Date,
  limit: Int
) async throws -> UpcomingChunkFetchResult {
  let query = db.collection(collectionName)
    .whereField("groupId", in: groupIds)
    .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: from))
    .order(by: "startAt")
    .limit(to: limit)

  let snapshot = try await query.getDocuments()
  let schedules = try snapshot.documents.compactMap { try convertDocumentToSchedule($0) }

  return UpcomingChunkFetchResult(
    schedules: schedules,
    fetchedDocumentCount: snapshot.documents.count
  )
}

// MARK: - Document Conversion Helper

/// QueryDocumentSnapshot을 ScheduleModel로 변환하는 헬퍼 함수
/// TaskGroup 내에서도 사용 가능하도록 file-private으로 정의
private func convertDocumentToSchedule(_ document: QueryDocumentSnapshot) throws -> ScheduleModel? {
  let dto = try document.data(as: ScheduleDTO.self)
  return ScheduleModel(dto: dto, id: document.documentID)
}
