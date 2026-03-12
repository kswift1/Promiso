import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared

// MARK: - Namespace

public enum CreateRecurringPersonalEvent {}

// MARK: - Reducer

extension CreateRecurringPersonalEvent {
  @Reducer
  public struct Feature {
    @Dependency(\.recurringPersonalEventClient) var recurringPersonalEventClient
    @Dependency(\.localNotificationClient) var localNotificationClient
    @Dependency(\.emojiClient) var emojiClient
    @Dependency(\.hapticFeedback) var hapticFeedback
    @Dependency(\.continuousClock) var clock

    public init() {}

    // MARK: - Cancel IDs

    private enum CancelID {
      case emojiDebounce
    }

    // MARK: - Mode

    public enum Mode: Equatable, Sendable {
      case create
      case edit
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {
      var event: RecurringPersonalEventModel
      var mode: Mode
      var isSaving: Bool = false
      var isEmojiLoading: Bool = false
      var useEndTime: Bool = false
      var useSeriesEndDate: Bool = false
      var errorMessage: String?

      @Presents var locationPicker: LocationPicker.Feature.State?

      var selectedFrequency: RecurrenceRule.Frequency = .weekly
      var selectedWeekdays: Set<Int> = [2]
      var selectedDayOfMonth: Int = 1

      public init(event: RecurringPersonalEventModel = .empty, mode: Mode = .create) {
        self.event = event
        self.mode = mode
        self.selectedFrequency = event.recurrence.frequency
        self.selectedWeekdays = Set(event.recurrence.daysOfWeek ?? [2])
        self.selectedDayOfMonth = event.recurrence.dayOfMonth ?? 1
        self.useEndTime = event.endTime != nil
        self.useSeriesEndDate = event.recurrence.seriesEndDate != nil
      }

      var canSave: Bool {
        event.isTitleValid && event.isRecurrenceValid && !isSaving
      }

      var navigationTitle: String {
        mode == .create ? LocalizedStrings.Personal.addRecurringEvent : LocalizedStrings.Personal.recurringDetailTitle
      }
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
      case locationPicker(PresentationAction<LocationPicker.Feature.Action>)
    }

    @CasePathable
    public enum View: Sendable {
      case onAppear
      case titleChanged(String)
      case frequencyChanged(RecurrenceRule.Frequency)
      case weekdayToggled(Int)
      case dayOfMonthChanged(Int)
      case startTimeChanged(Date)
      case toggleUseEndTime
      case endTimeChanged(Date)
      case seriesStartDateChanged(Date)
      case toggleUseSeriesEndDate
      case seriesEndDateChanged(Date)
      case reminderOptionSelected(Int?)
      case descriptionChanged(String)
      case locationTapped
      case removeLocation
      case saveTapped
      case dismissTapped
      case dismissError
    }

    @CasePathable
    public enum Internal: Sendable {
      case titleDebounced(String)
      case emojiGenerated(String)
      case emojiGenerationFailed
      case saveSuccess(RecurringPersonalEventModel)
      case saveFailed(String)
    }

    @CasePathable
    public enum Delegate: Sendable {
      case eventCreated
      case eventUpdated(RecurringPersonalEventModel)
      case dismiss
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {

        // MARK: - View Actions

        case let .view(viewAction):
          switch viewAction {
          case .onAppear:
            return .none

          case .titleChanged(let title):
            let oldTitle = state.event.title
            state.event.title = String(title.prefix(30))
            guard title != oldTitle else { return .none }
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
              state.event.emoji = nil
              return .cancel(id: CancelID.emojiDebounce)
            }
            return .run { [clock] send in
              try await clock.sleep(for: .seconds(1))
              await send(.internal(.titleDebounced(title)))
            }
            .cancellable(id: CancelID.emojiDebounce, cancelInFlight: true)

          case .frequencyChanged(let frequency):
            state.selectedFrequency = frequency
            rebuildRecurrence(state: &state)
            return .none

          case .weekdayToggled(let weekday):
            if state.selectedWeekdays.contains(weekday) {
              // 최소 1개는 선택 유지
              guard state.selectedWeekdays.count > 1 else { return .none }
              state.selectedWeekdays.remove(weekday)
            } else {
              state.selectedWeekdays.insert(weekday)
            }
            rebuildRecurrence(state: &state)
            return .run { _ in await hapticFeedback.selection() }

          case .dayOfMonthChanged(let day):
            state.selectedDayOfMonth = max(1, min(31, day))
            rebuildRecurrence(state: &state)
            return .none

          case .startTimeChanged(let date):
            let calendar = Calendar.current
            state.event.startTime = DateComponents(
              hour: calendar.component(.hour, from: date),
              minute: calendar.component(.minute, from: date)
            )
            return .none

          case .toggleUseEndTime:
            state.useEndTime.toggle()
            if state.useEndTime {
              // 기본 종료시간: 시작시간 + 1시간
              if state.event.endTime == nil {
                let startHour = state.event.startTime.hour ?? 0
                let startMinute = state.event.startTime.minute ?? 0
                let totalMinutes = startHour * 60 + startMinute + 60
                state.event.endTime = DateComponents(hour: (totalMinutes / 60) % 24, minute: totalMinutes % 60)
              }
            } else {
              state.event.endTime = nil
            }
            return .run { _ in await hapticFeedback.selection() }

          case .endTimeChanged(let date):
            let calendar = Calendar.current
            state.event.endTime = DateComponents(
              hour: calendar.component(.hour, from: date),
              minute: calendar.component(.minute, from: date)
            )
            return .none

          case .seriesStartDateChanged(let date):
            state.event.seriesStartDate = date
            return .none

          case .toggleUseSeriesEndDate:
            state.useSeriesEndDate.toggle()
            if !state.useSeriesEndDate {
              rebuildRecurrence(state: &state)
            } else {
              // 기본 종료일: 시작일로부터 3개월 후
              let defaultEndDate = Calendar.current.date(
                byAdding: .month,
                value: 3,
                to: state.event.seriesStartDate
              ) ?? state.event.seriesStartDate
              state.event.recurrence = RecurrenceRule(
                frequency: state.event.recurrence.frequency,
                daysOfWeek: state.event.recurrence.daysOfWeek,
                dayOfMonth: state.event.recurrence.dayOfMonth,
                seriesEndDate: defaultEndDate
              )
            }
            return .run { _ in await hapticFeedback.selection() }

          case .seriesEndDateChanged(let date):
            state.event.recurrence = RecurrenceRule(
              frequency: state.event.recurrence.frequency,
              daysOfWeek: state.event.recurrence.daysOfWeek,
              dayOfMonth: state.event.recurrence.dayOfMonth,
              seriesEndDate: date
            )
            return .none

          case .reminderOptionSelected(let minutes):
            state.event.reminderMinutesBefore = minutes
            return .run { _ in await hapticFeedback.selection() }

          case .descriptionChanged(let text):
            let trimmed = String(text.prefix(500))
            state.event.description = trimmed.isEmpty ? nil : trimmed
            return .none

          case .locationTapped:
            state.locationPicker = LocationPicker.Feature.State()
            return .none

          case .removeLocation:
            state.event.location = nil
            return .run { _ in await hapticFeedback.selection() }

          case .saveTapped:
            guard state.canSave else { return .none }
            state.isSaving = true
            state.errorMessage = nil
            return .run { [event = state.event, mode = state.mode, recurringPersonalEventClient] send in
              do {
                var savedEvent = event
                switch mode {
                case .create:
                  let eventId = try await recurringPersonalEventClient.createEvent(event)
                  savedEvent.id = eventId
                case .edit:
                  try await recurringPersonalEventClient.updateEvent(event)
                }
                await send(.internal(.saveSuccess(savedEvent)))
              } catch {
                await send(.internal(.saveFailed(LocalizedStrings.Error.serverError)))
              }
            }

          case .dismissTapped:
            return .send(.delegate(.dismiss))

          case .dismissError:
            state.errorMessage = nil
            return .none
          }

        // MARK: - Internal Actions

        case let .internal(internalAction):
          switch internalAction {
          case .titleDebounced(let title):
            state.isEmojiLoading = true
            return .run { [emojiClient] send in
              do {
                let emoji = try await emojiClient.generate(title)
                await send(.internal(.emojiGenerated(emoji)))
              } catch {
                await send(.internal(.emojiGenerationFailed))
              }
            }

          case .emojiGenerated(let emoji):
            state.isEmojiLoading = false
            state.event.emoji = emoji
            return .none

          case .emojiGenerationFailed:
            state.isEmojiLoading = false
            return .none

          case .saveSuccess(let event):
            state.isSaving = false
            let delegateAction: Action = state.mode == .create
              ? .delegate(.eventCreated)
              : .delegate(.eventUpdated(event))
            if let reminder = event.reminderMinutesBefore {
              return .merge(
                .run { _ in await hapticFeedback.success() },
                .run { [localNotificationClient] _ in
                  await cancelRecurringNotifications(event: event, client: localNotificationClient)
                  await scheduleRecurringNotifications(event: event, reminder: reminder, client: localNotificationClient)
                },
                .send(delegateAction)
              )
            }
            return .merge(
              .run { _ in await hapticFeedback.success() },
              .send(delegateAction)
            )

          case .saveFailed(let message):
            state.isSaving = false
            state.errorMessage = message
            return .run { _ in await hapticFeedback.error() }
          }

        // MARK: - LocationPicker

        case .locationPicker(.presented(.delegate(.locationSelected(let location)))):
          state.event.location = location
          state.locationPicker = nil
          return .none

        case .locationPicker(.presented(.delegate(.dismissed))):
          state.locationPicker = nil
          return .none

        case .locationPicker:
          return .none

        // MARK: - Delegate

        case .delegate:
          return .none
        }
      }
      .ifLet(\.$locationPicker, action: \.locationPicker) {
        LocationPicker.Feature()
      }
    }

    // MARK: - Recurrence Rebuild Helper

    private func rebuildRecurrence(state: inout State) {
      let endDate = state.useSeriesEndDate ? state.event.recurrence.seriesEndDate : nil
      switch state.selectedFrequency {
      case .daily:
        state.event.recurrence = .daily(until: endDate)
      case .weekly:
        state.event.recurrence = .weekly(Array(state.selectedWeekdays), until: endDate)
      case .monthly:
        state.event.recurrence = .monthly(day: state.selectedDayOfMonth, until: endDate)
      }
    }

    // MARK: - Notification Helpers

    private func scheduleRecurringNotifications(
      event: RecurringPersonalEventModel,
      reminder: Int,
      client: LocalNotificationClient
    ) async {
      let baseHour = event.startTime.hour ?? 0
      let baseMinute = event.startTime.minute ?? 0
      let totalMinutes = baseHour * 60 + baseMinute - reminder
      let notifyHour = (totalMinutes / 60 % 24 + 24) % 24
      let notifyMinute = (totalMinutes % 60 + 60) % 60
      let body = reminder == 0
        ? LocalizedStrings.Personal.notificationStartsNow
        : LocalizedStrings.Personal.notificationStartsInMinutes(reminder)
      let notificationTitle = "\(event.displayEmoji) \(event.title)"

      switch event.recurrence.frequency {
      case .daily:
        var components = DateComponents()
        components.hour = notifyHour
        components.minute = notifyMinute
        try? await client.scheduleRepeating(
          "recurring-\(event.id)-daily",
          notificationTitle,
          body,
          components,
          ["recurringEventId": event.id]
        )

      case .weekly:
        guard let weekdays = event.recurrence.daysOfWeek else { return }
        for weekday in weekdays {
          var components = DateComponents()
          components.weekday = weekday
          components.hour = notifyHour
          components.minute = notifyMinute
          try? await client.scheduleRepeating(
            "recurring-\(event.id)-weekly-\(weekday)",
            notificationTitle,
            body,
            components,
            ["recurringEventId": event.id]
          )
        }

      case .monthly:
        guard let day = event.recurrence.dayOfMonth else { return }
        var components = DateComponents()
        components.day = day
        components.hour = notifyHour
        components.minute = notifyMinute
        try? await client.scheduleRepeating(
          "recurring-\(event.id)-monthly",
          notificationTitle,
          body,
          components,
          ["recurringEventId": event.id]
        )
      }
    }

    private func cancelRecurringNotifications(
      event: RecurringPersonalEventModel,
      client: LocalNotificationClient
    ) async {
      var ids = [
        "recurring-\(event.id)-daily",
        "recurring-\(event.id)-monthly",
      ]
      for weekday in 1...7 {
        ids.append("recurring-\(event.id)-weekly-\(weekday)")
      }
      await client.cancelAll(ids)
    }
  }
}

// MARK: - Reminder Options

extension CreateRecurringPersonalEvent {
  public enum ReminderOption: Equatable, Sendable {
    case none
    case atEvent
    case fiveMinutes
    case tenMinutes
    case fifteenMinutes
    case thirtyMinutes
    case oneHour
    case twoHours
    case oneDay
    case twoDays
    case oneWeek

    public var minutes: Int? {
      switch self {
      case .none: return nil
      case .atEvent: return 0
      case .fiveMinutes: return 5
      case .tenMinutes: return 10
      case .fifteenMinutes: return 15
      case .thirtyMinutes: return 30
      case .oneHour: return 60
      case .twoHours: return 120
      case .oneDay: return 1440
      case .twoDays: return 2880
      case .oneWeek: return 10080
      }
    }

    public var title: String {
      switch self {
      case .none: return LocalizedStrings.Shared.reminderNone
      case .atEvent: return LocalizedStrings.Shared.reminderAtEvent
      case .fiveMinutes: return LocalizedStrings.Shared.reminder5min
      case .tenMinutes: return LocalizedStrings.Shared.reminder10min
      case .fifteenMinutes: return LocalizedStrings.Shared.reminder15min
      case .thirtyMinutes: return LocalizedStrings.Shared.reminder30min
      case .oneHour: return LocalizedStrings.Shared.reminder1hour
      case .twoHours: return LocalizedStrings.Shared.reminder2hours
      case .oneDay: return LocalizedStrings.Shared.reminder1day
      case .twoDays: return LocalizedStrings.Shared.reminder2days
      case .oneWeek: return LocalizedStrings.Shared.reminder1week
      }
    }

    public static let shortOptions: [ReminderOption] = [
      .atEvent, .fiveMinutes, .tenMinutes, .fifteenMinutes,
      .thirtyMinutes, .oneHour, .twoHours,
    ]

    public static let longOptions: [ReminderOption] = [
      .oneDay, .twoDays, .oneWeek,
    ]

    public static func from(minutes: Int?) -> ReminderOption {
      guard let minutes else { return .none }
      switch minutes {
      case 0: return .atEvent
      case 5: return .fiveMinutes
      case 10: return .tenMinutes
      case 15: return .fifteenMinutes
      case 30: return .thirtyMinutes
      case 60: return .oneHour
      case 120: return .twoHours
      case 1440: return .oneDay
      case 2880: return .twoDays
      case 10080: return .oneWeek
      default: return .none
      }
    }
  }
}
