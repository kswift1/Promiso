import ComposableArchitecture
import Foundation
import SwiftUI
import UIKit

// MARK: - TransportMode

public enum TransportMode: String, Sendable {
  case car
  case transit
  case walking
}

// MARK: - MapApp

// NOTE: Info.plist의 LSApplicationQueriesSchemes에 "kakaomap", "nmap"을 추가해야 canOpenURL이 동작합니다.
public enum MapApp: String, CaseIterable, Sendable {
  case kakao
  case naver

  public var displayName: String {
    switch self {
    case .kakao: return "카카오맵"
    case .naver: return "네이버 지도"
    }
  }

  public var iconName: String {
    switch self {
    case .kakao: return "map.fill"
    case .naver: return "map.fill"
    }
  }
}

// MARK: - MapClient

/// 지도 서비스 클라이언트 (SDK 중립적 인터페이스)
@DependencyClient
public struct MapClient: Sendable {
  /// 장소 검색
  public var searchPlaces: @Sendable (_ query: String) async throws -> [Place]

  /// 길찾기 앱 열기 (하위 호환 — 카카오맵 + 자동차 모드로 동작)
  public var openDirections: @Sendable (
    _ from: Coordinate?,
    _ to: Coordinate,
    _ name: String?,
    _ transportMode: TransportMode
  ) -> Void

  /// 설치된 지도 앱 목록 반환
  public var availableMapApps: @Sendable () -> [MapApp] = { [] }

  /// 특정 지도 앱으로 길찾기
  public var openDirectionsInApp: @Sendable (
    _ app: MapApp,
    _ from: Coordinate?,
    _ to: Coordinate,
    _ name: String?,
    _ fromName: String?,
    _ transportMode: TransportMode
  ) -> Void
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

    // MARK: Helpers

    func kakaoRouteKey(for mode: TransportMode) -> String {
      switch mode {
      case .car: return "CAR"
      case .transit: return "PUBLICTRANSIT"
      case .walking: return "FOOT"
      }
    }

    func naverRoutePath(for mode: TransportMode) -> String {
      switch mode {
      case .car: return "car"
      case .transit: return "public"
      case .walking: return "walk"
      }
    }

    func openKakaoDirections(
      from: Coordinate?,
      to: Coordinate,
      name: String?,
      transportMode: TransportMode
    ) {
      let encodedName = name?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
      let byKey = kakaoRouteKey(for: transportMode)

      var kakaoURLString = "kakaomap://route?ep=\(to.latitude),\(to.longitude)&by=\(byKey)"
      if let from {
        kakaoURLString += "&sp=\(from.latitude),\(from.longitude)"
      }

      guard let kakaoMapURL = URL(string: kakaoURLString),
            let webURL = URL(string: "https://map.kakao.com/link/to/\(encodedName),\(to.latitude),\(to.longitude)") else {
        return
      }

      if UIApplication.shared.canOpenURL(kakaoMapURL) {
        UIApplication.shared.open(kakaoMapURL)
      } else {
        UIApplication.shared.open(webURL)
      }
    }

    func openNaverDirections(
      from: Coordinate?,
      to: Coordinate,
      name: String?,
      fromName: String?,
      transportMode: TransportMode
    ) {
      let routePath = naverRoutePath(for: transportMode)

      var components = URLComponents()
      components.scheme = "nmap"
      components.host = "route"
      components.path = "/\(routePath)"

      var queryItems: [URLQueryItem] = []
      if let from {
        queryItems.append(contentsOf: [
          URLQueryItem(name: "slat", value: "\(from.latitude)"),
          URLQueryItem(name: "slng", value: "\(from.longitude)"),
          URLQueryItem(name: "sname", value: fromName ?? "출발지")
        ])
      }
      queryItems.append(contentsOf: [
        URLQueryItem(name: "dlat", value: "\(to.latitude)"),
        URLQueryItem(name: "dlng", value: "\(to.longitude)"),
        URLQueryItem(name: "dname", value: name ?? ""),
        URLQueryItem(name: "appname", value: Bundle.main.bundleIdentifier ?? "com.promiso.app")
      ])
      components.queryItems = queryItems

      guard let naverURL = components.url,
            let appStoreURL = URL(string: "https://itunes.apple.com/app/id311867728") else {
        return
      }

      if UIApplication.shared.canOpenURL(naverURL) {
        UIApplication.shared.open(naverURL)
      } else {
        UIApplication.shared.open(appStoreURL)
      }
    }

    return Self(
      searchPlaces: { query in
        try await dataSource.searchPlaces(query: query)
      },
      openDirections: { from, to, name, transportMode in
        Task { @MainActor in
          openKakaoDirections(from: from, to: to, name: name, transportMode: transportMode)
        }
      },
      availableMapApps: {
        MapApp.allCases.filter { app in
          let schemeURL: URL? = switch app {
          case .kakao: URL(string: "kakaomap://")
          case .naver: URL(string: "nmap://")
          }
          guard let url = schemeURL else { return false }
          return UIApplication.shared.canOpenURL(url)
        }
      },
      openDirectionsInApp: { app, from, to, name, fromName, transportMode in
        Task { @MainActor in
          switch app {
          case .kakao:
            openKakaoDirections(from: from, to: to, name: name, transportMode: transportMode)
          case .naver:
            openNaverDirections(from: from, to: to, name: name, fromName: fromName, transportMode: transportMode)
          }
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
    openDirections: { _, _, _, _ in },
    availableMapApps: { MapApp.allCases },
    openDirectionsInApp: { _, _, _, _, _, _ in }
  )

  public static let testValue = Self(
    searchPlaces: unimplemented("\(Self.self).searchPlaces", placeholder: []),
    openDirections: unimplemented("\(Self.self).openDirections"),
    availableMapApps: unimplemented("\(Self.self).availableMapApps", placeholder: []),
    openDirectionsInApp: unimplemented("\(Self.self).openDirectionsInApp")
  )
}
