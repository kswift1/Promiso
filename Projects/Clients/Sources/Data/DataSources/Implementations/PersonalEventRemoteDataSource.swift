import Foundation
import FirebaseAuth
import FirebaseFirestore
import PromisoShared

/// PersonalEvent 관련 Firestore CRUD 및 쿼리 작업을 담당하는 DataSource
public class PersonalEventRemoteDataSource: PersonalEventRemoteDataSourceProtocol {
  private let firestore: FirestoreProviding
  private let collectionName: String
  private var db: Firestore { firestore.db }

  public init(
    firestore: FirestoreProviding = DefaultFirestoreProvider(),
    collectionName: String = "personalEvents"
  ) {
    self.firestore = firestore
    self.collectionName = collectionName
  }

  // MARK: - CRUD Operations

  /// 개인 일정 생성
  public func createEvent(_ event: PersonalEventModel) async throws -> String {
    guard let currentUserId = Auth.auth().currentUser?.uid else {
      throw NSError(domain: "PersonalEventRemoteDataSource", code: 401, userInfo: [
        NSLocalizedDescriptionKey: "로그인이 필요합니다"
      ])
    }

    var newEvent = event
    newEvent.userId = currentUserId
    let dto = PersonalEventDTO(model: newEvent)
    let docRef = db.environmentCollection(collectionName).document()

    try await docRef.setData(from: dto)
    AppLogger.personal.info("📅 [PersonalEvent] 일정 생성 성공: \(docRef.documentID)")

    return docRef.documentID
  }

  /// 개인 일정 업데이트
  public func updateEvent(_ event: PersonalEventModel) async throws {
    guard let currentUserId = Auth.auth().currentUser?.uid else {
      throw NSError(domain: "PersonalEventRemoteDataSource", code: 401, userInfo: [
        NSLocalizedDescriptionKey: "로그인이 필요합니다"
      ])
    }

    guard event.userId == currentUserId else {
      throw NSError(domain: "PersonalEventRemoteDataSource", code: 403, userInfo: [
        NSLocalizedDescriptionKey: "본인의 일정만 수정할 수 있습니다"
      ])
    }

    var updatedEvent = event
    updatedEvent.updatedAt = Date()
    let dto = PersonalEventDTO(model: updatedEvent)

    try await db.environmentCollection(collectionName).document(event.id).setData(from: dto)
    AppLogger.personal.info("📅 [PersonalEvent] 일정 업데이트 성공: \(event.id)")
  }

  /// 개인 일정 삭제
  public func deleteEvent(id: String) async throws {
    guard let currentUserId = Auth.auth().currentUser?.uid else {
      throw NSError(domain: "PersonalEventRemoteDataSource", code: 401, userInfo: [
        NSLocalizedDescriptionKey: "로그인이 필요합니다"
      ])
    }

    let docRef = db.environmentCollection(collectionName).document(id)
    let document = try await docRef.getDocument()

    guard document.exists else {
      throw NSError(domain: "PersonalEventRemoteDataSource", code: 404, userInfo: [
        NSLocalizedDescriptionKey: "일정을 찾을 수 없습니다"
      ])
    }

    let dto = try document.data(as: PersonalEventDTO.self)
    guard dto.userId == currentUserId else {
      throw NSError(domain: "PersonalEventRemoteDataSource", code: 403, userInfo: [
        NSLocalizedDescriptionKey: "본인의 일정만 삭제할 수 있습니다"
      ])
    }

    try await docRef.delete()
    AppLogger.personal.info("📅 [PersonalEvent] 일정 삭제 성공: \(id)")
  }

  /// 개인 일정 조회
  public func getEvent(id: String) async throws -> PersonalEventModel? {
    let document = try await db.environmentCollection(collectionName).document(id).getDocument()
    return try documentSnapshotToEvent(document)
  }

  // MARK: - Query Operations

  /// 활성 일정 조회 (startAt >= now, 시간순)
  public func getActiveEvents(limit: Int) async throws -> [PersonalEventModel] {
    guard let currentUserId = Auth.auth().currentUser?.uid else {
      throw NSError(domain: "PersonalEventRemoteDataSource", code: 401, userInfo: [
        NSLocalizedDescriptionKey: "로그인이 필요합니다"
      ])
    }

    let query = db.environmentCollection(collectionName)
      .whereField("userId", isEqualTo: currentUserId)
      .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: Date()))
      .order(by: "startAt")
      .limit(to: limit)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try convertDocumentToEvent($0) }
  }

  /// 과거 일정 조회 (startAt < now, 최신순 정렬, 커서 기반 페이징)
  public func getPastEvents(limit: Int, lastStartAt: Date?) async throws -> [PersonalEventModel] {
    guard let currentUserId = Auth.auth().currentUser?.uid else {
      throw NSError(domain: "PersonalEventRemoteDataSource", code: 401, userInfo: [
        NSLocalizedDescriptionKey: "로그인이 필요합니다"
      ])
    }

    var query = db.environmentCollection(collectionName)
      .whereField("userId", isEqualTo: currentUserId)
      .whereField("startAt", isLessThan: Timestamp(date: Date()))
      .order(by: "startAt", descending: true)

    // 커서 기반 페이징: lastStartAt 이후 데이터만 조회
    if let lastStartAt = lastStartAt {
      query = query.start(after: [Timestamp(date: lastStartAt)])
    }

    query = query.limit(to: limit)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try convertDocumentToEvent($0) }
  }

  // MARK: - Real-time Listener

  /// 활성 일정 실시간 구독 (과거 일정 제외)
  public func subscribeToActiveEvents(limit: Int) -> AsyncStream<[PersonalEventModel]> {
    AppLogger.personal.debug("📅 [PersonalEvent] subscribeToActiveEvents 호출")

    return AsyncStream { continuation in
      guard let currentUserId = Auth.auth().currentUser?.uid else {
        AppLogger.personal.error("📅 [PersonalEvent] 로그인 필요")
        continuation.yield([])
        continuation.finish()
        return
      }

      AppLogger.personal.debug("📅 [PersonalEvent] AsyncStream 생성됨")

      let query = db.environmentCollection(collectionName)
        .whereField("userId", isEqualTo: currentUserId)
        .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: Date()))
        .order(by: "startAt")
        .limit(to: limit)

      AppLogger.personal.debug("📅 [PersonalEvent] Firestore 리스너 등록 중...")
      let listener = query.addSnapshotListener { [weak self] snapshot, error in
        guard let self = self else {
          AppLogger.personal.warning("📅 [PersonalEvent] self가 nil")
          continuation.yield([])
          return
        }

        if let error = error {
          AppLogger.personal.error("📅 [PersonalEvent] Listener error: \(error.localizedDescription)")
          continuation.yield([])
          return
        }

        guard let snapshot = snapshot else {
          AppLogger.personal.warning("📅 [PersonalEvent] snapshot이 nil")
          continuation.yield([])
          return
        }

        AppLogger.personal.debug("📅 [PersonalEvent] 스냅샷 수신: \(snapshot.documents.count)개 문서")
        let events = snapshot.documents.compactMap { doc -> PersonalEventModel? in
          do {
            let event = try convertDocumentToEvent(doc)
            return event
          } catch {
            AppLogger.personal.error("📅 [PersonalEvent] 파싱 에러: \(error)")
            return nil
          }
        }
        AppLogger.personal.debug("📅 [PersonalEvent] 파싱 완료: \(events.count)개 일정")

        continuation.yield(events)
      }

      continuation.onTermination = { _ in
        AppLogger.personal.debug("📅 [PersonalEvent] 리스너 종료")
        listener.remove()
      }
    }
  }

  // MARK: - Helper Methods

  private func documentSnapshotToEvent(_ document: DocumentSnapshot) throws -> PersonalEventModel? {
    guard document.exists else { return nil }
    let dto = try document.data(as: PersonalEventDTO.self)
    return PersonalEventModel(dto: dto, id: document.documentID)
  }
}

// MARK: - Document Conversion Helper

/// QueryDocumentSnapshot을 PersonalEventModel로 변환하는 헬퍼 함수
/// TaskGroup 내에서도 사용 가능하도록 file-private으로 정의
private func convertDocumentToEvent(_ document: QueryDocumentSnapshot) throws -> PersonalEventModel? {
  let dto = try document.data(as: PersonalEventDTO.self)
  return PersonalEventModel(dto: dto, id: document.documentID)
}
