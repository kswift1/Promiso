import CoreLocation
import ComposableArchitecture
import PromisoShared

// MARK: - LocationAuthorizationStatus

public enum LocationAuthorizationStatus: Equatable, Sendable {
  case notDetermined
  case authorized
  case denied
}

// MARK: - LocationClient

@DependencyClient
public struct LocationClient: Sendable {
  /// 위치 권한 상태 확인 (동기)
  public var authorizationStatus: @Sendable () -> LocationAuthorizationStatus = { .notDetermined }
  /// 현재 위치 좌표 조회 (권한 미부여 시 자동 요청)
  public var getCurrentLocation: @Sendable () async throws -> Coordinate
  /// 좌표를 사람이 읽을 수 있는 주소 텍스트로 변환
  public var reverseGeocode: @Sendable (_ coordinate: Coordinate) async throws -> String?
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var locationClient: LocationClient {
    get { self[LocationClient.self] }
    set { self[LocationClient.self] = newValue }
  }
}

// MARK: - Error

public enum LocationClientError: Error, Sendable {
  case unavailable
  case denied
}

// MARK: - Live Implementation

extension LocationClient: DependencyKey {
  public static let liveValue = Self(
    authorizationStatus: {
      switch CLLocationManager().authorizationStatus {
      case .authorizedWhenInUse, .authorizedAlways:
        return .authorized
      case .denied, .restricted:
        return .denied
      case .notDetermined:
        return .notDetermined
      @unknown default:
        return .notDetermined
      }
    },
    getCurrentLocation: {
      for try await update in CLLocationUpdate.liveUpdates() {
        if let location = update.location {
          return Coordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
          )
        }
      }
      throw LocationClientError.unavailable
    },
    reverseGeocode: { coordinate in
      let geocoder = CLGeocoder()
      let placemarks = try await geocoder.reverseGeocodeLocation(
        CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
      )
      return Self.displayAddress(from: placemarks.first)
    }
  )

  private static func displayAddress(from placemark: CLPlacemark?) -> String? {
    guard let placemark else { return nil }

    let primary = uniqueAddressParts([
      placemark.locality,
      placemark.subLocality,
    ])
    if !primary.isEmpty {
      return primary.joined(separator: " ")
    }

    let fallback = uniqueAddressParts([
      placemark.administrativeArea,
      placemark.locality,
      placemark.thoroughfare,
      placemark.subThoroughfare,
      placemark.name,
    ])
    return fallback.isEmpty ? nil : fallback.joined(separator: " ")
  }

  private static func uniqueAddressParts(_ values: [String?]) -> [String] {
    var seen = Set<String>()
    var parts: [String] = []

    for value in values {
      guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
            !trimmed.isEmpty,
            seen.insert(trimmed).inserted else {
        continue
      }
      parts.append(trimmed)
    }
    return parts
  }
}

// MARK: - Test / Preview

extension LocationClient: TestDependencyKey {
  public static let previewValue = Self(
    authorizationStatus: { .authorized },
    getCurrentLocation: {
      // 서울 시청
      Coordinate(latitude: 37.5665, longitude: 126.9780)
    },
    reverseGeocode: { _ in "서울 중구" }
  )

  public static let testValue = Self(
    authorizationStatus: unimplemented("\(Self.self).authorizationStatus", placeholder: .notDetermined),
    getCurrentLocation: unimplemented("\(Self.self).getCurrentLocation"),
    reverseGeocode: unimplemented("\(Self.self).reverseGeocode", placeholder: nil)
  )
}
