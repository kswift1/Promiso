import Foundation
import Combine
import FirebaseFirestore
import FirebaseFunctions
import PromisoShared

/// Promise 관련 Firestore CRUD 및 쿼리 작업을 담당하는 DataSource
public class PromiseRemoteDataSource: PromiseRemoteDataSourceProtocol {
  private let firestore: FirestoreProviding
  private let functions: Functions
  private let collectionName: String
  private var db: Firestore { firestore.db }

  public init(
    firestore: FirestoreProviding = DefaultFirestoreProvider(),
    functions: Functions = Functions.functions(region: "asia-northeast3"),
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
    // ISO 8601 형식으로 날짜 변환
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var callableData: [String: Any] = [
      "groupId": promise.groupId,
      "title": promise.title,
      "startAt": dateFormatter.string(from: promise.startAt),
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
      callableData["endAt"] = dateFormatter.string(from: endAt)
    }

    if let location = promise.location, !location.name.isEmpty {
      callableData["place"] = location.name
    }

    // env 파라미터 추가
    if let env = functionsEnvironmentParam() {
      callableData["env"] = env
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
  public func respondToPromise(promiseId: String, status: String) async throws {
    var callableData: [String: Any] = [
      "promiseId": promiseId,
      "status": status,
    ]

    if let env = functionsEnvironmentParam() {
      callableData["env"] = env
    }

    _ = try await functions.httpsCallable("respondPromise").call(callableData)
  }

  private func functionsEnvironmentParam() -> String? {
    switch FirestoreEnvironmentManager.shared.current {
    case .dev:
      return nil
    case .stage:
      return "stage"
    case .release:
      return "prod"
    }
  }
  
  /// 약속 업데이트
  /// Firebase Functions의 updatePromise를 호출합니다.
  public func updatePromise(_ promise: PromiseModel) async throws {
    // ISO 8601 형식으로 날짜 변환
    let dateFormatter = ISO8601DateFormatter()
    dateFormatter.timeZone = TimeZone(identifier: "Asia/Seoul")
    dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

    var callableData: [String: Any] = [
      "promiseId": promise.id,
      "title": promise.title,
      "startAt": dateFormatter.string(from: promise.startAt),
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
      callableData["endAt"] = dateFormatter.string(from: endAt)
    } else {
      callableData["endAt"] = NSNull()
    }

    // env 파라미터 추가
    if let env = functionsEnvironmentParam() {
      callableData["env"] = env
    }

    // Firebase Functions 호출
    _ = try await functions.httpsCallable("updatePromise").call(callableData)
  }
  
  /// 약속 삭제 (soft delete)
  public func deletePromise(id: String) async throws {
    let ref = db.environmentCollection(collectionName).document(id)
    try await ref.updateData(["isDeleted": true, "updatedAt": Timestamp(date: Date())])
  }
  
  /// 약속 조회
  public func getPromise(id: String) async throws -> PromiseModel? {
    let document = try await db.environmentCollection(collectionName).document(id).getDocument()
    return try documentSnapshotToPromise(document)
  }
  
  /// 오늘 약속 조회
  public func getTodayPromises(userId: String, groupId: String?) async throws -> [PromiseModel] {
    let today = Date()
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: today)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    
    var query = db.environmentCollection(collectionName)
      .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
      .whereField("startAt", isLessThan: Timestamp(date: endOfDay))
      .whereField("isDeleted", isEqualTo: false)
      .order(by: "startAt")
    
    if let groupId = groupId {
      query = query.whereField("groupId", isEqualTo: groupId)
    }
    
    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try documentToPromise($0) }
  }
  
  /// 다가오는 약속 조회 (모든 약속 - 클라이언트에서 필터링)
  public func getUpcomingPromises(userId: String, limit: Int) async throws -> [PromiseModel] {
    let now = Date()
    let query = db.environmentCollection(collectionName)
      .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: now))
      .whereField("isDeleted", isEqualTo: false)
      .order(by: "startAt")
      .limit(to: limit)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try documentToPromise($0) }
  }
  
  /// 답변 필요한 제안 조회 (현재는 임시 구현)
  public func getPendingProposals(userId: String, limit: Int) async throws -> [PromiseModel] {
    // TODO: 실제 구현 필요. 현재는 임시 데이터 반환
    return []
  }
  
  /// 활성 약속 조회
  public func getActivePromises(groupId: String, limit: Int) async throws -> [PromiseModel] {
    let query = db.environmentCollection(collectionName)
      .whereField("groupId", isEqualTo: groupId)
      .whereField("isDeleted", isEqualTo: false)
      .order(by: "startAt")
      .limit(to: limit)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try documentToPromise($0) }
  }

  /// 과거 약속 조회 (startAt < 현재시간, 최신순 정렬, 커서 기반 페이징)
  public func getPastPromises(groupId: String, limit: Int, lastStartAt: Date?) async throws -> [PromiseModel] {
    var query = db.environmentCollection(collectionName)
      .whereField("groupId", isEqualTo: groupId)
      .whereField("isDeleted", isEqualTo: false)
      .whereField("startAt", isLessThan: Timestamp(date: Date()))
      .order(by: "startAt", descending: true)

    // 커서 기반 페이징: lastStartAt 이후 데이터만 조회
    if let lastStartAt {
      query = query.start(after: [Timestamp(date: lastStartAt)])
    }

    query = query.limit(to: limit)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try documentToPastPromise($0) }
  }

  /// 날짜 범위로 약속 조회 (캘린더용)
  public func getPromisesByDateRange(userId: String, startDate: Date, endDate: Date) async throws -> [PromiseModel] {
    let query = db.environmentCollection(collectionName)
      .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startDate))
      .whereField("startAt", isLessThan: Timestamp(date: endDate))
      .whereField("isDeleted", isEqualTo: false)
      .order(by: "startAt")

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try documentToPromise($0) }
  }

  /// 그룹의 활성 약속 개수 조회 (Firestore count aggregation 사용)
  /// subscribeToActivePromises와 동일한 조건 (startAt >= now, isDeleted == false)
  /// 과거 여부는 클라이언트에서 isPast로 계산
  public func getActivePromiseCount(groupId: String) async throws -> Int {
    let query = db.environmentCollection(collectionName)
      .whereField("groupId", isEqualTo: groupId)
      .whereField("isDeleted", isEqualTo: false)
      .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: Date()))

    let snapshot = try await query.count.getAggregation(source: .server)
    return Int(truncating: snapshot.count)
  }

  /// 활성 약속 실시간 구독 (과거 약속 제외)
  public func subscribeToActivePromises(groupId: String, limit: Int) -> AsyncStream<[PromiseModel]> {
    print("[PromiseDataSource] 🔔 subscribeToActivePromises 호출: groupId=\(groupId)")
    return AsyncStream { continuation in
      print("[PromiseDataSource] 🔔 AsyncStream 생성됨")

      let query = db.environmentCollection(collectionName)
        .whereField("groupId", isEqualTo: groupId)
        .whereField("isDeleted", isEqualTo: false)
        .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: Date()))
        .order(by: "startAt")
        .limit(to: limit)

      print("[PromiseDataSource] 🔔 Firestore 리스너 등록 중...")
      let listener = query.addSnapshotListener { [weak self] snapshot, error in
        guard let self = self else {
          print("[PromiseDataSource] ⚠️ self가 nil")
          return
        }

        if let error = error {
          print("[PromiseDataSource] ❌ Listener error: \(error.localizedDescription)")
          return
        }

        guard let snapshot = snapshot else {
          print("[PromiseDataSource] ⚠️ snapshot이 nil")
          return
        }

        print("[PromiseDataSource] 📥 스냅샷 수신: \(snapshot.documents.count)개 문서")
        let now = Date()
        let promises = snapshot.documents.compactMap { doc -> PromiseModel? in
          do {
            let promise = try self.documentToPromise(doc)
            return promise
          } catch {
            print("[PromiseDataSource] ❌ 파싱 에러: \(error)")
            return nil
          }
        }
        print("[PromiseDataSource] ✅ 파싱 완료: \(promises.count)개 약속")
        print("[PromiseDataSource] 📅 현재 시간: \(now)")
        for promise in promises {
          print("[PromiseDataSource] - \(promise.title): startAt=\(promise.startAt), endAt=\(String(describing: promise.endAt)), isPast=\(promise.isPast), isConfirmed=\(promise.isConfirmed)")
        }

        continuation.yield(promises)
      }

      continuation.onTermination = { reason in
        print("[PromiseDataSource] 🛑 리스너 종료: \(reason)")
        listener.remove()
      }
    }
  }

  // MARK: - Helper Methods

  private func documentToPromise(_ document: QueryDocumentSnapshot) throws -> PromiseModel? {
    let dto = try document.data(as: PromiseDTO.self)
    return PromiseModel(dto: dto, id: document.documentID)
  }

  private func documentSnapshotToPromise(_ document: DocumentSnapshot) throws -> PromiseModel? {
    guard document.exists else { return nil }
    let dto = try document.data(as: PromiseDTO.self)
    return PromiseModel(dto: dto, id: document.documentID)
  }

  /// 과거 약속용 파싱
  private func documentToPastPromise(_ document: QueryDocumentSnapshot) throws -> PromiseModel? {
    let dto = try document.data(as: PromiseDTO.self)
    return PromiseModel(dto: dto, id: document.documentID)
  }
}

private class FirestoreQuerySubscription<S: Subscriber>: Subscription where S.Input == QuerySnapshot, S.Failure == Error {
  private var listener: ListenerRegistration?
  private let query: Query
  private let subscriber: S

  init(query: Query, subscriber: S) {
    self.query = query
    self.subscriber = subscriber
  }

  func request(_ demand: Subscribers.Demand) {
    listener = query.addSnapshotListener { [weak self] snapshot, error in
      if let error = error {
        self?.subscriber.receive(completion: .failure(error))
      } else if let snapshot = snapshot {
        _ = self?.subscriber.receive(snapshot)
      }
    }
  }

  func cancel() {
    listener?.remove()
    listener = nil
  }
}

private class FirestoreDocumentSubscription<S: Subscriber>: Subscription where S.Input == DocumentSnapshot?, S.Failure == Error {
  private var listener: ListenerRegistration?
  private let document: DocumentReference
  private let subscriber: S

  init(document: DocumentReference, subscriber: S) {
    self.document = document
    self.subscriber = subscriber
  }

  func request(_ demand: Subscribers.Demand) {
    listener = document.addSnapshotListener { [weak self] snapshot, error in
      if let error = error {
        self?.subscriber.receive(completion: .failure(error))
      } else {
        _ = self?.subscriber.receive(snapshot)
      }
    }
  }

  func cancel() {
    listener?.remove()
    listener = nil
  }
}
