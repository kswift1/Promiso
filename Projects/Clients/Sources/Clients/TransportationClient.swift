import ComposableArchitecture
import FirebaseFunctions
import Foundation

// MARK: - Transportation Result

public struct TransportationResult: Equatable, Sendable {
  public let transit: TransitInfo?
  public let driving: DrivingInfo?
  public let walkingMinutes: Int

  public struct TransitInfo: Equatable, Sendable {
    public let totalTime: Int
    public let payment: Int
    public let busTransitCount: Int
    public let subwayTransitCount: Int
  }

  public struct DrivingInfo: Equatable, Sendable {
    public let distance: Int
    public let duration: Int
    public let toll: Int
  }
}

// MARK: - TransportationClient

@DependencyClient
public struct TransportationClient: Sendable {
  /// 두 좌표 간 교통 정보 조회 (대중교통 + 자동차 + 도보)
  public var getTransportation: @Sendable (
    _ fromLat: Double, _ fromLng: Double,
    _ toLat: Double, _ toLng: Double
  ) async throws -> TransportationResult
}

// MARK: - Dependency Registration

extension DependencyValues {
  public var transportationClient: TransportationClient {
    get { self[TransportationClient.self] }
    set { self[TransportationClient.self] = newValue }
  }
}

// MARK: - Live Implementation

extension TransportationClient: DependencyKey {
  public static let liveValue: TransportationClient = {
    let functions = DefaultFunctionsProvider().functions

    return Self(
      getTransportation: { fromLat, fromLng, toLat, toLng in
        let result = try await functions.httpsCallable("getTransportation").call([
          "fromLat": fromLat,
          "fromLng": fromLng,
          "toLat": toLat,
          "toLng": toLng,
        ])

        guard let data = result.data as? [String: Any] else {
          throw TransportationClientError.invalidResponse
        }

        let transit: TransportationResult.TransitInfo?
        if let transitData = data["transit"] as? [String: Any] {
          transit = TransportationResult.TransitInfo(
            totalTime: transitData["totalTime"] as? Int ?? 0,
            payment: transitData["payment"] as? Int ?? 0,
            busTransitCount: transitData["busTransitCount"] as? Int ?? 0,
            subwayTransitCount: transitData["subwayTransitCount"] as? Int ?? 0
          )
        } else {
          transit = nil
        }

        let driving: TransportationResult.DrivingInfo?
        if let drivingData = data["driving"] as? [String: Any] {
          driving = TransportationResult.DrivingInfo(
            distance: drivingData["distance"] as? Int ?? 0,
            duration: drivingData["duration"] as? Int ?? 0,
            toll: drivingData["toll"] as? Int ?? 0
          )
        } else {
          driving = nil
        }

        let walkingMinutes = data["walkingMinutes"] as? Int ?? 0

        return TransportationResult(
          transit: transit,
          driving: driving,
          walkingMinutes: walkingMinutes
        )
      }
    )
  }()
}

// MARK: - Error

public enum TransportationClientError: Error, Sendable {
  case invalidResponse
}

// MARK: - Test / Preview

extension TransportationClient: TestDependencyKey {
  public static let previewValue = Self(
    getTransportation: { _, _, _, _ in
      TransportationResult(
        transit: .init(totalTime: 40, payment: 1250, busTransitCount: 1, subwayTransitCount: 1),
        driving: .init(distance: 15000, duration: 25, toll: 0),
        walkingMinutes: 55
      )
    }
  )

  public static let testValue = Self(
    getTransportation: unimplemented("\(Self.self).getTransportation")
  )
}
