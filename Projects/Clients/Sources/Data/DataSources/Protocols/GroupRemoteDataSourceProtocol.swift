import Foundation

// MARK: - Group Remote Data Source Protocol

public protocol GroupRemoteDataSourceProtocol {
  // MARK: - CRUD Operations

  /// 그룹 생성
  func createGroup(
    name: String,
    maxMembers: Int,
    description: String?,
    creatorId: String,
    photoData: Data?
  ) async throws -> GroupCreationResultModel

  /// 단일 그룹 상세 조회
  func fetchGroup(groupId: String) async throws -> GroupModel

  /// 그룹 나가기
  func leaveGroup(groupId: String) async throws

  /// 그룹 삭제
  func deleteGroup(groupId: String) async throws

  /// 그룹 정보 수정 (설명/이미지/최대 인원)
  func updateGroup(
    groupId: String,
    description: String?,
    maxMembers: Int?,
    photoData: Data?
  ) async throws -> GroupModel

  // MARK: - Query Operations

  /// 사용자가 속한 그룹 목록 조회
  func fetchGroups(userId: String) async throws -> [GroupModel]

  /// 그룹 ID 목록으로 상세 그룹 조회
  func fetchGroupsByIds(ids: [String]) async throws -> [GroupModel]

  /// 네비게이션용 그룹 요약 목록 조회
  func fetchGroupSummaries(userId: String) async throws -> [UserGroupInfo]

  // MARK: - Invite Operations

  /// 초대 코드로 그룹 미리보기
  func previewGroup(inviteCode: String) async throws -> GroupPreviewModel

  /// 초대 코드로 그룹 참여
  func joinGroup(inviteCode: String, userId: String) async throws -> GroupModel

  // MARK: - Badge Operations

  /// 그룹 배지 클리어 (Fire & Forget)
  func clearGroupBadge(groupId: String) async
}
