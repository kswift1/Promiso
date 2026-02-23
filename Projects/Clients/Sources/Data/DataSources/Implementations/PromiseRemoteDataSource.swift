import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import PromisoShared

// MARK: - Firebase Functions 상수

private enum FirebaseFunctionNames {
  static let deletePromise = "deletePromise"
  static let startLiveActivity = "startLiveActivity"
  static let updateETA = "updateETA"
  static let getConfirmedPromisesForCalendar = "getConfirmedPromisesForCalendar"
}

// MARK: - Date Formatter 상수

/// ISO8601 DateFormatter (Seoul 타임존, 쓰기용)
private let iso8601FormatterWithSeoulTimeZone: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter
}()

/// ISO8601 DateFormatter (기본 타임존, 읽기용)
private let iso8601Formatter: ISO8601DateFormatter = {
  let formatter = ISO8601DateFormatter()
  formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
  return formatter
}()

/// Promise 관련 Firestore CRUD 및 쿼리 작업을 담당하는 DataSource
public class PromiseRemoteDataSource: PromiseRemoteDataSourceProtocol {
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

  /// 약속 생성
  /// Firebase Functions의 createPromise를 호출합니다.
  public func createPromise(_ promise: PromiseModel) async throws -> String {
    var callableData: [String: Any] = [
      "groupId": promise.groupId,
      "title": promise.title,
      "startAt": iso8601FormatterWithSeoulTimeZone.string(from: promise.startAt),
      "minimumParticipants": promise.minimumParticipants
    ]

    // 선택적 필드 추가
    if let emoji = promise.emoji, !emoji.isEmpty {
      callableData["emoji"] = emoji
    }

    if let description = promise.description, !description.isEmpty {
      callableData["description"] = description
    }

    if let endAt = promise.endAt {
      callableData["endAt"] = iso8601FormatterWithSeoulTimeZone.string(from: endAt)
    }

    if let location = promise.location, !location.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
    if let trackingMinutes = promise.trackingStartMinutesBefore {
      callableData["arrivalSharingTime"] = trackingMinutes
    }

    // 이미지 URL 추가
    if !promise.imageUrls.isEmpty {
      callableData["imageUrls"] = promise.imageUrls
    }

    // Firebase Functions 호출
    let result = try await functions.httpsCallable("createPromise").call(callableData)

    guard let data = result.data as? [String: Any],
          let promiseId = data["promiseId"] as? String else {
      throw NSError(domain: "PromiseRemoteDataSource", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "약속 생성 응답이 올바르지 않습니다"
      ])
    }

    return promiseId
  }

  /// 약속 응답 업데이트
  public func respondToPromise(promiseId: String, status: String) async throws -> RespondPromiseResult {
    let callableData: [String: Any] = [
      "promiseId": promiseId,
      "status": status,
    ]

    AppLogger.calendar.debug("🌐 [DataSource] respondPromise 호출 - promiseId: \(promiseId), status: \(status)")

    let result = try await functions.httpsCallable("respondPromise").call(callableData)

    AppLogger.calendar.debug("🌐 [DataSource] respondPromise 응답 수신")

    guard let data = result.data as? [String: Any],
          let returnedPromiseId = data["promiseId"] as? String,
          let returnedStatus = data["status"] as? String,
          let isConfirmed = data["isConfirmed"] as? Bool else {
      AppLogger.calendar.error("🌐 [DataSource] respondPromise 파싱 실패 - data: \(String(describing: result.data))")
      throw NSError(domain: "PromiseRemoteDataSource", code: -1, userInfo: [
        NSLocalizedDescriptionKey: "약속 응답 결과가 올바르지 않습니다"
      ])
    }

    AppLogger.calendar.debug("🌐 [DataSource] respondPromise 파싱 - isConfirmed: \(isConfirmed), confirmedPromise 존재: \(data["confirmedPromise"] != nil)")

    var confirmedPromise: CalendarSyncPromise?

    if let promiseData = data["confirmedPromise"] as? [String: Any],
       let id = promiseData["id"] as? String,
       let title = promiseData["title"] as? String,
       let emoji = promiseData["emoji"] as? String,
       let startAtString = promiseData["startAt"] as? String,
       let groupId = promiseData["groupId"] as? String {

      if let startAt = iso8601Formatter.date(from: startAtString) {
        var endAt: Date?
        if let endAtString = promiseData["endAt"] as? String {
          endAt = iso8601Formatter.date(from: endAtString)
        }

        let location = promiseData["location"] as? String

        confirmedPromise = CalendarSyncPromise(
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

    return RespondPromiseResult(
      promiseId: returnedPromiseId,
      status: returnedStatus,
      isConfirmed: isConfirmed,
      confirmedPromise: confirmedPromise
    )
  }
  
  /// 약속 업데이트
  /// Firebase Functions의 updatePromise를 호출합니다.
  public func updatePromise(_ promise: PromiseModel) async throws {
    var callableData: [String: Any] = [
      "promiseId": promise.id,
      "title": promise.title,
      "startAt": iso8601FormatterWithSeoulTimeZone.string(from: promise.startAt),
      "minimumParticipants": promise.minimumParticipants
    ]

    // 선택적 필드 추가
    if let emoji = promise.emoji {
      callableData["emoji"] = emoji.isEmpty ? NSNull() : emoji
    }

    if let description = promise.description {
      callableData["description"] = description.isEmpty ? NSNull() : description
    } else {
      callableData["description"] = NSNull()
    }

    if let endAt = promise.endAt {
      callableData["endAt"] = iso8601FormatterWithSeoulTimeZone.string(from: endAt)
    } else {
      callableData["endAt"] = NSNull()
    }

    // trackingStartMinutesBefore (실시간 공유 시작 시간)
    if let trackingMinutes = promise.trackingStartMinutesBefore {
      callableData["trackingStartMinutesBefore"] = trackingMinutes
    } else {
      callableData["trackingStartMinutesBefore"] = NSNull()
    }

    // location (장소 정보)
    if let location = promise.location, !location.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
    if !promise.imageUrls.isEmpty {
      callableData["imageUrls"] = promise.imageUrls
    } else {
      callableData["imageUrls"] = NSNull()
    }

    // Firebase Functions 호출
    _ = try await functions.httpsCallable("updatePromise").call(callableData)
  }
  
  /// 약속 삭제 (hard delete)
  /// Firebase Functions의 deletePromise를 호출합니다.
  public func deletePromise(id: String) async throws {
    let callableData: [String: Any] = [
      "promiseId": id
    ]

    _ = try await functions.httpsCallable(FirebaseFunctionNames.deletePromise).call(callableData)
  }
  
  /// 약속 조회
  public func getPromise(id: String) async throws -> PromiseModel? {
    let document = try await db.environmentCollection(collectionName).document(id).getDocument()
    return try documentSnapshotToPromise(document)
  }
  
  /// 오늘 약속 조회 (사용자가 속한 그룹들의 약속)
  public func getTodayPromises(groupIds: [String]) async throws -> [PromiseModel] {
    guard !groupIds.isEmpty else { return [] }

    let today = Date()
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: today)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

    // Firestore 'in' 쿼리는 최대 10개까지 지원 - 병렬 처리
    let chunks = groupIds.chunked(into: 10)

    let allPromises = try await withThrowingTaskGroup(of: [PromiseModel].self) { group in
      for chunk in chunks {
        group.addTask { [db, collectionName] in
          let query = db.environmentCollection(collectionName)
            .whereField("groupId", in: chunk)
            .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
            .whereField("startAt", isLessThan: Timestamp(date: endOfDay))

          let snapshot = try await query.getDocuments()
          return try snapshot.documents.compactMap { try convertDocumentToPromise($0) }
        }
      }

      var results: [PromiseModel] = []
      for try await promises in group {
        results.append(contentsOf: promises)
      }
      return results
    }

    return allPromises.sorted { $0.startAt < $1.startAt }
  }

  /// 다가오는 약속 조회 (사용자가 속한 그룹들의 약속)
  ///
  /// 그룹 10개 단위 chunk로 분할해 병렬 조회한 뒤,
  /// 전역 정렬 + limit을 적용한다.
  /// 각 chunk에서 동일 limit을 적용해 불필요한 Firestore read를 줄인다.
  public func getUpcomingPromises(groupIds: [String], limit: Int) async throws -> [PromiseModel] {
    guard !groupIds.isEmpty, limit > 0 else { return [] }

    let now = Date()
    let chunks = groupIds.chunked(into: 10)
    let limitPerChunk = limit

    let allPromises = try await withThrowingTaskGroup(of: [PromiseModel].self) { group in
      for chunk in chunks {
        group.addTask { [db, collectionName] in
          let query = db.environmentCollection(collectionName)
            .whereField("groupId", in: chunk)
            .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: now))
            .order(by: "startAt")
            .limit(to: limitPerChunk)

          let snapshot = try await query.getDocuments()
          return try snapshot.documents.compactMap { try convertDocumentToPromise($0) }
        }
      }

      var results: [PromiseModel] = []
      for try await promises in group {
        results.append(contentsOf: promises)
      }
      return results
    }

    // 정렬 후 limit 적용
    return Array(allPromises.sorted { $0.startAt < $1.startAt }.prefix(limit))
  }
  
  /// 활성 약속 조회
  public func getActivePromises(groupId: String, limit: Int) async throws -> [PromiseModel] {
    let query = db.environmentCollection(collectionName)
      .whereField("groupId", isEqualTo: groupId)
      .order(by: "startAt")
      .limit(to: limit)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try convertDocumentToPromise($0) }
  }

  /// 과거 약속 조회 (startAt < 현재시간, 최신순 정렬, 커서 기반 페이징)
  public func getPastPromises(groupId: String, limit: Int, lastStartAt: Date?) async throws -> [PromiseModel] {
    var query = db.environmentCollection(collectionName)
      .whereField("groupId", isEqualTo: groupId)
      .whereField("startAt", isLessThan: Timestamp(date: Date()))
      .order(by: "startAt", descending: true)

    // 커서 기반 페이징: lastStartAt 이후 데이터만 조회
    if let lastStartAt {
      query = query.start(after: [Timestamp(date: lastStartAt)])
    }

    query = query.limit(to: limit)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try convertDocumentToPromise($0) }
  }

  /// 날짜 범위로 약속 조회 (캘린더용, 사용자가 속한 그룹들의 약속)
  public func getPromisesByDateRange(groupIds: [String], startDate: Date, endDate: Date) async throws -> [PromiseModel] {
    guard !groupIds.isEmpty else { return [] }

    let chunks = groupIds.chunked(into: 10)

    let allPromises = try await withThrowingTaskGroup(of: [PromiseModel].self) { group in
      for chunk in chunks {
        group.addTask { [db, collectionName] in
          let query = db.environmentCollection(collectionName)
            .whereField("groupId", in: chunk)
            .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startDate))
            .whereField("startAt", isLessThan: Timestamp(date: endDate))

          let snapshot = try await query.getDocuments()
          return try snapshot.documents.compactMap { try convertDocumentToPromise($0) }
        }
      }

      var results: [PromiseModel] = []
      for try await promises in group {
        results.append(contentsOf: promises)
      }
      return results
    }

    return allPromises.sorted { $0.startAt < $1.startAt }
  }

  /// 사용자가 수락한 약속을 날짜 범위로 조회 (일정 충돌 감지용)
  /// 인증된 사용자의 UID를 직접 사용하여 보안 강화
  public func getAcceptedPromisesByDateRange(startDate: Date, endDate: Date) async throws -> [PromiseModel] {
    guard let userId = Auth.auth().currentUser?.uid else {
      return []
    }

    let query = db.environmentCollection(collectionName)
      .whereField("votes.accepted", arrayContains: userId)
      .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startDate))
      .whereField("startAt", isLessThan: Timestamp(date: endDate))
      .order(by: "startAt")

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try convertDocumentToPromise($0) }
  }

  /// 그룹의 활성 약속 개수 조회 (Firestore count aggregation 사용)
  /// subscribeToActivePromises와 동일한 조건 (startAt >= now)
  /// 과거 여부는 클라이언트에서 isPast로 계산
  public func getActivePromiseCount(groupId: String) async throws -> Int {
    let query = db.environmentCollection(collectionName)
      .whereField("groupId", isEqualTo: groupId)
      .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: Date()))

    let snapshot = try await query.count.getAggregation(source: .server)
    return Int(truncating: snapshot.count)
  }

  /// 활성 약속 실시간 구독 (과거 약속 제외)
  public func subscribeToActivePromises(groupId: String, limit: Int) -> AsyncStream<[PromiseModel]> {
    return AsyncStream { continuation in
      let query = db.environmentCollection(collectionName)
        .whereField("groupId", isEqualTo: groupId)
        .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: Date()))
        .order(by: "startAt")
        .limit(to: limit)

      let listener = query.addSnapshotListener { snapshot, error in
        if let error = error {
          AppLogger.general.error("활성 약속 리스너 오류: \(error.localizedDescription)")
          return
        }

        guard let snapshot else { return }

        let promises = snapshot.documents.compactMap { doc -> PromiseModel? in
          do {
            return try convertDocumentToPromise(doc)
          } catch {
            AppLogger.general.error("활성 약속 파싱 실패: \(error.localizedDescription)")
            return nil
          }
        }

        continuation.yield(promises)
      }

      continuation.onTermination = { _ in
        listener.remove()
      }
    }
  }

  // MARK: - Home

  /// 홈화면용 약속 조회 (다중 그룹, 오늘 이후 약속)
  /// 그룹 10개씩 청킹하여 쿼리 (Firestore in 쿼리 제한)
  public func getHomePromises(groupIds: [String], limitPerChunk: Int) async throws -> [PromiseModel] {
    guard !groupIds.isEmpty else { return [] }

    let calendar = Calendar.current
    let startOfToday = calendar.startOfDay(for: Date())
    let chunks = groupIds.chunked(into: 10)

    let allPromises = try await withThrowingTaskGroup(of: [PromiseModel].self) { group in
      for chunk in chunks {
        group.addTask { [db, collectionName] in
          let query = db.environmentCollection(collectionName)
            .whereField("groupId", in: chunk)
            .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startOfToday))
            .order(by: "startAt")
            .limit(to: limitPerChunk)

          let snapshot = try await query.getDocuments()
          return try snapshot.documents.compactMap { try convertDocumentToPromise($0) }
        }
      }

      var results: [PromiseModel] = []
      for try await promises in group {
        results.append(contentsOf: promises)
      }
      return results
    }

    return allPromises.sorted { $0.startAt < $1.startAt }
  }

  // MARK: - Live Activity

  /// LiveActivity 시작 요청
  /// Firebase Functions의 startLiveActivity를 호출하여 Push to Start APNs 전송
  public func startLiveActivity(promiseId: String) async throws {
    let callableData: [String: Any] = [
      "promiseId": promiseId
    ]

    _ = try await functions.httpsCallable(FirebaseFunctionNames.startLiveActivity).call(callableData)
  }

  /// ETA 업데이트 요청
  /// Firebase Functions의 updateETA를 호출하여 모든 참가자에게 APNs 브로드캐스트
  /// Firestore 없이 클라이언트에서 전달한 데이터로 Broadcast만 전송
  public func updateETA(
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
      "channelId": channelId,
      "participants": participantsData,
      "trackingDurationMinutes": trackingDurationMinutes
    ]

    _ = try await functions.httpsCallable(FirebaseFunctionNames.updateETA).call(callableData)
  }

  // endLiveActivity 제거됨 - APNs dismissal-date로 auto-dismiss 처리
  // registerLiveActivityToken 제거됨 - iOS 18 Broadcast 방식으로 전환

  // MARK: - Calendar Sync

  /// 캘린더 동기화용 확정 약속 조회
  /// Firebase Functions를 통해 미래의 확정된 약속만 조회
  public func getConfirmedPromisesForCalendar() async throws -> [CalendarSyncPromise] {
    let result = try await functions
      .httpsCallable(FirebaseFunctionNames.getConfirmedPromisesForCalendar)
      .call()

    guard let data = result.data as? [String: Any],
          let promisesData = data["promises"] as? [[String: Any]] else {
      return []
    }

    return promisesData.compactMap { dict -> CalendarSyncPromise? in
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

      return CalendarSyncPromise(
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

  private func documentSnapshotToPromise(_ document: DocumentSnapshot) throws -> PromiseModel? {
    guard document.exists else { return nil }
    let dto = try document.data(as: PromiseDTO.self)
    return PromiseModel(dto: dto, id: document.documentID)
  }
}

// MARK: - Document Conversion Helper

/// QueryDocumentSnapshot을 PromiseModel로 변환하는 헬퍼 함수
/// TaskGroup 내에서도 사용 가능하도록 file-private으로 정의
private func convertDocumentToPromise(_ document: QueryDocumentSnapshot) throws -> PromiseModel? {
  let dto = try document.data(as: PromiseDTO.self)
  return PromiseModel(dto: dto, id: document.documentID)
}
