import Foundation
import FirebaseFirestore
import Combine
import Domain

/// Promise 관련 Firestore CRUD 및 쿼리 작업을 담당하는 Repository
public class FirebasePromiseRepository: PromiseRepositoryProtocol {
  private let db = Firestore.firestore()
  private let calendarKeyGenerator: CalendarKeyGenerator
  
  public init(calendarKeyGenerator: CalendarKeyGenerator) {
    self.calendarKeyGenerator = calendarKeyGenerator
  }
  
  // MARK: - CRUD Operations
  
  /// 약속 생성
  public func createPromise(_ promise: PromiseModel) async throws -> String {
    // TODO: Domain 모델을 Firestore 문서로 변환하여 저장
    // 현재는 기본 구조만 제공
    let promiseRef = db.collection("promises").document()
    try await promiseRef.setData([
      "id": promise.id,
      "title": promise.title,
      "description": promise.description as Any,
      "minimumParticipants": promise.minimumParticipants,
      "requiredCount": promise.requiredCount,
      "isConfirmed": promise.isConfirmed,
      "startAt": Timestamp(date: promise.startAt),
      "status": promise.status.rawValue
    ])
    return promiseRef.documentID
  }
  
  /// 약속 업데이트
  public func updatePromise(_ promise: PromiseModel) async throws {
    // TODO: Domain 모델을 Firestore 문서로 변환하여 업데이트
    let ref = db.collection("promises").document(promise.id)
    try await ref.updateData([
      "title": promise.title,
      "description": promise.description as Any,
      "isConfirmed": promise.isConfirmed,
      "updatedAt": Timestamp(date: Date())
    ])
  }
  
  /// 약속 삭제 (soft delete)
  public func deletePromise(id: String) async throws {
    let ref = db.collection("promises").document(id)
    try await ref.updateData([
      "isDeleted": true,
      "updatedAt": Timestamp(date: Date())
    ])
  }
  
  /// 약속 조회
  public func getPromise(id: String) async throws -> PromiseModel? {
    // TODO: Firestore 문서를 Domain 모델로 변환하여 반환
    let ref = db.collection("promises").document(id)
    let document = try await ref.getDocument()
    
    guard document.exists else { return nil }
    
    // 임시 구현 - 실제로는 Firestore 문서를 Domain 모델로 변환
    guard let data = document.data() else { return nil }
    
    return PromiseModel(
      id: data["id"] as? String ?? id,
      title: data["title"] as? String ?? "",
      minimumParticipants: data["minimumParticipants"] as? Int ?? 1,
      requiredCount: data["requiredCount"] as? Int ?? 1,
      host: User(id: "temp", email: "temp@example.com", nickname: "temp"),
      group: Group(id: "temp", name: "temp"),
      startAt: (data["startAt"] as? Timestamp)?.dateValue() ?? Date()
    )
  }
  
  // MARK: - Query Operations
  
  /// 오늘의 약속 조회
  public func getTodayPromises(userId: String, groupId: String?) async throws -> [PromiseModel] {
    // TODO: Firestore 쿼리를 구현하여 Domain 모델 배열 반환
    let todayKey = calendarKeyGenerator.generateYyyymmddKey(for: Date())
    let query = db.collection("promises")
      .whereField("localYyyymmdd", isEqualTo: todayKey)
      .whereField("isDeleted", isEqualTo: false)
    
    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { document in
      try self.documentToPromise(document)
    }
  }
  
  /// 다가오는 약속 조회
  public func getUpcomingPromises(userId: String, limit: Int) async throws -> [PromiseModel] {
    // TODO: Firestore 쿼리를 구현
    return []
  }
  
  /// 답변 필요한 제안 조회
  public func getPendingProposals(userId: String, limit: Int) async throws -> [PromiseModel] {
    // TODO: Firestore 쿼리를 구현
    return []
  }
  
  /// 그룹의 활성 약속 조회
  public func getActivePromises(groupId: String, limit: Int) async throws -> [PromiseModel] {
    // TODO: Firestore 쿼리를 구현
    return []
  }
  
  // MARK: - Real-time Operations
  
  /// 오늘의 약속 실시간 관찰
  public func observeTodayPromises(userId: String, groupId: String?) -> AnyPublisher<[PromiseModel], Error> {
    let todayKey = calendarKeyGenerator.generateYyyymmddKey(for: Date())
    let query = db.collection("promises")
      .whereField("localYyyymmdd", isEqualTo: todayKey)
      .whereField("isDeleted", isEqualTo: false)
    
    return Publishers.FirestoreQuery(query: query)
      .map { snapshot in
        snapshot.documents.compactMap { document in
          try? self.documentToPromise(document)
        }
      }
      .eraseToAnyPublisher()
  }
  
  /// 약속 실시간 관찰
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

// MARK: - Combine Extensions
extension Publishers {
  struct FirestoreQuery: Publisher {
    typealias Output = QuerySnapshot
    typealias Failure = Error
    
    let query: Query
    
    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
      let subscription = FirestoreQuerySubscription(query: query, subscriber: subscriber)
      subscriber.receive(subscription: subscription)
    }
  }
  
  struct FirestoreDocument: Publisher {
    typealias Output = DocumentSnapshot?
    typealias Failure = Error
    
    let document: DocumentReference
    
    func receive<S>(subscriber: S) where S : Subscriber, Failure == S.Failure, Output == S.Input {
      let subscription = FirestoreDocumentSubscription(document: document, subscriber: subscriber)
      subscriber.receive(subscription: subscription)
    }
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
