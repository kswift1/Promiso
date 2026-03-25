import ComposableArchitecture
import Foundation
import MapKit

// MARK: - Walking Directions Result

public struct WalkingDirectionsResult: Equatable, Sendable {
  /// 도보 예상 거리 (미터)
  public let distanceMeters: Int
  /// 도보 예상 소요시간 (분)
  public let durationMinutes: Int
  /// 도보 경로 좌표 [[lng, lat], ...]
  public let routePoints: [[Double]]

  public init(distanceMeters: Int, durationMinutes: Int, routePoints: [[Double]]) {
    self.distanceMeters = distanceMeters
    self.durationMinutes = durationMinutes
    self.routePoints = routePoints
  }
}

// MARK: - WalkingDirectionsClient

@DependencyClient
public struct WalkingDirectionsClient: Sendable {
  /// 두 좌표 간 도보 경로 조회
  public var getWalkingDirections: @Sendable (
    _ fromLat: Double, _ fromLng: Double,
    _ toLat: Double, _ toLng: Double
  ) async throws -> WalkingDirectionsResult
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var walkingDirectionsClient: WalkingDirectionsClient {
    get { self[WalkingDirectionsClient.self] }
    set { self[WalkingDirectionsClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension WalkingDirectionsClient: DependencyKey {
  public static let liveValue = Self(
    getWalkingDirections: { fromLat, fromLng, toLat, toLng in
      let request = MKDirections.Request()
      request.source = MKMapItem(
        placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: fromLat, longitude: fromLng))
      )
      request.destination = MKMapItem(
        placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: toLat, longitude: toLng))
      )
      request.transportType = .walking

      let directions = MKDirections(request: request)
      let response = try await directions.calculate()

      guard let route = response.routes.first else {
        throw WalkingDirectionsError.noRouteFound
      }

      // MKPolyline → [[lng, lat]] 변환
      let pointCount = route.polyline.pointCount
      let points = route.polyline.points()
      var routePoints: [[Double]] = []
      routePoints.reserveCapacity(pointCount)

      // 포인트가 너무 많으면 간소화 (최대 200포인트)
      let stride = max(1, pointCount / 200)
      for i in Swift.stride(from: 0, to: pointCount, by: stride) {
        let coordinate = points[i].coordinate
        routePoints.append([coordinate.longitude, coordinate.latitude])
      }
      // 마지막 포인트 보장
      if let last = routePoints.last,
         pointCount > 1 {
        let lastCoord = points[pointCount - 1].coordinate
        if last[0] != lastCoord.longitude || last[1] != lastCoord.latitude {
          routePoints.append([lastCoord.longitude, lastCoord.latitude])
        }
      }

      return WalkingDirectionsResult(
        distanceMeters: Int(route.distance),
        durationMinutes: max(1, Int(ceil(route.expectedTravelTime / 60))),
        routePoints: routePoints
      )
    }
  )
}

// MARK: - Error

public enum WalkingDirectionsError: Error, Sendable {
  case noRouteFound
}

// MARK: - Test / Preview

extension WalkingDirectionsClient: TestDependencyKey {
  public static let previewValue = Self(
    getWalkingDirections: { _, _, _, _ in
      WalkingDirectionsResult(
        distanceMeters: 2500,
        durationMinutes: 32,
        routePoints: [
          [127.0276, 37.4981],
          [127.0250, 37.5000],
          [127.0230, 37.5050],
          [126.9236, 37.5567]
        ]
      )
    }
  )

  public static let testValue = Self(
    getWalkingDirections: unimplemented("\(Self.self).getWalkingDirections")
  )
}
