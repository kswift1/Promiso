import Foundation
import FirebaseFirestore

/// 대량 작업 처리를 위한 Manager
public class BatchOperationManager {
  private let db = Firestore.firestore()
  private let maxBatchSize = 500 // Firestore 배치 제한
  
  // MARK: - Batch Operations
  
  /// 대량 사용자 초대 처리
  public func batchInviteUsers(
    promiseId: String,
    attendances: [AttendanceDocument]
  ) async throws {
    let batches = attendances.chunked(into: maxBatchSize)
    
    for batch in batches {
      try await processBatchInvite(promiseId: promiseId, attendances: batch)
    }
  }
  
  /// 대량 참석 상태 업데이트
  public func batchUpdateAttendances(
    promiseId: String,
    updates: [(userId: String, status: AttendanceStatus, message: String?)]
  ) async throws {
    let batches = updates.chunked(into: maxBatchSize)
    
    for batch in batches {
      try await processBatchUpdate(promiseId: promiseId, updates: batch)
    }
  }
  
  /// 대량 그룹 멤버 추가
  public func batchAddGroupMembers(
    groupId: String,
    members: [(userId: String, userName: String, profileImageUrl: String?)]
  ) async throws {
    let batches = members.chunked(into: maxBatchSize)
    
    for batch in batches {
      try await processBatchAddMembers(groupId: groupId, members: batch)
    }
  }
  
  /// 대량 알림 발송
  public func batchSendNotifications(
    notifications: [NotificationDocument]
  ) async throws {
    let batches = notifications.chunked(into: maxBatchSize)
    
    for batch in batches {
      try await processBatchNotifications(notifications: batch)
    }
  }
  
  // MARK: - Private Batch Processors
  
  private func processBatchInvite(
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
  
  private func processBatchUpdate(
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
  
  private func processBatchAddMembers(
    groupId: String,
    members: [(userId: String, userName: String, profileImageUrl: String?)]
  ) async throws {
    let batch = db.batch()
    
    for member in members {
      let ref = db.environmentCollection("groups")
        .document(groupId)
        .collection("members")
        .document(member.userId)
      
      let memberData: [String: Any] = [
        "userId": member.userId,
        "userName": member.userName,
        "profileImageUrl": member.profileImageUrl as Any,
        "joinedAt": Timestamp(),
        "role": "member"
      ]
      
      batch.setData(memberData, forDocument: ref)
    }
    
    try await batch.commit()
  }
  
  private func processBatchNotifications(
    notifications: [NotificationDocument]
  ) async throws {
    let batch = db.batch()
    
    for notification in notifications {
      let ref = db.environmentCollection("notifications").document()
      try batch.setData(from: notification, forDocument: ref)
    }
    
    try await batch.commit()
  }
  
  // MARK: - Transaction Operations
  
  /// 트랜잭션을 사용한 약속 확정 처리
  public func confirmPromiseWithTransaction(promiseId: String) async throws {
    // TODO: Firebase Transaction API 호환성 문제로 임시 비활성화
    // Firebase SDK 버전에 따른 Transaction API 변경으로 인한 문제
    // 추후 Firebase SDK 업데이트 시 다시 구현 필요
    throw NSError(domain: "NotImplemented", code: 501, userInfo: [NSLocalizedDescriptionKey: "Transaction operations temporarily disabled"])
  }
  
  /// 트랜잭션을 사용한 카운터 업데이트
  public func updateCountsWithTransaction(promiseId: String) async throws {
    // TODO: Firebase Transaction API 호환성 문제로 임시 비활성화
    // Firebase SDK 버전에 따른 Transaction API 변경으로 인한 문제
    // 추후 Firebase SDK 업데이트 시 다시 구현 필요
    throw NSError(domain: "NotImplemented", code: 501, userInfo: [NSLocalizedDescriptionKey: "Transaction operations temporarily disabled"])
  }
  
  // MARK: - Retry Logic
  
  /// 재시도 로직이 포함된 배치 작업
  public func batchOperationWithRetry<T>(
    operation: @escaping () async throws -> T,
    maxRetries: Int = 3,
    delay: TimeInterval = 1.0
  ) async throws -> T {
    var lastError: Error?
    
    for attempt in 1...maxRetries {
      do {
        return try await operation()
      } catch {
        lastError = error
        print("⚠️ Batch operation failed (attempt \(attempt)/\(maxRetries)): \(error)")
        
        if attempt < maxRetries {
          try await Task.sleep(nanoseconds: UInt64(delay * Double(attempt) * 1_000_000_000))
        }
      }
    }
    
    throw lastError ?? NSError(domain: "BatchOperationFailed", code: 500, userInfo: nil)
  }
  
  // MARK: - Progress Tracking
  
  /// 진행률 추적이 포함된 대량 작업
  public func batchOperationWithProgress<T>(
    items: [T],
    operation: @escaping ([T]) async throws -> Void,
    progressHandler: @escaping (Double) -> Void
  ) async throws {
    let batches = items.chunked(into: maxBatchSize)
    let totalBatches = batches.count
    
    for (index, batch) in batches.enumerated() {
      try await operation(batch)
      
      let progress = Double(index + 1) / Double(totalBatches)
      progressHandler(progress)
    }
  }
}

// MARK: - Array Extension for Chunking
extension Array {
  func chunked(into size: Int) -> [[Element]] {
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0..<Swift.min($0 + size, count)])
    }
  }
}
