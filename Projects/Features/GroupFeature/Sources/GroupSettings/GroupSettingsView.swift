import ComposableArchitecture
import Clients
import PromisoShared
import SwiftUI
import PhotosUI
import UIKit
import ResourceKit


extension GroupSettings {
  public struct View: SwiftUI.View {
    @Bindable var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some SwiftUI.View {
      content
        .navigationTitle(LocalizedStrings.GroupSettingsView.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button(LocalizedStrings.GroupSettingsView.invite) {
              store.send(.view(.inviteTapped))
            }
          }
        }
        .onAppear { store.send(.view(.onAppear)) }
        .modifier(SheetsModifier(store: store))
        .modifier(AlertsModifier(store: store))
        .toast(Binding(
          get: { store.toastMessage },
          set: { _ in store.send(.view(.toastDismissed)) }
        ))
        .sheet(
          isPresented: Binding(
            get: { store.editGroup != nil },
            set: { if !$0 { store.send(.view(.editGroupDismissed)) } }
          )
        ) {
          if store.editGroup != nil {
            EditGroupSheet(store: store)
              .presentationDetents([.large])
              .presentationDragIndicator(.visible)
          }
        }
    }

    private var content: some SwiftUI.View {
      ScrollView {
        VStack(spacing: 16) {
          groupHeaderSection
          menuSection
          dangerSection
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
    }

    // MARK: - Sections

    private var groupHeaderSection: some SwiftUI.View {
      VStack(spacing: 16) {
        HStack(spacing: 16) {
          GroupThumbnailView(
            imageUrl: store.group.imageUrl,
            name: store.group.name,
            size: 60
          )
          .contentShape(Circle())
          .onTapGesture {
            store.send(.view(.groupImageTapped))
          }

          VStack(alignment: .leading, spacing: 6) {
            Text(store.group.name)
              .font(.system(size: 20, weight: .semibold))

            Text(groupDescriptionText)
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
              .lineLimit(2)
          }

          Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(16)
      .adaptiveGlassCard()
      .overlay(alignment: .topTrailing) {
        if store.isHost {
          Button {
            store.send(.view(.editGroupTapped))
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "pencil")
                .font(.system(size: 12, weight: .semibold))
              Text(LocalizedStrings.Common.edit)
                .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(Color.pmindigo.n500)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.pmindigo.n500.opacity(0.12))
            .clipShape(Capsule())
          }
          .buttonStyle(.plain)
          .padding(12)
        }
      }
    }


    private var menuSection: some SwiftUI.View {
      VStack(alignment: .leading, spacing: 10) {
        VStack(spacing: 0) {
          // 그룹 색상
          NavigationLink {
            GroupColorPickerView(store: store)
          } label: {
            HStack(spacing: 12) {
              if let groupColor = store.groupColor {
                Circle()
                  .fill(groupColor.color)
                  .frame(width: 20, height: 20)
              } else {
                Image(systemName: "paintpalette")
                  .font(.system(size: 16, weight: .semibold))
                  .foregroundStyle(Color.pmindigo.n500)
              }

              Text(LocalizedStrings.GroupSettingsView.groupColorTitle)
                .foregroundStyle(.primary)
              Spacer()
              if let groupColor = store.groupColor {
                Text(groupColor.displayName)
                  .foregroundStyle(.secondary)
              } else {
                Text(LocalizedStrings.GroupSettingsView.colorNotSet)
                  .foregroundStyle(.secondary)
              }
              Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)

          dividerLine

          NavigationLink {
            NotificationSettingsView(store: store)
          } label: {
            menuRowContent(
              title: LocalizedStrings.GroupSettingsView.notificationSettings,
              systemImage: "bell",
              trailingText: nil
            )
          }
          .buttonStyle(.plain)
          .simultaneousGesture(
            TapGesture().onEnded { store.send(.view(.notificationSettingsTapped)) }
          )

          dividerLine

          NavigationLink {
            GroupMemberListView(store: store)
          } label: {
            menuRowContent(
              title: LocalizedStrings.Group.members,
              systemImage: "person.2",
              trailingText: LocalizedStrings.GroupSettingsView.membersCount(store.memberCount)
            )
          }
          .buttonStyle(.plain)
          .simultaneousGesture(
            TapGesture().onEnded { store.send(.view(.membersTapped)) }
          )

          dividerLine

          menuRow(
            title: LocalizedStrings.ManageGroup.pastPromises,
            systemImage: "clock.arrow.circlepath",
            trailingText: nil,
            action: { store.send(.view(.pastPromisesTapped)) }
          )
        }
        .adaptiveGlassCard()
      }
    }

    private var dangerSection: some SwiftUI.View {
      VStack(alignment: .leading, spacing: 10) {
        VStack(spacing: 0) {
          if store.isHost {
            // 호스트 양도 (다른 멤버가 있을 때만)
            if store.canTransferHost {
              dangerRow(
                title: LocalizedStrings.ManageGroup.transferHost,
                systemImage: "person.badge.key",
                color: .orange,
                isLoading: false,
                action: { store.send(.view(.transferHostTapped)) }
              )

              Divider()
                .padding(.leading, 52)
            }

            dangerRow(
              title: LocalizedStrings.ManageGroup.deleteGroup,
              systemImage: "trash",
              isLoading: store.isDeletingGroup,
              action: { store.send(.view(.deleteGroupTapped)) }
            )
            .disabled(store.isDeletingGroup)
          } else {
            dangerRow(
              title: LocalizedStrings.ManageGroup.leaveGroup,
              systemImage: "rectangle.portrait.and.arrow.right",
              isLoading: store.isLeavingGroup,
              action: { store.send(.view(.leaveGroupTapped)) }
            )
            .disabled(store.isLeavingGroup)
          }
        }
        .adaptiveGlassCard()
      }
    }

    private var groupDescriptionText: String {
      let description = store.group.description?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
      return description.isEmpty ? LocalizedStrings.GroupSettingsView.noDescription : description
    }

    private var dividerLine: some SwiftUI.View {
      Divider()
        .background(Color.white.opacity(0.12))
    }

    private func menuRow(
      title: String,
      systemImage: String,
      trailingText: String?,
      action: @escaping () -> Void
    ) -> some SwiftUI.View {
      Button(action: action) {
        menuRowContent(
          title: title,
          systemImage: systemImage,
          trailingText: trailingText
        )
      }
      .buttonStyle(.plain)
      .foregroundStyle(.primary)
    }

    private func menuRowContent(
      title: String,
      systemImage: String,
      trailingText: String?
    ) -> some SwiftUI.View {
      HStack(spacing: 12) {
        Image(systemName: systemImage)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.pmindigo.n500)

        Text(title)
          .foregroundStyle(.primary)
        Spacer()
        if let trailingText {
          Text(trailingText)
            .foregroundStyle(.secondary)
        }
        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }


    private func dangerRow(
      title: String,
      systemImage: String,
      color: Color = Color.pmerror.n500,
      isLoading: Bool,
      action: @escaping () -> Void
    ) -> some SwiftUI.View {
      Button(action: action) {
        HStack(spacing: 12) {
          Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(color)

          Text(title)
            .foregroundStyle(.primary)
          Spacer()
          if isLoading {
            ProgressView()
          }
          Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }
}

private struct NotificationSettingsView: View {
  @Bindable var store: StoreOf<GroupSettings.Feature>
  @State private var activeTooltip: NotificationTooltip?
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // 시스템 권한 미결정 (아직 요청 안 함)
        if store.systemAuthStatus == .notDetermined {
          notificationPermissionRequestBanner
        }
        // 시스템 권한 거부
        else if store.systemAuthStatus == .denied {
          systemNotificationDeniedBanner
        }

        groupNotificationSection
        promiseNotificationSection
        groupActivityNotificationSection
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 24)
    }
    .navigationTitle(LocalizedStrings.GroupSettingsView.notificationSettings)
    .navigationBarTitleDisplayMode(.inline)
    .onAppear {
      refreshNotificationStatus()
    }
    .onChange(of: scenePhase) { oldPhase, newPhase in
      if newPhase == .active {
        refreshNotificationStatus()
      }
    }
  }

  private func refreshNotificationStatus() {
    store.send(.view(.onAppear))
  }

  private var notificationPermissionRequestBanner: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "bell.badge.fill")
          .font(.system(size: 16))
          .foregroundStyle(Color.pmindigo.n500)

        Text(LocalizedStrings.GroupSettingsView.notificationPermissionNeeded)
          .font(.system(size: 14))
          .foregroundStyle(Color.pmtext.primary)

        Spacer()
      }

      Button {
        store.send(.view(.requestNotificationPermission))
      } label: {
        HStack {
          Image(systemName: "bell")
            .font(.system(size: 12))
          Text(LocalizedStrings.GroupSettingsView.allowNotificationPermission)
            .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.pmindigo.n500)
        .clipShape(Capsule())
      }
    }
    .padding(16)
    .adaptiveGlassCard()
  }

  private var systemNotificationDeniedBanner: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle.fill")
          .font(.system(size: 16))
          .foregroundStyle(Color.pmerror.n500)

        Text(LocalizedStrings.GroupSettingsView.notificationDeniedMessage)
          .font(.system(size: 14))
          .foregroundStyle(Color.pmtext.primary)

        Spacer()
      }

      Button {
        store.send(.view(.openSystemSettingsTapped))
      } label: {
        HStack {
          Image(systemName: "gear")
            .font(.system(size: 12))
          Text(LocalizedStrings.GroupSettingsView.openNotificationSettings)
            .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.pmerror.n500)
        .clipShape(Capsule())
      }
    }
    .padding(16)
    .adaptiveGlassCard()
  }

  private var groupNotificationSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(LocalizedStrings.GroupSettingsView.groupAll)
        .font(.system(size: 16, weight: .semibold))
        .padding(.horizontal, 4)

      VStack(spacing: 0) {
        notificationToggleRow(
          title: LocalizedStrings.GroupSettingsView.groupNotification,
          systemImage: "bell.fill",
          tooltip: .groupNotifications,
          activeTooltip: $activeTooltip,
          isOn: Binding(
            get: { store.notificationSettings.enabled },
            set: { store.send(.view(.groupNotificationsChanged($0))) }
          ),
          disabled: !isNotificationEnabled(store.systemAuthStatus)
        )
      }
      .adaptiveGlassCard()
    }
  }

  private var promiseNotificationSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(LocalizedStrings.GroupSettingsView.promiseSection)
        .font(.system(size: 16, weight: .semibold))
        .padding(.horizontal, 4)

      VStack(spacing: 0) {
        let promiseKeys: [GroupNotificationPreferenceKey] = [
          .promiseInvitation,
          .promiseConfirmed,
          .promiseCancelled,
          .promiseUpdated
        ]
        ForEach(Array(promiseKeys.enumerated()), id: \.element.rawValue) { index, key in
          notificationPreferenceRow(
              key: key,
              activeTooltip: $activeTooltip,
              isOn: Binding(
              get: { GroupNotificationPreferences.value(for: key, in: store.notificationSettings) },
              set: { store.send(.view(.notificationPreferenceChanged(key, $0))) }
            )
          )
          if index != promiseKeys.count - 1 {
            dividerLine
          }
        }
      }
      .adaptiveGlassCard()
    }
  }

  private var groupActivityNotificationSection: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(LocalizedStrings.GroupSettingsView.groupSection)
        .font(.system(size: 16, weight: .semibold))
        .padding(.horizontal, 4)

      VStack(spacing: 0) {
        let groupKeys: [GroupNotificationPreferenceKey] = [
          .groupUpdate
        ]
        ForEach(Array(groupKeys.enumerated()), id: \.element.rawValue) { index, key in
          notificationPreferenceRow(
            key: key,
            activeTooltip: $activeTooltip,
            isOn: Binding(
              get: { GroupNotificationPreferences.value(for: key, in: store.notificationSettings) },
              set: { store.send(.view(.notificationPreferenceChanged(key, $0))) }
            )
          )
          if index != groupKeys.count - 1 {
            dividerLine
          }
        }
      }
      .adaptiveGlassCard()
    }
  }

  private var dividerLine: some View {
    Divider()
      .background(Color.white.opacity(0.12))
  }

  private func notificationToggleRow(
    title: String,
    systemImage: String,
    tooltip: NotificationTooltip,
    activeTooltip: Binding<NotificationTooltip?>,
    isOn: Binding<Bool>,
    disabled: Bool = false
  ) -> some View {
    HStack(spacing: 12) {
      Image(systemName: systemImage)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Color.pmindigo.n500)

      Text(title)
        .foregroundStyle(.primary)

      tooltipButton(for: tooltip, activeTooltip: activeTooltip)

      Spacer()

      Toggle("", isOn: isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .disabled(disabled)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private func notificationPreferenceRow(
    key: GroupNotificationPreferenceKey,
    activeTooltip: Binding<NotificationTooltip?>,
    isOn: Binding<Bool>
  ) -> some View {
    let isDisabled = !isNotificationEnabled(store.systemAuthStatus)
                  || !store.notificationSettings.enabled

    return HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(key.title)
          .foregroundStyle(isDisabled ? .secondary : .primary)
        if let subtitle = key.subtitle {
          Text(subtitle)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
      }

      tooltipButton(for: .preference(key), activeTooltip: activeTooltip)

      Spacer()

      Toggle("", isOn: isOn)
        .labelsHidden()
        .toggleStyle(.switch)
        .disabled(isDisabled)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private func isNotificationEnabled(_ status: NotificationAuthorizationStatus) -> Bool {
    switch status {
    case .authorized, .provisional, .ephemeral:
      return true
    case .notDetermined, .denied:
      return false
    }
  }

  private func tooltipButton(
    for tooltip: NotificationTooltip,
    activeTooltip: Binding<NotificationTooltip?>
  ) -> some View {
    Button {
      activeTooltip.wrappedValue = tooltip
    } label: {
      Image(systemName: "info.circle")
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .popover(
      isPresented: Binding(
        get: { activeTooltip.wrappedValue == tooltip },
        set: { if !$0 { activeTooltip.wrappedValue = nil } }
      ),
      arrowEdge: .top
    ) {
      NotificationInfoPopover(tooltip: tooltip)
    }
  }
}

private struct NotificationInfoPopover: View {
  let tooltip: NotificationTooltip
  @State private var animateNotification: Bool = false
  @State private var loopContinues: Bool = true

  var body: some View {
    VStack(spacing: 16) {
      VStack(spacing: 4) {
        Text(tooltip.title)
          .font(.system(size: 17, weight: .bold))
          .foregroundColor(.primary)

        Text(tooltip.subtitle)
          .font(.system(size: 13))
          .foregroundColor(.secondary)
          .multilineTextAlignment(.center)
      }

      notificationPreview(title: tooltip.previewTitle, body: tooltip.previewBody)
    }
    .padding(20)
    .background(
      RoundedRectangle(cornerRadius: 20, style: .continuous)
        .fill(Color(.secondarySystemBackground).opacity(0.6))
    )
    .frame(width: UIScreen.main.bounds.width - 40)
    .presentationCompactAdaptation(.popover)
    .onDisappear {
      loopContinues = false
    }
  }

  private func notificationPreview(title: String, body: String) -> some View {
    HStack(alignment: .center, spacing: 8) {
      ResourceKitAsset.notificationLogo.swiftUIImage
        .resizable()
        .scaledToFit()
        .frame(width: 40, height: 40)
        .clipShape(.rect(cornerRadius: 10))

      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text("Promiso")
            .font(.callout)
            .fontWeight(.medium)
            .lineLimit(1)

          Spacer(minLength: 0)

          Text(LocalizedStrings.GroupSettingsView.now)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.gray)
        }

        Text(title)
          .font(.callout)
          .fontWeight(.medium)
          .lineLimit(1)

        Text(body)
          .font(.caption2)
          .fontWeight(.medium)
          .foregroundStyle(.gray)
          .lineLimit(2)
      }
    }
    .padding(12)
    .background(.background)
    .clipShape(.rect(cornerRadius: 20))
    .shadow(color: .gray.opacity(0.3), radius: 2)
    .padding(.horizontal, 12)
    .offset(y: animateNotification ? 0 : -80)
    .clipped()
    .task {
      await loopAnimation()
    }
  }

  private func loopAnimation() async {
    try? await Task.sleep(for: .seconds(0.35))

    withAnimation(.smooth(duration: 0.6)) {
      animateNotification = true
    }

    try? await Task.sleep(for: .seconds(2.8))

    withAnimation(.smooth(duration: 0.6)) {
      animateNotification = false
    }

    guard loopContinues else { return }
    try? await Task.sleep(for: .seconds(0.9))
    await loopAnimation()
  }
}

private enum NotificationTooltip: Identifiable, Equatable {
  case groupNotifications
  case preference(GroupNotificationPreferenceKey)

  var id: String {
    switch self {
    case .groupNotifications:
      return "groupNotifications"
    case .preference(let key):
      return "preference.\(key.rawValue)"
    }
  }

  var title: String {
    switch self {
    case .groupNotifications:
      return LocalizedStrings.GroupSettingsView.groupNotification
    case .preference(let key):
      return key.title
    }
  }

  var subtitle: String {
    switch self {
    case .groupNotifications:
      return LocalizedStrings.GroupSettingsView.tooltipGroupNotificationSubtitle
    case .preference(let key):
      return key.subtitle ?? LocalizedStrings.GroupSettingsView.tooltipToggleDescription
    }
  }

  var previewTitle: String {
    switch self {
    case .groupNotifications:
      return LocalizedStrings.GroupSettingsView.tooltipNewPromise
    case .preference(let key):
      switch key {
      case .promiseInvitation:
        return LocalizedStrings.GroupSettingsView.tooltipNewPromise
      case .promiseConfirmed:
        return LocalizedStrings.GroupSettingsView.tooltipConfirmed
      case .promiseCancelled:
        return LocalizedStrings.GroupSettingsView.tooltipCancelled
      case .promiseUpdated:
        return LocalizedStrings.GroupSettingsView.tooltipUpdated
      case .groupUpdate:
        return LocalizedStrings.GroupSettingsView.tooltipNewMember
      }
    }
  }

  var previewBody: String {
    switch self {
    case .groupNotifications:
      return LocalizedStrings.GroupSettingsView.tooltipNewPromiseBody
    case .preference(let key):
      switch key {
      case .promiseInvitation:
        return LocalizedStrings.GroupSettingsView.tooltipNewPromiseBody
      case .promiseConfirmed:
        return LocalizedStrings.GroupSettingsView.tooltipConfirmedBody
      case .promiseCancelled:
        return LocalizedStrings.GroupSettingsView.tooltipCancelledBody
      case .promiseUpdated:
        return LocalizedStrings.GroupSettingsView.tooltipUpdatedBody
      case .groupUpdate:
        return LocalizedStrings.GroupSettingsView.tooltipNewMemberBody
      }
    }
  }
}

private struct EditGroupSheet: View {
  @Bindable var store: StoreOf<GroupSettings.Feature>

  private var editState: GroupSettings.Feature.EditGroupState? {
    store.editGroup
  }

  var body: some View {
    NavigationStack {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 20) {
            photoSection
              .glassSection()

            groupNameSection
              .glassSection()

            descriptionSection
              .glassSection()

            maxMembersSection
              .glassSection()

            Spacer(minLength: 12)
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: focusedField) { _, newValue in
          guard let newValue else { return }
          withAnimation(.easeInOut(duration: 0.2)) {
            proxy.scrollTo(newValue, anchor: .center)
          }
        }
      }
      .onTapGesture {
        dismissKeyboard()
      }
      .navigationTitle(LocalizedStrings.GroupSettingsView.editGroupTitle)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            store.send(.view(.editGroupDismissed))
          } label: {
            Image(systemName: "xmark")
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        BottomButton(
          isLoading: editState?.isSaving == true,
          isEnabled: !saveDisabled,
          action: { store.send(.view(.editGroupSaveTapped)) }
        )
      }
    }
    .alert(
      LocalizedStrings.GroupSettingsView.editGroupFailed,
      isPresented: Binding(
        get: { store.editGroup?.error != nil },
        set: { if !$0 { store.send(.view(.editGroupErrorDismissed)) } }
      ),
      actions: {
        Button(LocalizedStrings.Common.ok, role: .cancel) {
          store.send(.view(.editGroupErrorDismissed))
        }
      },
      message: {
        Text(store.editGroup?.error ?? LocalizedStrings.GroupSettingsView.tryAgainLater)
      }
    )
  }

  private var saveDisabled: Bool {
    guard let editState else { return true }
    return editState.isSaving ||
      editState.maxMembers < store.minMaxMembers ||
      editState.maxMembers > store.maxMembersUpperLimit
  }

  @FocusState private var focusedField: Field?

  private enum Field: Hashable {
    case description
  }

  private var photoSection: some View {
    VStack(spacing: 12) {
      Text(LocalizedStrings.GroupSettingsView.groupPhoto)
        .font(.system(size: 16, weight: .semibold))
        .foregroundColor(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)

      PhotosPicker(
        selection: Binding(
          get: { editState?.selectedPhoto },
          set: { store.send(.view(.editGroupPhotoSelected($0))) }
        ),
        matching: .images
      ) {
        ZStack {
          if let photoData = editState?.photoData,
             let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
              .resizable()
              .scaledToFill()
              .frame(width: 120, height: 120)
              .clipShape(Circle())
          } else if let imageUrl = store.group.imageUrl {
            GroupThumbnailView(
              imageUrl: imageUrl,
              name: store.group.name,
              size: 120
            )
          } else {
            photoPlaceholder
          }

          Image(systemName: "pencil.circle.fill")
            .font(.system(size: 24))
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color.pmindigo.n500, Color(.systemBackground))
            .frame(width: 28, height: 28)
            .background(
              Circle().fill(Color(.systemBackground))
            )
            .overlay(
              Circle().stroke(Color.pmindigo.n500.opacity(0.2), lineWidth: 1)
            )
            .offset(x: 38, y: 38)
        }
      }
    }
  }

  private var groupNameSection: some View {
    VStack(spacing: 12) {
      HStack {
        Text(LocalizedStrings.CreateGroup.groupName)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)

        Spacer()
      }

      Text(store.group.name)
        .font(.system(size: 16, weight: .semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)

      Label(LocalizedStrings.GroupSettingsView.groupNameCannotChange, systemImage: "info.circle")
        .font(.system(size: 12))
        .foregroundColor(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var descriptionSection: some View {
    let count = editState?.description.count ?? 0
    let maxLength = 50

    return VStack(spacing: 12) {
      HStack {
        Text(LocalizedStrings.CreateGroup.groupDescription)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)

        Spacer()

        Text("\(count)/\(maxLength)")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }

      TextField(
        LocalizedStrings.GroupSettingsView.groupDescriptionPlaceholder,
        text: Binding(
          get: { editState?.description ?? "" },
          set: { store.send(.view(.editGroupDescriptionChanged($0))) }
        ),
        axis: .vertical
      )
      .lineLimit(2, reservesSpace: true)
      .textFieldStyle(.plain)
      .padding(12)
      .background(Color(.systemBackground))
      .cornerRadius(8)
      .focused($focusedField, equals: .description)
      .id(Field.description)
    }
  }

  private var maxMembersSection: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack {
        Text(LocalizedStrings.CreateGroup.maxMembers)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)

        Spacer()

        Picker(
          "",
          selection: Binding(
            get: { editState?.maxMembers ?? store.group.maxMembers },
            set: { store.send(.view(.editGroupMaxMembersChanged($0))) }
          )
        ) {
          ForEach(store.minMaxMembers...10, id: \.self) { value in
            Text(LocalizedStrings.CreateGroup.membersCount(value))
              .tag(value)
          }
        }
        .pickerStyle(.menu)
        .tint(.blue)
      }

      Text(LocalizedStrings.GroupSettingsView.currentMembersMax(store.group.memberIds.count))
        .font(.system(size: 12))
        .foregroundColor(.secondary)
    }
  }

  private var photoPlaceholder: some View {
    Circle()
      .fill(Color(.systemGray5))
      .frame(width: 120, height: 120)
      .overlay {
        VStack(spacing: 8) {
          Image(systemName: "camera.fill")
            .font(.system(size: 28))
            .foregroundColor(.secondary)
          Text(LocalizedStrings.GroupSettingsView.changePhoto)
            .font(.system(size: 13))
            .foregroundColor(.secondary)
        }
      }
  }

  private func dismissKeyboard() {
    UIApplication.shared.sendAction(
      #selector(UIResponder.resignFirstResponder),
      to: nil,
      from: nil,
      for: nil
    )
  }
}

private struct BottomButton: View {
  let isLoading: Bool
  let isEnabled: Bool
  let action: () -> Void

  var body: some View {
    VStack(spacing: 8) {
      GlassActionButton(
        title: isLoading ? LocalizedStrings.GroupSettingsView.saving : LocalizedStrings.GroupSettingsView.editGroupButton,
        isPrimary: true,
        isVisible: true,
        isEnabled: isEnabled && !isLoading,
        action: action
      )
      .overlay(alignment: .trailing) {
        if isLoading {
          ProgressView()
            .tint(.white)
            .padding(.trailing, 16)
        }
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
    .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: -2)
  }
}

private extension View {
  func glassSection() -> some View {
    self
      .padding(16)
      .background(
        Group {
          if #available(iOS 26.0, *) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .fill(.clear)
              .glassEffect(
                .regular
                  .tint(.pmindigo.n200.opacity(0.1))
                  .interactive(),
                in: .rect(cornerRadius: 16)
              )
          } else {
            glassBackground
          }
        }
      )
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .strokeBorder(Color.white.opacity(0.12))
      )
  }

  var glassBackground: some View {
    RoundedRectangle(cornerRadius: 16, style: .continuous)
      .fill(Color.white.opacity(0.06))
      .background(
        RoundedRectangle(cornerRadius: 16, style: .continuous)
          .fill(.ultraThinMaterial)
      )
  }
}

