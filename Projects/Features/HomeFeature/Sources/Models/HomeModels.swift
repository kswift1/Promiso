import Foundation
import PromisoShared

// MARK: - Overview Data

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

// MARK: - Timeline Section

public struct TimelineSection: Equatable, Identifiable {
  public let day: Date               // startOfDay로 정규화
  public let promises: [PromiseModel]

  public var id: String { dayKey }   // "2026-01-26" 형식 (타임존 안전)

  private var dayKey: String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: day)
  }

  public init(day: Date, promises: [PromiseModel]) {
    self.day = day
    self.promises = promises
  }
}

// MARK: - Status Filter

public enum StatusFilter: String, Equatable, CaseIterable, Sendable {
  case all = "전체"
  case needResponse = "응답 필요"
  case confirmed = "확정됨"
  case inProgress = "진행 중"
}

// MARK: - Scroll Target

public enum ScrollTarget: Equatable {
  case needResponse          // 응답 필요 첫 번째 섹션으로
  case date(Date)            // 특정 날짜로 (향후 "오늘로 스크롤" 등)
}

// MARK: - Hero Data (홈 상단 "지금 가장 중요한 약속")

public struct HeroData: Equatable {
  public let priority: HeroPriority
  public let promise: PromiseModel

  public init(priority: HeroPriority, promise: PromiseModel) {
    self.priority = priority
    self.promise = promise
  }

  /// Hero 우선순위 (LiveActivity는 BottomAccessoryView에서 처리하므로 제외)
  public enum HeroPriority: Int, Comparable, Equatable, Sendable {
    case departureSoon = 1    // T-30분 이내 임박 약속
    case todayNext = 2        // 오늘 가장 가까운 확정 약속
    case needResponse = 3     // 응답 필요한 약속 중 가장 빠른 것

    public static func < (lhs: HeroPriority, rhs: HeroPriority) -> Bool {
      lhs.rawValue < rhs.rawValue
    }

    public var displayTitle: String {
      switch self {
      case .departureSoon: "출발 임박"
      case .todayNext: "다음 약속"
      case .needResponse: "응답 필요"
      }
    }

    public var iconName: String {
      switch self {
      case .departureSoon: "clock.badge.exclamationmark"
      case .todayNext: "calendar.badge.clock"
      case .needResponse: "hand.raised.fill"
      }
    }
  }
}

// MARK: - Quick Insights Data

public struct QuickInsightsData: Equatable {
  public let todayCount: Int
  public let needResponseCount: Int
  public let thisWeekCount: Int

  public init(todayCount: Int, needResponseCount: Int, thisWeekCount: Int) {
    self.todayCount = todayCount
    self.needResponseCount = needResponseCount
    self.thisWeekCount = thisWeekCount
  }
}

public enum InsightType: String, CaseIterable, Equatable, Sendable {
  case today = "오늘"
  case needResponse = "응답 필요"
  case thisWeek = "이번 주"

  public var iconName: String {
    switch self {
    case .today: "calendar"
    case .needResponse: "exclamationmark.bubble"
    case .thisWeek: "calendar.badge.plus"
    }
  }

  public var accentColor: String {
    switch self {
    case .today: "pmindigo"
    case .needResponse: "pmaurora"
    case .thisWeek: "green"
    }
  }
}
