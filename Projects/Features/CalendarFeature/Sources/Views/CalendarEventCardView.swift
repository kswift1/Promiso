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
      .contentShape(Rectangle())
      .adaptiveGlassBackground()
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Personal Event Card View

/// 개인 일정 카드 (약속/시스템 캘린더와 시각적으로 구분)
struct PersonalEventCardView: View {
  let event: PersonalEventModel
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        // 인디고 인디케이터
        RoundedRectangle(cornerRadius: 2)
          .fill(Color.pmindigo.n500)
          .frame(width: 4, height: 44)

        VStack(alignment: .leading, spacing: 4) {
          // 개인 일정 라벨
          HStack(spacing: 4) {
            Image(systemName: "person.fill")
              .font(.system(size: 10))
              .foregroundColor(Color.pmindigo.n500)

            Text("개인 일정")
              .font(.system(size: 11, weight: .medium))
              .foregroundColor(Color.pmindigo.n500)
          }

          // 이모지 + 제목
          HStack(spacing: 6) {
            Text(event.displayEmoji)
              .font(.system(size: 16))

            Text(event.title)
              .font(.system(size: 15, weight: .medium))
              .foregroundColor(.primary)
              .lineLimit(1)
          }

          // 시간 + 위치
          HStack(spacing: 8) {
            Text(event.timeText)
              .font(.system(size: 13))
              .foregroundColor(.secondary)

            if let location = event.location {
              HStack(spacing: 2) {
                Image(systemName: "location.fill")
                  .font(.system(size: 10))
                Text(location.name)
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
      .contentShape(Rectangle())
      .adaptiveGlassBackground()
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Calendar Permission Banner

/// 캘린더 권한 요청 배너
struct CalendarPermissionBanner: View {
  let permissionStatus: CalendarAuthorizationStatus
  let onRequestPermission: () -> Void
  let onOpenSettings: () -> Void
  let onDismiss: () -> Void

  @State private var dontShowAgain = false

  var body: some View {
    switch permissionStatus {
    case .notDetermined:
      bannerContent(
        icon: "calendar.badge.plus",
        iconColor: Color.pmindigo.n500,
        title: "시스템 캘린더 연동",
        message: "시스템 캘린더 일정을 함께 표시하세요",
        buttonLabel: "연동하기",
        buttonColor: Color.pmindigo.n500,
        buttonAction: onRequestPermission
      )
    case .writeOnly:
      bannerContent(
        icon: "calendar.badge.exclamationmark",
        iconColor: Color.pmpurple.n400,
        title: "읽기 권한 필요",
        message: "시스템 캘린더를 읽으려면 전체 액세스가 필요해요",
        buttonLabel: "설정",
        buttonColor: Color.pmpurple.n500,
        buttonAction: onOpenSettings
      )
    case .denied, .restricted:
      bannerContent(
        icon: "calendar.badge.exclamationmark",
        iconColor: Color.pmpurple.n600,
        title: "캘린더 권한 필요",
        message: "시스템 캘린더 접근을 위해선 권한이 필요해요",
        buttonLabel: "설정",
        buttonColor: Color.pmpurple.n600,
        buttonAction: onOpenSettings
      )
    default:
      EmptyView()
    }
  }

  private func bannerContent(
    icon: String,
    iconColor: Color,
    title: String,
    message: String,
    buttonLabel: String,
    buttonColor: Color,
    buttonAction: @escaping () -> Void
  ) -> some View {
    VStack(spacing: 8) {
      // 메인 컨텐츠
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.system(size: 24))
          .foregroundColor(iconColor)

        VStack(alignment: .leading, spacing: 2) {
          Text(title)
            .font(.system(size: 15, weight: .semibold))
          Text(message)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
        }

        Spacer()

        Button(buttonLabel) {
          buttonAction()
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(buttonColor)
        .cornerRadius(8)
      }

      // 다시 보지 않기 체크박스 (우측 하단)
      HStack {
        Spacer()
        Button {
          dontShowAgain.toggle()
          if dontShowAgain {
            onDismiss()
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: dontShowAgain ? "checkmark.square.fill" : "square")
              .font(.system(size: 12))
            Text("다시 보지 않기")
              .font(.system(size: 11))
          }
          .foregroundColor(.secondary)
        }
      }
    }
    .padding(16)
    .adaptiveGlassBackground()
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
    onOpenSettings: {},
    onDismiss: {}
  )
}

#Preview("Permission Banner - Write Only") {
  CalendarPermissionBanner(
    permissionStatus: .writeOnly,
    onRequestPermission: {},
    onOpenSettings: {},
    onDismiss: {}
  )
}

#Preview("Permission Banner - Denied") {
  CalendarPermissionBanner(
    permissionStatus: .denied,
    onRequestPermission: {},
    onOpenSettings: {},
    onDismiss: {}
  )
}
