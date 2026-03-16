import Clients
import Foundation
import PromisoShared

// MARK: - Home Models Namespace

public enum HomeModels {}

// MARK: - Schedule Item (통합 일정 아이템)

extension HomeModels {
  /// 홈 화면에서 그룹 일정과 개인 일정을 통합 표시하기 위한 타입
  public enum ScheduleItem: Identifiable, Equatable {
    case schedule(ScheduleModel)
    case personalEvent(PersonalEventModel)
    case recurringPersonalEvent(ExpandedEventInstance)

    public var id: String {
      switch self {
      case .schedule(let p): return "schedule-\(p.id)"
      case .personalEvent(let e): return "personal-\(e.id)"
      case .recurringPersonalEvent(let e): return "recurring-\(e.id)"
      }
    }

    public var startAt: Date {
      switch self {
      case .schedule(let p): return p.startAt
      case .personalEvent(let e): return e.startAt
      case .recurringPersonalEvent(let e): return e.startAt
      }
    }

    public var endAt: Date? {
      switch self {
      case .schedule(let p): return p.endAt
      case .personalEvent(let e): return e.endAt
      case .recurringPersonalEvent(let e): return e.endAt
      }
    }

    /// endAt이 없는 경우 단발성 (시작 = 종료)
    public var effectiveEndAt: Date {
      endAt ?? startAt
    }

    public var displayEmoji: String {
      switch self {
      case .schedule(let p): return p.displayEmoji
      case .personalEvent(let e): return e.displayEmoji
      case .recurringPersonalEvent(let e): return e.emoji ?? "🔄"
      }
    }

    public var title: String {
      switch self {
      case .schedule(let p): return p.title
      case .personalEvent(let e): return e.title
      case .recurringPersonalEvent(let e): return e.title
      }
    }

    public var location: LocationInfoModel? {
      switch self {
      case .schedule(let p): return p.location
      case .personalEvent(let e): return e.location
      case .recurringPersonalEvent(let e): return e.location
      }
    }

    /// 확정 여부 (일정만 해당, 개인 일정은 항상 true)
    public var isConfirmed: Bool {
      switch self {
      case .schedule(let p): return p.isConfirmed
      case .personalEvent, .recurringPersonalEvent: return true
      }
    }
  }
}

// MARK: - Overview Data

extension HomeModels {
  public struct OverviewData: Equatable {
    public let todayCount: Int
    public let nextSchedule: ScheduleModel?
    public let needResponseCount: Int

    public init(
      todayCount: Int,
      nextSchedule: ScheduleModel?,
      needResponseCount: Int
    ) {
      self.todayCount = todayCount
      self.nextSchedule = nextSchedule
      self.needResponseCount = needResponseCount
    }
  }
}

// MARK: - Timeline Section

extension HomeModels {
  public struct TimelineSection: Equatable, Identifiable {
    public let day: Date               // startOfDay로 정규화
    public let schedules: [ScheduleModel]

    public var id: String { dayKey }   // "2026-01-26" 형식 (타임존 안전)

    private var dayKey: String {
      LocalizedDateFormatters.date.string(from: day)
    }

    public init(day: Date, schedules: [ScheduleModel]) {
      self.day = day
      self.schedules = schedules
    }
  }
}

// MARK: - Group Info

extension HomeModels {
  public struct GroupInfo: Equatable, Identifiable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
      self.id = id
      self.name = name
    }
  }
}

// MARK: - Status Filter

extension HomeModels {
  public enum StatusFilter: String, Equatable, CaseIterable, Sendable {
    case all = "all"
    case needResponse = "needResponse"
    case confirmed = "confirmed"
    case inProgress = "inProgress"

    public var displayTitle: String {
      switch self {
      case .all: return LocalizedStrings.Home.filterAll
      case .needResponse: return LocalizedStrings.Home.filterNeedResponse
      case .confirmed: return LocalizedStrings.Home.filterConfirmed
      case .inProgress: return LocalizedStrings.Home.filterInProgress
      }
    }
  }
}

// MARK: - Scroll Target

extension HomeModels {
  public enum ScrollTarget: Equatable {
    case needResponse          // 응답 필요 첫 번째 섹션으로
    case date(Date)            // 특정 날짜로 (향후 "오늘로 스크롤" 등)
  }
}

// MARK: - Critical Zone Data

extension HomeModels {
  public struct CriticalZoneData: Equatable {
    public let reason: CriticalReason
    public let schedule: ScheduleModel

    public init(reason: CriticalReason, schedule: ScheduleModel) {
      self.reason = reason
      self.schedule = schedule
    }

    public enum CriticalReason: Int, Comparable, Equatable {
      case liveActivity = 1     // 최우선: LiveActivity 공유 중
      case inProgress = 2       // 진행 중
      case departureSoon = 3    // 출발 임박 (30분 전)

      public static func < (lhs: CriticalReason, rhs: CriticalReason) -> Bool {
        lhs.rawValue < rhs.rawValue
      }
    }
  }
}

// MARK: - Recurring Event Summary

extension HomeModels {
  /// 반복 일정 시리즈 요약 (다가오는 일정 섹션용)
  public struct RecurringEventSummary: Equatable, Identifiable {
    public let recurringEventId: String
    public let title: String
    public let emoji: String
    public let recurrenceText: String
    public let nextInstanceDate: Date

    public var id: String { recurringEventId }
  }
}

// MARK: - Departure Alert

extension HomeModels {
  /// 교통수단 타입
  public enum TransportType: String, Equatable, CaseIterable, Sendable, Codable {
    case driving
    case transit
    case walking

    public var displayName: String {
      switch self {
      case .driving: return LocalizedStrings.Home.transportDriving
      case .transit: return LocalizedStrings.Home.transportTransit
      case .walking: return LocalizedStrings.Home.transportWalking
      }
    }

    public var iconName: String {
      switch self {
      case .driving: return "car.fill"
      case .transit: return "tram.fill"
      case .walking: return "figure.walk"
      }
    }
  }

  /// 시트에서 선택 가능한 항목 식별
  public enum TransportSelection: Equatable, Hashable, Sendable {
    case driving
    case transit(index: Int)
    case walking
  }

  /// 교통수단별 이동 정보 (도보 / 자동차용 단순 옵션)
  public struct TransportOption: Equatable, Sendable {
    public let type: TransportType
    public let durationMinutes: Int
    /// buffer=0 기준 순수 출발 시간 (startAt - durationMinutes)
    public let departureTime: Date
    public let additionalInfo: String?
    /// 이동 거리 (미터, 도보/자동차에서만 사용)
    public let distanceMeters: Int?
    /// 자동차 경로 좌표 [[lng, lat], ...]
    public let routePoints: [[Double]]

    public init(
      type: TransportType,
      durationMinutes: Int,
      departureTime: Date,
      additionalInfo: String? = nil,
      distanceMeters: Int? = nil,
      routePoints: [[Double]] = []
    ) {
      self.type = type
      self.durationMinutes = durationMinutes
      self.departureTime = departureTime
      self.additionalInfo = additionalInfo
      self.distanceMeters = distanceMeters
      self.routePoints = routePoints
    }
  }

  /// 대중교통 경로 카테고리 태그
  public enum TransitRouteTag: String, Equatable, Sendable {
    case fastest           // 최단
    case leastTransfers    // 최소환승
    case cheapest          // 최저요금

    public var displayName: String {
      switch self {
      case .fastest: return LocalizedStrings.Home.routeTagFastest
      case .leastTransfers: return LocalizedStrings.Home.routeTagLeastTransfers
      case .cheapest: return LocalizedStrings.Home.routeTagCheapest
      }
    }
  }

  /// 대중교통 경로 옵션 (여러 경로 중 하나)
  public struct TransitRouteOption: Equatable, Sendable, Identifiable {
    public let id: Int                    // index
    public let totalTime: Int
    public let payment: Int
    public let busTransitCount: Int
    public let subwayTransitCount: Int
    public let pathType: Int
    public let departureTime: Date
    public let subPaths: [TransportSubPath]
    public let tags: [TransitRouteTag]

    public init(
      id: Int,
      totalTime: Int,
      payment: Int,
      busTransitCount: Int,
      subwayTransitCount: Int,
      pathType: Int,
      departureTime: Date,
      subPaths: [TransportSubPath],
      tags: [TransitRouteTag] = []
    ) {
      self.id = id
      self.totalTime = totalTime
      self.payment = payment
      self.busTransitCount = busTransitCount
      self.subwayTransitCount = subwayTransitCount
      self.pathType = pathType
      self.departureTime = departureTime
      self.subPaths = subPaths
      self.tags = tags
    }

    /// 총 환승 횟수
    public var transitCount: Int { busTransitCount + subwayTransitCount }
  }

  /// 대중교통 경로의 세부 구간
  public struct TransportSubPath: Equatable, Sendable {
    public let trafficType: Int           // 1=지하철, 2=버스, 3=도보
    public let sectionTime: Int
    public let distance: Int
    public let startName: String?
    public let endName: String?
    public let stationCount: Int?
    public let laneName: String?          // 대표 노선명 (2호선, 143번 등)

    public init(
      trafficType: Int,
      sectionTime: Int,
      distance: Int,
      startName: String?,
      endName: String?,
      stationCount: Int?,
      laneName: String?
    ) {
      self.trafficType = trafficType
      self.sectionTime = sectionTime
      self.distance = distance
      self.startName = startName
      self.endName = endName
      self.stationCount = stationCount
      self.laneName = laneName
    }
  }

  /// 출발 알림 시트에 표시할 전체 교통 데이터
  public struct DepartureTransportData: Equatable, Sendable {
    public let driving: TransportOption?
    public let transitRoutes: [TransitRouteOption]  // 여러 대중교통 경로
    public let walking: TransportOption
    /// 이용 가능 교통수단 (표시 순서 결정)
    public let availableTransports: Set<AvailableTransport>

    public init(
      driving: TransportOption?,
      transitRoutes: [TransitRouteOption],
      walking: TransportOption,
      availableTransports: Set<AvailableTransport> = [.transit, .car]
    ) {
      self.driving = driving
      self.transitRoutes = transitRoutes
      self.walking = walking
      self.availableTransports = availableTransports
    }

    /// 서버 응답에서 카테고리별 최적 경로를 선별 (최단/최소환승/최저요금)
    public static func categorizeTransitRoutes(
      _ routes: [TransitRouteOption]
    ) -> [TransitRouteOption] {
      guard !routes.isEmpty else { return [] }

      // 각 카테고리 최적 경로 찾기 (인덱스)
      var fastestIdx = 0
      var leastTransfersIdx = 0
      var cheapestIdx = 0

      for (i, route) in routes.enumerated() {
        if route.totalTime < routes[fastestIdx].totalTime { fastestIdx = i }
        if route.transitCount < routes[leastTransfersIdx].transitCount { leastTransfersIdx = i }
        if route.payment < routes[cheapestIdx].payment { cheapestIdx = i }
      }

      // 중복 제거 + 태그 병합
      var indexToTags: [Int: [TransitRouteTag]] = [:]
      indexToTags[fastestIdx, default: []].append(.fastest)
      indexToTags[leastTransfersIdx, default: []].append(.leastTransfers)
      indexToTags[cheapestIdx, default: []].append(.cheapest)

      // 인덱스 순서대로 정렬, 새 id 부여
      let sorted = indexToTags.sorted { $0.key < $1.key }
      return sorted.enumerated().map { (newId, entry) in
        let route = routes[entry.key]
        return TransitRouteOption(
          id: newId,
          totalTime: route.totalTime,
          payment: route.payment,
          busTransitCount: route.busTransitCount,
          subwayTransitCount: route.subwayTransitCount,
          pathType: route.pathType,
          departureTime: route.departureTime,
          subPaths: route.subPaths,
          tags: entry.value
        )
      }
    }
  }

  /// 출발 알림 설정 정보
  public struct DepartureAlertInfo: Equatable, Sendable, Codable {
    public let scheduleItemId: String  // ScheduleItem.id (schedule-xxx 또는 personal-xxx)
    public let selectedTransport: TransportType
    public let durationMinutes: Int
    public let departureTime: Date

    public init(scheduleItemId: String, selectedTransport: TransportType, durationMinutes: Int, departureTime: Date) {
      self.scheduleItemId = scheduleItemId
      self.selectedTransport = selectedTransport
      self.durationMinutes = durationMinutes
      self.departureTime = departureTime
    }
  }

  /// 출발 알림 시트의 출발지 선택
  public enum DepartureOrigin: Equatable, Sendable {
    /// 현재 GPS 위치
    case currentLocation
    /// 직전 일정 장소
    case previousSchedule(name: String, latitude: Double, longitude: Double)
  }

  /// 직전 일정 장소 정보 (출발지 선택용)
  public struct PreviousScheduleLocation: Equatable, Sendable {
    public let name: String
    public let locationName: String?
    public let latitude: Double
    public let longitude: Double

    public init(name: String, locationName: String?, latitude: Double, longitude: Double) {
      self.name = name
      self.locationName = locationName
      self.latitude = latitude
      self.longitude = longitude
    }
  }

  /// 출발 알림 시트의 에러 타입
  public enum DepartureLoadError: Equatable, Sendable {
    case locationPermission
    case general(String)
  }
}
