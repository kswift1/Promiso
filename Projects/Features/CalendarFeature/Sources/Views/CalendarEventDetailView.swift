// MARK: - CalendarEventDetailView.swift
// Apple Calendar 이벤트 상세 뷰 (순수 SwiftUI, TCA 없음)

import SwiftUI
import Clients
import PromisoShared
import SharedFeature

// MARK: - Calendar Event Detail View

struct CalendarEventDetailView: View {
  let event: CalendarEvent
  @Environment(\.openURL) private var openURL

  var body: some View {
    ScrollView {
      VStack(spacing: 24) {
        headerSection
        scheduleSection
        sourceSection
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 24)
    }
    .auroraBackground()
    .navigationBarTitleDisplayMode(.inline)
  }

  // MARK: - Header Section

  private var headerSection: some View {
    HStack(alignment: .top, spacing: 12) {
      // 이모지 (있을 때만 표시)
      if let emoji = event.displayEmoji {
        Text(emoji)
          .font(.system(size: 44))
      }

      // 제목 + 캘린더 이름
      VStack(alignment: .leading, spacing: 6) {
        Text(event.displayTitle)
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(.primary)

        HStack(spacing: 6) {
          Circle()
            .fill(event.calendarColor)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)

          Text(event.calendarName)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
      }

      Spacer()
    }
    .padding(16)
    .staticGlassBackground(cornerRadius: 16)
  }

  // MARK: - Schedule Section

  private var scheduleSection: some View {
    VStack(spacing: 0) {
      PromiseDetailSectionHeader(title: LocalizedStrings.Common.schedule)

      VStack(spacing: 0) {
        // 날짜
        PromiseDetailEmojiInfoRow(
          emoji: "📅",
          title: LocalizedStrings.Common.date,
          value: formatFullDate(event.startDate)
        )

        Divider().padding(.leading, 44)

        // 시간
        PromiseDetailEmojiInfoRow(
          emoji: "⏰",
          title: LocalizedStrings.Common.time,
          value: event.timeText
        )

        // 위치 (있는 경우)
        if let location = event.location, !location.isEmpty {
          Divider().padding(.leading, 44)

          PromiseDetailEmojiInfoRow(
            emoji: "📍",
            title: LocalizedStrings.Common.location,
            value: location
          )
        }
      }
      .staticGlassBackground(cornerRadius: 16)
    }
  }

  // MARK: - Source Section

  private var sourceSection: some View {
    Button {
      let timeInterval = event.startDate.timeIntervalSinceReferenceDate
      if let url = URL(string: "calshow:\(timeInterval)") {
        openURL(url)
      }
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "apple.logo")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.secondary)

        Text(LocalizedStrings.Calendar.calendarEventSource)
          .font(.system(size: 14))
          .foregroundStyle(.secondary)

        Spacer()

        HStack(spacing: 4) {
          Text(LocalizedStrings.Calendar.openInCalendarApp)
            .font(.system(size: 13, weight: .medium))

          Image(systemName: "chevron.right")
            .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .adaptiveGlassCard()
  }

  // MARK: - Helpers

  private func formatFullDate(_ date: Date) -> String {
    LocalizedDateFormatters.sectionHeader.string(from: date)
  }
}

// MARK: - Preview

#Preview("Calendar Event Detail") {
  NavigationStack {
    CalendarEventDetailView(
      event: CalendarEvent(
        id: "preview-1",
        title: "🎂 생일 파티",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        location: "강남역 카페",
        isAllDay: false,
        calendarName: "개인",
        calendarColorHex: "#007AFF"
      )
    )
  }
}

#Preview("Calendar Event - All Day") {
  NavigationStack {
    CalendarEventDetailView(
      event: CalendarEvent(
        id: "preview-2",
        title: "휴가",
        startDate: Date(),
        endDate: Date(),
        location: nil,
        isAllDay: true,
        calendarName: "휴일",
        calendarColorHex: "#FF9500"
      )
    )
  }
}
