import SwiftUI
import ComposableArchitecture
import PromisoShared

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
          VStack(spacing: 24) {
            titleSection
            dateTimeSection
            reminderSection
            descriptionSection
          }
          .padding(16)
          .padding(.bottom, 24)
        }
        .auroraBackground()
        .navigationTitle("새 일정")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("취소") {
              store.send(.view(.dismissTapped))
            }
          }
          ToolbarItem(placement: .confirmationAction) {
            if store.isCreating {
              ProgressView()
            } else {
              Button("저장") {
                store.send(.view(.saveTapped))
              }
              .fontWeight(.semibold)
              .disabled(!store.canSave)
            }
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
      }
    }

    // MARK: - Title Section

    @ViewBuilder
    private var titleSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("일정 정보")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        HStack(spacing: 12) {
          // Emoji
          ZStack {
            RoundedRectangle(cornerRadius: 12)
              .fill(Color(UIColor.systemGray6))
              .frame(width: 56, height: 56)

            if store.isEmojiLoading {
              ProgressView()
            } else {
              Text(store.event.displayEmoji)
                .font(.system(size: 28))
            }
          }

          // Title
          TextField("일정 제목을 입력하세요", text: Binding(
            get: { store.event.title },
            set: { store.send(.view(.titleChanged($0))) }
          ))
          .font(.system(size: 18, weight: .medium))
          .textFieldStyle(.plain)
        }
        .padding(12)
        .adaptiveGlassCard()
      }
    }

    // MARK: - Date Time Section

    @ViewBuilder
    private var dateTimeSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("날짜 및 시간")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          // Start Date
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
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)

          Divider()
            .background(Color.white.opacity(0.12))

          // End Time Toggle
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

          // End Date Picker (conditional)
          if store.useEndTime, let endAt = store.event.endAt {
            Divider()
              .background(Color.white.opacity(0.12))

            HStack {
              Spacer()
                .frame(width: 40)

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

              Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .transition(.opacity.combined(with: .move(edge: .top)))
          }
        }
        .adaptiveGlassCard()
      }
    }

    // MARK: - Reminder Section

    @ViewBuilder
    private var reminderSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("알림")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          HStack {
            Image(systemName: "bell")
              .font(.body)
              .foregroundStyle(Color.pmindigo.n500)
              .frame(width: 24)

            Text("미리 알림")
              .font(.body)
              .foregroundStyle(Color.pmtext.primary)

            Spacer()

            Toggle("", isOn: Binding(
              get: { store.useReminder },
              set: { _ in store.send(.view(.toggleUseReminder), animation: .default) }
            ))
            .labelsHidden()
            .tint(Color.pmindigo.n500)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)

          if store.useReminder {
            Divider()
              .background(Color.white.opacity(0.12))

            // Reminder options
            let currentMinutes = store.event.reminderMinutesBefore ?? 30
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8) {
                ForEach(CreatePersonalEvent.ReminderOption.allCases, id: \.rawValue) { option in
                  Button {
                    store.send(.view(.reminderChanged(option.rawValue)))
                  } label: {
                    Text(option.title)
                      .font(.system(size: 14, weight: currentMinutes == option.rawValue ? .semibold : .regular))
                      .foregroundStyle(currentMinutes == option.rawValue ? .white : Color.pmtext.primary)
                      .padding(.horizontal, 14)
                      .padding(.vertical, 8)
                      .background(
                        currentMinutes == option.rawValue
                          ? Color.pmindigo.n500
                          : Color(UIColor.systemGray6)
                      )
                      .clipShape(Capsule())
                  }
                  .buttonStyle(.plain)
                }
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 12)
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
          }
        }
        .adaptiveGlassCard()
      }
    }

    // MARK: - Description Section

    @ViewBuilder
    private var descriptionSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("메모")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

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
