import Foundation
import FirebaseAuth
import FirebaseFirestore
import PromisoShared

/// PersonalEvent 관련 Firestore CRUD 및 쿼리 작업을 담당하는 DataSource
/// 경로: users/{userId}/personalEvents/{eventId}
public actor PersonalEventRemoteDataSource: PersonalEventRemoteDataSourceProtocol {
  private let firestore: FirestoreProviding
  private let subcollectionName: String
  private var db: Firestore { firestore.db }

  public init(
    firestore: FirestoreProviding = DefaultFirestoreProvider(),
    subcollectionName: String = "personalEvents"
  ) {
    self.firestore = firestore
    self.subcollectionName = subcollectionName
  }

  // MARK: - Helper

  /// 현재 사용자의 personalEvents 서브컬렉션 참조
  private func eventsCollection() throws -> CollectionReference {
    guard let currentUserId = Auth.auth().currentUser?.uid else {
      throw NSError(domain: "PersonalEventRemoteDataSource", code: 401, userInfo: [
        NSLocalizedDescriptionKey: "로그인이 필요합니다"
      ])
    }
    return db.environmentCollection("users")
      .document(currentUserId)
      .collection(subcollectionName)
  }

  // MARK: - CRUD Operations

  /// 개인 일정 생성
  public func createEvent(_ event: PersonalEventModel) async throws -> String {
    let collection = try eventsCollection()
    let dto = PersonalEventDTO(model: event)
    let docRef = collection.document()

    try docRef.setData(from: dto)
    AppLogger.personal.info("📅 [PersonalEvent] 일정 생성 성공: \(docRef.documentID)")

    return docRef.documentID
  }

  /// 개인 일정 업데이트
  public func updateEvent(_ event: PersonalEventModel) async throws {
    let collection = try eventsCollection()

    var updatedEvent = event
    updatedEvent.updatedAt = Date()
    let dto = PersonalEventDTO(model: updatedEvent)

    try collection.document(event.id).setData(from: dto)
    AppLogger.personal.info("📅 [PersonalEvent] 일정 업데이트 성공: \(event.id)")
  }

  /// 개인 일정 삭제
  public func deleteEvent(id: String) async throws {
    let collection = try eventsCollection()
    try await collection.document(id).delete()
    AppLogger.personal.info("📅 [PersonalEvent] 일정 삭제 성공: \(id)")
  }

  /// 개인 일정 조회
  public func getEvent(id: String) async throws -> PersonalEventModel? {
    let collection = try eventsCollection()
    let document = try await collection.document(id).getDocument()
    return try documentSnapshotToEvent(document)
  }

  // MARK: - Query Operations

  /// 활성 일정 조회 (오늘 시작 이후, 시간순)
  public func getActiveEvents(limit: Int) async throws -> [PersonalEventModel] {
    let collection = try eventsCollection()
    let startOfToday = Calendar.current.startOfDay(for: Date())

    let query = collection
      .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startOfToday))
      .order(by: "startAt")
      .limit(to: limit)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try convertDocumentToEvent($0) }
  }

  /// 과거 일정 조회 (startAt < 오늘 00:00, 최신순 정렬, 커서 기반 페이징)
  public func getPastEvents(limit: Int, lastStartAt: Date?) async throws -> [PersonalEventModel] {
    let collection = try eventsCollection()
    let startOfToday = Calendar.current.startOfDay(for: Date())

    var query = collection
      .whereField("startAt", isLessThan: Timestamp(date: startOfToday))
      .order(by: "startAt", descending: true)

    // 커서 기반 페이징: lastStartAt 이후 데이터만 조회
    if let lastStartAt = lastStartAt {
      query = query.start(after: [Timestamp(date: lastStartAt)])
    }

    query = query.limit(to: limit)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try convertDocumentToEvent($0) }
      .filter { $0.isPast }
  }

  /// 진행 중인 일정 조회 (startAt < 오늘이지만 endAt >= 오늘인 일정)
  public func getOngoingEvents(limit: Int) async throws -> [PersonalEventModel] {
    let collection = try eventsCollection()
    let startOfToday = Calendar.current.startOfDay(for: Date())

    let query = collection
      .whereField("endAt", isGreaterThanOrEqualTo: Timestamp(date: startOfToday))
      .order(by: "endAt")
      .limit(to: limit)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try convertDocumentToEvent($0) }
      .filter { $0.isOngoing }
  }

  /// 날짜 범위로 개인 일정 조회 (일정 충돌 감지용)
  public func getEventsByDateRange(startDate: Date, endDate: Date) async throws -> [PersonalEventModel] {
    let collection = try eventsCollection()

    let query = collection
      .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startDate))
      .whereField("startAt", isLessThan: Timestamp(date: endDate))
      .order(by: "startAt")
      .limit(to: 50)

    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { try convertDocumentToEvent($0) }
  }

  // MARK: - Real-time Listener

  /// 활성 일정 실시간 구독 (과거 일정 제외)
  public func subscribeToActiveEvents(limit: Int) async -> AsyncStream<[PersonalEventModel]> {
    AppLogger.personal.debug("📅 [PersonalEvent] subscribeToActiveEvents 호출")

    return AsyncStream { continuation in
      guard let currentUserId = Auth.auth().currentUser?.uid else {
        AppLogger.personal.error("📅 [PersonalEvent] 로그인 필요")
        continuation.yield([])
        continuation.finish()
        return
      }

      AppLogger.personal.debug("📅 [PersonalEvent] AsyncStream 생성됨")

      let collection = db.environmentCollection("users")
        .document(currentUserId)
        .collection(subcollectionName)

      let startOfToday = Calendar.current.startOfDay(for: Date())
      let query = collection
        .whereField("startAt", isGreaterThanOrEqualTo: Timestamp(date: startOfToday))
        .order(by: "startAt")
        .limit(to: limit)

      AppLogger.personal.debug("📅 [PersonalEvent] Firestore 리스너 등록 중...")
      let listener = query.addSnapshotListener { snapshot, error in
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
private func convertDocumentToEvent(_ document: QueryDocumentSnapshot) throws -> PersonalEventModel? {
  let dto = try document.data(as: PersonalEventDTO.self)
  return PersonalEventModel(dto: dto, id: document.documentID)
}
