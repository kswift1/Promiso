import Foundation
import FirebaseFirestore
import Combine

/// Attendance 관련 Firestore 작업을 담당하는 Repository
public class AttendanceRepository {
  private let db = Firestore.firestore()
  
  // MARK: - CRUD Operations
  
  /// 참석 상태 생성
  public func createAttendance(
    _ attendance: AttendanceDocument,
    promiseId: String
  ) async throws {
    let ref = db.environmentCollection("promises")
      .document(promiseId)
      .collection("attendances")
      .document(attendance.userId)
    
    try await ref.setData(from: attendance)
  }
  
  /// 참석 상태 업데이트
  public func updateAttendance(
    promiseId: String,
    userId: String,
    status: AttendanceStatus,
    message: String? = nil
  ) async throws {
    let ref = db.environmentCollection("promises")
      .document(promiseId)
      .collection("attendances")
      .document(userId)
    
    var updateData: [String: Any] = [
      "status": status.rawValue,
      "respondedAt": Timestamp()
    ]
    
    if let message = message {
      updateData["message"] = message
    }
    
    try await ref.updateData(updateData)
  }
  
  /// 참석 상태 조회
  public func getAttendance(promiseId: String, userId: String) async throws -> AttendanceDocument? {
    let ref = db.environmentCollection("promises")
      .document(promiseId)
      .collection("attendances")
      .document(userId)
    
    let document = try await ref.getDocument()
    guard document.exists else { return nil }
    
    return try document.data(as: AttendanceDocument.self)
  }
  
  /// 약속의 모든 참석 상태 조회
  public func getAttendances(promiseId: String) async throws -> [AttendanceDocument] {
    let query = db.environmentCollection("promises")
      .document(promiseId)
      .collection("attendances")
      .order(by: "invitedAt")
    
    let snapshot = try await query.getDocuments()
    return try snapshot.documents.compactMap { document in
      try document.data(as: AttendanceDocument.self)
    }
  }
  
  // MARK: - Collection Group Queries
  
  /// 사용자가 참여한 약속 조회 (Collection Group)
  public func getUserPromises(
    userId: String,
    statuses: [AttendanceStatus] = [.accepted, .tentative],
    limit: Int = 20
  ) async throws -> [PromiseDocument] {
    let query = db.collectionGroup("attendances")
      .whereField("userId", isEqualTo: userId)
      .whereField("status", in: statuses.map { $0.rawValue })
      .order(by: "invitedAt", descending: true)
      .limit(to: limit)
    
    let snapshot = try await query.getDocuments()
    let promiseIds = Set(snapshot.documents.compactMap { $0.reference.parent.parent?.documentID })
    
    // 각 약속의 상세 정보 조회
    var promises: [PromiseDocument] = []
    for promiseId in promiseIds {
      if let promise = try await getPromiseById(promiseId) {
        promises.append(promise)
      }
    }
    
    return promises.sorted { $0.startAt.dateValue() < $1.startAt.dateValue() }
  }
  
  /// 사용자의 대기 중인 약속 조회
  public func getPendingPromises(userId: String, limit: Int = 20) async throws -> [PromiseDocument] {
    let query = db.collectionGroup("attendances")
      .whereField("userId", isEqualTo: userId)
      .whereField("status", isEqualTo: AttendanceStatus.pending.rawValue)
      .order(by: "invitedAt", descending: true)
      .limit(to: limit)
    
    let snapshot = try await query.getDocuments()
    let promiseIds = Set(snapshot.documents.compactMap { $0.reference.parent.parent?.documentID })
    
    var promises: [PromiseDocument] = []
    for promiseId in promiseIds {
      if let promise = try await getPromiseById(promiseId) {
        promises.append(promise)
      }
    }
    
    return promises.sorted { $0.startAt.dateValue() < $1.startAt.dateValue() }
  }
  
  // MARK: - Batch Operations
  
  /// 대량 초대 처리
  public func batchInviteUsers(
    promiseId: String,
    attendances: [AttendanceDocument]
  ) async throws {
    let batch = db.batch()
    
    for attendance in attendances {
      let ref = db.environmentCollection("promises")
        .document(promiseId)
        .collection("attendances")
        .document(attendance.userId)
      
      try batch.setData(from: attendance, forDocument: ref)
    }
    
    try await batch.commit()
  }
  
  /// 대량 참석 상태 업데이트
  public func batchUpdateAttendances(
    promiseId: String,
    updates: [(userId: String, status: AttendanceStatus, message: String?)]
  ) async throws {
    let batch = db.batch()
    
    for update in updates {
      let ref = db.environmentCollection("promises")
        .document(promiseId)
        .collection("attendances")
        .document(update.userId)
      
      var updateData: [String: Any] = [
        "status": update.status.rawValue,
        "respondedAt": Timestamp()
      ]
      
      if let message = update.message {
        updateData["message"] = message
      }
      
      batch.updateData(updateData, forDocument: ref)
    }
    
    try await batch.commit()
  }
  
  // MARK: - Real-time Listeners
  
  /// 약속의 참석 상태 실시간 리스너
  public func observeAttendances(promiseId: String) -> AnyPublisher<[AttendanceDocument], Error> {
    let query = db.environmentCollection("promises")
      .document(promiseId)
      .collection("attendances")
      .order(by: "invitedAt")
    
    return Publishers.FirestoreQuery(query: query)
      .map { snapshot in
        snapshot.documents.compactMap { document in
          try? document.data(as: AttendanceDocument.self)
        }
      }
      .eraseToAnyPublisher()
  }
  
  /// 사용자의 대기 중인 약속 실시간 리스너
  public func observePendingPromises(userId: String) -> AnyPublisher<[PromiseDocument], Error> {
    let query = db.collectionGroup("attendances")
      .whereField("userId", isEqualTo: userId)
      .whereField("status", isEqualTo: AttendanceStatus.pending.rawValue)
      .order(by: "invitedAt", descending: true)
    
    return Publishers.FirestoreQuery(query: query)
      .map { snapshot in
        let promiseIds = Set(snapshot.documents.compactMap { $0.reference.parent.parent?.documentID })
        return promiseIds.compactMap { promiseId in
          // 실제 구현에서는 캐시된 데이터를 사용하거나 별도 쿼리 필요
          nil
        }
      }
      .eraseToAnyPublisher()
  }
  
  // MARK: - Helper Methods
  
  private func getPromiseById(_ promiseId: String) async throws -> PromiseDocument? {
    let ref = db.environmentCollection("promises").document(promiseId)
    let document = try await ref.getDocument()
    
    guard document.exists else { return nil }
    return try document.data(as: PromiseDocument.self)
  }
  
  /// 참석 상태별 통계 조회
  public func getAttendanceStats(promiseId: String) async throws -> PromiseCounts {
    let attendances = try await getAttendances(promiseId: promiseId)
    
    let total = attendances.count
    let accepted = attendances.filter { $0.status == .accepted }.count
    let declined = attendances.filter { $0.status == .declined }.count
    let tentative = attendances.filter { $0.status == .tentative }.count
    
    return PromiseCounts(
      total: total,
      accepted: accepted,
      declined: declined,
      tentative: tentative
    )
  }
  
  /// 약속 확정 여부 확인
  public func checkPromiseConfirmation(promiseId: String) async throws -> Bool {
    let stats = try await getAttendanceStats(promiseId: promiseId)
    
    // 최소 참가자 수 확인을 위해 약속 정보도 필요
    guard let promise = try await getPromiseById(promiseId) else { return false }
    
    return stats.accepted >= promise.minimumParticipants
  }
}
