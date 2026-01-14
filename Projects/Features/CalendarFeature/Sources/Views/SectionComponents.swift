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
    KoreanDateFormatters.sectionHeader.string(from: date)
  }
}

// MARK: - Adaptive Glass Section Background

extension View {
  @ViewBuilder
  func adaptiveGlassSectionBackground() -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(.regular, in: .rect)
    } else {
      self
        .background(.ultraThinMaterial)
    }
  }
}

// MARK: - Rounded Corner Shape

struct RoundedCorner: Shape {
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

  var id: String {
    switch self {
    case .promise(let promise):
      return "promise_\(promise.id)"
    case .calendarEvent(let event):
      return "event_\(event.id)"
    }
  }

  var startTime: Date {
    switch self {
    case .promise(let promise):
      return promise.startAt
    case .calendarEvent(let event):
      return event.startDate
    }
  }
}
