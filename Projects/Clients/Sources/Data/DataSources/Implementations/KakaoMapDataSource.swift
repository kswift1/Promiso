import Foundation

// MARK: - Kakao Local API DTO (Internal)

/// Kakao Local API 검색 응답
struct KakaoLocalSearchResponse: Codable {
  let meta: KakaoSearchMeta
  let documents: [KakaoPlaceDTO]
}

struct KakaoSearchMeta: Codable {
  let totalCount: Int
  let pageableCount: Int
  let isEnd: Bool

  enum CodingKeys: String, CodingKey {
    case totalCount = "total_count"
    case pageableCount = "pageable_count"
    case isEnd = "is_end"
  }
}

struct KakaoPlaceDTO: Codable {
  let id: String
  let placeName: String
  let categoryName: String
  let categoryGroupCode: String
  let categoryGroupName: String
  let phone: String
  let addressName: String
  let roadAddressName: String
  let x: String  // longitude
  let y: String  // latitude
  let placeUrl: String
  let distance: String

  enum CodingKeys: String, CodingKey {
    case id
    case placeName = "place_name"
    case categoryName = "category_name"
    case categoryGroupCode = "category_group_code"
    case categoryGroupName = "category_group_name"
    case phone
    case addressName = "address_name"
    case roadAddressName = "road_address_name"
    case x, y
    case placeUrl = "place_url"
    case distance
  }

  /// Domain Place로 변환 (좌표 파싱 실패 시 nil 반환)
  func toPlace() -> Place? {
    guard let latitude = Double(y), let longitude = Double(x) else {
      return nil
    }
    return Place(
      id: id,
      name: placeName,
      coordinate: Coordinate(latitude: latitude, longitude: longitude),
      address: addressName,
      roadAddress: roadAddressName.isEmpty ? nil : roadAddressName,
      category: categoryName.isEmpty ? nil : categoryName,
      phone: phone.isEmpty ? nil : phone
    )
  }
}

// MARK: - KakaoMapDataSource

/// Kakao Map API 데이터소스
final class KakaoMapDataSource: Sendable {
  private let baseURL = "https://dapi.kakao.com/v2/local/search/keyword.json"

  /// REST API 키 (Info.plist에서 로드)
  private var apiKey: String {
    Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") as? String ?? ""
  }

  /// 장소 검색
  func searchPlaces(query: String) async throws -> [Place] {
    guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
      return []
    }

    guard !apiKey.isEmpty else {
      throw MapDataSourceError.missingApiKey
    }

    guard var components = URLComponents(string: baseURL) else {
      throw MapDataSourceError.invalidResponse
    }
    components.queryItems = [
      URLQueryItem(name: "query", value: query),
      URLQueryItem(name: "size", value: "15")
    ]

    guard let url = components.url else {
      throw MapDataSourceError.invalidResponse
    }

    var request = URLRequest(url: url)
    request.setValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")

    let (data, response) = try await URLSession.shared.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse else {
      throw MapDataSourceError.invalidResponse
    }

    guard httpResponse.statusCode == 200 else {
      throw MapDataSourceError.httpError(statusCode: httpResponse.statusCode)
    }

    let decoder = JSONDecoder()
    let searchResponse = try decoder.decode(KakaoLocalSearchResponse.self, from: data)

    return searchResponse.documents.compactMap { $0.toPlace() }
  }
}

// MARK: - Error

enum MapDataSourceError: Error, LocalizedError {
  case missingApiKey
  case invalidResponse
  case httpError(statusCode: Int)

  var errorDescription: String? {
    switch self {
    case .missingApiKey:
      return "API 키가 설정되지 않았습니다"
    case .invalidResponse:
      return "응답을 처리할 수 없습니다"
    case .httpError(let code):
      return "서버 오류 (\(code))"
    }
  }
}
