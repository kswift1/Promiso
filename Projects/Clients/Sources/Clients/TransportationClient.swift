import ComposableArchitecture
import Foundation

// MARK: - Transportation Result

public struct TransportationResult: Equatable, Sendable {
  public let transitRoutes: [TransitRouteInfo]
  public let driving: DrivingInfo?
  public let walkingMinutes: Int
  /// 도보 예상 거리 (미터, 직선거리 × 1.3 보정)
  public let walkingDistanceMeters: Int

  public init(
    transitRoutes: [TransitRouteInfo],
    driving: DrivingInfo?,
    walkingMinutes: Int,
    walkingDistanceMeters: Int
  ) {
    self.transitRoutes = transitRoutes
    self.driving = driving
    self.walkingMinutes = walkingMinutes
    self.walkingDistanceMeters = walkingDistanceMeters
  }

  public struct TransitRouteInfo: Equatable, Sendable, Decodable {
    public let totalTime: Int
    public let payment: Int
    public let busTransitCount: Int
    public let subwayTransitCount: Int
    public let pathType: Int           // 1=지하철, 2=버스, 3=복합
    public let subPaths: [SubPathInfo]

    public init(
      totalTime: Int,
      payment: Int,
      busTransitCount: Int,
      subwayTransitCount: Int,
      pathType: Int,
      subPaths: [SubPathInfo]
    ) {
      self.totalTime = totalTime
      self.payment = payment
      self.busTransitCount = busTransitCount
      self.subwayTransitCount = subwayTransitCount
      self.pathType = pathType
      self.subPaths = subPaths
    }
  }

  public struct SubPathInfo: Equatable, Sendable, Decodable {
    public let trafficType: Int       // 1=지하철, 2=버스, 3=도보
    public let sectionTime: Int
    public let distance: Int          // 미터
    public let startName: String?
    public let endName: String?
    public let stationCount: Int?
    public let lanes: [LaneInfo]
    public let startX: Double?
    public let startY: Double?
    public let endX: Double?
    public let endY: Double?
    public let way: String?           // 지하철 행선지 방향
    public let endExitNo: String?     // 하차 출구 번호
    public let passStopCoords: [[Double]]  // 경유 정류장 좌표

    public init(
      trafficType: Int,
      sectionTime: Int,
      distance: Int,
      startName: String?,
      endName: String?,
      stationCount: Int?,
      lanes: [LaneInfo],
      startX: Double? = nil,
      startY: Double? = nil,
      endX: Double? = nil,
      endY: Double? = nil,
      way: String? = nil,
      endExitNo: String? = nil,
      passStopCoords: [[Double]] = []
    ) {
      self.trafficType = trafficType
      self.sectionTime = sectionTime
      self.distance = distance
      self.startName = startName
      self.endName = endName
      self.stationCount = stationCount
      self.lanes = lanes
      self.startX = startX
      self.startY = startY
      self.endX = endX
      self.endY = endY
      self.way = way
      self.endExitNo = endExitNo
      self.passStopCoords = passStopCoords
    }

    private enum CodingKeys: String, CodingKey {
      case trafficType, sectionTime, distance, startName, endName, stationCount, lanes
      case startX, startY, endX, endY, way, endExitNo, passStopCoords
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      trafficType = try container.decode(Int.self, forKey: .trafficType)
      sectionTime = try container.decode(Int.self, forKey: .sectionTime)
      distance = try container.decode(Int.self, forKey: .distance)
      startName = try container.decodeIfPresent(String.self, forKey: .startName)
      endName = try container.decodeIfPresent(String.self, forKey: .endName)
      stationCount = try container.decodeIfPresent(Int.self, forKey: .stationCount)
      lanes = (try? container.decode([LaneInfo].self, forKey: .lanes)) ?? []
      startX = try container.decodeIfPresent(Double.self, forKey: .startX)
      startY = try container.decodeIfPresent(Double.self, forKey: .startY)
      endX = try container.decodeIfPresent(Double.self, forKey: .endX)
      endY = try container.decodeIfPresent(Double.self, forKey: .endY)
      way = try container.decodeIfPresent(String.self, forKey: .way)
      endExitNo = try container.decodeIfPresent(String.self, forKey: .endExitNo)
      passStopCoords = (try container.decodeIfPresent([[Double]].self, forKey: .passStopCoords)) ?? []
    }
  }

  public struct LaneInfo: Equatable, Sendable, Decodable {
    public let name: String?          // 지하철 노선명
    public let busNo: String?         // 버스번호
    public let subwayCode: Int?       // 지하철 호선
    public let busColor: String?      // 노선 색상 (Hex) — ODsay API에서 실제로 내려오지 않음
    public let busType: Int?          // 버스 종류 코드 (1=일반, 2=좌석, 3=마을, 4=직행좌석, 5=공항, 6=간선급행, 10=외곽, 11=간선, 13=순환, 14=광역, 15=급행)

    private enum CodingKeys: String, CodingKey {
      case name, busNo, subwayCode, busColor
      case busType = "type"
    }

    public init(name: String?, busNo: String?, subwayCode: Int?, busColor: String? = nil, busType: Int? = nil) {
      self.name = name
      self.busNo = busNo
      self.subwayCode = subwayCode
      self.busColor = busColor
      self.busType = busType
    }
  }

  public struct DrivingInfo: Equatable, Sendable, Decodable {
    public let distance: Int
    public let duration: Int
    public let toll: Int
    /// 자동차 경로 좌표 [[lng, lat], [lng, lat], ...]
    public let routePoints: [[Double]]

    public init(distance: Int, duration: Int, toll: Int, routePoints: [[Double]] = []) {
      self.distance = distance
      self.duration = duration
      self.toll = toll
      self.routePoints = routePoints
    }

    private enum CodingKeys: String, CodingKey {
      case distance, duration, toll, routePoints
    }

    public init(from decoder: Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      distance = try container.decode(Int.self, forKey: .distance)
      duration = try container.decode(Int.self, forKey: .duration)
      toll = try container.decode(Int.self, forKey: .toll)
      routePoints = (try container.decodeIfPresent([[Double]].self, forKey: .routePoints)) ?? []
    }
  }
}

// MARK: - TransportationResult + Decodable

extension TransportationResult: Decodable {
  private enum CodingKeys: String, CodingKey {
    case transitRoutes
    case driving
    case walkingMinutes
    case walkingDistanceKm
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    transitRoutes = try container.decodeIfPresent([TransitRouteInfo].self, forKey: .transitRoutes) ?? []
    driving = try container.decodeIfPresent(DrivingInfo.self, forKey: .driving)
    walkingMinutes = try container.decodeIfPresent(Int.self, forKey: .walkingMinutes) ?? 0
    let walkingDistanceKm = try container.decodeIfPresent(Double.self, forKey: .walkingDistanceKm) ?? 0
    walkingDistanceMeters = Int(walkingDistanceKm * 1000)
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

private struct GetTransportationBody: Encodable {
  let fromLat: Double
  let fromLng: Double
  let toLat: Double
  let toLng: Double
}

extension TransportationClient: DependencyKey {
  public static let liveValue: TransportationClient = {
    let rustClient = RustAPIClient()

    return Self(
      getTransportation: { fromLat, fromLng, toLat, toLng in
        do {
          return try await rustClient.post(
            "/api/v1/transportation",
            body: GetTransportationBody(
              fromLat: fromLat,
              fromLng: fromLng,
              toLat: toLat,
              toLng: toLng
            )
          )
        } catch let error as RustAPIError {
          switch error {
          case .invalidResponse, .noData:
            throw TransportationClientError.invalidResponse
          case .httpError(let statusCode):
            throw TransportationClientError.httpError(statusCode: statusCode)
          case .serverError(let code, let message):
            throw TransportationClientError.serverError(code: code, message: message)
          }
        }
      }
    )
  }()
}

// MARK: - Error

public enum TransportationClientError: Error, Sendable {
  case invalidResponse
  case httpError(statusCode: Int)
  case serverError(code: String, message: String)
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
                .init(name: "2호선", busNo: nil, subwayCode: 2, busColor: nil, busType: nil)
              ], startX: 127.0276, startY: 37.4981, endX: 126.9236, endY: 37.5567, way: "합정", passStopCoords: [[127.0276, 37.4981], [126.9824, 37.5340], [126.9236, 37.5567]]),
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
                .init(name: nil, busNo: "143", subwayCode: nil, busColor: nil, busType: 11)
              ], startX: 127.0276, startY: 37.4981, endX: 126.9236, endY: 37.5567, passStopCoords: [[127.0276, 37.4981], [126.9236, 37.5567]]),
              .init(trafficType: 3, sectionTime: 7, distance: 550, startName: "홍대입구버스정류장", endName: nil, stationCount: nil, lanes: [])
            ]
          )
        ],
        driving: .init(distance: 15000, duration: 25, toll: 0, routePoints: [
          [126.9784, 37.5665],
          [126.9612, 37.5567],
          [126.9250, 37.5550],
          [126.9236, 37.5547]
        ]),
        walkingMinutes: 55,
        walkingDistanceMeters: 4000
      )
    }
  )

  public static let testValue = Self(
    getTransportation: unimplemented("\(Self.self).getTransportation")
  )
}
