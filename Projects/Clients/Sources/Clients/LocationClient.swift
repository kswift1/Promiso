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
    }
  )
}

// MARK: - Test / Preview

extension LocationClient: TestDependencyKey {
  public static let previewValue = Self(
    authorizationStatus: { .authorized },
    getCurrentLocation: {
      // 서울 시청
      Coordinate(latitude: 37.5665, longitude: 126.9780)
    }
  )

  public static let testValue = Self(
    authorizationStatus: unimplemented("\(Self.self).authorizationStatus", placeholder: .notDetermined),
    getCurrentLocation: unimplemented("\(Self.self).getCurrentLocation")
  )
}
