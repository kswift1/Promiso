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
  public func updatePromise(_ promise: PromiseModel) async throws {
    let ref = db.environmentCollection(collectionName).document(promise.id)
    let updateData: [String: Any] = [
      "title": promise.title,
      "description": promise.description as Any,
      "updatedAt": Timestamp(date: Date())
    ]

    try await ref.updateData(updateData)
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
      .whereField("status", isEqualTo: PromiseStatus.active.rawValue)
      .whereField("isDeleted", isEqualTo: false)
      .order(by: "startAt")
    
    if let groupId = groupId {
      query = query.whereField("groupId", isEqualTo: groupId)
    }
    
    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try documentToPromise($0) }
  }
  
  /// 다가오는 약속 조회
  public func getUpcomingPromises(userId: String, limit: Int) async throws -> [PromiseModel] {
    let now = Date()
    let query = db.environmentCollection(collectionName)
      .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: now))
      .whereField("status", isEqualTo: PromiseStatus.active.rawValue)
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
  
  // MARK: - Helper Methods

  private func documentToPromise(_ document: QueryDocumentSnapshot) throws -> PromiseModel? {
    let dto = try document.data(as: PromiseDTO.self)
    // cancelled 또는 completed 상태는 제외
    let status = PromiseStatus(rawValue: dto.status)
    if status == .cancelled || status == .completed {
      return nil
    }
    return PromiseModel(dto: dto, id: document.documentID)
  }

  private func documentSnapshotToPromise(_ document: DocumentSnapshot) throws -> PromiseModel? {
    guard document.exists else { return nil }
    let dto = try document.data(as: PromiseDTO.self)
    // cancelled 또는 completed 상태는 제외
    let status = PromiseStatus(rawValue: dto.status)
    if status == .cancelled || status == .completed {
      return nil
    }
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
