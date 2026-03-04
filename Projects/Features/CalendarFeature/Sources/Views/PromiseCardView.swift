// MARK: - PromiseCardView.swift
// 약속 카드 뷰 컴포넌트

import SwiftUI
import Clients
import ResourceKit
import PromisoShared

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
    case .needResponse: return LocalizedStrings.Calendar.statusWaiting
    case .responded:    return LocalizedStrings.Calendar.statusVoting
    case .confirmed:    return LocalizedStrings.Calendar.statusConfirmed
    case .failed:       return LocalizedStrings.Calendar.statusFailed
    }
  }
}

// MARK: - Promise Card View

/// 약속 카드 (하단 리스트용)
struct PromiseCardView: View {
  let promise: PromiseModel
  let currentUserId: String
  let weather: WeatherInfo?
  let onTap: () -> Void
  let onRespond: (() -> Void)?

  init(
    promise: PromiseModel,
    currentUserId: String,
    weather: WeatherInfo? = nil,
    onTap: @escaping () -> Void,
    onRespond: (() -> Void)? = nil
  ) {
    self.promise = promise
    self.currentUserId = currentUserId
    self.weather = weather
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
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 12) {
          // 왼쪽: 상태 컬러 바
          RoundedRectangle(cornerRadius: 2)
            .fill(responseStatus.color)
            .frame(width: 4)

          // 메인 콘텐츠
          VStack(alignment: .leading, spacing: 8) {
          // 상단: 시간 + 상태 + 그룹 + 참여자
          HStack(spacing: 6) {
            Text(promise.timeText)
              .font(.system(size: 14, weight: .medium))
              .foregroundColor(.secondary)

            Text("·")
              .foregroundColor(.secondary.opacity(0.5))

            Text(responseStatus.statusText)
              .font(.system(size: 13, weight: .medium))
              .foregroundColor(responseStatus.color)

            Spacer()

            // 그룹 썸네일 + 그룹명 + 참여자 수
            if let group = promise.group {
              HStack(spacing: 4) {
                GroupThumbnailView(
                  imageUrl: group.imageUrl,
                  name: group.name,
                  size: 24
                )

                Text(group.name)
                  .font(.system(size: 13, weight: .medium))
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
            }
          }

          // 제목 행
          HStack(spacing: 8) {
            Text(promise.displayEmoji)
              .font(.system(size: 18))

            Text(promise.title)
              .font(.system(size: 16, weight: .semibold))
              .foregroundColor(.primary)
              .lineLimit(1)
          }

          // 위치
          if let location = promise.location {
            HStack(spacing: 4) {
              Image(systemName: "location.fill")
                .font(.system(size: 10))
              Text(location.name)
                .font(.system(size: 13))
                .lineLimit(1)
            }
            .foregroundColor(.secondary.opacity(0.8))
          }

          // 실시간 공유 (과거 약속은 표시 안 함)
          if let minutes = promise.trackingStartMinutesBefore, !promise.isPast {
            HStack(spacing: 4) {
              Text("📡")
                .font(.system(size: 10))
              Text(LocalizedStrings.Shared.liveStartMinutes(minutes))
                .font(.system(size: 13))
                .lineLimit(1)
            }
            .foregroundColor(.secondary.opacity(0.8))
          }

          // 응답하기 버튼 (필요한 경우)
          if needsMyResponse, let onRespond = onRespond {
            respondButton(action: onRespond)
          }
        }
        }

        // 날씨
        if let weather = weather,
           let forecast = weather.forecast(for: promise.startAt) {
          WeatherCardStrip(
            forecast: forecast,
            rangeForecasts: weather.forecasts(from: promise.startAt, to: promise.endAt),
            referenceTimeText: promise.startAt.formattedMonthDayTime,
            forecastSource: weather.forecastSource(for: promise.startAt)
          )
          .padding(.top, 8)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
      .adaptiveGlassBackground()
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Subviews

extension PromiseCardView {
  @ViewBuilder
  fileprivate func respondButton(action: @escaping () -> Void) -> some View {
    Button(action: action) {
      HStack(spacing: 8) {
        Image(systemName: "hand.tap.fill")
          .font(.system(size: 14, weight: .medium))
        Text(LocalizedStrings.Calendar.respondAction)
          .font(.system(size: 15, weight: .semibold))
      }
      .foregroundColor(.white)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 12)
      .adaptiveGlassRespondButton()
    }
    .buttonStyle(.plain)
  }
}

private let promiseViewCalendar = Calendar.current

// MARK: - Compact Day Row (약속 + 캘린더 이벤트 통합)

/// 월간 뷰용 컴팩트 행 (약속과 캘린더 이벤트 모두 표시)
struct CompactDayRow: View {
  let date: Date
  let promises: [PromiseModel]
  let calendarEvents: [CalendarEvent]
  let personalEvents: [PersonalEventModel]
  let isSelected: Bool
  let currentUserId: String
  let onTap: () -> Void

  init(
    date: Date,
    promises: [PromiseModel],
    calendarEvents: [CalendarEvent],
    personalEvents: [PersonalEventModel] = [],
    isSelected: Bool,
    currentUserId: String = "",
    onTap: @escaping () -> Void
  ) {
    self.date = date
    self.promises = promises
    self.calendarEvents = calendarEvents
    self.personalEvents = personalEvents
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
                .fill(Color.pmindigo.n500)
                .frame(width: 32, height: 32)
            }
            Text(dayNumber)
              .font(.system(size: 18, weight: .bold))
              .foregroundColor(dateTextColor)
          }
          Text(weekday)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(isSelected ? Color.pmindigo.n500 : .secondary)
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
                    Text(LocalizedStrings.Calendar.additionalItems(promises.count - 1))
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

          // 개인 일정이 있으면 표시
          if !personalEvents.isEmpty {
            HStack(spacing: 6) {
              Circle()
                .fill(Color.pmindigo.n500)
                .frame(width: 6, height: 6)

              if let firstEvent = personalEvents.first {
                Text("\(firstEvent.displayEmoji) \(firstEvent.title)")
                  .font(.system(size: 13))
                  .foregroundColor(.secondary)
                  .lineLimit(1)

                if personalEvents.count > 1 {
                  Text(LocalizedStrings.Calendar.additionalItems(personalEvents.count - 1))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.7))
                }
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
                  Text(LocalizedStrings.Calendar.additionalItems(calendarEvents.count - 1))
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
      .contentShape(Rectangle())
      .adaptiveGlassBackground()
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
    LocalizedDateFormatters.weekday.string(from: date)
  }

  private var isToday: Bool {
    promiseViewCalendar.isDateInToday(date)
  }

  private var dateTextColor: Color {
    if isSelected {
      return .white
    }
    if isToday {
      return Color.pmindigo.n500
    }
    return .primary
  }
}

// MARK: - Empty Day Placeholder

/// 약속이 없는 날 표시
struct EmptyDayPlaceholder: View {
  let date: Date

  var body: some View {
    HStack {
      Text(LocalizedStrings.Calendar.noPromises)
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
  let sampleGroup = GroupModel(
    id: "group1",
    name: "가족 모임",
    memberIds: ["user1", "user2"],
    maxMembers: 10,
    inviteCode: "ABC123",
    createdBy: "user1",
    createdAt: Date(),
    updatedAt: Date()
  )

  let promise = PromiseModel(
    id: "1",
    title: "점심 약속",
    emoji: "🍽️",
    hostId: "user1",
    groupId: "group1",
    group: sampleGroup,
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
  let sampleGroup = GroupModel(
    id: "group1",
    name: "친구들",
    memberIds: ["user1", "user2"],
    maxMembers: 10,
    inviteCode: "XYZ789",
    createdBy: "user2",
    createdAt: Date(),
    updatedAt: Date()
  )

  let promise = PromiseModel(
    id: "2",
    title: "카페 데이트",
    emoji: "☕",
    hostId: "user2",
    groupId: "group1",
    group: sampleGroup,
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
