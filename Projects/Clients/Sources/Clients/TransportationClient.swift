import ComposableArchitecture
import FirebaseFunctions
import Foundation

// MARK: - Transportation Result

public struct TransportationResult: Equatable, Sendable {
  public let transitRoutes: [TransitRouteInfo]
  public let driving: DrivingInfo?
  public let walkingMinutes: Int

  public struct TransitRouteInfo: Equatable, Sendable {
    public let totalTime: Int
    public let payment: Int
    public let busTransitCount: Int
    public let subwayTransitCount: Int
    public let pathType: Int           // 1=지하철, 2=버스, 3=복합
    public let subPaths: [SubPathInfo]
  }

  public struct SubPathInfo: Equatable, Sendable {
    public let trafficType: Int       // 1=지하철, 2=버스, 3=도보
    public let sectionTime: Int
    public let distance: Int          // 미터
    public let startName: String?
    public let endName: String?
    public let stationCount: Int?
    public let lanes: [LaneInfo]
  }

  public struct LaneInfo: Equatable, Sendable {
    public let name: String?          // 지하철 노선명
    public let busNo: String?         // 버스번호
    public let subwayCode: Int?       // 지하철 호선
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

        // transitRoutes 배열 파싱
        let transitRoutes: [TransportationResult.TransitRouteInfo]
        if let routesData = data["transitRoutes"] as? [[String: Any]] {
          transitRoutes = routesData.map { routeData in
            let subPathsData = routeData["subPaths"] as? [[String: Any]] ?? []
            let subPaths = subPathsData.map { subPathData -> TransportationResult.SubPathInfo in
              let lanesData = subPathData["lanes"] as? [[String: Any]] ?? []
              let lanes = lanesData.map { laneData in
                TransportationResult.LaneInfo(
                  name: laneData["name"] as? String,
                  busNo: laneData["busNo"] as? String,
                  subwayCode: laneData["subwayCode"] as? Int
                )
              }
              return TransportationResult.SubPathInfo(
                trafficType: subPathData["trafficType"] as? Int ?? 3,
                sectionTime: subPathData["sectionTime"] as? Int ?? 0,
                distance: subPathData["distance"] as? Int ?? 0,
                startName: subPathData["startName"] as? String,
                endName: subPathData["endName"] as? String,
                stationCount: subPathData["stationCount"] as? Int,
                lanes: lanes
              )
            }
            return TransportationResult.TransitRouteInfo(
              totalTime: routeData["totalTime"] as? Int ?? 0,
              payment: routeData["payment"] as? Int ?? 0,
              busTransitCount: routeData["busTransitCount"] as? Int ?? 0,
              subwayTransitCount: routeData["subwayTransitCount"] as? Int ?? 0,
              pathType: routeData["pathType"] as? Int ?? 3,
              subPaths: subPaths
            )
          }
        } else {
          transitRoutes = []
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
          transitRoutes: transitRoutes,
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
        transitRoutes: [
          .init(
            totalTime: 40,
            payment: 1250,
            busTransitCount: 0,
            subwayTransitCount: 1,
            pathType: 1,
            subPaths: [
              .init(trafficType: 3, sectionTime: 5, distance: 400, startName: nil, endName: "강남역", stationCount: nil, lanes: []),
              .init(trafficType: 1, sectionTime: 28, distance: 18000, startName: "강남역", endName: "홍대입구역", stationCount: 6, lanes: [
                .init(name: "2호선", busNo: nil, subwayCode: 2)
              ]),
              .init(trafficType: 3, sectionTime: 7, distance: 550, startName: "홍대입구역", endName: nil, stationCount: nil, lanes: [])
            ]
          ),
          .init(
            totalTime: 45,
            payment: 1250,
            busTransitCount: 1,
            subwayTransitCount: 0,
            pathType: 2,
            subPaths: [
              .init(trafficType: 3, sectionTime: 3, distance: 250, startName: nil, endName: "강남역버스정류장", stationCount: nil, lanes: []),
              .init(trafficType: 2, sectionTime: 35, distance: 20000, startName: "강남역버스정류장", endName: "홍대입구버스정류장", stationCount: 8, lanes: [
                .init(name: nil, busNo: "143", subwayCode: nil)
              ]),
              .init(trafficType: 3, sectionTime: 7, distance: 550, startName: "홍대입구버스정류장", endName: nil, stationCount: nil, lanes: [])
            ]
          )
        ],
        driving: .init(distance: 15000, duration: 25, toll: 0),
        walkingMinutes: 55
      )
    }
  )

  public static let testValue = Self(
    getTransportation: unimplemented("\(Self.self).getTransportation")
  )
}
