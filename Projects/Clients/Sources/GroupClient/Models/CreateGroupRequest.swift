import Foundation

/// 그룹 생성 요청
///
/// Firebase Functions의 createGroup과 매핑됩니다.
/// 생성자 정보(name, nickname 등)는 Functions에서 users 컬렉션을 조회하여 자동으로 처리됩니다.
public struct CreateGroupRequest: Equatable, Sendable {
  /// 그룹 이름 (최소 2글자)
  public let name: String

  /// 최대 인원 (2~10)
  public let maxMembers: Int

  /// 그룹 설명 (선택적)
  public let description: String?

  /// 생성자 ID (Firebase Auth UID)
  public let creatorId: String

  /// 그룹 이미지 데이터 (선택적, Storage 업로드용)
  public let photoData: Data?

  public init(
    name: String,
    maxMembers: Int,
    description: String? = nil,
    creatorId: String,
    photoData: Data? = nil
  ) {
    self.name = name
    self.maxMembers = maxMembers
    self.description = description
    self.creatorId = creatorId
    self.photoData = photoData
  }
}
