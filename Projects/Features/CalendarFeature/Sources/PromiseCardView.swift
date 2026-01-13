// MARK: - PromiseCardView.swift
// 약속 카드 뷰 컴포넌트

import SwiftUI
import Clients

// MARK: - Promise Response Status UI Extension

extension PromiseResponseStatus {
  var color: Color {
    switch self {
    case .needResponse: return .yellow
    case .responded:    return .orange
    case .confirmed:    return .green
    case .failed:       return Color(UIColor.systemGray3)
    }
  }

  var icon: String {
    switch self {
    case .needResponse: return "questionmark.circle.fill"
    case .responded:    return "clock.fill"
    case .confirmed:    return "checkmark.circle.fill"
    case .failed:       return "xmark.circle.fill"
    }
  }

  var statusText: String {
    switch self {
    case .needResponse: return "응답 대기"
    case .responded:    return "투표중"
    case .confirmed:    return "확정"
    case .failed:       return "미성사"
    }
  }
}

// MARK: - Promise Card View

/// 약속 카드 (하단 리스트용)
struct PromiseCardView: View {
  let promise: PromiseModel
  let currentUserId: String
  let onTap: () -> Void
  let onRespond: (() -> Void)?

  init(
    promise: PromiseModel,
    currentUserId: String,
    onTap: @escaping () -> Void,
    onRespond: (() -> Void)? = nil
  ) {
    self.promise = promise
    self.currentUserId = currentUserId
    self.onTap = onTap
    self.onRespond = onRespond
  }

  private var responseStatus: PromiseResponseStatus {
    promise.responseStatus(currentUserId: currentUserId)
  }

  private var needsMyResponse: Bool {
    responseStatus == .needResponse
  }

  var body: some View {
    Button(action: onTap) {
      VStack(alignment: .leading, spacing: 12) {
        // 상단: 상태 + 시간
        HStack(spacing: 8) {
          // 상태 아이콘
          Image(systemName: responseStatus.icon)
            .font(.system(size: 14))
            .foregroundColor(responseStatus.color)

          // 시간
          Text(promise.timeText)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.secondary)

          Spacer()

          // 위치 (있는 경우)
          if let location = promise.location {
            HStack(spacing: 4) {
              Image(systemName: "location.fill")
                .font(.system(size: 10))
              Text(location.name)
                .font(.system(size: 12))
                .lineLimit(1)
            }
            .foregroundColor(.secondary.opacity(0.8))
            .frame(maxWidth: 120, alignment: .trailing)
          }
        }

        // 제목 행
        HStack(spacing: 8) {
          Text(promise.displayEmoji)
            .font(.system(size: 20))

          Text(promise.title)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.primary)
            .lineLimit(1)
        }

        // 하단: 참여자 + 상태 텍스트
        HStack {
          // 참여자 요약
          HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
              .font(.system(size: 11))
            Text("\(promise.votes.acceptedCount)/\(promise.minimumParticipants)")
              .font(.system(size: 13))
          }
          .foregroundColor(.secondary)

          Spacer()

          // 상태 상세 텍스트
          Text(statusDetailText)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(responseStatus.color)
        }

        // 응답하기 버튼 (필요한 경우)
        if needsMyResponse, let onRespond = onRespond {
          respondButton(action: onRespond)
        }
      }
      .padding(16)
      .background(cardBackground)
      .cornerRadius(16)
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(borderColor, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
  }

  // MARK: - Subviews

  @ViewBuilder
  private func respondButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: "hand.tap.fill")
          .font(.system(size: 12))
        Text("응답하기")
          .font(.system(size: 14, weight: .semibold))
      }
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(Color.blue)
      .cornerRadius(10)
    }
    .buttonStyle(.plain)
  }

  // MARK: - Computed Properties

  private var statusDetailText: String {
    switch responseStatus {
    case .confirmed:
      return "\(responseStatus.statusText) · \(promise.votes.acceptedCount)/\(promise.minimumParticipants)"
    case .responded:
      if let deadline = promise.deadlineText {
        return "\(responseStatus.statusText) · \(promise.votes.acceptedCount)/\(promise.minimumParticipants) · 마감 \(deadline)"
      }
      return "\(responseStatus.statusText) · \(promise.votes.acceptedCount)/\(promise.minimumParticipants)"
    case .needResponse:
      return "내 응답 대기중"
    case .failed:
      return "약속 미성사"
    }
  }

  private var cardBackground: Color {
    switch responseStatus {
    case .needResponse:
      return Color.yellow.opacity(0.08)
    case .responded:
      return Color.orange.opacity(0.06)
    case .confirmed:
      return Color(.secondarySystemBackground)
    case .failed:
      return Color(.systemGray6)
    }
  }

  private var borderColor: Color {
    switch responseStatus {
    case .needResponse:
      return Color.yellow.opacity(0.3)
    case .responded:
      return Color.orange.opacity(0.2)
    case .confirmed:
      return Color(.separator).opacity(0.3)
    case .failed:
      return Color(.separator).opacity(0.2)
    }
  }
}

// MARK: - Cached Formatters

private enum PromiseViewFormatterCache {
  static let shortWeekday: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "E"
    return formatter
  }()
}

private let promiseViewCalendar = Calendar.current

// MARK: - Compact Day Row (약속 + 캘린더 이벤트 통합)

/// 월간 뷰용 컴팩트 행 (약속과 캘린더 이벤트 모두 표시)
struct CompactDayRow: View {
  let date: Date
  let promises: [PromiseModel]
  let calendarEvents: [CalendarEvent]
  let isSelected: Bool
  let currentUserId: String
  let onTap: () -> Void

  init(
    date: Date,
    promises: [PromiseModel],
    calendarEvents: [CalendarEvent],
    isSelected: Bool,
    currentUserId: String = "",
    onTap: @escaping () -> Void
  ) {
    self.date = date
    self.promises = promises
    self.calendarEvents = calendarEvents
    self.isSelected = isSelected
    self.currentUserId = currentUserId
    self.onTap = onTap
  }

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // 날짜
        VStack(spacing: 2) {
          ZStack {
            if isSelected {
              Circle()
                .fill(Color.blue)
                .frame(width: 32, height: 32)
            }
            Text(dayNumber)
              .font(.system(size: 18, weight: .bold))
              .foregroundColor(dateTextColor)
          }
          Text(weekday)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(isSelected ? .blue : .secondary)
        }
        .frame(width: 36)

        // 구분선
        Rectangle()
          .fill(Color(.separator).opacity(0.3))
          .frame(width: 1, height: 32)

        // 일정 요약
        VStack(alignment: .leading, spacing: 4) {
          // 약속이 있으면 약속 먼저 표시
          if let firstPromise = promises.first {
            HStack(spacing: 8) {
              Text(firstPromise.displayEmoji)
                .font(.system(size: 16))

              VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                  Text(firstPromise.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                  if promises.count > 1 {
                    Text("외 \(promises.count - 1)건")
                      .font(.system(size: 12))
                      .foregroundColor(.secondary)
                  }
                }

                Text(firstPromise.timeText)
                  .font(.system(size: 12))
                  .foregroundColor(.secondary)
              }
            }
          }

          // 캘린더 이벤트가 있으면 표시
          if !calendarEvents.isEmpty {
            HStack(spacing: 6) {
              Circle()
                .fill(Color.gray)
                .frame(width: 6, height: 6)

              if let firstEvent = calendarEvents.first {
                Text(firstEvent.title)
                  .font(.system(size: 13))
                  .foregroundColor(.secondary)
                  .lineLimit(1)

                if calendarEvents.count > 1 {
                  Text("외 \(calendarEvents.count - 1)건")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                }
              }
            }
          }
        }

        Spacer()

        // 화살표
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundColor(.secondary.opacity(0.5))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .background(rowBackground)
      .cornerRadius(12)
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(isSelected ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1.5)
      )
    }
    .buttonStyle(.plain)
    .padding(.horizontal, 16)
    .padding(.vertical, 4)
  }

  // MARK: - Computed Properties

  private var dayNumber: String {
    String(promiseViewCalendar.component(.day, from: date))
  }

  private var weekday: String {
    PromiseViewFormatterCache.shortWeekday.string(from: date)
  }

  private var isToday: Bool {
    promiseViewCalendar.isDateInToday(date)
  }

  private var dateTextColor: Color {
    if isSelected {
      return .white
    }
    if isToday {
      return .blue
    }
    return .primary
  }

  private var rowBackground: Color {
    if isSelected {
      return Color.blue.opacity(0.08)
    }
    return Color(.secondarySystemBackground).opacity(0.5)
  }
}

// MARK: - Empty Day Placeholder

/// 약속이 없는 날 표시
struct EmptyDayPlaceholder: View {
  let date: Date

  var body: some View {
    HStack {
      Text("약속이 없습니다")
        .font(.system(size: 15))
        .foregroundColor(.secondary)
      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 20)
  }
}

// MARK: - Preview

#Preview("Promise Card - Confirmed") {
  let promise = PromiseModel(
    id: "1",
    title: "점심 약속",
    emoji: "🍽️",
    hostId: "user1",
    groupId: "group1",
    minimumParticipants: 2,
    votes: PromiseVotesModel(
      accepted: ["user1", "user2"],
      declined: [],
      until: Date()
    ),
    startAt: Date(),
    location: LocationInfoModel(name: "강남역 맛집")
  )

  PromiseCardView(
    promise: promise,
    currentUserId: "user1",
    onTap: {}
  )
  .padding()
}

#Preview("Promise Card - Needs Response") {
  let promise = PromiseModel(
    id: "2",
    title: "카페 데이트",
    emoji: "☕",
    hostId: "user2",
    groupId: "group1",
    minimumParticipants: 2,
    votes: PromiseVotesModel(
      accepted: ["user2"],
      declined: [],
      until: Date().addingTimeInterval(3600)
    ),
    startAt: Date().addingTimeInterval(86400),
    location: LocationInfoModel(name: "스타벅스 신촌점")
  )

  PromiseCardView(
    promise: promise,
    currentUserId: "user1",
    onTap: {},
    onRespond: {}
  )
  .padding()
}
