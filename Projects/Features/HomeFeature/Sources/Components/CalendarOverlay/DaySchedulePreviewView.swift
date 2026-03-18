import SwiftUI
import PromisoShared
import ResourceKit

// MARK: - Day Schedule Preview View

/// 월간 캘린더 날짜 꾹 누르기 contextMenu 프리뷰
/// 해당 날짜의 일정 목록을 타임라인 카드 스타일로 표시
struct DaySchedulePreviewView: View {
  let day: OverlayCalendarModels.DayItem

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // 날짜 헤더 (예: 2월 25일 화요일)
      Text(dateHeaderString)
        .font(.system(size: 16, weight: .bold))
        .foregroundStyle(.primary)

      if day.scheduleIndicators.isEmpty {
        // 빈 상태
        Text(LocalizedStrings.Calendar.noSchedules)
          .font(.system(size: 14))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
          .padding(.vertical, 20)
      } else {
        // 일정 카드 목록
        ForEach(day.scheduleIndicators) { indicator in
          scheduleCard(indicator)
        }
      }
    }
    .padding(16)
    .frame(width: 300)
    .background(Color(.systemBackground))
  }

  // MARK: - Schedule Card

  /// 각 일정 카드 — DayTimelineView scheduleBlock 스타일
  private func scheduleCard(_ indicator: OverlayCalendarModels.ScheduleIndicator) -> some View {
    let shape = RoundedRectangle(cornerRadius: 10)

    return HStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 2) {
        // Row 1: 이모지 + 제목
        HStack(spacing: 5) {
          if let emoji = indicator.emoji {
            Text(emoji)
              .font(.system(size: 14))
          }
          Text(indicator.title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
        }

        // Row 2: 시간
        Text(timeRangeString(indicator))
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 8)

      Spacer(minLength: 0)
    }
    .background(.ultraThinMaterial, in: shape)
    .overlay(shape.strokeBorder(.white.opacity(0.2), lineWidth: 1))
    .overlay(alignment: .leading) {
      UnevenRoundedRectangle(
        topLeadingRadius: 10,
        bottomLeadingRadius: 10,
        bottomTrailingRadius: 0,
        topTrailingRadius: 0
      )
      .fill(indicator.color)
      .frame(width: 4)
    }
    .clipShape(shape)
  }

  // MARK: - Helpers

  /// 시간 포맷 — 오늘이 아닌 날짜는 월일 포함
  private func timeRangeString(_ indicator: OverlayCalendarModels.ScheduleIndicator) -> String {
    let isToday = Calendar.scheduleDisplay.isDateInToday(day.date)
    let startStr = isToday
      ? Formatters.time.string(from: indicator.startAt)
      : Formatters.dateTime.string(from: indicator.startAt)
    if let endAt = indicator.endAt {
      let endStr = isToday
        ? Formatters.time.string(from: endAt)
        : Formatters.dateTime.string(from: endAt)
      return "\(startStr) ~ \(endStr)"
    }
    return startStr
  }

  /// 날짜 헤더 포맷 (M월 d일 EEEE)
  private var dateHeaderString: String {
    Formatters.dateHeader.string(from: day.date)
  }

  // MARK: - Formatters

  private enum Formatters {
    static let displayTimeZone = Calendar.scheduleDisplay.timeZone

    static let time: DateFormatter = {
      let f = DateFormatter()
      f.locale = Locale(identifier: "en_US_POSIX")
      f.timeZone = displayTimeZone
      f.dateFormat = "HH:mm"
      return f
    }()

    static let dateTime: DateFormatter = {
      let f = DateFormatter()
      f.locale = .current
      f.timeZone = displayTimeZone
      f.setLocalizedDateFormatFromTemplate("M/d HH:mm")
      return f
    }()

    static let dateHeader: DateFormatter = {
      let f = DateFormatter()
      f.locale = .current
      f.timeZone = displayTimeZone
      f.setLocalizedDateFormatFromTemplate("MMMdEEEE")
      return f
    }()
  }
}
