import Shared
import FirebaseFunctions
import Foundation

public final class FirebaseGroupCreationGateway: GroupCreationGatewayProtocol {
  private let functions: Functions

  public init(functions: Functions = Functions.functions(region: "asia-northeast3")) {
    self.functions = functions
  }

  public func createGroup(
    name: String,
    maxMembers: Int,
    creatorId: String,
    photoPath: String?
  ) async throws -> (id: String, inviteCode: String) {
    var data: [String: Any] = [
      "name": name,
      "maxMembers": maxMembers,
    ]
    if let photoPath {
      data["photoPath"] = photoPath
    }

    let result = try await functions.httpsCallable("createGroup").call(data)
    guard let payload = result.data as? [String: Any] else {
      throw CreateGroupUseCaseError.invalidResponse
    }

    let id = (payload["id"] as? String) ?? (payload["groupId"] as? String)
    let inviteCode = payload["inviteCode"] as? String
    guard let id, let inviteCode else {
      throw CreateGroupUseCaseError.invalidResponse
    }

    return (id, inviteCode)
  }
}

