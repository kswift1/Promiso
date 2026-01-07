import Foundation
import FirebaseFirestore
import Combine

import PromisoShared

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
  
  /// 약속 투표 캐시 일관성 검증
  /// votes Map 방식에서는 단일 문서에 투표 정보가 저장되므로 별도 검증 불필요
  public func validatePromiseVotesCache(promiseId: String) async throws -> Bool {
    // votes Map은 약속 문서 내에 저장되므로
    // 문서를 읽으면 항상 최신 상태를 얻음
    guard let cachedPromise = getCache(PromiseDTO.self, forKey: "promise_\(promiseId)") else {
      return false
    }

    // Firestore에서 최신 정보 조회
    let ref = db.environmentCollection("promises").document(promiseId)
    let document = try await ref.getDocument()

    guard document.exists,
          let latestPromise = try? document.data(as: PromiseDTO.self) else {
      return false
    }

    // 투표 상태 비교
    let isConsistent = cachedPromise.votes.accepted == latestPromise.votes.accepted &&
                      cachedPromise.votes.declined == latestPromise.votes.declined

    if !isConsistent {
      // 캐시 업데이트
      setCache(latestPromise, forKey: "promise_\(promiseId)")
    }

    return isConsistent
  }
  
  // MARK: - Private Helpers

  /// 그룹 이름 변경 시 캐시 무효화
  /// votes Map 방식에서는 hostName/groupName을 저장하지 않으므로
  /// 캐시된 그룹 정보만 업데이트하면 됨
  private func updateGroupNameInRelatedData(groupId: String, newName: String) async throws {
    // 그룹 캐시 업데이트는 validateGroupNameCache에서 이미 처리됨
    // 약속 문서에는 groupName이 저장되지 않으므로 추가 작업 불필요
  }
  
  // MARK: - Cache Warming
  
  /// 자주 사용되는 데이터 캐시 워밍
//  public func warmCache(for userId: String) async throws {
//    // 사용자 정보 캐시
//    let userRef = db.environmentCollection("users").document(userId)
//    let userDoc = try await userRef.getDocument()
//    if let user = try? userDoc.data(as: UserDocument.self) {
//      setCache(user, forKey: "user_\(userId)")
//    }
//    
//    // 사용자가 속한 그룹들 캐시
//    let groupsQuery = db.environmentCollection("users")
//      .document(userId)
//      .collection("groups")
//      .whereField("isDeleted", isEqualTo: false)
//    
//    let groupsSnapshot = try await groupsQuery.getDocuments()
//    for document in groupsSnapshot.documents {
//      if let group = try? document.data(as: GroupDocument.self) {
//        setCache(group, forKey: "group_\(document.documentID)")
//      }
//    }
//    
//    // 사용자의 대기 중인 약속들 캐시
//    let pendingQuery = db.collectionGroup("attendances")
//      .whereField("userId", isEqualTo: userId)
//      .whereField("status", isEqualTo: AttendanceStatus.pending.rawValue)
//      .limit(to: 20)
//    
//    let pendingSnapshot = try await pendingQuery.getDocuments()
//    for document in pendingSnapshot.documents {
//      if let attendance = try? document.data(as: AttendanceDocument.self) {
//        setCache(attendance, forKey: "attendance_\(document.documentID)")
//      }
//    }
//  }
  
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
