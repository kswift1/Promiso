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
  @Environment(\.scenePhase) private var scenePhase

  let groupName: String
  let photoData: Data?
  let notificationEnabled: Bool
  let calendarSyncEnabled: Bool
  let notificationAuthStatus: NotificationAuthorizationStatus
  let calendarAuthStatus: CalendarAuthorizationStatus
  let isSaving: Bool
  let showCalendarPermissionInfoAlert: Bool
  let selectedGroupColor: GroupColor?
  let existingGroupColorMap: [GroupColor: String]
  let onNotificationToggle: (Bool) -> Void
  let onCalendarSyncToggle: (Bool) -> Void
  let onGroupColorSelected: (GroupColor?) -> Void
  let onComplete: () -> Void
  let onCalendarPermissionInfoAlertDismiss: () -> Void
  let onAppear: () -> Void

  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        Spacer()
          .frame(height: 8)

        // Header
        headerSection

        // Group Color
        groupColorSection

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
    .onChange(of: scenePhase) { _, newPhase in
      // 시스템 설정에서 돌아올 때 권한 상태 새로고침
      if newPhase == .active {
        onAppear()
      }
    }
    .alert(
      LocalizedStrings.GroupSettings.calendarPermissionTitle,
      isPresented: .constant(showCalendarPermissionInfoAlert),
      actions: {
        Button(LocalizedStrings.Common.ok) {
          onCalendarPermissionInfoAlertDismiss()
        }
      },
      message: {
        Text(LocalizedStrings.GroupSettings.calendarPermissionMessage)
      }
    )
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 12) {
      ZStack {
        if let photoData, let uiImage = UIImage(data: photoData) {
          Image(uiImage: uiImage)
            .resizable()
            .scaledToFill()
            .frame(width: 72, height: 72)
            .clipShape(Circle())
        } else {
          Circle()
            .fill(Color.pmindigo.n100.opacity(0.5))
            .frame(width: 72, height: 72)
            .overlay {
              Text(String(groupName.prefix(1)))
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Color.pmindigo.n500)
            }
        }
      }
      .overlay(
        Circle()
          .strokeBorder(
            (selectedGroupColor ?? .purple).color,
            lineWidth: 3
          )
          .frame(width: 72, height: 72)
      )

      Text(LocalizedStrings.GroupSettings.settingsHeaderTitle(groupName))
        .font(.title3.bold())
    }
  }

  // MARK: - Settings Section

  private var settingsSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      // 통합 헤더
      VStack(alignment: .leading, spacing: 4) {
        Text(LocalizedStrings.GroupSettings.notificationSectionTitle)
          .font(.system(size: 16, weight: .semibold))

        Text(LocalizedStrings.GroupSettings.notificationSectionSubtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      // 알림 설정
      notificationSettingRow

      Divider()

      // 캘린더 동기화 설정
      calendarSettingRow

      // 변경 가능 힌트
      Text(LocalizedStrings.GroupSettings.changeableHint)
        .font(.caption2)
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
    .padding(20)
    .staticGlassBackground(cornerRadius: 20)
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
        Text(LocalizedStrings.GroupSettings.pushNotification)
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
      return LocalizedStrings.GroupSettings.notificationDenied
    }
    return LocalizedStrings.GroupSettings.notificationDescription
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
          Text(LocalizedStrings.GroupSettings.calendarSync)
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
        ? LocalizedStrings.GroupSettings.calendarDeniedSyncOn
        : LocalizedStrings.GroupSettings.calendarDeniedSyncOff
    case .writeOnly, .fullAccess, .authorized, .notDetermined:
      return LocalizedStrings.GroupSettings.calendarDescription
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

  // MARK: - Group Color Section

  private var groupColorSection: some View {
    VStack(alignment: .leading, spacing: 16) {
      // 섹션 헤더
      VStack(alignment: .leading, spacing: 4) {
        HStack(spacing: 8) {
          Image(systemName: "paintpalette.fill")
            .font(.system(size: 16))
            .foregroundStyle(
              LinearGradient(
                colors: [Color.pmindigo.n500, Color.pmaurora.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              )
            )
          Text(LocalizedStrings.GroupSettings.groupColorSectionTitle)
            .font(.system(size: 16, weight: .semibold))
        }

        Text(LocalizedStrings.GroupSettings.groupColorSectionSubtitle)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      // 색상 그리드 (4열)
      let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
      ]

      LazyVGrid(columns: columns, spacing: 12) {
        ForEach(GroupColor.allCases, id: \.self) { color in
          groupColorCell(color)
        }
      }
    }
    .padding(20)
    .staticGlassBackground(cornerRadius: 20)
  }

  private func groupColorCell(_ color: GroupColor) -> some View {
    let isSelected = selectedGroupColor == color
    let usedByGroupName = existingGroupColorMap[color]

    return Button {
      if isSelected {
        onGroupColorSelected(nil)
      } else {
        onGroupColorSelected(color)
      }
    } label: {
      VStack(spacing: 4) {
        ZStack {
          Circle()
            .fill(color.color)
            .frame(width: 44, height: 44)

          if isSelected {
            Circle()
              .strokeBorder(.white, lineWidth: 3)
              .frame(width: 44, height: 44)

            Image(systemName: "checkmark")
              .font(.system(size: 14, weight: .bold))
              .foregroundStyle(.white)
          }

          if usedByGroupName != nil && !isSelected {
            Circle()
              .fill(.black.opacity(0.3))
              .frame(width: 44, height: 44)
          }
        }

        Text(color.displayName)
          .font(.system(size: 10))
          .foregroundStyle(isSelected ? .primary : .secondary)
          .lineLimit(1)

        if let groupName = usedByGroupName, !isSelected {
          Text("'\(groupName)' 사용중")
            .font(.system(size: 8))
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
      }
      .frame(height: 82)
    }
    .buttonStyle(.plain)
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
          Text(isSaving ? LocalizedStrings.GroupSettings.saving : LocalizedStrings.GroupSettings.complete)
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

      Text(LocalizedStrings.GroupSettings.changeableHint)
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .padding(.horizontal, 24)
    .padding(.top, 16)
    .padding(.bottom, 16)
    .background(
      LinearGradient(
        stops: [
          .init(color: Color(.systemBackground).opacity(0), location: 0),
          .init(color: Color(.systemBackground).opacity(0.8), location: 0.15),
          .init(color: Color(.systemBackground), location: 0.3),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea(.container, edges: .bottom)
    )
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    CreateGroupSettingsView(
      groupName: "대학 친구들",
      photoData: nil,
      notificationEnabled: true,
      calendarSyncEnabled: true,
      notificationAuthStatus: .authorized,
      calendarAuthStatus: .writeOnly,
      isSaving: false,
      showCalendarPermissionInfoAlert: false,
      selectedGroupColor: .purple,
      existingGroupColorMap: [.blue: "회사", .green: "동아리"],
      onNotificationToggle: { _ in },
      onCalendarSyncToggle: { _ in },
      onGroupColorSelected: { _ in },
      onComplete: {},
      onCalendarPermissionInfoAlertDismiss: {},
      onAppear: {}
    )
    .auroraBackground()
  }
}
