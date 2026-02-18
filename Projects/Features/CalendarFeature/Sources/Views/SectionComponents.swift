// MARK: - SectionComponents.swift
// 캘린더 섹션 관련 컴포넌트

import SwiftUI
import SharedFeature

// MARK: - Diary Style Section Header

struct DiaryStyleSectionHeader: View {
  let date: Date

  var body: some View {
    HStack {
      Text(formattedDate)
        .font(.system(size: 20, weight: .bold))
        .foregroundColor(.primary)
        .textCase(nil)

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .adaptiveGlassSectionBackground()
  }

  private var formattedDate: String {
    LocalizedDateFormatters.sectionHeader.string(from: date)
  }
}

// MARK: - Rounded Corner Shape

struct RoundedCorner: SwiftUI.Shape {
  var radius: CGFloat = .infinity
  var corners: UIRectCorner = .allCorners

  func path(in rect: CGRect) -> Path {
    let path = UIBezierPath(
      roundedRect: rect,
      byRoundingCorners: corners,
      cornerRadii: CGSize(width: radius, height: radius)
    )
    return Path(path.cgPath)
  }
}

// MARK: - Calendar List Item (통합 정렬용)

import Clients

/// 약속과 캘린더 이벤트를 통합하여 시간순 정렬하기 위한 타입
enum CalendarListItem: Identifiable {
  case promise(PromiseModel)
  case calendarEvent(CalendarEvent)
  case personalEvent(PersonalEventModel)

  var id: String {
    switch self {
    case .promise(let promise):
      return "promise_\(promise.id)"
    case .calendarEvent(let event):
      return "event_\(event.id)"
    case .personalEvent(let event):
      return "personal_\(event.id)"
    }
  }

  var startTime: Date {
    switch self {
    case .promise(let promise):
      return promise.startAt
    case .calendarEvent(let event):
      return event.startDate
    case .personalEvent(let event):
      return event.startAt
    }
  }
}
