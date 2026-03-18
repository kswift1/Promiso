import FirebaseFunctions
import Foundation

// MARK: - Firebase Functions Response Models

/// searchPlaces Functions 응답
private struct SearchPlacesResponse: Decodable {
  let places: [PlaceItem]
}

/// 장소 아이템
private struct PlaceItem: Decodable {
  let id: String
  let name: String
  let latitude: Double
  let longitude: Double
  let address: String
  let roadAddress: String
  let category: String
  let phone: String
}

// MARK: - KakaoMapDataSource

/// Kakao Map API 데이터소스 (Firebase Functions 프록시)
final class KakaoMapDataSource: Sendable {
  private let functions = DefaultFunctionsProvider().functions

  /// 장소 검색
  func searchPlaces(query: String) async throws -> [Place] {
    guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
      return []
    }

    // Firebase Functions 호출 (Kakao REST API 프록시)
    let callable = functions.httpsCallable("searchPlaces")
    let result = try await callable.call(["query": query, "size": 15])

    guard let data = try? JSONSerialization.data(withJSONObject: result.data) else {
      throw MapDataSourceError.invalidResponse
    }

    let decoder = JSONDecoder()
    let response: SearchPlacesResponse
    do {
      response = try decoder.decode(SearchPlacesResponse.self, from: data)
    } catch {
      throw MapDataSourceError.invalidResponse
    }

    return response.places.map { item in
      Place(
        id: item.id,
        name: item.name,
        coordinate: Coordinate(latitude: item.latitude, longitude: item.longitude),
        address: item.address,
        roadAddress: item.roadAddress.isEmpty ? nil : item.roadAddress,
        category: item.category.isEmpty ? nil : item.category,
        phone: item.phone.isEmpty ? nil : item.phone
      )
    }
  }
}

// MARK: - Error

enum MapDataSourceError: Error {
  case invalidResponse
  case httpError(statusCode: Int)
}
