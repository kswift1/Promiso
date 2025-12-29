import Foundation
import ComposableArchitecture
import Shared
import XCTestDynamicOverlay

private struct UnimplementedGroupRepository: GroupRepositoryProtocol {
  func uploadGroupImage(creatorId: String, imageData: Data) async throws -> String {
    XCTFail("Unimplemented: GroupRepository.uploadGroupImage")
    return ""
  }

  func deleteImage(at path: String) async throws {
    XCTFail("Unimplemented: GroupRepository.deleteImage")
  }

  func createGroup(
    name: String,
    maxMembers: Int,
    creatorId: String,
    photoPath: String?
  ) async throws -> (id: String, inviteCode: String) {
    XCTFail("Unimplemented: GroupRepository.createGroup")
    return ("", "")
  }
}

private enum GroupRepositoryKey: DependencyKey {
  static let liveValue: any GroupRepositoryProtocol = UnimplementedGroupRepository()
  static let testValue: any GroupRepositoryProtocol = UnimplementedGroupRepository()
}

public extension DependencyValues {
  var groupRepository: any GroupRepositoryProtocol {
    get { self[GroupRepositoryKey.self] }
    set { self[GroupRepositoryKey.self] = newValue }
  }
}
