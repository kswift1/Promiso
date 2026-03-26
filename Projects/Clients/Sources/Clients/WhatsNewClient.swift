import ComposableArchitecture
import FirebaseFunctions
import Foundation
import PromisoShared

// MARK: - Client

/// What's New 데이터를 Firebase Functions에서 가져오는 클라이언트
@DependencyClient
public struct WhatsNewClient: Sendable {
  /// 특정 버전의 What's New 조회 (enabled=true인 경우만 반환)
  public var fetchWhatsNew: @Sendable (_ version: String) async throws -> WhatsNewModel?
}

// MARK: - Error

public enum WhatsNewClientError: Error {
  case fetchFailed(String)
  case decodingFailed(String)
}

// MARK: - Firebase Functions Response Models

private struct GetWhatsNewResponse: Decodable {
  let success: Bool
  let whatsNew: WhatsNewDocument?
}

private struct WhatsNewDocument: Decodable {
  let version: String
  let enabled: Bool
  let items: [WhatsNewItemDTO]
}

private struct WhatsNewItemDTO: Decodable {
  let title: String
  let description: String
  let imageURL: String
  let displayOrder: Int
}

// MARK: - Test / Preview

extension WhatsNewClient: TestDependencyKey {
  public static let previewValue = Self(
    fetchWhatsNew: { _ in WhatsNewModel.example }
  )

  public static let testValue = Self(
    fetchWhatsNew: unimplemented("\(Self.self).fetchWhatsNew")
  )
}

// MARK: - Live

extension WhatsNewClient: DependencyKey {
  public static let liveValue: WhatsNewClient = {
    let functions = DefaultFunctionsProvider().functions
    let decoder = JSONDecoder()

    return Self(
      fetchWhatsNew: { version in
        let resultData: Any
        do {
          let callable = functions.httpsCallable("getWhatsNew")
          let result = try await callable.call(["version": version])
          resultData = result.data
        } catch {
          throw WhatsNewClientError.fetchFailed(error.localizedDescription)
        }

        guard let data = try? JSONSerialization.data(withJSONObject: resultData) else {
          throw WhatsNewClientError.decodingFailed("Failed to serialize response data")
        }

        let response: GetWhatsNewResponse
        do {
          response = try decoder.decode(GetWhatsNewResponse.self, from: data)
        } catch {
          throw WhatsNewClientError.decodingFailed(error.localizedDescription)
        }

        guard let doc = response.whatsNew else {
          return nil
        }

        let items = doc.items
          .sorted { $0.displayOrder < $1.displayOrder }
          .map { item in
            WhatsNewModel.Item(
              title: item.title,
              description: item.description,
              imageURL: URL(string: item.imageURL),
              displayOrder: item.displayOrder
            )
          }

        return WhatsNewModel(
          version: doc.version,
          enabled: doc.enabled,
          items: items
        )
      }
    )
  }()
}

// MARK: - Dependency Values

extension DependencyValues {
  public var whatsNewClient: WhatsNewClient {
    get { self[WhatsNewClient.self] }
    set { self[WhatsNewClient.self] = newValue }
  }
}
