import SwiftUI
import ComposableArchitecture
import PromisoShared
import PhotosUI

// MARK: - Root View

extension CreatePersonalEvent {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStack {
        ScrollView {
          VStack(spacing: 16) {
            essentialSection
            endTimeSection
            locationSection
            reminderSection
            descriptionSection

            // 사진 첨부
            ImageAttachmentSection(
              existingImageUrls: store.event.imageUrls.filter { !store.removedImageUrls.contains($0) },
              localImages: store.localImageData,
              onPhotosSelected: { items in
                store.send(.view(.photosSelected(items)))
              },
              onRemoveExisting: { index in
                store.send(.view(.removeExistingImage(index)))
              },
              onRemoveLocal: { index in
                store.send(.view(.removeLocalImage(index)))
              }
            )
          }
          .padding(16)
          .padding(.bottom, 24)
        }
        .auroraBackground()
        .navigationTitle(store.mode == .create ? "새 일정" : "일정 수정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("취소") {
              store.send(.view(.dismissTapped))
            }
          }

          ToolbarItem(placement: .confirmationAction) {
            if store.isSaving {
              ProgressView()
            } else {
              Button(store.mode == .create ? "저장" : "수정") {
                store.send(.view(.saveTapped))
              }
              .fontWeight(.semibold)
              .disabled(!store.canSave)
            }
          }
        .keyboardDismissToolbar()
        }
      }
      .alert(
        "오류",
        isPresented: Binding(
          get: { store.errorMessage != nil },
          set: { if !$0 { store.send(.view(.dismissError)) } }
        ),
        actions: {
          Button("확인") { store.send(.view(.dismissError)) }
        },
        message: {
          if let message = store.errorMessage {
            Text(message)
          }
        }
      )
      .sheet(item: $store.scope(state: \.locationPicker, action: \.locationPicker)) { pickerStore in
        LocationPicker.RootView(store: pickerStore)
      }
      .sheet(item: $store.scope(state: \.notificationPermission, action: \.notificationPermission)) { permissionStore in
        NotificationPermission.View(store: permissionStore)
          .presentationDetents([.large])
      }
    }

    // MARK: - Essential Section (제목 + 시작 시간)

    @ViewBuilder
    private var essentialSection: some View {
      VStack(spacing: 0) {
          // 제목 + 이모지
          VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 12) {
              Group {
                if store.isEmojiLoading {
                  ProgressView()
                } else {
                  Text(store.event.displayEmoji)
                    .font(.system(size: 28))
                }
              }
              .frame(width: 40, height: 40)

              TextField("일정 제목을 입력하세요", text: Binding(
                get: { store.event.title },
                set: { store.send(.view(.titleChanged($0))) }
              ))
              .font(.system(size: 18, weight: .medium))
              .textFieldStyle(.plain)
            }

            Text("\(store.event.title.count)/30")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
          }
          .padding(12)

          Divider()
            .background(Color.white.opacity(0.12))

          // 시작 시간
          HStack {
            Image(systemName: "clock")
              .font(.body)
              .foregroundStyle(Color.pmindigo.n500)
              .frame(width: 24)

            Text("시작")
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Spacer()

            DatePicker(
              "",
              selection: Binding(
                get: { store.event.startAt },
                set: { store.send(.view(.startDateChanged($0))) }
              ),
              in: Date()...,
              displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .tint(Color.pmindigo.n500)
            .environment(\.locale, Locale(identifier: "ko_KR"))
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
      .adaptiveGlassCard()
    }

    // MARK: - End Time Section

    @ViewBuilder
    private var endTimeSection: some View {
      VStack(spacing: 0) {
        HStack {
          Image(systemName: "clock.badge.checkmark")
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24)

          Text("종료 시간")
            .font(.body)
            .foregroundStyle(Color.pmtext.primary)

          Spacer()

          Toggle("", isOn: Binding(
            get: { store.useEndTime },
            set: { _ in store.send(.view(.toggleUseEndTime), animation: .default) }
          ))
          .labelsHidden()
          .tint(Color.pmindigo.n500)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        if store.useEndTime, let endAt = store.event.endAt {
          Divider()
            .background(Color.white.opacity(0.12))

          HStack {
            Text(store.event.startAt.durationText(to: endAt, prefix: "총 "))
              .font(.system(size: 13))
              .foregroundStyle(Color.pmtext.secondary)

            Spacer()

            DatePicker(
              "",
              selection: Binding(
                get: { endAt },
                set: { store.send(.view(.endDateChanged($0))) }
              ),
              in: store.event.startAt...,
              displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .tint(Color.pmindigo.n500)
            .environment(\.locale, Locale(identifier: "ko_KR"))
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .adaptiveGlassCard()
    }

    // MARK: - Location Section

    @ViewBuilder
    private var locationSection: some View {
      VStack(spacing: 0) {
        if let location = store.event.location {
          // 장소가 선택된 상태
          HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
              .font(.title3)
              .foregroundStyle(Color.pmindigo.n500)
              .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
              Text(location.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.pmtext.primary)
                .lineLimit(1)

              if let address = location.address {
                Text(address)
                  .font(.system(size: 13))
                  .foregroundStyle(Color.pmtext.secondary)
                  .lineLimit(1)
              }
            }

            Spacer()

            Button {
              store.send(.view(.removeLocation))
            } label: {
              Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.pmgray.n400)
            }
            .buttonStyle(.plain)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .contentShape(Rectangle())
          .onTapGesture {
            store.send(.view(.locationTapped))
          }
        } else {
          // 장소 미선택
          Button {
            store.send(.view(.locationTapped))
          } label: {
            HStack {
              Image(systemName: "mappin")
                .font(.body)
                .foregroundStyle(Color.pmindigo.n500)
                .frame(width: 24)

              Text("장소 추가")
                .font(.body)
                .foregroundStyle(Color.pmtext.primary)

              Spacer()

              Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(Color.pmtext.secondary)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
      }
      .adaptiveGlassCard()
    }

    // MARK: - Reminder Section

    @ViewBuilder
    private var reminderSection: some View {
      let currentOption = CreatePersonalEvent.ReminderOption.from(
        minutes: store.event.reminderMinutesBefore
      )
      HStack {
        Image(systemName: "bell")
          .font(.body)
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 24)

        Text("미리 알림")
          .font(.body)
          .foregroundStyle(Color.pmtext.primary)

        Spacer()

        Menu {
          Button {
            store.send(.view(.reminderOptionSelected(nil)), animation: .default)
          } label: {
            if currentOption == .none {
              Label("없음", systemImage: "checkmark")
            } else {
              Text("없음")
            }
          }

          Divider()

          ForEach(CreatePersonalEvent.ReminderOption.shortOptions, id: \.title) { option in
            Button {
              store.send(.view(.reminderOptionSelected(option.minutes)), animation: .default)
            } label: {
              if currentOption == option {
                Label(option.title, systemImage: "checkmark")
              } else {
                Text(option.title)
              }
            }
          }

          Divider()

          ForEach(CreatePersonalEvent.ReminderOption.longOptions, id: \.title) { option in
            Button {
              store.send(.view(.reminderOptionSelected(option.minutes)), animation: .default)
            } label: {
              if currentOption == option {
                Label(option.title, systemImage: "checkmark")
              } else {
                Text(option.title)
              }
            }
          }
        } label: {
          HStack(spacing: 4) {
            Text(currentOption.title)
              .font(.system(size: 15))
              .foregroundStyle(
                currentOption == .none
                  ? Color.pmtext.secondary
                  : Color.pmindigo.n500
              )

            Image(systemName: "chevron.up.chevron.down")
              .font(.system(size: 11))
              .foregroundStyle(Color.pmtext.secondary)
          }
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .adaptiveGlassCard()

      if let warning = store.reminderWarning {
        Text(warning)
          .font(.pmCaption)
          .foregroundStyle(.red)
          .padding(.horizontal, 16)
          .padding(.top, 4)
      }
    }

    // MARK: - Description Section

    @ViewBuilder
    private var descriptionSection: some View {
      VStack(alignment: .trailing, spacing: 4) {
        TextField(
          "메모를 입력하세요 (선택)",
          text: Binding(
            get: { store.event.description ?? "" },
            set: { store.send(.view(.descriptionChanged($0))) }
          ),
          axis: .vertical
        )
        .lineLimit(3...6)
        .font(.body)
        .padding(16)
        .adaptiveGlassCard()

        Text("\((store.event.description ?? "").count)/500")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
          .padding(.trailing, 4)
      }
    }
  }
}

// MARK: - Preview

#Preview {
  CreatePersonalEvent.RootView(
    store: Store(
      initialState: CreatePersonalEvent.Feature.State()
    ) {
      CreatePersonalEvent.Feature()
    }
  )
}
