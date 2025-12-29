import Clients
import Shared
import ExternalDependency
import Foundation

enum LiveDependencies {
  static func install(into dependencies: inout DependencyValues) {
    // Clients 주입 (각 레이어가 자체 liveValue 구현)
    dependencies.authClient = .liveValue
    dependencies.promiseClient = makePromiseClient()
    dependencies.groupRepository = GroupRemoteDataSource()
  }
}

// MARK: - PromiseClient

private func makePromiseClient() -> PromiseClient {
  let repository: PromiseRepositoryProtocol = PromiseRepository()

  return PromiseClient(
    createPromise: { proposal, hostId in
      guard let group = proposal.group else { throw Clients.PromiseClientError.invalidData }
      return try await repository.createPromise(
        proposal.toDomainModel(hostId: hostId, group: group)
      )
    },
    updatePromise: { _, _ in
      throw Clients.PromiseClientError.unknown
    },
    deletePromise: { promiseId in
      try await repository.deletePromise(id: promiseId)
    },
    getPromise: { _ in
      nil
    },
    getTodayPromises: { _, _ in [] },
    getUpcomingPromises: { _, _ in [] },
    getActivePromises: { _, _ in [] }
  )
}
