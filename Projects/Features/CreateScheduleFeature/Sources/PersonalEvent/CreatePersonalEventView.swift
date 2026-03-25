import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared
import PhotosUI
import UIKit

// MARK: - Root View

extension CreatePersonalEvent {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @FocusState private var focusedField: Field?
    private let dismissButtonVisibility: DismissButtonVisibility

    public enum DismissButtonVisibility {
      case always
      case hiddenForCreateMode
    }

    public init(
      store: StoreOf<Feature>,
      dismissButtonVisibility: DismissButtonVisibility = .always
    ) {
      self.store = store
      self.dismissButtonVisibility = dismissButtonVisibility
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
        showsDismissButton: showsDismissButton,
        onDismiss: { store.send(.view(.dismissTapped)) }
      ) {
        singleStepContent
      } floatingContent: {
        floatingBonusView
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
      .sheet(item: $store.scope(state: \.notificationPermission, action: \.notificationPermission)) { permissionStore in
        NotificationPermission.View(store: permissionStore)
          .presentationDetents([.large])
      }
    }

    private var showsDismissButton: Bool {
      switch dismissButtonVisibility {
      case .always:
        return true
      case .hiddenForCreateMode:
        return store.mode == .edit
      }
    }

    // MARK: - Single Step Content

    @ViewBuilder
    private var singleStepContent: some View {
      ScrollViewReader { proxy in
        ScrollView {
          VStack(spacing: 16) {
            essentialSection
              .id(Field.title)
            endTimeSection
            locationSection
            reminderSection
            descriptionSection
              .id(Field.description)

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

    // MARK: - Floating Bonus View

    @ViewBuilder
    private var floatingBonusView: some View {
      ProBonusFloatingView(
        isPro: store.isPro,
        hasCheckedConflicts: store.hasCheckedConflicts,
        weatherForecast: weatherForecast,
        rangeForecasts: weatherRangeForecasts,
        forecastSource: weatherForecastSource,
        isLoadingWeather: store.weatherState.isLoading,
        weatherLocationName: store.event.location?.name,
        conflicts: store.conflicts.map {
          ConflictInfo(
            title: $0.title,
            overlapMinutes: $0.overlapMinutes,
            gapMinutes: $0.gapMinutes,
            startAt: $0.startAt,
            endAt: $0.endAt,
            emoji: $0.emoji,
            severity: $0.severity == .confirmed ? .confirmed : .pending
          )
        },
        isCheckingConflicts: store.isCheckingConflicts,
        conflictCheckTrigger: store.conflictCheckTrigger,
        conflictThresholdMinutes: store.conflictDetectionThreshold,
        newEventTitle: store.event.title,
        newEventEmoji: store.event.emoji,
        newEventStartAt: store.event.startAt,
        newEventEndAt: store.event.endAt
      )
    }

    private var weatherForecast: HourlyForecast? {
      guard let info = store.weatherState.value else { return nil }
      return WeatherHintHelper.forecast(from: info, startAt: store.event.startAt, endAt: store.event.endAt)
    }

    private var weatherRangeForecasts: [HourlyForecast] {
      guard let info = store.weatherState.value else { return [] }
      return WeatherHintHelper.rangeForecasts(from: info, startAt: store.event.startAt, endAt: store.event.endAt)
    }

    private var weatherForecastSource: ForecastSource {
      guard let info = store.weatherState.value else { return .shortTerm }
      return WeatherHintHelper.forecastSource(from: info, startAt: store.event.startAt)
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

          Divider()
            .background(Color.white.opacity(0.12))

          // 시작 시간
          HStack {
            Image(systemName: "clock")
              .font(.body)
              .foregroundStyle(Color.pmindigo.n500)
              .frame(width: 24)

            Text(LocalizedStrings.Common.start)
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
            .environment(\.locale, LocaleManager.appLocale)
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

          Text(LocalizedStrings.Common.endTime)
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

        if store.useEndTime, let endAt = store.event.endAt {
          Divider()
            .background(Color.white.opacity(0.12))

          HStack {
            Text(store.event.startAt.durationText(to: endAt, prefix: LocalizedStrings.CreateSchedule.totalDurationPrefix))
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
      let currentOption = CreatePersonalEvent.ReminderOption.from(
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
          .foregroundStyle(Color.pmerror.n500)
          .padding(.horizontal, 16)
          .padding(.top, 4)
      }
    }

    // MARK: - Description Section

    @ViewBuilder
    private var descriptionSection: some View {
      DescriptionBlockEditor(
        blocks: Binding(
          get: { store.event.descriptionBlocks },
          set: { store.send(.view(.descriptionBlocksChanged($0))) }
        )
      )
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
