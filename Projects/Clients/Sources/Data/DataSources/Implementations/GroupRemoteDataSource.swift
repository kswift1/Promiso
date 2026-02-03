import Foundation
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage
import PromisoShared

/// 그룹 원격 데이터 소스 에러
public enum GroupRemoteDataSourceError: Error, LocalizedError {
  case invalidFunctionResponse
  case invalidRequestData
  case imageUploadFailed

  public var errorDescription: String? {
    switch self {
    case .invalidFunctionResponse:
      return "서버 응답이 올바르지 않아요. 잠시 후 다시 시도해주세요."
    case .invalidRequestData:
      return "요청 데이터가 올바르지 않아요."
    case .imageUploadFailed:
      return "그룹 사진 업로드에 실패했어요. 잠시 후 다시 시도해주세요."
    }
  }
}

/// Firebase Functions를 통한 그룹 데이터 관리
///
/// - GroupRemoteDataSource는 Clients 레이어에 속함
public final class GroupRemoteDataSource: GroupRemoteDataSourceProtocol, @unchecked Sendable {
  private let functions: Functions
  private let storage: Storage
  private let db: Firestore
  
  public init(
    functions: Functions = Functions.functions(region: "asia-northeast3"),
    storage: Storage = Storage.storage(),
    db: Firestore = Firestore.firestore()
  ) {
    self.functions = functions
    self.storage = storage
    self.db = db
  }
  
  /// 그룹 생성
  ///
  /// - Parameters:
  ///   - name: 그룹 이름
  ///   - maxMembers: 최대 인원 (2 이상)
  ///   - description: 그룹 설명 (선택적)
  ///   - creatorId: 생성자 ID (Firebase Auth UID)
  ///   - photoData: 그룹 이미지 데이터 (선택적)
  /// - Returns: GroupCreationResult
  /// - Throws: GroupRemoteDataSourceError
  ///
  /// Firebase Functions의 createGroup을 호출합니다.
  /// Functions에서 다음 작업을 수행합니다:
  /// 1. groups/{groupId} 생성 (memberIds: [creatorId] 포함)
  /// 2. users/{creatorId}.groups Map에 그룹 정보 추가
  public func createGroup(
    name: String,
    maxMembers: Int,
    description: String?,
    creatorId: String,
    photoData: Data?
  ) async throws -> GroupCreationResultModel {
    let groupId = UUID().uuidString
    let photoPath = "group_images/\(groupId)/main.jpg"

    // 1. 이미지 업로드 (선택적) - downloadURL 반환
    var imageUrl: String?
    if let photoData {
      imageUrl = try await uploadGroupImage(
        groupId: groupId,
        imageData: photoData
      )
    }

    // 2. Firebase Functions 호출
    do {
      var callableData: [String: Any] = [
        "groupId": groupId,
        "name": name,
        "maxMembers": maxMembers,
      ]

      if let description {
        callableData["description"] = description
      }

      if let imageUrl {
        callableData["imageUrl"] = imageUrl
      }

      let result = try await functions.httpsCallable("createGroup").call(callableData)

      guard let data = result.data as? [String: Any] else {
        throw GroupRemoteDataSourceError.invalidFunctionResponse
      }

      let id = data["id"] as? String
      let inviteCode = data["inviteCode"] as? String

      guard let id, let inviteCode else {
        throw GroupRemoteDataSourceError.invalidFunctionResponse
      }

      return GroupCreationResultModel(
        id: id,
        name: name,
        inviteCode: inviteCode
      )
    } catch {
      // 실패 시 업로드된 이미지 삭제
      if imageUrl != nil {
        try? await deleteImage(at: photoPath)
      }
      throw error
    }
  }
  
  
  /// 사용자가 속한 그룹 목록 조회
  /// Map 방식: users/{userId}.groups에서 groupId 목록을 가져온 후 상세 조회
  public func fetchGroups(userId: String) async throws -> [GroupModel] {
    let userDoc = try await db.environmentCollection("users")
      .document(userId)
      .getDocument()

    guard let data = userDoc.data(),
          let groupsMap = data["groups"] as? [String: [String: Any]] else {
      return []
    }

    let groupIds = Array(groupsMap.keys)
    guard !groupIds.isEmpty else { return [] }

    return try await fetchGroupsInParallel(ids: groupIds)
  }

  /// 그룹 ID 목록으로 상세 그룹 조회
  public func fetchGroupsByIds(ids: [String]) async throws -> [GroupModel] {
    guard !ids.isEmpty else { return [] }
    return try await fetchGroupsInParallel(ids: ids)
  }

  /// 단일 그룹 상세 조회
  public func fetchGroup(groupId: String) async throws -> GroupModel {
    let groupRef = db.environmentCollection("groups").document(groupId)
    let groupSnapshot = try await groupRef.getDocument()
    guard groupSnapshot.exists else {
      throw GroupRemoteDataSourceError.invalidFunctionResponse
    }

    let dto = try groupSnapshot.data(as: GroupDTO.self)
    return GroupModel(dto: dto, id: groupId)
  }

  private func fetchGroupsInParallel(ids: [String]) async throws -> [GroupModel] {
    try await withThrowingTaskGroup(of: GroupModel?.self) { group in
      for groupId in ids {
        group.addTask { [db] in
          let groupRef = db.environmentCollection("groups").document(groupId)
          let groupSnapshot = try await groupRef.getDocument()
          guard groupSnapshot.exists else { return nil }

          let dto = try groupSnapshot.data(as: GroupDTO.self)
          return GroupModel(dto: dto, id: groupId)
        }
      }

      var groups: [GroupModel] = []
      for try await groupModel in group {
        if let groupModel {
          groups.append(groupModel)
        }
      }

      return groups
    }
  }

  /// 네비게이션용 그룹 요약 목록 조회
  /// Map 방식으로 변경: N회 읽기 → 1회 읽기로 비용 절감
  public func fetchGroupSummaries(userId: String) async throws -> [UserGroupInfo] {
    let userDoc = try await db.environmentCollection("users")
      .document(userId)
      .getDocument()

    guard let data = userDoc.data(),
          let groupsMap = data["groups"] as? [String: [String: Any]] else {
      return []
    }

    return groupsMap.compactMap { (groupId, groupData) in
      UserGroupInfo(id: groupId, data: groupData)
    }
    .sorted { ($0.joinedAt ?? .distantPast) > ($1.joinedAt ?? .distantPast) }
  }

  /// 초대 코드로 그룹 미리보기
  ///
  /// - Parameters:
  ///   - inviteCode: 6자리 초대 코드
  /// - Returns: 그룹 정보
  /// - Throws: GroupRemoteDataSourceError
  ///
  /// Firebase Functions의 previewGroup을 호출합니다.
  /// 실제로 참여하지 않고 그룹 정보만 조회합니다.
  public func previewGroup(inviteCode: String) async throws -> GroupPreviewModel {
    let callableData: [String: Any] = [
      "inviteCode": inviteCode.uppercased()
    ]

    let result = try await functions.httpsCallable("previewGroup").call(callableData)

    guard let data = result.data as? [String: Any] else {
      throw GroupRemoteDataSourceError.invalidFunctionResponse
    }

    guard let groupId = data["groupId"] as? String,
          let groupName = data["groupName"] as? String,
          let maxMembers = data["maxMembers"] as? Int else {
      throw GroupRemoteDataSourceError.invalidFunctionResponse
    }

    let description = data["description"] as? String
    let imageUrl = data["imageUrl"] as? String
    let membersData = data["members"] as? [[String: Any]] ?? []
    let members = membersData.compactMap(parseMemberPreview(_:))

    // Functions 응답으로 GroupModel 생성 (Firestore 읽기 불필요)
    let group = GroupModel(
      id: groupId,
      name: groupName,
      description: description,
      imageUrl: imageUrl,
      memberIds: [], // 미리보기에선 불필요
      maxMembers: maxMembers,
      inviteCode: inviteCode.uppercased(),
      createdBy: "", // 미리보기에선 불필요
      createdAt: Date(),
      updatedAt: Date()
    )

    return GroupPreviewModel(group: group, members: members)
  }

  /// 초대 코드로 그룹 참여
  ///
  /// - Parameters:
  ///   - inviteCode: 6자리 초대 코드
  ///   - userId: 참여하려는 사용자 ID (Firebase Auth UID)
  /// - Returns: 참여한 그룹 정보
  /// - Throws: GroupRemoteDataSourceError
  ///
  /// Firebase Functions의 joinGroup을 호출합니다.
  /// Functions에서 다음 작업을 수행합니다:
  /// 1. inviteCode로 그룹 조회
  /// 2. memberIds 배열에 userId 추가 (arrayUnion)
  /// 3. users/{userId}.groups Map에 그룹 정보 추가
  public func joinGroup(inviteCode: String, userId: String) async throws -> GroupModel {
    let callableData: [String: Any] = [
      "inviteCode": inviteCode.uppercased(),
      "userId": userId
    ]

    let result = try await functions.httpsCallable("joinGroup").call(callableData)

    guard let data = result.data as? [String: Any] else {
      throw GroupRemoteDataSourceError.invalidFunctionResponse
    }

    guard let groupId = data["groupId"] as? String else {
      throw GroupRemoteDataSourceError.invalidFunctionResponse
    }

    // 그룹 상세 정보 조회
    return try await fetchGroup(groupId: groupId)
  }

  /// 그룹 나가기
  ///
  /// - Parameters:
  ///   - groupId: 나갈 그룹 ID
  /// - Throws: GroupRemoteDataSourceError
  ///
  /// Firebase Functions의 leaveGroup을 호출합니다.
  /// Functions에서 다음 작업을 수행합니다:
  /// 1. 호스트인지 확인 (호스트는 나갈 수 없음)
  /// 2. groups/{groupId}의 memberIds에서 userId 제거
  /// 3. users/{userId}/groups Map에서 해당 그룹 삭제
  public func leaveGroup(groupId: String) async throws {
    let callableData: [String: Any] = [
      "groupId": groupId
    ]

    _ = try await functions.httpsCallable("leaveGroup").call(callableData)
  }

  /// 그룹 삭제
  ///
  /// - Parameters:
  ///   - groupId: 삭제할 그룹 ID
  /// - Throws: GroupRemoteDataSourceError
  ///
  /// Firebase Functions의 deleteGroup을 호출합니다.
  /// Functions에서 다음 작업을 수행합니다:
  /// 1. 호스트인지 확인
  /// 2. groups/{groupId} 문서 삭제 (hard delete)
  /// 3. Storage의 그룹 이미지 삭제
  /// 4. 모든 멤버의 users/{userId}/groups Map에서 해당 그룹 삭제
  public func deleteGroup(groupId: String) async throws {
    let callableData: [String: Any] = [
      "groupId": groupId
    ]

    _ = try await functions.httpsCallable("deleteGroup").call(callableData)
  }

  /// 그룹 정보 수정 (설명/이미지/최대 인원)
  public func updateGroup(
    groupId: String,
    description: String?,
    maxMembers: Int?,
    photoData: Data?
  ) async throws -> GroupModel {
    var imageUrl: String?

    if let photoData {
      imageUrl = try await uploadGroupImage(
        groupId: groupId,
        imageData: photoData
      )
    }

    var callableData: [String: Any] = [
      "groupId": groupId
    ]

    let trimmedDescription = description?.trimmingCharacters(in: .whitespacesAndNewlines)
    if let trimmedDescription {
      callableData["description"] = trimmedDescription.isEmpty ? NSNull() : trimmedDescription
    }

    if let imageUrl {
      callableData["imageUrl"] = imageUrl
    }

    if let maxMembers {
      callableData["maxMembers"] = maxMembers
    }

    _ = try await functions.httpsCallable("updateGroup").call(callableData)
    return try await fetchGroup(groupId: groupId)
  }

  /// 그룹 알림 상세 설정 업데이트
  public func updateGroupNotificationSettings(
    groupId: String,
    userId: String,
    settings: GroupNotificationSettings
  ) async throws {
    let userRef = db.environmentCollection("users").document(userId)
    try await userRef.setData(
      [
        "groups": [
          groupId: [
            "notifications": settings.asDictionary,
            "notificationPreferences": FieldValue.delete()
          ]
        ]
      ],
      merge: true
    )
  }

  /// 그룹 배지 클리어 (Fire & Forget)
  ///
  /// - Parameters:
  ///   - groupId: 배지를 클리어할 그룹 ID
  ///
  /// Firebase Functions의 clearGroupBadge를 호출합니다.
  /// 실패해도 무시합니다 (다음 fetch 시 동기화).
  public func clearGroupBadge(groupId: String) async {
    let callableData: [String: Any] = [
      "groupId": groupId
    ]

    AppLogger.group.debug("[clearGroupBadge] Calling with groupId: \(groupId)")

    do {
      _ = try await functions.httpsCallable("clearGroupBadge").call(callableData)
      AppLogger.group.debug("[clearGroupBadge] Success for groupId: \(groupId)")
    } catch {
      AppLogger.group.error("[clearGroupBadge] Failed for groupId: \(groupId), error: \(error.localizedDescription)")
    }
  }

  /// 그룹 호스트 양도
  ///
  /// - Parameters:
  ///   - groupId: 그룹 ID
  ///   - newHostId: 새 호스트 사용자 ID
  ///
  /// Firebase Functions의 transferGroupHost를 호출합니다.
  public func transferHost(groupId: String, newHostId: String) async throws {
    let callableData: [String: Any] = [
      "groupId": groupId,
      "newHostId": newHostId
    ]

    AppLogger.group.debug("[transferHost] Calling with groupId: \(groupId), newHostId: \(newHostId)")

    do {
      _ = try await functions.httpsCallable("transferGroupHost").call(callableData)
      AppLogger.group.debug("[transferHost] Success for groupId: \(groupId)")
    } catch {
      AppLogger.group.error("[transferHost] Failed: \(error.localizedDescription)")
      throw error
    }
  }

  // MARK: - Image Upload
  
  /// 그룹 이미지 업로드 및 다운로드 URL 반환
  private func uploadGroupImage(
    groupId: String,
    imageData: Data
  ) async throws -> String {
    let uploadData = compressImageDataForUpload(imageData) ?? imageData
    let photoPath = "group_images/\(groupId)/main.jpg"
    let ref = storage.reference().child(photoPath)

    let metadata = StorageMetadata()
    metadata.contentType = "image/jpeg"

    do {
      _ = try await ref.putDataAsync(uploadData, metadata: metadata)
      let downloadURL = try await ref.downloadURL()
      return downloadURL.absoluteString
    } catch {
      throw GroupRemoteDataSourceError.imageUploadFailed
    }
  }
  
  /// 이미지 삭제
  private func deleteImage(at path: String) async throws {
    let ref = storage.reference().child(path)
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      ref.delete { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume(returning: ())
        }
      }
    }
  }

  private func parseMemberPreview(_ data: [String: Any]) -> UserPublicModel? {
    guard let userId = data["userId"] as? String else { return nil }
    let name = data["name"] as? String ?? ""
    let nickname = data["nickname"] as? String ?? name

    let profileImage: ProfileImage?
    if let remoteImage = parseRemoteImage(data["profileImage"]),
       remoteImage.type == .externalURL {
      profileImage = ProfileImage(url: remoteImage.url, thumbUrl: nil, updatedAt: Date())
    } else {
      profileImage = nil
    }

    return UserPublicModel(
      userId: userId,
      name: name,
      nickname: nickname,
      profile: profileImage,
      metadata: Metadata(createdAt: Date(), updatedAt: Date())
    )
  }

  private func parseRemoteImage(_ value: Any?) -> RemoteImage? {
    guard let payload = value as? [String: Any],
          let type = payload["type"] as? String,
          let url = payload["url"] as? String else {
      return nil
    }

    guard let sourceType = RemoteImage.SourceType(rawValue: type) else {
      return nil
    }

    return RemoteImage(type: sourceType, url: url)
  }
}

// MARK: - UserGroupInfo Mapping

private extension UserGroupInfo {
  init?(id: String, data: [String: Any]) {
    let groupName = data["groupName"] as? String ?? ""
    let trimmedName = groupName.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedName.isEmpty else { return nil }

    let roleString = data["role"] as? String
    let role = roleString.flatMap { GroupRole(rawValue: $0) }
    let notifications = parseNotificationSettings(
      value: data["notifications"],
      legacyPreferences: data["notificationPreferences"]
    )
    let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue()
    let hasNewActivity = data["hasNewActivity"] as? Bool ?? false
    let imageUrl = data["imageUrl"] as? String

    self.init(
      id: id,
      name: trimmedName,
      role: role,
      joinedAt: joinedAt,
      notifications: notifications,
      hasNewActivity: hasNewActivity,
      imageUrl: imageUrl
    )
  }
}

private func parseNotificationSettings(
  value: Any?,
  legacyPreferences: Any?
) -> GroupNotificationSettings? {
  if let legacyEnabled = value as? Bool {
    let legacyMap = legacyPreferences as? [String: Bool]
    return GroupNotificationPreferences.fromLegacy(
      enabled: legacyEnabled,
      preferences: legacyMap
    )
  }

  guard let map = value as? [String: Any] else { return nil }
  let enabled = map["enabled"] as? Bool ?? true
  let promise = parseNotificationMap(map["promise"])
  let group = parseNotificationMap(map["group"])
  let calendarSync = map["calendarSync"] as? Bool ?? true
  return GroupNotificationSettings(
    enabled: enabled,
    promise: promise,
    group: group,
    calendarSync: calendarSync
  )
}

private func parseNotificationMap(_ value: Any?) -> [String: Bool] {
  if let map = value as? [String: Bool] {
    return map
  }
  guard let map = value as? [String: Any] else { return [:] }
  return map.compactMapValues { $0 as? Bool }
}

// MARK: - StorageReference Extension

private extension StorageReference {
  func putDataAsync(_ data: Data, metadata: StorageMetadata?) async throws -> StorageMetadata {
    try await withCheckedThrowingContinuation { continuation in
      putData(data, metadata: metadata) { metadata, error in
        if let error {
          continuation.resume(throwing: error)
        } else if let metadata {
          continuation.resume(returning: metadata)
        } else {
          continuation.resume(throwing: GroupRemoteDataSourceError.imageUploadFailed)
        }
      }
    }
  }
}
