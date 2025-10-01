import Foundation
import Combine
import FirebaseFirestore
import Domain

/// Promise 관련 Firestore CRUD 및 쿼리 작업을 담당하는 Repository
public class PromiseRepository: PromiseRepositoryProtocol {
  private let db = Firestore.firestore()
  
  public init() {}
  
  // MARK: - CRUD Operations
  
  /// 약속 생성
  public func createPromise(_ promise: PromiseModel) async throws -> String {
    let promiseRef = db.collection("promises").document()
    let promiseData: [String: Any] = [
      "id": promise.id,
      "title": promise.title,
      "description": promise.description as Any,
      "minimumParticipants": promise.minimumParticipants,
      "requiredCount": promise.requiredCount,
      "isConfirmed": promise.isConfirmed,
      "hostId": promise.host.id,
      "groupId": promise.group.id,
      "startAt": Timestamp(date: promise.startAt),
      "endAt": promise.endAt.map { Timestamp(date: $0) } as Any,
      "status": promise.status.rawValue,
      "createdAt": Timestamp(date: Date()),
      "updatedAt": Timestamp(date: Date()),
      "isDeleted": false
    ]
    
    try await promiseRef.setData(promiseData)
    return promiseRef.documentID
  }
  
  /// 약속 업데이트
  public func updatePromise(_ promise: PromiseModel) async throws {
    let ref = db.collection("promises").document(promise.id)
    let updateData: [String: Any] = [
      "title": promise.title,
      "description": promise.description as Any,
      "isConfirmed": promise.isConfirmed,
      "updatedAt": Timestamp(date: Date())
    ]
    
    try await ref.updateData(updateData)
  }
  
  /// 약속 삭제 (soft delete)
  public func deletePromise(id: String) async throws {
    let ref = db.collection("promises").document(id)
    try await ref.updateData(["isDeleted": true, "updatedAt": Timestamp(date: Date())])
  }
  
  /// 약속 조회
  public func getPromise(id: String) async throws -> PromiseModel? {
    let document = try await db.collection("promises").document(id).getDocument()
    return try documentSnapshotToPromise(document)
  }
  
  /// 오늘 약속 조회
  public func getTodayPromises(userId: String, groupId: String?) async throws -> [PromiseModel] {
    let today = Date()
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: today)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    
    var query = db.collection("promises")
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
    let query = db.collection("promises")
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
    let query = db.collection("promises")
      .whereField("groupId", isEqualTo: groupId)
      .whereField("status", isEqualTo: PromiseStatus.active.rawValue)
      .whereField("isDeleted", isEqualTo: false)
      .order(by: "startAt")
      .limit(to: limit)
    
    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try documentToPromise($0) }
  }
  
  /// 오늘 약속 실시간 관찰
  public func observeTodayPromises(userId: String, groupId: String?) -> AnyPublisher<[PromiseModel], Error> {
    let today = Date()
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: today)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    
    let query = db.collection("promises")
      .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
      .whereField("startAt", isLessThan: Timestamp(date: endOfDay))
      .whereField("status", isEqualTo: PromiseStatus.active.rawValue)
      .whereField("isDeleted", isEqualTo: false)
      .order(by: "startAt")
    
    return Publishers.FirestoreQuery(query: query)
      .map { snapshot in
        snapshot.documents.compactMap { try? self.documentToPromise($0) }
      }
      .eraseToAnyPublisher()
  }
  
  /// 약속 실시간 관찰 (단일 문서)
  public func observePromise(id: String) -> AnyPublisher<PromiseModel?, Error> {
    let ref = db.collection("promises").document(id)
    
    return Publishers.FirestoreDocument(document: ref)
      .map { document in
        guard let document = document else { return nil }
        return try? self.documentSnapshotToPromise(document)
      }
      .eraseToAnyPublisher()
  }
  
  // MARK: - Helper Methods
  
  private func documentToPromise(_ document: QueryDocumentSnapshot) throws -> PromiseModel? {
    let data = document.data()
    
    return PromiseModel(
      id: data["id"] as? String ?? document.documentID,
      title: data["title"] as? String ?? "",
      minimumParticipants: data["minimumParticipants"] as? Int ?? 1,
      requiredCount: data["requiredCount"] as? Int ?? 1,
      host: User(id: "temp", email: "temp@example.com", nickname: "temp"),
      group: Group(id: "temp", name: "temp"),
      startAt: (data["startAt"] as? Timestamp)?.dateValue() ?? Date()
    )
  }
  
  private func documentSnapshotToPromise(_ document: DocumentSnapshot) throws -> PromiseModel? {
    guard document.exists else { return nil }
    let data = document.data() ?? [:]
    
    return PromiseModel(
      id: data["id"] as? String ?? document.documentID,
      title: data["title"] as? String ?? "",
      minimumParticipants: data["minimumParticipants"] as? Int ?? 1,
      requiredCount: data["requiredCount"] as? Int ?? 1,
      host: User(id: "temp", email: "temp@example.com", nickname: "temp"),
      group: Group(id: "temp", name: "temp"),
      startAt: (data["startAt"] as? Timestamp)?.dateValue() ?? Date()
    )
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
