import SwiftUI
import ComposableArchitecture
import SharedFeature

// MARK: - Root View

extension CreateRecurringPersonalEvent {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @FocusState private var focusedField: Field?

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    private enum Field: Hashable {
      case title
      case description
    }

    public var body: some View {
      StepSheetContainer(
        title: store.navigationTitle,
        currentStep: 0,
        totalSteps: 1,
        showsDismissButton: true,
        onDismiss: { store.send(.view(.dismissTapped)) }
      ) {
        mainContent
      } bottomContent: {
        bottomBar
      }
      .onAppear { store.send(.view(.onAppear)) }
      .alert(
        LocalizedStrings.Common.error,
        isPresented: Binding(
          get: { store.errorMessage != nil },
          set: { if !$0 { store.send(.view(.dismissError)) } }
        ),
        actions: {
          Button(LocalizedStrings.Common.confirm) { store.send(.view(.dismissError)) }
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
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 16) {
            essentialSection
              .id(Field.title)
            recurrenceSection
            timeSection
            if store.isCheckingConflicts || !store.conflicts.isEmpty {
              ConflictWarningSection(
                conflicts: store.conflicts,
                isChecking: store.isCheckingConflicts
              )
            }
            seriesDateSection
            locationSection
            reminderSection
            descriptionSection
              .id(Field.description)
          }
          .padding(16)
          .padding(.bottom, 24)
        }
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
      .auroraBackground()
    }

    // MARK: - Bottom Bar

    @ViewBuilder
    private var bottomBar: some View {
      StepBottomBar(configuration: .navigation(
        showPrevious: false,
        previousAction: {},
        nextTitle: store.mode == .create
          ? LocalizedStrings.Common.save
          : LocalizedStrings.Common.modify,
        nextSystemImage: "checkmark.circle.fill",
        isNextDisabled: !store.canSave,
        isNextLoading: store.isSaving,
        nextAction: { store.send(.view(.saveTapped)) }
      ))
    }

    // MARK: - Essential Section (제목 + 이모지)

    @ViewBuilder
    private var essentialSection: some View {
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

          TextField(LocalizedStrings.Shared.eventTitlePlaceholder, text: Binding(
            get: { store.event.title },
            set: { store.send(.view(.titleChanged($0))) }
          ))
          .focused($focusedField, equals: .title)
          .font(.system(size: 18, weight: .medium))
          .textFieldStyle(.plain)
        }

        Text("\(store.event.title.count)/30")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
      .padding(12)
      .adaptiveGlassCard()
    }

    // MARK: - Recurrence Section

    @ViewBuilder
    private var recurrenceSection: some View {
      VStack(spacing: 0) {
        // 반복 주기 헤더
        HStack {
          Image(systemName: "arrow.clockwise")
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24)

          Text("반복 주기")
            .font(.body)
            .foregroundStyle(Color.pmtext.primary)

          Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        // Frequency Picker
        Picker("반복 주기", selection: Binding(
          get: { store.selectedFrequency },
          set: { store.send(.view(.frequencyChanged($0))) }
        )) {
          Text("매일").tag(RecurrenceRule.Frequency.daily)
          Text("매주").tag(RecurrenceRule.Frequency.weekly)
          Text("매월").tag(RecurrenceRule.Frequency.monthly)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)

        // 요일 선택 (weekly)
        if store.selectedFrequency == .weekly {
          Divider()
            .background(Color.white.opacity(0.12))

          HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { weekday in
              let isSelected = store.selectedWeekdays.contains(weekday)
              Button {
                store.send(.view(.weekdayToggled(weekday)))
              } label: {
                Text(weekdayShortName(weekday))
                  .font(.system(size: 14, weight: isSelected ? .bold : .regular))
                  .frame(width: 36, height: 36)
                  .background(isSelected ? Color.pmindigo.n500 : Color.clear)
                  .foregroundStyle(isSelected ? .white : Color.pmtext.primary)
                  .clipShape(Circle())
              }
              .buttonStyle(.plain)
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .transition(.opacity.combined(with: .move(edge: .top)))
        }

        // 일자 선택 (monthly)
        if store.selectedFrequency == .monthly {
          Divider()
            .background(Color.white.opacity(0.12))

          HStack {
            Text("매월")
              .font(.body)
              .foregroundStyle(Color.pmtext.secondary)

            Spacer()

            Picker("일자", selection: Binding(
              get: { store.selectedDayOfMonth },
              set: { store.send(.view(.dayOfMonthChanged($0))) }
            )) {
              ForEach(1...31, id: \.self) { day in
                Text("\(day)일").tag(day)
              }
            }
            .pickerStyle(.menu)
            .tint(Color.pmindigo.n500)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .adaptiveGlassCard()
      .animation(.default, value: store.selectedFrequency)
    }

    // MARK: - Time Section

    @ViewBuilder
    private var timeSection: some View {
      VStack(spacing: 0) {
        // 시작 시각
        HStack {
          Image(systemName: "clock")
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24)

          Text("시작 시각")
            .font(.body)
            .foregroundStyle(Color.pmtext.primary)

          Spacer()

          DatePicker(
            "",
            selection: Binding(
              get: {
                var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                components.hour = store.event.startTime.hour ?? 0
                components.minute = store.event.startTime.minute ?? 0
                return Calendar.current.date(from: components) ?? Date()
              },
              set: { store.send(.view(.startTimeChanged($0))) }
            ),
            displayedComponents: [.hourAndMinute]
          )
          .labelsHidden()
          .tint(Color.pmindigo.n500)
          .environment(\.locale, LocaleManager.appLocale)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        Divider()
          .background(Color.white.opacity(0.12))

        // 종료 시간 토글
        HStack {
          Image(systemName: "timer")
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24)

          Text("종료 시간")
            .font(.body)
            .foregroundStyle(Color.pmtext.primary)

          Spacer()

          Toggle("", isOn: Binding(
            get: { store.useEndTime },
            set: { _ in store.send(.view(.toggleUseEndTime)) }
          ))
          .labelsHidden()
          .tint(Color.pmindigo.n500)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        // 종료 시간 선택
        if store.useEndTime {
          Divider()
            .background(Color.white.opacity(0.12))

          let endTimeBinding = Binding<Date>(
            get: {
              var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
              components.hour = store.event.endTime?.hour ?? 0
              components.minute = store.event.endTime?.minute ?? 0
              return Calendar.current.date(from: components) ?? Date()
            },
            set: { store.send(.view(.endTimeChanged($0))) }
          )

          HStack {
            Spacer()
            DatePicker(
              "종료 시간",
              selection: endTimeBinding,
              displayedComponents: [.hourAndMinute]
            )
            .labelsHidden()
            .tint(Color.pmindigo.n500)
            .environment(\.locale, LocaleManager.appLocale)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .adaptiveGlassCard()
      .animation(.default, value: store.useEndTime)
    }

    // MARK: - Series Date Section

    @ViewBuilder
    private var seriesDateSection: some View {
      VStack(spacing: 0) {
        // 시작일
        HStack {
          Image(systemName: "calendar")
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24)

          Text("시작일")
            .font(.body)
            .foregroundStyle(Color.pmtext.primary)

          Spacer()

          DatePicker(
            "",
            selection: Binding(
              get: { store.event.seriesStartDate },
              set: { store.send(.view(.seriesStartDateChanged($0))) }
            ),
            displayedComponents: [.date]
          )
          .labelsHidden()
          .tint(Color.pmindigo.n500)
          .environment(\.locale, LocaleManager.appLocale)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        Divider()
          .background(Color.white.opacity(0.12))

        // 종료일 토글
        HStack {
          Image(systemName: "flag.checkered")
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24)

          Text("종료일")
            .font(.body)
            .foregroundStyle(Color.pmtext.primary)

          Spacer()

          Toggle("", isOn: Binding(
            get: { store.useSeriesEndDate },
            set: { _ in store.send(.view(.toggleUseSeriesEndDate)) }
          ))
          .labelsHidden()
          .tint(Color.pmindigo.n500)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)

        // 종료일 선택
        if store.useSeriesEndDate, let endDate = store.event.recurrence.seriesEndDate {
          Divider()
            .background(Color.white.opacity(0.12))

          HStack {
            Spacer()

            DatePicker(
              "",
              selection: Binding(
                get: { endDate },
                set: { store.send(.view(.seriesEndDateChanged($0))) }
              ),
              in: store.event.seriesStartDate...,
              displayedComponents: [.date]
            )
            .labelsHidden()
            .tint(Color.pmindigo.n500)
            .environment(\.locale, LocaleManager.appLocale)
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
          .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
      .adaptiveGlassCard()
      .animation(.default, value: store.useSeriesEndDate)
    }

    // MARK: - Location Section

    @ViewBuilder
    private var locationSection: some View {
      VStack(spacing: 0) {
        if let location = store.event.location {
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
          Button {
            store.send(.view(.locationTapped))
          } label: {
            HStack {
              Image(systemName: "mappin")
                .font(.body)
                .foregroundStyle(Color.pmindigo.n500)
                .frame(width: 24)

              Text(LocalizedStrings.Shared.addLocation)
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
      let currentOption = CreateRecurringPersonalEvent.ReminderOption.from(
        minutes: store.event.reminderMinutesBefore
      )
      HStack {
        Image(systemName: "bell")
          .font(.body)
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 24)

        Text(LocalizedStrings.Shared.reminderLabel)
          .font(.body)
          .foregroundStyle(Color.pmtext.primary)

        Spacer()

        Menu {
          Button {
            store.send(.view(.reminderOptionSelected(nil)), animation: .default)
          } label: {
            if currentOption == .none {
              Label(LocalizedStrings.Shared.reminderNone, systemImage: "checkmark")
            } else {
              Text(LocalizedStrings.Shared.reminderNone)
            }
          }

          Divider()

          ForEach(CreateRecurringPersonalEvent.ReminderOption.shortOptions, id: \.title) { option in
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

          ForEach(CreateRecurringPersonalEvent.ReminderOption.longOptions, id: \.title) { option in
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
    }

    // MARK: - Description Section

    @ViewBuilder
    private var descriptionSection: some View {
      VStack(alignment: .trailing, spacing: 4) {
        TextField(
          LocalizedStrings.Shared.memoPlaceholder,
          text: Binding(
            get: { store.event.description ?? "" },
            set: { store.send(.view(.descriptionChanged($0))) }
          ),
          axis: .vertical
        )
        .focused($focusedField, equals: .description)
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

    // MARK: - Helpers

    private func weekdayShortName(_ weekday: Int) -> String {
      switch weekday {
      case 1: return "일"
      case 2: return "월"
      case 3: return "화"
      case 4: return "수"
      case 5: return "목"
      case 6: return "금"
      case 7: return "토"
      default: return ""
      }
    }
  }
}

// MARK: - Preview

#Preview {
  CreateRecurringPersonalEvent.RootView(
    store: Store(
      initialState: CreateRecurringPersonalEvent.Feature.State()
    ) {
      CreateRecurringPersonalEvent.Feature()
    }
  )
}
