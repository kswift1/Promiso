import Foundation
import FirebaseAuth
import FirebaseFirestore
import PromisoShared

/// RecurringPersonalEvent 관련 Firestore CRUD 및 실시간 구독을 담당하는 DataSource
/// 경로: users/{userId}/recurringEvents/{eventId}
public actor RecurringPersonalEventRemoteDataSource: RecurringPersonalEventRemoteDataSourceProtocol {
  private let firestore: FirestoreProviding
  private let subcollectionName: String
  private var db: Firestore { firestore.db }

  public init(
    firestore: FirestoreProviding = DefaultFirestoreProvider(),
    subcollectionName: String = "recurringEvents"
  ) {
    self.firestore = firestore
    self.subcollectionName = subcollectionName
  }

  // MARK: - Helper

  /// 현재 사용자의 recurringEvents 서브컬렉션 참조
  private func eventsCollection() throws -> CollectionReference {
    guard let currentUserId = Auth.auth().currentUser?.uid else {
      throw NSError(domain: "RecurringPersonalEventRemoteDataSource", code: 401, userInfo: [
        NSLocalizedDescriptionKey: LocalizedStrings.Error.userAuthRequired
      ])
    }
    return db.collection("users")
      .document(currentUserId)
      .collection(subcollectionName)
  }

  // MARK: - CRUD Operations

  /// 반복 일정 생성
  public func createEvent(_ event: RecurringPersonalEventModel) async throws -> String {
    let collection = try eventsCollection()
    let dto = RecurringPersonalEventDTO(model: event)
    let docRef = collection.document()
    try docRef.setData(from: dto)
    AppLogger.personal.info("🔄 [RecurringEvent] 반복 일정 생성: \(docRef.documentID)")
    return docRef.documentID
  }

  /// 반복 일정 업데이트
  public func updateEvent(_ event: RecurringPersonalEventModel) async throws {
    let collection = try eventsCollection()
    var updatedEvent = event
    updatedEvent.updatedAt = Date()
    let dto = RecurringPersonalEventDTO(model: updatedEvent)
    try collection.document(event.id).setData(from: dto)
    AppLogger.personal.info("🔄 [RecurringEvent] 반복 일정 업데이트: \(event.id)")
  }

  /// 반복 일정 삭제
  public func deleteEvent(id: String) async throws {
    let collection = try eventsCollection()
    try await collection.document(id).delete()
    AppLogger.personal.info("🔄 [RecurringEvent] 반복 일정 삭제: \(id)")
  }

  /// 반복 일정 단건 조회
  public func getEvent(id: String) async throws -> RecurringPersonalEventModel? {
    let collection = try eventsCollection()
    let document = try await collection.document(id).getDocument()
    guard document.exists else { return nil }
    let dto = try document.data(as: RecurringPersonalEventDTO.self)
    return RecurringPersonalEventModel(dto: dto, id: document.documentID)
  }

  /// 반복 일정 전체 조회
  public func getAllEvents() async throws -> [RecurringPersonalEventModel] {
    let collection = try eventsCollection()
    let snapshot = try await collection.order(by: "createdAt").getDocuments()
    return snapshot.documents.compactMap { doc -> RecurringPersonalEventModel? in
      do {
        let dto = try doc.data(as: RecurringPersonalEventDTO.self)
        return RecurringPersonalEventModel(dto: dto, id: doc.documentID)
      } catch {
        AppLogger.personal.error("🔄 [RecurringEvent] 파싱 에러: \(error)")
        return nil
      }
    }
  }

  // MARK: - Real-time Listener

  /// 반복 일정 전체 실시간 구독
  public func subscribeToAllEvents() async -> AsyncStream<[RecurringPersonalEventModel]> {
    return AsyncStream { continuation in
      guard let currentUserId = Auth.auth().currentUser?.uid else {
        AppLogger.personal.error("🔄 [RecurringEvent] 로그인 필요")
        continuation.yield([])
        continuation.finish()
        return
      }

      let collection = db.collection("users")
        .document(currentUserId)
        .collection(subcollectionName)

      let listener = collection.order(by: "createdAt").addSnapshotListener { snapshot, error in
        if let error = error {
          AppLogger.personal.error("🔄 [RecurringEvent] Listener error: \(error.localizedDescription)")
          continuation.yield([])
          return
        }

        guard let snapshot = snapshot else {
          continuation.yield([])
          return
        }

        let events = snapshot.documents.compactMap { doc -> RecurringPersonalEventModel? in
          do {
            let dto = try doc.data(as: RecurringPersonalEventDTO.self)
            return RecurringPersonalEventModel(dto: dto, id: doc.documentID)
          } catch {
            AppLogger.personal.error("🔄 [RecurringEvent] 파싱 에러: \(error)")
            return nil
          }
        }

        continuation.yield(events)
      }

      continuation.onTermination = { _ in
        AppLogger.personal.debug("🔄 [RecurringEvent] 리스너 종료")
        listener.remove()
      }
    }
  }
}
