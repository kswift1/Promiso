import Clients
import Foundation
import PromisoShared

// MARK: - Home Models Namespace

public enum HomeModels {}

// MARK: - Schedule Item (통합 일정 아이템)

extension HomeModels {
  /// 홈 화면에서 그룹 약속과 개인 일정을 통합 표시하기 위한 타입
  public enum ScheduleItem: Identifiable, Equatable {
    case promise(PromiseModel)
    case personalEvent(PersonalEventModel)
    case recurringPersonalEvent(ExpandedEventInstance)

    public var id: String {
      switch self {
      case .promise(let p): return "promise-\(p.id)"
      case .personalEvent(let e): return "personal-\(e.id)"
      case .recurringPersonalEvent(let e): return "recurring-\(e.id)"
      }
    }

    public var startAt: Date {
      switch self {
      case .promise(let p): return p.startAt
      case .personalEvent(let e): return e.startAt
      case .recurringPersonalEvent(let e): return e.startAt
      }
    }

    public var endAt: Date? {
      switch self {
      case .promise(let p): return p.endAt
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
      case .promise(let p): return p.displayEmoji
      case .personalEvent(let e): return e.displayEmoji
      case .recurringPersonalEvent(let e): return e.emoji ?? "🔄"
      }
    }

    public var title: String {
      switch self {
      case .promise(let p): return p.title
      case .personalEvent(let e): return e.title
      case .recurringPersonalEvent(let e): return e.title
      }
    }

    public var location: LocationInfoModel? {
      switch self {
      case .promise(let p): return p.location
      case .personalEvent(let e): return e.location
      case .recurringPersonalEvent(let e): return e.location
      }
    }
  }
}

// MARK: - Overview Data

extension HomeModels {
  public struct OverviewData: Equatable {
    public let todayCount: Int
    public let nextPromise: PromiseModel?
    public let needResponseCount: Int

    public init(
      todayCount: Int,
      nextPromise: PromiseModel?,
      needResponseCount: Int
    ) {
      self.todayCount = todayCount
      self.nextPromise = nextPromise
      self.needResponseCount = needResponseCount
    }
  }
}

// MARK: - Timeline Section

extension HomeModels {
  public struct TimelineSection: Equatable, Identifiable {
    public let day: Date               // startOfDay로 정규화
    public let promises: [PromiseModel]

    public var id: String { dayKey }   // "2026-01-26" 형식 (타임존 안전)

    private var dayKey: String {
      LocalizedDateFormatters.date.string(from: day)
    }

    public init(day: Date, promises: [PromiseModel]) {
      self.day = day
      self.promises = promises
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
    case all = "전체"
    case needResponse = "응답 필요"
    case confirmed = "확정됨"
    case inProgress = "진행 중"

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
    public let promise: PromiseModel

    public init(reason: CriticalReason, promise: PromiseModel) {
      self.reason = reason
      self.promise = promise
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

// MARK: - Departure Alert

extension HomeModels {
  /// 교통수단 타입
  public enum TransportType: String, Equatable, CaseIterable, Sendable {
    case driving
    case transit
    case walking

    public var displayName: String {
      switch self {
      case .driving: return "자동차"
      case .transit: return "대중교통"
      case .walking: return "도보"
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
    public let departureTime: Date
    public let additionalInfo: String?

    public init(type: TransportType, durationMinutes: Int, departureTime: Date, additionalInfo: String? = nil) {
      self.type = type
      self.durationMinutes = durationMinutes
      self.departureTime = departureTime
      self.additionalInfo = additionalInfo
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

    public init(
      id: Int,
      totalTime: Int,
      payment: Int,
      busTransitCount: Int,
      subwayTransitCount: Int,
      pathType: Int,
      departureTime: Date,
      subPaths: [TransportSubPath]
    ) {
      self.id = id
      self.totalTime = totalTime
      self.payment = payment
      self.busTransitCount = busTransitCount
      self.subwayTransitCount = subwayTransitCount
      self.pathType = pathType
      self.departureTime = departureTime
      self.subPaths = subPaths
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

    public init(
      driving: TransportOption?,
      transitRoutes: [TransitRouteOption],
      walking: TransportOption
    ) {
      self.driving = driving
      self.transitRoutes = transitRoutes
      self.walking = walking
    }
  }

  /// 출발 알림 설정 정보
  public struct DepartureAlertInfo: Equatable, Sendable {
    public let scheduleItemId: String  // ScheduleItem.id (promise-xxx 또는 personal-xxx)
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
}
