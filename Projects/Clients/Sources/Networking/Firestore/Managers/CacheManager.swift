import Foundation
import FirebaseFirestore
import Combine

import Shared

/// Firestore 캐시 일관성 검증 및 관리
public class CacheManager {
  private let db = Firestore.firestore()
  private var cache: [String: Any] = [:]
  private let cacheQueue = DispatchQueue(label: "cache.queue", attributes: .concurrent)
  
  // MARK: - Cache Operations
  
  /// 캐시에 데이터 저장
  public func setCache<T: Codable>(_ data: T, forKey key: String) {
    cacheQueue.async(flags: .barrier) {
      self.cache[key] = data
    }
  }
  
  /// 캐시에서 데이터 조회
  public func getCache<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
    return cacheQueue.sync {
      return cache[key] as? T
    }
  }
  
  /// 캐시에서 데이터 제거
  public func removeCache(forKey key: String) {
    cacheQueue.async(flags: .barrier) {
      self.cache.removeValue(forKey: key)
    }
  }
  
  /// 모든 캐시 제거
  public func clearCache() {
    cacheQueue.async(flags: .barrier) {
      self.cache.removeAll()
    }
  }
  
  // MARK: - Cache Consistency Validation
  
  /// 사용자 이름 캐시 일관성 검증
  public func validateUserNameCache(userId: String) async throws -> Bool {
    // 캐시된 사용자 정보 조회
    guard let cachedUser = getCache(UserDocument.self, forKey: "user_\(userId)") else {
      return false
    }
    
    // Firestore에서 최신 사용자 정보 조회
    let ref = db.environmentCollection("users").document(userId)
    let document = try await ref.getDocument()
    
    guard document.exists,
          let latestUser = try? document.data(as: UserDocument.self) else {
      return false
    }
    
    // 이름이 변경되었는지 확인
    let isConsistent = cachedUser.name == latestUser.name
    
    if !isConsistent {
      // 캐시 업데이트
      setCache(latestUser, forKey: "user_\(userId)")
      
      // 관련된 모든 캐시된 데이터에서 사용자 이름 업데이트
      try await updateUserNameInRelatedData(userId: userId, newName: latestUser.name)
    }
    
    return isConsistent
  }
  
  /// 그룹 이름 캐시 일관성 검증
  public func validateGroupNameCache(groupId: String) async throws -> Bool {
    // 캐시된 그룹 정보 조회
    guard let cachedGroup = getCache(GroupDocument.self, forKey: "group_\(groupId)") else {
      return false
    }
    
    // Firestore에서 최신 그룹 정보 조회
    let ref = db.environmentCollection("groups").document(groupId)
    let document = try await ref.getDocument()
    
    guard document.exists,
          let latestGroup = try? document.data(as: GroupDocument.self) else {
      return false
    }
    
    // 이름이 변경되었는지 확인
    let isConsistent = cachedGroup.name == latestGroup.name
    
    if !isConsistent {
      // 캐시 업데이트
      setCache(latestGroup, forKey: "group_\(groupId)")
      
      // 관련된 모든 캐시된 데이터에서 그룹 이름 업데이트
      try await updateGroupNameInRelatedData(groupId: groupId, newName: latestGroup.name)
    }
    
    return isConsistent
  }
  
  /// 약속 카운터 캐시 일관성 검증
  public func validatePromiseCountsCache(promiseId: String) async throws -> Bool {
    // 캐시된 약속 정보 조회
    guard let cachedPromise = getCache(PromiseDocument.self, forKey: "promise_\(promiseId)") else {
      return false
    }
    
    // 실제 참석 데이터로부터 카운터 계산
    let actualCounts = try await calculateActualCounts(promiseId: promiseId)
    
    // 카운터가 일치하는지 확인
    let isConsistent = cachedPromise.counts.accepted == actualCounts.accepted &&
                      cachedPromise.counts.declined == actualCounts.declined &&
                      cachedPromise.counts.tentative == actualCounts.tentative &&
                      cachedPromise.counts.total == actualCounts.total
    
    if !isConsistent {
      // 약속 문서의 카운터 업데이트 (Cloud Function에서 처리해야 함)
      print("⚠️ Promise counts inconsistency detected for promise \(promiseId)")
      print("Cached: \(cachedPromise.counts)")
      print("Actual: \(actualCounts)")
    }
    
    return isConsistent
  }
  
  // MARK: - Batch Cache Updates
  
  /// 사용자 이름 변경 시 관련 데이터 업데이트
  private func updateUserNameInRelatedData(userId: String, newName: String) async throws {
    // 약속의 hostName 업데이트
    let promisesQuery = db.environmentCollection("promises")
      .whereField("hostId", isEqualTo: userId)
      .whereField("isDeleted", isEqualTo: false)
    
    let promisesSnapshot = try await promisesQuery.getDocuments()
    
    let batch = db.batch()
    for document in promisesSnapshot.documents {
      batch.updateData(["hostName": newName], forDocument: document.reference)
    }
    
    if !promisesSnapshot.documents.isEmpty {
      try await batch.commit()
    }
    
    // 참석 데이터의 userName 업데이트
    let attendancesQuery = db.collectionGroup("attendances")
      .whereField("userId", isEqualTo: userId)
    
    let attendancesSnapshot = try await attendancesQuery.getDocuments()
    
    let attendanceBatch = db.batch()
    for document in attendancesSnapshot.documents {
      attendanceBatch.updateData(["userName": newName], forDocument: document.reference)
    }
    
    if !attendancesSnapshot.documents.isEmpty {
      try await attendanceBatch.commit()
    }
  }
  
  /// 그룹 이름 변경 시 관련 데이터 업데이트
  private func updateGroupNameInRelatedData(groupId: String, newName: String) async throws {
    // 약속의 groupName 업데이트
    let promisesQuery = db.environmentCollection("promises")
      .whereField("groupId", isEqualTo: groupId)
      .whereField("isDeleted", isEqualTo: false)
    
    let promisesSnapshot = try await promisesQuery.getDocuments()
    
    let batch = db.batch()
    for document in promisesSnapshot.documents {
      batch.updateData(["groupName": newName], forDocument: document.reference)
    }
    
    if !promisesSnapshot.documents.isEmpty {
      try await batch.commit()
    }
  }
  
  /// 실제 참석 데이터로부터 카운터 계산
  private func calculateActualCounts(promiseId: String) async throws -> PromiseCounts {
    let attendancesQuery = db.environmentCollection("promises")
      .document(promiseId)
      .collection("attendances")
    
    let snapshot = try await attendancesQuery.getDocuments()
    let attendances = try snapshot.documents.compactMap { document in
      try document.data(as: AttendanceDocument.self)
    }
    
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
  
  // MARK: - Cache Warming
  
  /// 자주 사용되는 데이터 캐시 워밍
  public func warmCache(for userId: String) async throws {
    // 사용자 정보 캐시
    let userRef = db.environmentCollection("users").document(userId)
    let userDoc = try await userRef.getDocument()
    if let user = try? userDoc.data(as: UserDocument.self) {
      setCache(user, forKey: "user_\(userId)")
    }
    
    // 사용자가 속한 그룹들 캐시
    let groupsQuery = db.environmentCollection("users")
      .document(userId)
      .collection("groups")
      .whereField("isDeleted", isEqualTo: false)
    
    let groupsSnapshot = try await groupsQuery.getDocuments()
    for document in groupsSnapshot.documents {
      if let group = try? document.data(as: GroupDocument.self) {
        setCache(group, forKey: "group_\(document.documentID)")
      }
    }
    
    // 사용자의 대기 중인 약속들 캐시
    let pendingQuery = db.collectionGroup("attendances")
      .whereField("userId", isEqualTo: userId)
      .whereField("status", isEqualTo: AttendanceStatus.pending.rawValue)
      .limit(to: 20)
    
    let pendingSnapshot = try await pendingQuery.getDocuments()
    for document in pendingSnapshot.documents {
      if let attendance = try? document.data(as: AttendanceDocument.self) {
        setCache(attendance, forKey: "attendance_\(document.documentID)")
      }
    }
  }
  
  // MARK: - Cache Statistics
  
  /// 캐시 통계 조회
  public func getCacheStatistics() -> CacheStatistics {
    return cacheQueue.sync {
      let totalItems = cache.count
      let memoryUsage = cache.reduce(0) { total, item in
        total + MemoryLayout.size(ofValue: item.value)
      }
      
      return CacheStatistics(
        totalItems: totalItems,
        memoryUsageBytes: memoryUsage,
        keys: Array(cache.keys)
      )
    }
  }
}

// MARK: - Cache Statistics Model
public struct CacheStatistics {
  public let totalItems: Int
  public let memoryUsageBytes: Int
  public let keys: [String]
  
  public var memoryUsageMB: Double {
    return Double(memoryUsageBytes) / (1024 * 1024)
  }
}
