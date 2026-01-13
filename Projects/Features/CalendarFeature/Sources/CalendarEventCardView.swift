// MARK: - CalendarEventCardView.swift
// 시스템 캘린더 이벤트 카드 뷰

import SwiftUI
import Clients

// MARK: - Calendar Event Card View

/// 시스템 캘린더 이벤트 카드 (약속 카드와 시각적으로 구분)
struct CalendarEventCardView: View {
  let event: CalendarEvent
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // 캘린더 색상 인디케이터
        RoundedRectangle(cornerRadius: 2)
          .fill(event.calendarColor)
          .frame(width: 4, height: 44)

        VStack(alignment: .leading, spacing: 4) {
          // 캘린더 이름 + 시스템 아이콘
          HStack(spacing: 4) {
            Image(systemName: "calendar")
              .font(.system(size: 10))
              .foregroundColor(.secondary)

            Text(event.calendarName)
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(.secondary)
          }

          // 제목
          Text(event.title)
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(.primary)
            .lineLimit(1)

          // 시간 + 위치
          HStack(spacing: 8) {
            Text(event.timeText)
              .font(.system(size: 13))
              .foregroundColor(.secondary)

            if let location = event.location, !location.isEmpty {
              HStack(spacing: 2) {
                Image(systemName: "location.fill")
                  .font(.system(size: 10))
                Text(location)
                  .font(.system(size: 12))
                  .lineLimit(1)
              }
              .foregroundColor(.secondary.opacity(0.8))
            }
          }
        }

        Spacer()
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .adaptiveGlassBackground()
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Adaptive Glass Background

private extension View {
  @ViewBuilder
  func adaptiveGlassBackground() -> some View {
    if #available(iOS 26.0, *) {
      self
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
    } else {
      self
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
  }
}

// MARK: - Calendar Permission Banner

/// 캘린더 권한 요청 배너
struct CalendarPermissionBanner: View {
  let permissionStatus: CalendarAuthorizationStatus
  let onRequestPermission: () -> Void
  let onOpenSettings: () -> Void

  var body: some View {
    switch permissionStatus {
    case .notDetermined:
      requestPermissionBanner
    case .denied, .restricted:
      deniedPermissionBanner
    default:
      EmptyView()
    }
  }

  private var requestPermissionBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "calendar.badge.plus")
        .font(.system(size: 24))
        .foregroundColor(.blue)

      VStack(alignment: .leading, spacing: 2) {
        Text("캘린더 연동")
          .font(.system(size: 15, weight: .semibold))
        Text("시스템 캘린더 일정을 함께 표시하세요")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }

      Spacer()

      Button("연동하기") {
        onRequestPermission()
      }
      .font(.system(size: 14, weight: .semibold))
      .foregroundColor(.white)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Color.blue)
      .cornerRadius(8)
    }
    .padding(16)
    .background(Color.blue.opacity(0.08))
    .cornerRadius(12)
    .padding(.horizontal, 16)
  }

  private var deniedPermissionBanner: some View {
    HStack(spacing: 12) {
      Image(systemName: "calendar.badge.exclamationmark")
        .font(.system(size: 24))
        .foregroundColor(.orange)

      VStack(alignment: .leading, spacing: 2) {
        Text("캘린더 권한 필요")
          .font(.system(size: 15, weight: .semibold))
        Text("설정에서 캘린더 접근을 허용해주세요")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }

      Spacer()

      Button("설정") {
        onOpenSettings()
      }
      .font(.system(size: 14, weight: .semibold))
      .foregroundColor(.orange)
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Color.orange.opacity(0.15))
      .cornerRadius(8)
    }
    .padding(16)
    .background(Color.orange.opacity(0.08))
    .cornerRadius(12)
    .padding(.horizontal, 16)
  }
}

// MARK: - Preview

#Preview("Calendar Event Card") {
  VStack(spacing: 16) {
    CalendarEventCardView(
      event: CalendarEvent(
        id: "1",
        title: "팀 미팅",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        location: "회의실 A",
        isAllDay: false,
        calendarName: "업무",
        calendarColorHex: "#007AFF"
      ),
      onTap: {}
    )

    CalendarEventCardView(
      event: CalendarEvent(
        id: "2",
        title: "점심 약속",
        startDate: Date(),
        endDate: Date().addingTimeInterval(3600),
        location: nil,
        isAllDay: false,
        calendarName: "개인",
        calendarColorHex: "#34C759"
      ),
      onTap: {}
    )

    CalendarEventCardView(
      event: CalendarEvent(
        id: "3",
        title: "휴가",
        startDate: Date(),
        endDate: Date(),
        location: nil,
        isAllDay: true,
        calendarName: "휴일",
        calendarColorHex: "#FF9500"
      ),
      onTap: {}
    )
  }
  .padding()
}

#Preview("Permission Banner - Not Determined") {
  CalendarPermissionBanner(
    permissionStatus: .notDetermined,
    onRequestPermission: {},
    onOpenSettings: {}
  )
}

#Preview("Permission Banner - Denied") {
  CalendarPermissionBanner(
    permissionStatus: .denied,
    onRequestPermission: {},
    onOpenSettings: {}
  )
}
