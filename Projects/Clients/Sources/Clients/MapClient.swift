import ComposableArchitecture
import Foundation
import SwiftUI
import UIKit

// MARK: - MapClient

/// 지도 서비스 클라이언트 (SDK 중립적 인터페이스)
@DependencyClient
public struct MapClient: Sendable {
  /// 장소 검색
  public var searchPlaces: @Sendable (_ query: String) async throws -> [Place]

  /// 길찾기 앱 열기
  public var openDirections: @Sendable (_ to: Coordinate, _ name: String?) -> Void
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var mapClient: MapClient {
    get { self[MapClient.self] }
    set { self[MapClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension MapClient: DependencyKey {
  public static let liveValue: MapClient = {
    let dataSource = KakaoMapDataSource()

    return Self(
      searchPlaces: { query in
        try await dataSource.searchPlaces(query: query)
      },
      openDirections: { coordinate, name in
        // 카카오맵 앱 또는 웹으로 길찾기
        let encodedName = name?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let kakaoMapURL = URL(string: "kakaomap://route?ep=\(coordinate.latitude),\(coordinate.longitude)&by=CAR"),
              let webURL = URL(string: "https://map.kakao.com/link/to/\(encodedName),\(coordinate.latitude),\(coordinate.longitude)") else {
          return
        }

        if UIApplication.shared.canOpenURL(kakaoMapURL) {
          UIApplication.shared.open(kakaoMapURL)
        } else {
          UIApplication.shared.open(webURL)
        }
      }
    )
  }()
}

// MARK: - Test / Preview

extension MapClient: TestDependencyKey {
  public static let previewValue = Self(
    searchPlaces: { query in
      // 미리보기용 샘플 데이터
      [
        Place(
          id: "1",
          name: "스타벅스 강남역점",
          coordinate: Coordinate(latitude: 37.498095, longitude: 127.027610),
          address: "서울 강남구 강남대로 390",
          roadAddress: "서울 강남구 강남대로 390",
          category: "카페",
          phone: "02-1234-5678"
        ),
        Place(
          id: "2",
          name: "CGV 강남",
          coordinate: Coordinate(latitude: 37.501087, longitude: 127.026632),
          address: "서울 강남구 강남대로 438",
          roadAddress: "서울 강남구 강남대로 438",
          category: "영화관",
          phone: nil
        )
      ].filter { $0.name.contains(query) || query.isEmpty }
    },
    openDirections: { _, _ in }
  )

  public static let testValue = Self(
    searchPlaces: unimplemented("\(Self.self).searchPlaces", placeholder: []),
    openDirections: unimplemented("\(Self.self).openDirections")
  )
}
