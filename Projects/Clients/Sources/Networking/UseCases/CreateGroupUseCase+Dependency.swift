import Dependencies
import Shared
import XCTestDynamicOverlay

//public extension DependencyValues {
//  var createGroupUseCase: any CreateGroupUseCaseProtocol {
//    get { self[CreateGroupUseCaseKey.self] }
//    set { self[CreateGroupUseCaseKey.self] = newValue }
//  }
//}
//
//private enum CreateGroupUseCaseKey: DependencyKey {
//  static var liveValue: any CreateGroupUseCaseProtocol {
//    @Dependency(\.groupRemoteDataSource) var dataSource
//    return DefaultCreateGroupUseCase(
//      imageUploader: dataSource,
//      gateway: dataSource
//    )
//  }
//
//  static let testValue: any CreateGroupUseCaseProtocol = UnimplementedCreateGroupUseCase()
//}
//
//private struct UnimplementedCreateGroupUseCase: CreateGroupUseCaseProtocol {
//  func execute(_ input: CreateGroupUseCaseInput) async throws -> CreateGroupUseCaseOutput {
//    XCTFail("Unimplemented: CreateGroupUseCase.execute")
//    return CreateGroupUseCaseOutput(id: "", inviteCode: "", photoPath: nil)
//  }
//}

