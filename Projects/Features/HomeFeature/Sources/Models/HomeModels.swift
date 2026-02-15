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

    public var id: String {
      switch self {
      case .promise(let p): return "promise-\(p.id)"
      case .personalEvent(let e): return "personal-\(e.id)"
      }
    }

    public var startAt: Date {
      switch self {
      case .promise(let p): return p.startAt
      case .personalEvent(let e): return e.startAt
      }
    }

    public var endAt: Date? {
      switch self {
      case .promise(let p): return p.endAt
      case .personalEvent(let e): return e.endAt
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
      }
    }

    public var title: String {
      switch self {
      case .promise(let p): return p.title
      case .personalEvent(let e): return e.title
      }
    }

    public var location: LocationInfoModel? {
      switch self {
      case .promise(let p): return p.location
      case .personalEvent(let e): return e.location
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
      KoreanDateFormatters.date.string(from: day)
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
