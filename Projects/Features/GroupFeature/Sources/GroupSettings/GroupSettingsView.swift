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
        .navigationTitle("그룹 설정")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.send(.view(.onAppear)) }
        .modifier(SheetsModifier(store: store))
        .modifier(AlertsModifier(store: store))
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
              Text("수정")
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
          NavigationLink {
            NotificationSettingsView(store: store)
          } label: {
            menuRowContent(
              title: "알림 설정",
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
              title: "멤버",
              systemImage: "person.2",
              trailingText: "\(store.memberCount)명"
            )
          }
          .buttonStyle(.plain)
          .simultaneousGesture(
            TapGesture().onEnded { store.send(.view(.membersTapped)) }
          )

          dividerLine

          menuRow(
            title: "지난 약속",
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
                title: "호스트 양도",
                systemImage: "person.badge.key",
                color: .orange,
                isLoading: false,
                action: { store.send(.view(.transferHostTapped)) }
              )

              Divider()
                .padding(.leading, 52)
            }

            dangerRow(
              title: "그룹 삭제",
              systemImage: "trash",
              isLoading: store.isDeletingGroup,
              action: { store.send(.view(.deleteGroupTapped)) }
            )
            .disabled(store.isDeletingGroup)
          } else {
            dangerRow(
              title: "그룹 나가기",
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
      return description.isEmpty ? "설명이 없습니다" : description
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
    .navigationTitle("알림 설정")
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

        Text("알림을 받으려면 권한 허용이 필요해요")
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
          Text("알림 권한 허용하기")
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

        Text("iOS 알림 권한이 거부되어 알림을 받을 수 없어요")
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
          Text("알림 설정 열기")
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
      Text("그룹 전체")
        .font(.system(size: 16, weight: .semibold))
        .padding(.horizontal, 4)

      VStack(spacing: 0) {
        notificationToggleRow(
          title: "그룹 알림",
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
      Text("약속")
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
      Text("그룹")
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

          Text("지금")
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
      return "그룹 알림"
    case .preference(let key):
      return key.title
    }
  }

  var subtitle: String {
    switch self {
    case .groupNotifications:
      return "그룹 알림이 켜져 있어야 도착해요"
    case .preference(let key):
      return key.subtitle ?? "해당 알림을 켜고 끌 수 있어요"
    }
  }

  var previewTitle: String {
    switch self {
    case .groupNotifications:
      return "새 약속 도착 📩"
    case .preference(let key):
      switch key {
      case .promiseInvitation:
        return "새 약속 도착 📩"
      case .promiseConfirmed:
        return "영화 관람 약속 확정! 🎉"
      case .promiseCancelled:
        return "영화 관람 약속 무산 😢"
      case .promiseUpdated:
        return "영화 관람 변경 📝"
      case .groupUpdate:
        return "새 멤버 합류 👋"
      }
    }
  }

  var previewBody: String {
    switch self {
    case .groupNotifications:
      return "성원님이 영화 관람을 제안했어요. 확인해주세요!"
    case .preference(let key):
      switch key {
      case .promiseInvitation:
        return "성원님이 영화 관람을 제안했어요. 확인해주세요!"
      case .promiseConfirmed:
        return "오늘 오후 2:00에 만나요!"
      case .promiseCancelled:
        return "참여 인원이 부족해서 확정되지 않았어요"
      case .promiseUpdated:
        return "약속 정보가 수정됐어요. 확인해주세요!"
      case .groupUpdate:
        return "재윤님이 대학 친구들에 들어왔어요"
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
      .navigationTitle("그룹 수정")
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
      "그룹 수정 실패",
      isPresented: Binding(
        get: { store.editGroup?.error != nil },
        set: { if !$0 { store.send(.view(.editGroupErrorDismissed)) } }
      ),
      actions: {
        Button("확인", role: .cancel) {
          store.send(.view(.editGroupErrorDismissed))
        }
      },
      message: {
        Text(store.editGroup?.error ?? "잠시 후 다시 시도해주세요.")
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
      Text("그룹 사진")
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
        Text("그룹 이름")
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

      Label("그룹 이름은 변경할 수 없습니다", systemImage: "info.circle")
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
        Text("그룹 설명")
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(.primary)

        Spacer()

        Text("\(count)/\(maxLength)")
          .font(.system(size: 13))
          .foregroundColor(.secondary)
      }

      TextField(
        "그룹 설명을 입력하세요 (선택)",
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
        Text("최대 인원")
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
            Text("\(value)명")
              .tag(value)
          }
        }
        .pickerStyle(.menu)
        .tint(.blue)
      }

      Text("현재 인원 \(store.group.memberIds.count)명 이상, 최대 10명까지 설정할 수 있어요.")
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
          Text("사진 변경")
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
        title: isLoading ? "저장 중..." : "그룹 수정하기",
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

// MARK: - SheetsModifier

private struct SheetsModifier: ViewModifier {
  let store: StoreOf<GroupSettings.Feature>
  @State private var inviteSheetHeight: CGFloat = 360

  private var inviteSheetBinding: Binding<Bool> {
    Binding(
      get: { store.showInviteSheet },
      set: { if !$0 { store.send(.view(.dismissInviteSheet)) } }
    )
  }

  func body(content: Content) -> some View {
    content
      .sheet(isPresented: inviteSheetBinding) {
        InviteSheet(
          groupName: store.group.name,
          inviteCode: store.inviteCode,
        )
        .presentationDetents([.height(270)])
        .presentationDragIndicator(.visible)
      }
  }
}

// MARK: - AlertsModifier

private struct AlertsModifier: ViewModifier {
  let store: StoreOf<GroupSettings.Feature>

  private var leaveAlertBinding: Binding<Bool> {
    Binding(
      get: { store.showLeaveAlert },
      set: { if !$0 { store.send(.view(.dismissLeaveAlert)) } }
    )
  }

  private var deleteAlertBinding: Binding<Bool> {
    Binding(
      get: { store.showDeleteAlert },
      set: { if !$0 { store.send(.view(.dismissDeleteAlert)) } }
    )
  }

  private var errorAlertBinding: Binding<Bool> {
    Binding(
      get: { store.leaveError != nil || store.deleteError != nil || store.notificationError != nil },
      set: { if !$0 { store.send(.view(.dismissError)) } }
    )
  }

  private var imageDetailBinding: Binding<UserPublicModel?> {
    Binding(
      get: { store.selectedMemberForImage },
      set: { if $0 == nil { store.send(.view(.imageDetailDismissed)) } }
    )
  }

  private var groupImageDetailBinding: Binding<Bool> {
    Binding(
      get: { store.showGroupImageDetail },
      set: { if !$0 { store.send(.view(.groupImageDetailDismissed)) } }
    )
  }

  private var transferSheetBinding: Binding<Bool> {
    Binding(
      get: { store.isShowingTransferSheet },
      set: { if !$0 { store.send(.view(.dismissTransferSheet)) } }
    )
  }

  private var transferErrorBinding: Binding<Bool> {
    Binding(
      get: { store.transferError != nil },
      set: { if !$0 { store.send(.view(.dismissTransferError)) } }
    )
  }

  func body(content: Content) -> some View {
    content
      .alert("그룹 나가기", isPresented: leaveAlertBinding) {
        Button("취소", role: .cancel) {}
        Button("나가기", role: .destructive) { store.send(.view(.confirmLeave)) }
      } message: {
        Text("정말 '\(store.group.name)' 그룹을 나가시겠습니까?")
      }
      .alert("그룹 삭제", isPresented: deleteAlertBinding) {
        Button("취소", role: .cancel) {}
        Button("삭제", role: .destructive) { store.send(.view(.confirmDelete)) }
      } message: {
        Text("정말 '\(store.group.name)' 그룹을 삭제하시겠습니까?\n모든 약속과 데이터가 삭제됩니다.")
      }
      .alert("오류", isPresented: errorAlertBinding) {
        Button("확인") { store.send(.view(.dismissError)) }
      } message: {
        Text(store.leaveError ?? store.deleteError ?? store.notificationError ?? "알 수 없는 오류가 발생했습니다.")
      }
      .fullScreenCover(item: imageDetailBinding) { member in
        PromisoShared.ImageDetailView(
          imageUrl: member.profileImageUrl,
          displayName: member.displayName,
          onDismiss: { store.send(.view(.imageDetailDismissed)) }
        )
      }
      .fullScreenCover(isPresented: groupImageDetailBinding) {
        PromisoShared.ImageDetailView(
          imageUrl: store.group.imageUrl,
          displayName: store.group.name,
          onDismiss: { store.send(.view(.groupImageDetailDismissed)) }
        )
        .presentationBackground(.black)
      }
      .sheet(isPresented: transferSheetBinding) {
        TransferHostSheet(store: store)
      }
      .alert("호스트 양도 실패", isPresented: transferErrorBinding) {
        Button("확인") { store.send(.view(.dismissTransferError)) }
      } message: {
        Text(store.transferError ?? "알 수 없는 오류가 발생했습니다.")
      }
  }
}

// MARK: - TransferHostSheet

private struct TransferHostSheet: View {
  let store: StoreOf<GroupSettings.Feature>

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 16) {
          // 안내 텍스트
          VStack(alignment: .leading, spacing: 10) {
            Text("새 호스트를 선택하세요")
              .font(.system(size: 16, weight: .semibold))
              .padding(.horizontal, 4)

            VStack(spacing: 0) {
              ForEach(Array(store.transferCandidates.enumerated()), id: \.element.userId) { index, member in
                transferCandidateRow(member: member)

                if index < store.transferCandidates.count - 1 {
                  Divider()
                    .background(Color.white.opacity(0.12))
                }
              }
            }
            .adaptiveGlassCard()

            Text("호스트를 양도하면 해당 멤버가 그룹을 관리할 수 있습니다.")
              .font(.system(size: 12))
              .foregroundStyle(Color.pmtext.secondary)
              .padding(.horizontal, 4)
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
      }
      .auroraBackground()
      .navigationTitle("호스트 양도")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("취소") {
            store.send(.view(.dismissTransferSheet))
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          confirmButton
        }
      }
    }
    .interactiveDismissDisabled(store.isTransferringHost)
  }

  private func transferCandidateRow(member: UserPublicModel) -> some View {
    Button {
      store.send(.view(.selectNewHost(member)))
    } label: {
      HStack(spacing: 12) {
        ProfileAvatarView(
          profileImageUrl: member.profileImageUrl,
          displayName: member.displayName,
          isCurrentUser: false,
          size: 44
        )

        VStack(alignment: .leading, spacing: 2) {
          Text(member.displayName)
            .font(.body)
            .foregroundStyle(.primary)
          if member.name != member.nickname {
            Text(member.name)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        if store.selectedNewHost?.userId == member.userId {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.pmindigo.n500)
            .font(.title3)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var confirmButton: some View {
    if store.isTransferringHost {
      ProgressView()
    } else {
      Button("양도") {
        store.send(.view(.confirmTransferHost))
      }
      .disabled(store.selectedNewHost == nil)
    }
  }
}

// MARK: - GroupMemberListView

struct GroupMemberListView: View {
  let store: StoreOf<GroupSettings.Feature>

  var body: some View {
    ScrollView {
      VStack(spacing: 16) {
        // 멤버 목록
        VStack(alignment: .leading, spacing: 10) {
          Text("멤버")
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 4)

          VStack(spacing: 0) {
            ForEach(Array(store.members.enumerated()), id: \.element.userId) { index, member in
              MemberRow(
                member: member,
                isHost: member.userId == store.group.createdBy,
                isCurrentUser: member.userId == store.currentUserId,
                onImageTap: { store.send(.view(.memberImageTapped(member))) }
              )

              if index < store.members.count - 1 {
                Divider()
                  .background(Color.white.opacity(0.12))
              }
            }
          }
          .adaptiveGlassCard()
        }

        // 초대 섹션
        VStack(alignment: .leading, spacing: 10) {
          Text("초대")
            .font(.system(size: 16, weight: .semibold))
            .padding(.horizontal, 4)

          InviteTileRow {
            store.send(.view(.inviteTapped))
          }
          .adaptiveGlassCard()
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 12)
      .padding(.bottom, 24)
    }
    .auroraBackground()
    .navigationTitle("멤버 (\(store.members.count)명)")
    .navigationBarTitleDisplayMode(.inline)
    .fullScreenCover(
      item: Binding(
        get: { store.selectedMemberForImage },
        set: { _ in store.send(.view(.imageDetailDismissed)) }
      )
    ) { member in
      PromisoShared.ImageDetailView(
        imageUrl: member.profileImageUrl,
        displayName: member.displayName,
        onDismiss: { store.send(.view(.imageDetailDismissed)) }
      )
      .presentationBackground(.clear)
    }
  }
}

private struct MemberRow: View {
  let member: UserPublicModel
  let isHost: Bool
  let isCurrentUser: Bool
  let onImageTap: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      ProfileAvatarView(
        profileImageUrl: member.profileImageUrl,
        displayName: member.displayName,
        isCurrentUser: isCurrentUser,
        size: 44
      )
      .padding(4)
      .contentShape(Rectangle())
      .onTapGesture(perform: onImageTap)

      Text(member.displayName)
        .font(.body)

      Spacer()

      if isHost {
        HStack(spacing: 4) {
          Image(systemName: "crown.fill")
            .font(.system(size: 12))
          Text("호스트")
            .font(.caption)
        }
        .foregroundStyle(.orange)
      }

      if isCurrentUser {
        Text("나")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(Color.pmindigo.n600)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.pmindigo.n500.opacity(0.12))
          .clipShape(Capsule())
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

private struct InviteTileRow: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: "person.badge.plus")
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.pmindigo.n500)

        VStack(alignment: .leading, spacing: 4) {
          Text("친구 초대하기")
            .font(.body)
            .foregroundStyle(.primary)

          Text("링크를 공유해 멤버를 초대하세요")
            .font(.caption)
            .foregroundStyle(.secondary)
        }

        Spacer()

        Image(systemName: "chevron.right")
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - InviteSheet

struct InviteSheet: View {
  let groupName: String
  let inviteCode: String

  @State private var isCopied = false

  var body: some View {
    VStack(spacing: 20) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("친구 초대")
            .font(.system(size: 20, weight: .bold))

          Text("초대 코드를 공유해 멤버를 추가하세요")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        .padding(.top, 12)

        Spacer()
      }

      VStack(spacing: 12) {
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text("초대 코드")
              .font(.system(size: 12, weight: .semibold))
              .foregroundStyle(.secondary)

            Text(inviteCode)
              .font(.system(size: 28, weight: .bold, design: .monospaced))
              .tracking(2)
          }

          Spacer()

          Button {
            copyCode()
          } label: {
            Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(isCopied ? .green : Color.pmindigo.n500)
              .frame(width: 36, height: 36)
              .background(Color.pmindigo.n500.opacity(0.12))
              .clipShape(Circle())
          }
          .buttonStyle(.bounce)
        }

      }
      .padding(16)
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

      GroupInviteShareMessage.shareLink(groupName: groupName, inviteCode: inviteCode) {
        HStack(spacing: 8) {
          Image(systemName: "square.and.arrow.up")
          Text("링크 공유하기")
        }
        .font(.system(size: 16, weight: .semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.pmindigo.n500)
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.scale)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 20)
  }

  private func copyCode() {
    UIPasteboard.general.string = inviteCode
    Haptic.success()
    withAnimation(.easeInOut(duration: 0.2)) {
      isCopied = true
    }
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    GroupSettings.View(
      store: Store(
        initialState: GroupSettings.Feature.State(
          group: GroupModel(
            id: "g1",
            name: "지민과 나",
            maxMembers: 10,
            inviteCode: "ABC123",
            createdBy: "preview-user"
          ),
          summary: UserGroupInfo(
            id: "g1",
            name: "지민과 나",
            role: .admin,
            hasNewActivity: true
          ),
          currentUserId: "preview-user",
          userPlan: .free,
          preloadedMembers: [
            UserPublicModel(
              userId: "preview-user",
              name: "나",
              nickname: "나",
              metadata: Metadata()
            ),
            UserPublicModel(
              userId: "user2",
              name: "지민",
              nickname: "지민",
              metadata: Metadata()
            )
          ]
        )
      ) {
        GroupSettings.Feature()
      }
    )
  }
}
