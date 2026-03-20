// MARK: - CalendarHeader.swift
// 캘린더 헤더 컴포넌트

import SwiftUI
import ResourceKit
import PromisoShared

// MARK: - Calendar Header

struct CalendarHeader: View {
  let title: String
  let displayMode: CalendarDisplayMode
  let isSelectedDateToday: Bool
  let isFilterActive: Bool
  let isShowingGuideTooltip: Bool
  let onGuideTapped: () -> Void
  let onFilterTapped: () -> Void
  let onToggleMode: () -> Void
  let onSetMode: (CalendarDisplayMode) -> Void
  let onMoveToToday: () -> Void
  let onMovePrevious: () -> Void
  let onMoveNext: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      // < 타이틀 > 네비게이션
      HStack(spacing: 0) {
        Button(action: onMovePrevious) {
          Image(systemName: "chevron.left")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 28, height: 36)
        }

        Text(title)
          .font(.system(size: 18, weight: .bold).monospacedDigit())
          .foregroundStyle(.primary)
          .fixedSize(horizontal: true, vertical: false)
          .contentTransition(.numericText())
          .animation(.spring(duration: 0.3), value: title)

        Button(action: onMoveNext) {
          Image(systemName: "chevron.right")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.primary)
            .frame(width: 28, height: 36)
        }
      }

      Spacer(minLength: 4)

      // 오늘 버튼
      if !isSelectedDateToday {
        Button(action: onMoveToToday) {
          Text(LocalizedStrings.Common.today)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.pmindigo.n500)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.pmindigo.n500.opacity(0.1))
            .cornerRadius(8)
        }
        .fixedSize()
      }

      // 가이드
      Button(action: onGuideTapped) {
        Image(systemName: "questionmark.circle")
          .font(.system(size: 18))
          .foregroundStyle(.primary)
          .frame(width: 32, height: 36)
      }
      .overlay(alignment: .bottom) {
        if isShowingGuideTooltip {
          GuideTooltip()
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }

      // 필터
      Button(action: onFilterTapped) {
        Image(systemName: isFilterActive
          ? "line.3.horizontal.decrease.circle.fill"
          : "line.3.horizontal.decrease.circle")
          .font(.system(size: 18))
          .foregroundColor(isFilterActive ? Color.pmindigo.n500 : .primary)
          .frame(width: 32, height: 36)
      }

      // 모드 전환 (탭: 순환, 꾹 누르기: 메뉴)
      Menu {
        ForEach(CalendarDisplayMode.allCases, id: \.self) { mode in
          Button {
            onSetMode(mode)
          } label: {
            Label(mode.label, systemImage: mode.iconName)
          }
          .disabled(mode == displayMode)
        }
      } label: {
        Image(systemName: displayMode.iconName)
          .font(.system(size: 18))
          .foregroundStyle(.primary)
          .frame(width: 32, height: 36)
          .contentShape(Rectangle())
      } primaryAction: {
        onToggleMode()
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

// MARK: - Weekday Header

struct WeekdayHeader: View {
  @AppStorage(AppConstants.UserDefaults.calendarStartOnMonday) private var calendarStartOnMonday = true

  private var weekdaySymbols: [String] {
    LocalizedStrings.Calendar.orderedWeekdaySymbols(startOnMonday: calendarStartOnMonday)
  }

  var body: some View {
    HStack(spacing: 0) {
      ForEach(weekdaySymbols, id: \.self) { symbol in
        Text(symbol)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(weekdayColor(for: symbol))
          .frame(maxWidth: .infinity)
      }
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 8)
  }

  private func weekdayColor(for symbol: String) -> Color {
    if symbol == LocalizedStrings.Calendar.weekdaySun { return .red.opacity(0.8) }
    if symbol == LocalizedStrings.Calendar.weekdaySat { return .blue.opacity(0.8) }
    return .secondary
  }
}

// MARK: - Guide Tooltip

private struct GuideTooltip: View {
  var body: some View {
    Text(LocalizedStrings.Calendar.guideTooltip)
      .font(.caption)
      .foregroundStyle(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color.pmindigo.n700, in: RoundedRectangle(cornerRadius: 8))
      .overlay(alignment: .top) {
        // 말풍선 꼬리
        Triangle()
          .fill(Color.pmindigo.n700)
          .frame(width: 12, height: 6)
          .offset(y: -6)
      }
      .offset(y: 42)
      .fixedSize()
  }
}

private struct Triangle: SwiftUI.Shape {
  func path(in rect: CGRect) -> SwiftUI.Path {
    var path = SwiftUI.Path()
    path.move(to: CGPoint(x: rect.midX, y: rect.minY))
    path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    path.closeSubpath()
    return path
  }
}
