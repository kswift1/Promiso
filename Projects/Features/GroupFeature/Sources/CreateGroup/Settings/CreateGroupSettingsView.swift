//
//  CreateGroupSettingsView.swift
//  GroupFeature
//
//  그룹 생성/합류 후 초기 설정 화면
//

import SwiftUI
import PromisoShared
import Clients

struct CreateGroupSettingsView: View {
  let groupName: String
  let notificationEnabled: Bool
  let calendarSyncEnabled: Bool
  let notificationAuthStatus: NotificationAuthorizationStatus
  let calendarAuthStatus: CalendarAuthorizationStatus
  let isSaving: Bool
  let showCalendarPermissionInfoAlert: Bool
  let onNotificationToggle: (Bool) -> Void
  let onCalendarSyncToggle: (Bool) -> Void
  let onComplete: () -> Void
  let onSkip: () -> Void
  let onCalendarPermissionInfoAlertDismiss: () -> Void
  let onAppear: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        Spacer()
          .frame(height: 20)

        // Header
        headerSection

        // Settings
        settingsSection

        Spacer()
          .frame(height: 20)
      }
      .padding(.horizontal, 24)
    }
    .safeAreaInset(edge: .bottom) {
      bottomButtons
    }
    .navigationBarBackButtonHidden()
    .onAppear {
      onAppear()
    }
    .alert(
      "캘린더 권한 안내",
      isPresented: .constant(showCalendarPermissionInfoAlert),
      actions: {
        Button("확인") {
          onCalendarPermissionInfoAlertDismiss()
        }
      },
      message: {
        Text("설정이 저장되었습니다.\n캘린더 동기화를 사용하려면 나중에 시스템 설정에서 캘린더 권한을 허용해주세요.")
      }
    )
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 16) {
      ZStack {
        Circle()
          .fill(
            LinearGradient(
              colors: [Color.pmindigo.n200.opacity(0.3), Color.pmaurora.purple.opacity(0.2)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 100, height: 100)

        Image(systemName: "gearshape.2.fill")
          .font(.system(size: 44))
          .foregroundStyle(
            LinearGradient(
              colors: [Color.pmindigo.n500, Color.pmaurora.purple],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }

      VStack(spacing: 8) {
        Text("'\(groupName)' 알림 설정")
          .font(.title2.bold())

        Text("이 그룹의 알림과 캘린더 동기화를\n설정해주세요")
          .font(.body)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
          .lineSpacing(4)
      }
    }
  }

  // MARK: - Settings Section

  private var settingsSection: some View {
    VStack(spacing: 16) {
      // 알림 설정
      notificationSettingRow

      Divider()
        .padding(.horizontal, 16)

      // 캘린더 동기화 설정
      calendarSettingRow
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 20)
        .fill(Color(.systemBackground))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
    )
  }

  private var notificationSettingRow: some View {
    HStack(spacing: 16) {
      ZStack {
        RoundedRectangle(cornerRadius: 10)
          .fill(
            LinearGradient(
              colors: [Color.orange.opacity(0.15), Color.yellow.opacity(0.15)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 44, height: 44)

        Image(systemName: "bell.fill")
          .font(.system(size: 20))
          .foregroundStyle(
            LinearGradient(
              colors: [.orange, .yellow],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }

      VStack(alignment: .leading, spacing: 4) {
        Text("푸시 알림")
          .font(.headline)

        Text(notificationSubtitle)
          .font(.caption)
          .foregroundStyle(notificationSubtitleColor)
      }

      Spacer()

      Toggle("", isOn: Binding(
        get: { notificationEnabled },
        set: { onNotificationToggle($0) }
      ))
      .labelsHidden()
      .tint(Color.pmindigo.n500)
    }
  }

  private var notificationSubtitle: String {
    if notificationAuthStatus == .denied {
      return "권한 없음 - 토글 시 설정으로 이동"
    }
    return "새로운 약속 초대, 일정 변경, 리마인더를 알려드려요"
  }

  private var notificationSubtitleColor: Color {
    if notificationAuthStatus == .denied {
      return .orange
    }
    return .secondary
  }

  private var calendarSettingRow: some View {
    HStack(spacing: 16) {
      ZStack {
        RoundedRectangle(cornerRadius: 10)
          .fill(
            LinearGradient(
              colors: [Color.blue.opacity(0.15), Color.cyan.opacity(0.15)],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .frame(width: 44, height: 44)

        Image(systemName: "calendar")
          .font(.system(size: 20))
          .foregroundStyle(
            LinearGradient(
              colors: [.blue, .cyan],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
      }

      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 6) {
          Text("캘린더 동기화")
            .font(.headline)

          if !calendarAuthStatus.canWriteEvents && calendarSyncEnabled {
            permissionWarningBadge
          }
        }

        Text(calendarSubtitle)
          .font(.caption)
          .foregroundStyle(calendarSubtitleColor)
      }

      Spacer()

      Toggle("", isOn: Binding(
        get: { calendarSyncEnabled },
        set: { onCalendarSyncToggle($0) }
      ))
      .labelsHidden()
      .tint(Color.pmindigo.n500)
    }
  }

  private var calendarSubtitle: String {
    switch calendarAuthStatus {
    case .denied, .restricted:
      return calendarSyncEnabled
        ? "권한 없음 - 설정에서 허용하면 동기화가 시작돼요"
        : "권한 없음 - 토글 ON 후 설정에서 허용 필요"
    case .writeOnly, .fullAccess, .authorized, .notDetermined:
      return "확정된 약속을 기기 캘린더에 자동으로 추가해요"
    }
  }

  private var calendarSubtitleColor: Color {
    switch calendarAuthStatus {
    case .denied, .restricted:
      return .orange
    default:
      return .secondary
    }
  }

  private var permissionWarningBadge: some View {
    Image(systemName: "exclamationmark.triangle.fill")
      .font(.system(size: 12))
      .foregroundStyle(.orange)
  }

  // MARK: - Bottom Buttons

  private var bottomButtons: some View {
    VStack(spacing: 12) {
      Button(action: onComplete) {
        HStack(spacing: 8) {
          if isSaving {
            ProgressView()
              .tint(.white)
          }
          Text(isSaving ? "저장 중..." : "설정 완료")
            .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color.pmindigo.n500)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
          color: Color.pmindigo.n500.opacity(0.2),
          radius: 10,
          x: 0,
          y: 6
        )
      }
      .disabled(isSaving)

      Button(action: onSkip) {
        Text("건너뛰기")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      .disabled(isSaving)

      Text("나중에 그룹 설정에서 변경할 수 있어요")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 24)
    .padding(.vertical, 16)
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    CreateGroupSettingsView(
      groupName: "대학 친구들",
      notificationEnabled: true,
      calendarSyncEnabled: true,
      notificationAuthStatus: .authorized,
      calendarAuthStatus: .writeOnly,
      isSaving: false,
      showCalendarPermissionInfoAlert: false,
      onNotificationToggle: { _ in },
      onCalendarSyncToggle: { _ in },
      onComplete: {},
      onSkip: {},
      onCalendarPermissionInfoAlertDismiss: {},
      onAppear: {}
    )
    .auroraBackground()
  }
}
