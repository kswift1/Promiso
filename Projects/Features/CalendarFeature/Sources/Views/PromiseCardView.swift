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
    case .expired:      return Color(UIColor.systemGray3)
    case .responded:    return .orange
    case .confirmed:    return .green
    case .failed:       return Color(UIColor.systemGray3)
    }
  }

  var icon: String {
    switch self {
    case .needResponse: return "questionmark.circle.fill"
    case .expired:      return "clock.badge.xmark"
    case .responded:    return "clock.fill"
    case .confirmed:    return "checkmark.circle.fill"
    case .failed:       return "xmark.circle.fill"
    }
  }

  var statusText: String {
    switch self {
    case .needResponse: return LocalizedStrings.Calendar.statusWaiting
    case .expired:      return "마감됨"
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
            Text(promise.timeRangeText)
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

          // 설명
          if let description = promise.description, !description.isEmpty {
            Text(description)
              .font(.system(size: 14))
              .foregroundColor(.secondary)
              .lineLimit(3)
          }

          // 이미지
          if !promise.imageUrls.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 6) {
                ForEach(promise.imageUrls.prefix(4), id: \.self) { urlString in
                  if let url = URL(string: urlString) {
                    ScheduleItemThumbnail(url: url, size: 64, placeholder: Color.gray.opacity(0.15))
                  }
                }
                if promise.imageUrls.count > 4 {
                  Text("+\(promise.imageUrls.count - 4)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(width: 64, height: 64)
                    .background(Color.gray.opacity(0.15), in: RoundedRectangle(cornerRadius: 8))
                }
              }
            }
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
enum CompactDayRowItem: Identifiable, Equatable {
  case promise(PromiseModel)
  case personalEvent(PersonalEventModel)
  case calendarEvent(CalendarEvent)
  case recurringPersonalEvent(ExpandedEventInstance)

  var id: String {
    switch self {
    case .promise(let promise):
      return "promise_\(promise.id)"
    case .personalEvent(let event):
      return "personal_\(event.id)"
    case .calendarEvent(let event):
      return "calendar_\(event.id)"
    case .recurringPersonalEvent(let event):
      return "recurring_\(event.id)"
    }
  }

  static func sortedItems(
    for date: Date,
    promises: [PromiseModel],
    calendarEvents: [CalendarEvent],
    personalEvents: [PersonalEventModel],
    recurringPersonalEvents: [ExpandedEventInstance] = []
  ) -> [CompactDayRowItem] {
    let dayStart = Calendar.current.startOfDay(for: date)

    return (
      promises.map(CompactDayRowItem.promise) +
      personalEvents.map(CompactDayRowItem.personalEvent) +
      calendarEvents.map(CompactDayRowItem.calendarEvent) +
      recurringPersonalEvents.map(CompactDayRowItem.recurringPersonalEvent)
    )
    .sorted { lhs, rhs in
      let lhsDisplayStart = lhs.displayStartAt(on: dayStart)
      let rhsDisplayStart = rhs.displayStartAt(on: dayStart)

      if lhsDisplayStart != rhsDisplayStart {
        return lhsDisplayStart < rhsDisplayStart
      }
      if lhs.originalStartAt != rhs.originalStartAt {
        return lhs.originalStartAt < rhs.originalStartAt
      }
      if lhs.kindPriority != rhs.kindPriority {
        return lhs.kindPriority < rhs.kindPriority
      }
      return lhs.id < rhs.id
    }
  }

  private var originalStartAt: Date {
    switch self {
    case .promise(let promise):
      return promise.startAt
    case .personalEvent(let event):
      return event.startAt
    case .calendarEvent(let event):
      return event.startDate
    case .recurringPersonalEvent(let event):
      return event.startAt
    }
  }

  private var kindPriority: Int {
    switch self {
    case .promise:
      return 0
    case .personalEvent:
      return 1
    case .recurringPersonalEvent:
      return 1
    case .calendarEvent:
      return 2
    }
  }

  private func displayStartAt(on dayStart: Date) -> Date {
    max(originalStartAt, dayStart)
  }
}

struct CompactDayRow: View {
  let date: Date
  let promises: [PromiseModel]
  let calendarEvents: [CalendarEvent]
  let personalEvents: [PersonalEventModel]
  var recurringPersonalEvents: [ExpandedEventInstance] = []
  let isSelected: Bool
  let currentUserId: String
  var holidayName: String? = nil
  var groupColorMap: [String: Color] = [:]
  let onDateTap: () -> Void
  var onPromiseTap: ((PromiseModel) -> Void)? = nil
  var onPersonalEventTap: ((PersonalEventModel) -> Void)? = nil
  var onCalendarEventTap: ((CalendarEvent) -> Void)? = nil
  var onRecurringPersonalEventTap: ((ExpandedEventInstance) -> Void)? = nil
  var onCreatePersonalEvent: (() -> Void)? = nil
  var onCreatePromise: (() -> Void)? = nil

  init(
    date: Date,
    promises: [PromiseModel],
    calendarEvents: [CalendarEvent],
    personalEvents: [PersonalEventModel] = [],
    recurringPersonalEvents: [ExpandedEventInstance] = [],
    isSelected: Bool,
    currentUserId: String = "",
    holidayName: String? = nil,
    groupColorMap: [String: Color] = [:],
    onDateTap: @escaping () -> Void,
    onPromiseTap: ((PromiseModel) -> Void)? = nil,
    onPersonalEventTap: ((PersonalEventModel) -> Void)? = nil,
    onCalendarEventTap: ((CalendarEvent) -> Void)? = nil,
    onRecurringPersonalEventTap: ((ExpandedEventInstance) -> Void)? = nil,
    onCreatePersonalEvent: (() -> Void)? = nil,
    onCreatePromise: (() -> Void)? = nil
  ) {
    self.date = date
    self.promises = promises
    self.calendarEvents = calendarEvents
    self.personalEvents = personalEvents
    self.recurringPersonalEvents = recurringPersonalEvents
    self.isSelected = isSelected
    self.currentUserId = currentUserId
    self.holidayName = holidayName
    self.groupColorMap = groupColorMap
    self.onDateTap = onDateTap
    self.onPromiseTap = onPromiseTap
    self.onPersonalEventTap = onPersonalEventTap
    self.onCalendarEventTap = onCalendarEventTap
    self.onRecurringPersonalEventTap = onRecurringPersonalEventTap
    self.onCreatePersonalEvent = onCreatePersonalEvent
    self.onCreatePromise = onCreatePromise
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // 날짜 헤더 — 탭하면 타임라인으로 전환
      Button(action: onDateTap) {
        HStack(spacing: 12) {
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

          if isToday {
            Text("오늘")
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(Color.pmindigo.n500)
          }

          if let holidayName {
            Text(holidayName)
              .font(.system(size: 13, weight: .medium))
              .foregroundColor(.red.opacity(0.8))
              .lineLimit(1)
          }

          Spacer()

          Image(systemName: "chevron.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.secondary.opacity(0.5))
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)

      // 일정 목록
      let allItems = CompactDayRowItem.sortedItems(
        for: date,
        promises: promises,
        calendarEvents: calendarEvents,
        personalEvents: personalEvents,
        recurringPersonalEvents: recurringPersonalEvents
      )
      if !allItems.isEmpty {
        Divider()
          .opacity(0.4)
          .padding(.top, 10)
          .padding(.bottom, 2)

        VStack(alignment: .leading, spacing: 0) {
          ForEach(Array(allItems.enumerated()), id: \.element.id) { index, item in
            if index > 0 {
              Divider().opacity(0.3)
            }
            rowView(for: item)
              .padding(.vertical, 8)
          }
        }
      }

      // 일정 생성 메뉴 (오늘 이후만, 최하단 오른쪽)
      if canCreateEvent {
        HStack {
          Spacer()
          Menu {
            Button {
              onCreatePersonalEvent?()
            } label: {
              Label("개인 일정 추가", systemImage: "person.fill")
            }
            Button {
              onCreatePromise?()
            } label: {
              Label("그룹 일정 추가", systemImage: "person.3.fill")
            }
          } label: {
            HStack(spacing: 4) {
              Image(systemName: "plus")
                .font(.system(size: 11, weight: .semibold))
              Text("일정 추가")
                .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(Color.pmindigo.n500)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .adaptiveGlassBackground()
          }
        }
        .padding(.top, 6)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .contentShape(Rectangle())
    .adaptiveGlassBackground()
    .padding(.horizontal, 16)
    .padding(.vertical, 4)
  }

  // MARK: - Item Builder

  @ViewBuilder
  private func rowView(for item: CompactDayRowItem) -> some View {
    switch item {
    case .promise(let promise):
      promiseRow(promise)
    case .personalEvent(let event):
      personalEventRow(event)
    case .calendarEvent(let event):
      calendarEventRow(event)
    case .recurringPersonalEvent(let event):
      recurringPersonalEventRow(event)
    }
  }

  @ViewBuilder
  private func promiseRow(_ promise: PromiseModel) -> some View {
    let groupColor = groupColorMap[promise.groupId]

    Button {
      onPromiseTap?(promise)
    } label: {
      HStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 1)
          .fill(groupColor ?? Color.pmindigo.n500)
          .frame(width: 3)

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(promise.displayEmoji)
              .font(.system(size: 16))
            Text(promise.title)
              .font(.system(size: 15, weight: .medium))
              .foregroundColor(.primary)
              .lineLimit(1)
            Spacer()
            HStack(spacing: 4) {
              if let group = promise.group {
                GroupThumbnailView(
                  imageUrl: group.imageUrl,
                  name: group.name,
                  size: 14
                )
                Text(group.name)
                  .font(.system(size: 12))
                  .foregroundColor(.secondary)
                  .lineLimit(1)
                Text("·")
                  .font(.system(size: 12))
                  .foregroundColor(.secondary.opacity(0.5))
              }
              Text(unifiedStatusText(for: promise))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(unifiedStatusColor(for: promise))
            }
          }
          HStack(spacing: 4) {
            Text(promise.timeRangeText)
              .font(.system(size: 12))
              .foregroundColor(.secondary)
            if let location = promise.location {
              Text("·")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.5))
              Text(location.name)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        RoundedRectangle(cornerRadius: 6)
          .fill(promise.responseStatus(currentUserId: currentUserId) == .needResponse
            ? Color.pmwarning.n500.opacity(0.08)
            : Color.clear)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func personalEventRow(_ event: PersonalEventModel) -> some View {
    Button {
      onPersonalEventTap?(event)
    } label: {
      HStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 1)
          .fill(Color.pmindigo.n500)
          .frame(width: 3)

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(event.displayEmoji)
              .font(.system(size: 16))
            Text(event.title)
              .font(.system(size: 15, weight: .medium))
              .foregroundColor(.primary)
              .lineLimit(1)
            Spacer()
            Text("개인")
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(Color.pmindigo.n500)
          }
          HStack(spacing: 4) {
            Text(event.timeRangeText)
              .font(.system(size: 12))
              .foregroundColor(.secondary)
            if let location = event.location {
              Text("·")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.5))
              Text(location.name)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func calendarEventRow(_ event: CalendarEvent) -> some View {
    Button {
      onCalendarEventTap?(event)
    } label: {
      HStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 1)
          .fill(event.calendarColor)
          .frame(width: 3)

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(event.title)
              .font(.system(size: 15, weight: .medium))
              .foregroundColor(.primary)
              .lineLimit(1)
            Spacer()
            Text(event.calendarName)
              .font(.system(size: 12))
              .foregroundColor(.secondary)
              .lineLimit(1)
          }
          HStack(spacing: 4) {
            if event.isAllDay {
              Text("종일")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            } else {
              Text(event.timeText)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            if let location = event.location, !location.isEmpty {
              Text("·")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.5))
              Text(location)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private func recurringPersonalEventRow(_ event: ExpandedEventInstance) -> some View {
    Button {
      onRecurringPersonalEventTap?(event)
    } label: {
      HStack(spacing: 8) {
        RoundedRectangle(cornerRadius: 1)
          .fill(Color.pmindigo.n500)
          .frame(width: 3)

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(event.emoji ?? "🔄")
              .font(.system(size: 16))
            Text(event.title)
              .font(.system(size: 15, weight: .medium))
              .foregroundColor(.primary)
              .lineLimit(1)
            Spacer()
            Text("반복")
              .font(.system(size: 12, weight: .medium))
              .foregroundColor(Color.pmindigo.n500)
          }
          HStack(spacing: 4) {
            Text(recurringEventTimeText(event))
              .font(.system(size: 12))
              .foregroundColor(.secondary)
            if let location = event.location {
              Text("·")
                .font(.system(size: 12))
                .foregroundColor(.secondary.opacity(0.5))
              Text(location.name)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
            }
          }
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(Color.clear)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func recurringEventTimeText(_ event: ExpandedEventInstance) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    let start = formatter.string(from: event.startAt)
    if let endAt = event.endAt {
      let end = formatter.string(from: endAt)
      return "\(start) ~ \(end)"
    }
    return start
  }


  // MARK: - Unified Status (필터와 통일)

  private func unifiedStatusText(for promise: PromiseModel) -> String {
    let status = promise.responseStatus(currentUserId: currentUserId)
    switch status {
    case .needResponse: return "응답 필요"
    case .expired: return "마감됨"
    case .responded: return "확정 대기"
    case .confirmed:
      return promise.isPast ? "완료" : "확정"
    case .failed: return "불발"
    }
  }

  private func unifiedStatusColor(for promise: PromiseModel) -> Color {
    let status = promise.responseStatus(currentUserId: currentUserId)
    switch status {
    case .needResponse: return Color.pmwarning.n500
    case .expired: return Color.pmgray.n500
    case .responded: return Color.pminfo.n500
    case .confirmed:
      return promise.isPast ? Color.pmgray.n500 : Color.pmsuccess.n500
    case .failed: return Color.pmerror.n500
    }
  }

  // MARK: - Create Event

  private var canCreateEvent: Bool {
    let calendar = Calendar.current
    let endOfDay = calendar.startOfDay(for: date).addingTimeInterval(86400)
    return endOfDay > Date()
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
    if holidayName != nil {
      return .red.opacity(0.8)
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
    description: "강남역 근처에서 점심 먹어요! 메뉴는 현장에서 정해요.",
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
    location: LocationInfoModel(name: "강남역 맛집"),
    imageUrls: ["https://example.com/photo1.jpg", "https://example.com/photo2.jpg"]
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
