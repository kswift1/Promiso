import Foundation
import PromisoShared

// MARK: - Home Models Namespace

public enum HomeModels {}

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
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd"
      return formatter.string(from: day)
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
