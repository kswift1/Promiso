import Foundation
import Dependencies
import CoreDependencies
import CoreNetworking
import CoreLogger
import SharedModels

// MARK: - Promise Request Models

/// 약속 생성 요청
//public struct CreatePromiseRequest: Codable {
//  public let title: String
//  public let description: String?
//  public let groupId: UUID?
//  public let scheduledAt: Date
//  public let location: PromiseLocation?
//  public let settings: PromiseSettings
//  public let visibility: PromiseVisibility
//  
//  public init(
//    title: String,
//    description: String? = nil,
//    groupId: UUID? = nil,
//    scheduledAt: Date,
//    location: PromiseLocation? = nil,
//    settings: PromiseSettings = PromiseSettings(),
//    visibility: PromiseVisibility = .group
//  ) {
//    self.title = title
//    self.description = description
//    self.groupId = groupId
//    self.scheduledAt = scheduledAt
//    self.location = location
//    self.settings = settings
//    self.visibility = visibility
//  }
//}
//
///// 약속 업데이트 요청
//public struct UpdatePromiseRequest: Codable {
//  public let title: String?
//  public let description: String?
//  public let scheduledAt: Date?
//  public let location: PromiseLocation?
//  public let settings: PromiseSettings?
//  
//  public init(
//    title: String? = nil,
//    description: String? = nil,
//    scheduledAt: Date? = nil,
//    location: PromiseLocation? = nil,
//    settings: PromiseSettings? = nil
//  ) {
//    self.title = title
//    self.description = description
//    self.scheduledAt = scheduledAt
//    self.location = location
//    self.settings = settings
//  }
//}
//
///// 약속 목록 조회 요청
//public struct GetPromisesRequest: Codable {
//  public let page: Int
//  public let limit: Int
//  public let status: PromiseStatus?
//  public let groupId: UUID?
//  public let startDate: Date?
//  public let endDate: Date?
//  
//  public init(
//    page: Int = 1,
//    limit: Int = 20,
//    status: PromiseStatus? = nil,
//    groupId: UUID? = nil,
//    startDate: Date? = nil,
//    endDate: Date? = nil
//  ) {
//    self.page = page
//    self.limit = limit
//    self.status = status
//    self.groupId = groupId
//    self.startDate = startDate
//    self.endDate = endDate
//  }
//}
//
//// MARK: - Promise API Requests
//
///// 약속 생성 API 요청
//struct CreatePromiseAPIRequest: APIRequest {
//  typealias Response = Promise
//  
//  let body: Data?
//  
//  var path: String { "/promises" }
//  var method: HTTPMethod { .POST }
//  
//  init(request: CreatePromiseRequest) throws {
//    self.body = try JSONEncoder().encode(request)
//  }
//}
//
///// 약속 목록 조회 API 요청
//struct GetPromisesAPIRequest: APIRequest {
//  typealias Response = [Promise]
//  
//  let queryItems: [URLQueryItem]
//  
//  var path: String { "/promises" }
//  var method: HTTPMethod { .GET }
//  
//  init(request: GetPromisesRequest) {
//    var items: [URLQueryItem] = [
//      URLQueryItem(name: "page", value: String(request.page)),
//      URLQueryItem(name: "limit", value: String(request.limit))
//    ]
//    
//    if let status = request.status {
//      items.append(URLQueryItem(name: "status", value: status.rawValue))
//    }
//    
//    if let groupId = request.groupId {
//      items.append(URLQueryItem(name: "groupId", value: groupId.uuidString))
//    }
//    
//    if let startDate = request.startDate {
//      let formatter = ISO8601DateFormatter()
//      items.append(URLQueryItem(name: "startDate", value: formatter.string(from: startDate)))
//    }
//    
//    if let endDate = request.endDate {
//      let formatter = ISO8601DateFormatter()
//      items.append(URLQueryItem(name: "endDate", value: formatter.string(from: endDate)))
//    }
//    
//    self.queryItems = items
//  }
//}
//
///// 약속 상세 조회 API 요청
//struct GetPromiseAPIRequest: APIRequest {
//  typealias Response = Promise
//  
//  let promiseId: UUID
//  
//  var path: String { "/promises/\(promiseId.uuidString)" }
//  var method: HTTPMethod { .GET }
//  
//  init(promiseId: UUID) {
//    self.promiseId = promiseId
//  }
//}
//
///// 약속 업데이트 API 요청
//struct UpdatePromiseAPIRequest: APIRequest {
//  typealias Response = Promise
//  
//  let promiseId: UUID
//  let body: Data?
//  
//  var path: String { "/promises/\(promiseId.uuidString)" }
//  var method: HTTPMethod { .PUT }
//  
//  init(promiseId: UUID, request: UpdatePromiseRequest) throws {
//    self.promiseId = promiseId
//    self.body = try JSONEncoder().encode(request)
//  }
//}
//
///// 약속 삭제 API 요청
//struct DeletePromiseAPIRequest: APIRequest {
//  typealias Response = EmptyResponse
//  
//  let promiseId: UUID
//  
//  var path: String { "/promises/\(promiseId.uuidString)" }
//  var method: HTTPMethod { .DELETE }
//  
//  init(promiseId: UUID) {
//    self.promiseId = promiseId
//  }
//}
//
///// 약속 참가 API 요청
//struct JoinPromiseAPIRequest: APIRequest {
//  typealias Response = PromiseParticipant
//  
//  let promiseId: UUID
//  
//  var path: String { "/promises/\(promiseId.uuidString)/join" }
//  var method: HTTPMethod { .POST }
//  
//  init(promiseId: UUID) {
//    self.promiseId = promiseId
//  }
//}
//
///// 약속 나가기 API 요청
//struct LeavePromiseAPIRequest: APIRequest {
//  typealias Response = EmptyResponse
//  
//  let promiseId: UUID
//  
//  var path: String { "/promises/\(promiseId.uuidString)/leave" }
//  var method: HTTPMethod { .POST }
//  
//  init(promiseId: UUID) {
//    self.promiseId = promiseId
//  }
//}
//
//// MARK: - Promise Service Protocol
//
///// 약속 서비스 프로토콜
//public protocol PromiseServiceProtocol: Sendable {
//  func createPromise(_ request: CreatePromiseRequest) async throws -> Promise
//  func getPromises(_ request: GetPromisesRequest) async throws -> [Promise]
//  func getPromise(id: UUID) async throws -> Promise
//  func updatePromise(id: UUID, request: UpdatePromiseRequest) async throws -> Promise
//  func deletePromise(id: UUID) async throws
//  func joinPromise(id: UUID) async throws -> PromiseParticipant
//  func leavePromise(id: UUID) async throws
//  func completePromise(id: UUID) async throws -> Promise
//  func cancelPromise(id: UUID) async throws -> Promise
//}
//
//// MARK: - Promise Service Implementation
//
///// 약속 서비스 구현
//public final class PromiseService: PromiseServiceProtocol, @unchecked Sendable {
//  @Dependency(\.apiClient) private var apiClient
//  @Dependency(\.logger) private var logger
//  
//  public init() {}
//  
//  public func createPromise(_ request: CreatePromiseRequest) async throws -> Promise {
//    logger.info("Creating promise: \(request.title)", "Promise", #file, #function, #line)
//    
//    let apiRequest = try CreatePromiseAPIRequest(request: request)
//    let promise: Promise = try await apiClient.send(apiRequest) as! Promise
//    
//    logger.info("Promise created successfully: \(promise.id)", "Promise", #file, #function, #line)
//    return promise
//  }
//  
//  public func getPromises(_ request: GetPromisesRequest = GetPromisesRequest()) async throws -> [Promise] {
//    logger.info("Fetching promises", "Promise", #file, #function, #line)
//    
//    let apiRequest = GetPromisesAPIRequest(request: request)
//    let promises: [Promise] = try await apiClient.send(apiRequest) as! [Promise]
//    
//    logger.info("Fetched \(promises.count) promises", "Promise", #file, #function, #line)
//    return promises
//  }
//  
//  public func getPromise(id: UUID) async throws -> Promise {
//    logger.info("Fetching promise: \(id)", "Promise", #file, #function, #line)
//    
//    let apiRequest = GetPromiseAPIRequest(promiseId: id)
//    let promise: Promise = try await apiClient.send(apiRequest) as! Promise
//    
//    logger.info("Promise fetched successfully: \(promise.id)", "Promise", #file, #function, #line)
//    return promise
//  }
//  
//  public func updatePromise(id: UUID, request: UpdatePromiseRequest) async throws -> Promise {
//    logger.info("Updating promise: \(id)", "Promise", #file, #function, #line)
//    
//    let apiRequest = try UpdatePromiseAPIRequest(promiseId: id, request: request)
//    let promise: Promise = try await apiClient.send(apiRequest) as! Promise
//    
//    logger.info("Promise updated successfully: \(promise.id)", "Promise", #file, #function, #line)
//    return promise
//  }
//  
//  public func deletePromise(id: UUID) async throws {
//    logger.info("Deleting promise: \(id)", "Promise", #file, #function, #line)
//    
//    let apiRequest = DeletePromiseAPIRequest(promiseId: id)
//    let _: EmptyResponse = try await apiClient.send(apiRequest) as! EmptyResponse
//    
//    logger.info("Promise deleted successfully: \(id)", "Promise", #file, #function, #line)
//  }
//  
//  public func joinPromise(id: UUID) async throws -> PromiseParticipant {
//    logger.info("Joining promise: \(id)", "Promise", #file, #function, #line)
//    
//    let apiRequest = JoinPromiseAPIRequest(promiseId: id)
//    let participant: PromiseParticipant = try await apiClient.send(apiRequest) as! PromiseParticipant
//    
//    logger.info("Joined promise successfully: \(id)", "Promise", #file, #function, #line)
//    return participant
//  }
//  
//  public func leavePromise(id: UUID) async throws {
//    logger.info("Leaving promise: \(id)", "Promise", #file, #function, #line)
//    
//    let apiRequest = LeavePromiseAPIRequest(promiseId: id)
//    let _: EmptyResponse = try await apiClient.send(apiRequest) as! EmptyResponse
//    
//    logger.info("Left promise successfully: \(id)", "Promise", #file, #function, #line)
//  }
//  
//  public func completePromise(id: UUID) async throws -> Promise {
//    logger.info("Completing promise: \(id)", "Promise", #file, #function, #line)
//    
//    let request = UpdatePromiseRequest()
//    let apiRequest = try UpdatePromiseAPIRequest(promiseId: id, request: request)
//    let promise: Promise = try await apiClient.send(apiRequest) as! Promise
//    
//    logger.info("Promise completed successfully: \(promise.id)", "Promise", #file, #function, #line)
//    return promise
//  }
//  
//  public func cancelPromise(id: UUID) async throws -> Promise {
//    logger.info("Cancelling promise: \(id)", "Promise", #file, #function, #line)
//    
//    let request = UpdatePromiseRequest()
//    let apiRequest = try UpdatePromiseAPIRequest(promiseId: id, request: request)
//    let promise: Promise = try await apiClient.send(apiRequest) as! Promise
//    
//    logger.info("Promise cancelled successfully: \(promise.id)", "Promise", #file, #function, #line)
//    return promise
//  }
//}
//
//// MARK: - Promise Service Dependency
//
///// TCA Dependency로 Promise Service 등록
//public struct PromiseServiceClient: Sendable {
//  public var createPromise: @Sendable (CreatePromiseRequest) async throws -> Promise
//  public var getPromises: @Sendable (GetPromisesRequest) async throws -> [Promise]
//  public var getPromise: @Sendable (UUID) async throws -> Promise
//  public var updatePromise: @Sendable (UUID, UpdatePromiseRequest) async throws -> Promise
//  public var deletePromise: @Sendable (UUID) async throws -> Void
//  public var joinPromise: @Sendable (UUID) async throws -> PromiseParticipant
//  public var leavePromise: @Sendable (UUID) async throws -> Void
//  public var completePromise: @Sendable (UUID) async throws -> Promise
//  public var cancelPromise: @Sendable (UUID) async throws -> Promise
//  
//  public init(
//    createPromise: @escaping @Sendable (CreatePromiseRequest) async throws -> Promise,
//    getPromises: @escaping @Sendable (GetPromisesRequest) async throws -> [Promise],
//    getPromise: @escaping @Sendable (UUID) async throws -> Promise,
//    updatePromise: @escaping @Sendable (UUID, UpdatePromiseRequest) async throws -> Promise,
//    deletePromise: @escaping @Sendable (UUID) async throws -> Void,
//    joinPromise: @escaping @Sendable (UUID) async throws -> PromiseParticipant,
//    leavePromise: @escaping @Sendable (UUID) async throws -> Void,
//    completePromise: @escaping @Sendable (UUID) async throws -> Promise,
//    cancelPromise: @escaping @Sendable (UUID) async throws -> Promise
//  ) {
//    self.createPromise = createPromise
//    self.getPromises = getPromises
//    self.getPromise = getPromise
//    self.updatePromise = updatePromise
//    self.deletePromise = deletePromise
//    self.joinPromise = joinPromise
//    self.leavePromise = leavePromise
//    self.completePromise = completePromise
//    self.cancelPromise = cancelPromise
//  }
//}
//
//extension PromiseServiceClient: DependencyKey {
//  public static let liveValue: PromiseServiceClient = {
//    let service = PromiseService()
//    
//    return PromiseServiceClient(
//      createPromise: service.createPromise,
//      getPromises: service.getPromises,
//      getPromise: service.getPromise,
//      updatePromise: service.updatePromise,
//      deletePromise: service.deletePromise,
//      joinPromise: service.joinPromise,
//      leavePromise: service.leavePromise,
//      completePromise: service.completePromise,
//      cancelPromise: service.cancelPromise
//    )
//  }()
//  
//  public static let testValue: PromiseServiceClient = PromiseServiceClient(
//    createPromise: { _ in throw APIError.networkError("Test mode") },
//    getPromises: { _ in [] },
//    getPromise: { _ in throw APIError.networkError("Test mode") },
//    updatePromise: { _, _ in throw APIError.networkError("Test mode") },
//    deletePromise: { _ in throw APIError.networkError("Test mode") },
//    joinPromise: { _ in throw APIError.networkError("Test mode") },
//    leavePromise: { _ in throw APIError.networkError("Test mode") },
//    completePromise: { _ in throw APIError.networkError("Test mode") },
//    cancelPromise: { _ in throw APIError.networkError("Test mode") }
//  )
//}
//
//extension DependencyValues {
//  public var promiseService: PromiseServiceClient {
//    get { self[PromiseServiceClient.self] }
//    set { self[PromiseServiceClient.self] = newValue }
//  }
//}
