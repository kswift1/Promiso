import Foundation

// MARK: - Rust API Response DTOs

/// Rust API places/search 응답
private struct RustPlacesResponse: Decodable {
  let places: [RustPlaceItem]
}

/// Rust API 장소 아이템
private struct RustPlaceItem: Decodable {
  let id: String
  let name: String
  let latitude: Double
  let longitude: Double
  let address: String
  let roadAddress: String?
  let category: String?
  let phone: String?
}

// MARK: - PlacesRustDataSource

/// Rust API places/search 데이터소스
/// GET /api/v1/places/search?q={query}&size={size}  (인증 불필요)
public actor PlacesRustDataSource {
  private let api: RustAPIClient

  public init(api: RustAPIClient) {
    self.api = api
  }

  public func searchPlaces(query: String, size: Int = 15) async throws -> [Place] {
    guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
      return []
    }

    let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    let response: RustPlacesResponse = try await api.get(
      "/api/v1/places/search?q=\(encoded)&size=\(size)"
    )

    return response.places.map { item in
      Place(
        id: item.id,
        name: item.name,
        coordinate: Coordinate(latitude: item.latitude, longitude: item.longitude),
        address: item.address,
        roadAddress: item.roadAddress?.isEmpty == false ? item.roadAddress : nil,
        category: item.category?.isEmpty == false ? item.category : nil,
        phone: item.phone?.isEmpty == false ? item.phone : nil
      )
    }
  }
}
