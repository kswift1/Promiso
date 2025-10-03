import Foundation
import Domain

/// 그룹 관련 Repository (현재는 Mock 구현)
public class GroupRepository: GroupRepositoryProtocol {
  
  public init() {}
  
  // MARK: - CRUD Operations
  
  /// 그룹 생성
  public func createGroup(_ group: Group) async throws -> String {
    try await Task.sleep(for: .seconds(1))
    return UUID().uuidString
  }
  
  /// 그룹 업데이트
  public func updateGroup(_ group: Group) async throws {
    try await Task.sleep(for: .seconds(1))
  }
  
  /// 그룹 삭제 (soft delete)
  public func deleteGroup(id: String) async throws {
    try await Task.sleep(for: .seconds(0.5))
  }
  
  /// 그룹 조회
  public func getGroup(id: String) async throws -> Group? {
    try await Task.sleep(for: .seconds(0.5))
    return nil
  }
  
  // MARK: - Query Operations
  
  /// 사용자의 그룹 목록 조회
  public func getUserGroups(userId: String) async throws -> [Group] {
    try await Task.sleep(for: .seconds(1))
    return [
      Group(id: "g1", name: "지민과 나", memberCount: 2),
      Group(id: "g2", name: "회사 동료들", memberCount: 8),
      Group(id: "g3", name: "대학 친구들", memberCount: 12),
      Group(id: "g4", name: "가족", memberCount: 4)
    ]
  }
  
  /// 그룹 검색
  public func searchGroups(query: String) async throws -> [Group] {
    try await Task.sleep(for: .seconds(1))
    return []
  }
  
  /// 공개 그룹 목록 조회
  public func getPublicGroups(limit: Int) async throws -> [Group] {
    try await Task.sleep(for: .seconds(1))
    return []
  }
}
