import Foundation
import Shared

// MARK: - Promise Response Status
public enum PromiseResponseStatus: String, Equatable, Sendable, Codable {
  case needResponse  // 답변 필요
  case confirmed     // 확정됨
  case sent          // 응답 대기
}

// MARK: - Attendance Status
public enum PromiseAttendanceStatus: String, Equatable, Sendable, Codable {
  case accepted
  case declined
  case tentative
}

// MARK: - Promise Item

/// Feature에서 사용하는 Promise 모델
public struct PromiseItem: Identifiable, Equatable, Sendable {
  public let id: String
  public let title: String
  public let emoji: String
  public let time: String
  public let date: String
  public let location: String
  public let distance: String?
  public let with: String
  public let status: PromiseResponseStatus
  public let responses: PromiseResponse?
  public let deadline: String?

  public init(
    id: String,
    title: String,
    emoji: String,
    time: String,
    date: String,
    location: String,
    distance: String? = nil,
    with: String,
    status: PromiseResponseStatus,
    responses: PromiseResponse? = nil,
    deadline: String? = nil
  ) {
    self.id = id
    self.title = title
    self.emoji = emoji
    self.time = time
    self.date = date
    self.location = location
    self.distance = distance
    self.with = with
    self.status = status
    self.responses = responses
    self.deadline = deadline
  }
  
  // FIXME:
  public init(domainModel: PromiseModel) {
    self.id = domainModel.id
    self.title = domainModel.title
    self.emoji = domainModel.emoji?.isEmpty == false ? domainModel.emoji! : "📌"
    self.time = Self.timeText(from: domainModel.startAt)
    self.date = Self.dateText(from: domainModel.startAt)
    self.location = domainModel.location?.name ?? "장소 미정"
    self.distance = nil
    self.with = domainModel.host.nickname.isEmpty
      ? domainModel.group.name
      : domainModel.host.nickname
    self.status = Self.responseStatus(from: domainModel)
    if domainModel.counts.total > 0 {
      self.responses = PromiseResponse(
        current: domainModel.counts.accepted,
        total: domainModel.counts.total
      )
    } else {
      self.responses = nil
    }
    self.deadline = nil
  }

  private static func responseStatus(from model: PromiseModel) -> PromiseResponseStatus {
    if model.status == .active || model.isConfirmed {
      return .confirmed
    }

    if model.counts.pending > 0 {
      return .needResponse
    }

    return .sent
  }

  private static func timeText(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }

  private static func dateText(from date: Date) -> String {
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return "오늘"
    }

    if calendar.isDateInTomorrow(date) {
      return "내일"
    }

    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일"
    return formatter.string(from: date)
  }
}

// MARK: - Promise Response

public struct PromiseResponse: Equatable, Sendable {
  public let current: Int
  public let total: Int

  public init(current: Int, total: Int) {
    self.current = current
    self.total = total
  }
}

public extension PromiseItem {
  static let exampleArr: [Self] = [
    PromiseItem(
      id: "1",
      title: "카페 데이트",
      emoji: "☕",
      time: "오후 2:00",
      date: "오늘",
      location: "스타벅스 강남점",
      distance: "1.2km",
      with: "지민",
      status: .needResponse,
      responses: PromiseResponse(current: 0, total: 2),
      deadline: "3시간 후"
    ),
    PromiseItem(
      id: "2",
      title: "저녁 식사",
      emoji: "🍽️",
      time: "오후 7:00",
      date: "오늘",
      location: "이탈리안 레스토랑",
      distance: "2.5km",
      with: "지민",
      status: .confirmed,
      responses: PromiseResponse(current: 2, total: 2),
      deadline: nil
    ),
    PromiseItem(
      id: "3",
      title: "영화 보기",
      emoji: "🎬",
      time: "오후 3:00",
      date: "내일",
      location: "CGV 강남",
      distance: "3.1km",
      with: "지민",
      status: .sent,
      responses: PromiseResponse(current: 1, total: 2),
      deadline: nil
    ),
    PromiseItem(
      id: "4",
      title: "런닝",
      emoji: "🏃",
      time: "오전 7:00",
      date: "토요일",
      location: "한강공원",
      distance: "5.0km",
      with: "지민",
      status: .needResponse,
      responses: PromiseResponse(current: 0, total: 2),
      deadline: "1일 후"
    ),
  ]
}
