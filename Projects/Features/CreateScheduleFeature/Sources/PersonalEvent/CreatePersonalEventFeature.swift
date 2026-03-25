import SwiftUI
import UIKit
import ComposableArchitecture
import Clients
import PromisoShared
import PhotosUI

// MARK: - Namespace

public enum CreatePersonalEvent {}

// MARK: - Reducer

extension CreatePersonalEvent {
  @Reducer
  public struct Feature {
    @Dependency(\.personalEventClient) var personalEventClient
    @Dependency(\.localNotificationClient) var localNotificationClient
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.emojiClient) var emojiClient
    @Dependency(\.hapticFeedback) var hapticFeedback
    @Dependency(\.continuousClock) var clock
    @Dependency(\.calendarSyncClient) var calendarSyncClient
    @Dependency(\.imageUploadClient) var imageUploadClient
    @Dependency(\.authClient) var authClient
    @Dependency(\.scheduleConflictClient) var scheduleConflictClient
    @Dependency(\.userSettingsClient) var userSettingsClient
    @Dependency(\.weatherClient) var weatherClient
    @Dependency(\.appReviewClient) var appReviewClient

    public init() {}

    // MARK: - Cancel IDs

    private enum CancelID {
      case emojiDebounce
      case conflictCheckDebounce
      case weatherFetchDebounce
      case appReviewDelay
    }

    // MARK: - Mode

    public enum Mode: Equatable, Sendable {
      case create
      case edit
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {
      var event: PersonalEventModel
      var mode: Mode
      var isSaving: Bool = false
      var isEmojiLoading: Bool = false
      var useEndTime: Bool = false
      var errorMessage: String?
      /// 알림 권한 미허용 시 보류할 분 값
      var pendingReminderMinutes: Int?
      /// 알림 시간 성립 불가 시 경고 메시지
      var reminderWarning: String?

      @Presents var locationPicker: LocationPicker.Feature.State?
      @Presents var notificationPermission: NotificationPermission.Feature.State?

      // 이미지 첨부
      var localImageData: [Data] = []
      var removedImageUrls: [String] = []

      // 일정 충돌 감지
      var currentUserId: String = ""
      var conflicts: [ScheduleConflict] = []
      var isCheckingConflicts: Bool = false
      var hasCheckedConflicts: Bool = false
      var conflictCheckTrigger: ConflictCheckTrigger = .initial
      var conflictDetectionThreshold: Int = 0
      var hasLoadedSettings: Bool = false
      @Shared(.inMemory(AppConstants.SharedState.isPro)) var isPro: Bool = false

      // 날씨 힌트 (보너스)
      var weatherState: LoadingState<WeatherInfo> = .idle

      public init(event: PersonalEventModel = .empty, mode: Mode = .create) {
        self.event = event
        self.mode = mode
        self.useEndTime = event.endAt != nil
      }

      var canSave: Bool {
        event.isTitleValid && !isSaving
      }

      var navigationTitle: String {
        mode == .create ? LocalizedStrings.Shared.newEvent : LocalizedStrings.Shared.editEvent
      }
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
      case locationPicker(PresentationAction<LocationPicker.Feature.Action>)
      case notificationPermission(PresentationAction<NotificationPermission.Feature.Action>)
    }

    @CasePathable
    public enum View: Sendable {
      case titleChanged(String)
      case startDateChanged(Date)
      case endDateChanged(Date)
      case toggleUseEndTime
      case reminderOptionSelected(Int?)
      case descriptionChanged(String)
      case descriptionBlocksChanged([DescriptionBlock])
      case locationTapped
      case removeLocation
      case saveTapped
      case dismissTapped
      case dismissError
      // 이미지 첨부
      case photosSelected([PhotosPickerItem])
      case removeLocalImage(Int)
      case removeExistingImage(Int)
      case onAppear
    }

    @CasePathable
    public enum Internal: Sendable {
      case titleDebounced(String)
      case emojiGenerated(String)
      case emojiGenerationFailed
      case photosLoaded([Data])
      case saveSuccess(PersonalEventModel)
      case saveFailed(String)
      case notificationStatusChecked(NotificationAuthorizationStatus)
      case conflictsLoaded([ScheduleConflict])
      case settingsLoaded(String, Int)
      case refreshProFeatures(debounce: Bool)
      case weatherResponse(Result<WeatherInfo, Error>)
    }

    @CasePathable
    public enum Delegate: Sendable {
      case eventCreated
      case eventUpdated(PersonalEventModel)
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
            guard !state.hasLoadedSettings else { return .none }
            return .merge(
              .run { [authClient, userSettingsClient] send in
                guard let user = await authClient.currentUser() else { return }
                do {
                  let settings = try await userSettingsClient.fetchSettings(user.uid)
                  await send(.internal(.settingsLoaded(user.uid, settings.conflictDetectionThreshold)))
                } catch {
                  // 설정 로드 실패 시 기본값으로 처리 (충돌 감지 비활성)
                }
              },
              .send(.internal(.refreshProFeatures(debounce: false)))
            )

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

          case .startDateChanged(let date):
            state.event.startAt = date
            state.conflictCheckTrigger = .startTimeChanged
            if let endAt = state.event.endAt, endAt <= date {
              state.event.endAt = date.addingTimeInterval(3600)
            }
            // 기존 알림 설정 재검증
            if let minutes = state.event.reminderMinutesBefore {
              let reminderDate = date.addingTimeInterval(-Double(minutes) * 60)
              if reminderDate <= Date() {
                state.reminderWarning = LocalizedStrings.Personal.reminderTooSoonWarning
                state.event.reminderMinutesBefore = nil
              } else {
                state.reminderWarning = nil
              }
            }
            return .send(.internal(.refreshProFeatures(debounce: true)))

          case .endDateChanged(let date):
            state.event.endAt = date
            state.conflictCheckTrigger = .endTimeChanged
            return .send(.internal(.refreshProFeatures(debounce: false)))

          case .toggleUseEndTime:
            state.useEndTime.toggle()
            state.conflictCheckTrigger = .endTimeChanged
            if state.useEndTime {
              state.event.endAt = state.event.startAt.addingTimeInterval(3600)
            } else {
              state.event.endAt = nil
            }
            return .merge(
              .run { _ in await hapticFeedback.selection() },
              .send(.internal(.refreshProFeatures(debounce: false)))
            )

          case .reminderOptionSelected(let minutes):
            if let minutes {
              // 알림 시간 성립 여부 검증
              let reminderDate = state.event.startAt.addingTimeInterval(-Double(minutes) * 60)
              if reminderDate <= Date() {
                state.reminderWarning = LocalizedStrings.Personal.reminderTooSoonWarning
                state.event.reminderMinutesBefore = nil
                state.pendingReminderMinutes = nil
                return .run { _ in await hapticFeedback.error() }
              }
              state.reminderWarning = nil
              // 알림 설정 시 권한 확인
              state.pendingReminderMinutes = minutes
              return .run { [notificationClient] send in
                let status = await notificationClient.getAuthorizationStatus()
                await send(.internal(.notificationStatusChecked(status)))
              }
            } else {
              // "없음" 선택
              state.event.reminderMinutesBefore = nil
              state.pendingReminderMinutes = nil
              state.reminderWarning = nil
              return .run { _ in await hapticFeedback.selection() }
            }

          case .descriptionChanged(let text):
            let trimmed = String(text.prefix(500))
            state.event.description = trimmed.isEmpty ? nil : trimmed
            return .none

          case .descriptionBlocksChanged(let blocks):
            state.event.descriptionBlocks = blocks
            state.event.description = blocks.plainText
            return .none

          case .locationTapped:
            state.locationPicker = LocationPicker.Feature.State()
            return .none

          case .removeLocation:
            state.event.location = nil
            state.weatherState = .idle
            return .merge(
              .run { _ in await hapticFeedback.selection() },
              .cancel(id: CancelID.weatherFetchDebounce)
            )

          case .saveTapped:
            guard state.canSave else { return .none }
            state.isSaving = true
            state.errorMessage = nil
            let localImages = state.localImageData
            let removedUrls = state.removedImageUrls
            return .run { [event = state.event, mode = state.mode, personalEventClient, localNotificationClient, calendarSyncClient, imageUploadClient, authClient] send in
              do {
                var savedEvent = event
                let syncEnabled = UserDefaults.standard.bool(
                  forKey: AppConstants.UserDefaults.personalCalendarSync
                )
                guard let userId = await authClient.currentUser()?.uid else {
                  throw NSError(
                    domain: "CreatePersonalEvent",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: LocalizedStrings.Error.userAuthRequired]
                  )
                }

                switch mode {
                case .create:
                  let eventId = try await personalEventClient.createEvent(event)
                  savedEvent.id = eventId

                  // 이미지 업로드
                  if !localImages.isEmpty {
                    do {
                      let imageUrls = try await imageUploadClient.uploadImages(localImages, "personal_event_images/\(userId)/\(eventId)")
                      savedEvent.imageUrls = imageUrls
                      try await personalEventClient.updateEvent(savedEvent)
                    } catch {
                      AppLogger.general.error("이미지 업로드 실패: \(error.localizedDescription)")
                      // 이미지 업로드 실패해도 이벤트 생성은 성공
                    }
                  }

                  try? await calendarSyncClient.addPersonalEvent(savedEvent, syncEnabled)

                case .edit:
                  // 이미지 처리
                  if !localImages.isEmpty || !removedUrls.isEmpty {
                    var finalImageUrls = event.imageUrls.filter { !removedUrls.contains($0) }

                    if !localImages.isEmpty {
                      do {
                        let newUrls = try await imageUploadClient.uploadImages(localImages, "personal_event_images/\(userId)/\(event.id)")
                        finalImageUrls.append(contentsOf: newUrls)
                      } catch {
                        AppLogger.general.error("이미지 업로드 실패: \(error.localizedDescription)")
                        // 이미지 업로드 실패 시 기존 이미지만 유지
                      }
                    }

                    savedEvent.imageUrls = Array(finalImageUrls.prefix(3))
                  }

                  try await personalEventClient.updateEvent(savedEvent)
                  try? await calendarSyncClient.updatePersonalEvent(savedEvent, syncEnabled)

                  // 삭제된 이미지 Storage에서 제거 (best-effort)
                  if !removedUrls.isEmpty {
                    await imageUploadClient.deleteImages(removedUrls)
                  }
                }

                // 기존 알림 취소 후 재스케줄링
                await localNotificationClient.cancel(savedEvent.notificationId)
                if savedEvent.canScheduleReminder, let date = savedEvent.reminderDate {
                  try? await localNotificationClient.schedule(
                    savedEvent.notificationId,
                    savedEvent.notificationTitle,
                    savedEvent.notificationBody,
                    date,
                    ["type": "personal_event_reminder", "eventId": savedEvent.id]
                  )
                }

                await send(.internal(.saveSuccess(savedEvent)))
              } catch {
                await send(.internal(.saveFailed(LocalizedStrings.Error.unknownError)))
              }
            }

          case .dismissTapped:
            return .send(.delegate(.dismiss))

          case .dismissError:
            state.errorMessage = nil
            return .none

          case .photosSelected(let items):
            return .run { send in
              var loadedData: [Data] = []
              for item in items {
                if let data = try? await item.loadTransferable(type: Data.self) {
                  loadedData.append(data)
                }
              }
              await send(.internal(.photosLoaded(loadedData)))
            }

          case .removeLocalImage(let index):
            guard index < state.localImageData.count else { return .none }
            state.localImageData.remove(at: index)
            return .none

          case .removeExistingImage(let index):
            let visibleUrls = state.event.imageUrls.filter { !state.removedImageUrls.contains($0) }
            guard index < visibleUrls.count else { return .none }
            state.removedImageUrls.append(visibleUrls[index])
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

          case .photosLoaded(let data):
            let totalExisting = state.event.imageUrls.count - state.removedImageUrls.count
            let remaining = 3 - totalExisting - state.localImageData.count
            let toAdd = Array(data.prefix(max(0, remaining)))
            state.localImageData.append(contentsOf: toAdd)
            return .none

          case .saveSuccess(let event):
            state.isSaving = false
            let isCreate = state.mode == .create
            let delegateAction: Action = isCreate
              ? .delegate(.eventCreated)
              : .delegate(.eventUpdated(event))
            var effects: [Effect<Action>] = [
              .run { _ in await hapticFeedback.success() },
              .send(delegateAction),
            ]
            if isCreate {
              effects.append(
                .run { [appReviewClient, clock] _ in
                  try? await clock.sleep(for: .seconds(2))
                  await appReviewClient.requestReviewIfEligible()
                }
                .cancellable(id: CancelID.appReviewDelay)
              )
            }
            return .merge(effects)

          case .saveFailed(let message):
            state.isSaving = false
            state.errorMessage = message
            return .run { _ in await hapticFeedback.error() }

          case .notificationStatusChecked(let status):
            switch status {
            case .authorized, .provisional, .ephemeral:
              state.event.reminderMinutesBefore = state.pendingReminderMinutes
              state.pendingReminderMinutes = nil
              return .run { _ in await hapticFeedback.selection() }
            case .notDetermined, .denied:
              state.notificationPermission = NotificationPermission.Feature.State(allowInteractiveDismiss: true)
              return .none
            }

          case .conflictsLoaded(let conflicts):
            AppLogger.personal.info("[ConflictCheck] 개인 일정 - 충돌 결과 수신: \(conflicts.count)건")
            state.conflicts = conflicts
            state.isCheckingConflicts = false
            state.hasCheckedConflicts = true
            return .none

          case .settingsLoaded(let userId, let threshold):
            state.currentUserId = userId
            state.conflictDetectionThreshold = threshold
            state.hasLoadedSettings = true
            return .send(.internal(.refreshProFeatures(debounce: false)))

          case .refreshProFeatures(let debounce):
            guard state.isPro else {
              state.isCheckingConflicts = false
              state.conflicts = []
              state.hasCheckedConflicts = false
              state.weatherState = .idle
              return .none
            }
            return .merge(
              checkConflictsEffect(state: &state),
              fetchWeatherHintEffect(state: &state, debounce: debounce)
            )

          case .weatherResponse(.success(let info)):
            state.weatherState = .loaded(info)
            return .none

          case .weatherResponse(.failure):
            state.weatherState = .idle
            return .none
          }

        // MARK: - LocationPicker

        case .locationPicker(.presented(.delegate(.locationSelected(let location)))):
          state.event.location = location
          state.locationPicker = nil
          return .send(.internal(.refreshProFeatures(debounce: false)))

        case .locationPicker(.presented(.delegate(.dismissed))):
          state.locationPicker = nil
          return .none

        case .locationPicker:
          return .none

        // MARK: - NotificationPermission

        case .notificationPermission(.presented(.delegate(.permissionChanged(let isGranted)))):
          if isGranted {
            state.event.reminderMinutesBefore = state.pendingReminderMinutes
          }
          state.pendingReminderMinutes = nil
          return .none

        case .notificationPermission(.presented(.delegate(.dismissed))):
          state.notificationPermission = nil
          // 스와이프로 닫았을 때도 권한 상태 재확인 후 pending 적용
          guard state.pendingReminderMinutes != nil else { return .none }
          return .run { [notificationClient] send in
            let status = await notificationClient.getAuthorizationStatus()
            if status.isGranted {
              await send(.internal(.notificationStatusChecked(status)))
            }
          }

        case .notificationPermission(.dismiss):
          // 스와이프 dismiss 시 pendingReminderMinutes 정리
          state.pendingReminderMinutes = nil
          return .none

        case .notificationPermission:
          return .none

        // MARK: - Delegate

        case .delegate:
          return .none
        }
      }
      .ifLet(\.$locationPicker, action: \.locationPicker) {
        LocationPicker.Feature()
      }
      .ifLet(\.$notificationPermission, action: \.notificationPermission) {
        NotificationPermission.Feature()
      }
    }

    // MARK: - Schedule Conflict Check

    private enum Constants {
      static let weatherForecastMaxDays = 10
      static let weatherFetchDebounceMilliseconds = 500
    }

    private func fetchWeatherHintEffect(state: inout State, debounce: Bool = false) -> Effect<Action> {
      guard let location = state.event.location,
            let lat = location.latitude,
            let lng = location.longitude else {
        state.weatherState = .idle
        return .cancel(id: CancelID.weatherFetchDebounce)
      }

      let startAt = state.event.startAt
      let maxForecastDate = Date().addingTimeInterval(TimeInterval(Constants.weatherForecastMaxDays) * 24 * 3600)
      guard startAt > Date(), startAt < maxForecastDate else {
        state.weatherState = .idle
        return .cancel(id: CancelID.weatherFetchDebounce)
      }

      state.weatherState = .loading
      return .run { [weatherClient, clock] send in
        if debounce {
          try await clock.sleep(for: .milliseconds(Constants.weatherFetchDebounceMilliseconds))
        }
        do {
          let info = try await weatherClient.getWeather(lat, lng, startAt)
          await send(.internal(.weatherResponse(.success(info))))
        } catch {
          await send(.internal(.weatherResponse(.failure(error))))
        }
      }
      .cancellable(id: CancelID.weatherFetchDebounce, cancelInFlight: true)
    }

    private func checkConflictsEffect(state: inout State) -> Effect<Action> {
      guard !state.currentUserId.isEmpty else { return .none }
      // 충돌 감지 비활성화 (threshold == -1)
      guard state.conflictDetectionThreshold >= 0 else {
        state.isCheckingConflicts = false
        state.conflicts = []
        return .none
      }

      state.isCheckingConflicts = true

      let userId = state.currentUserId
      let startAt = state.event.startAt
      let endAt = state.event.endAt
      let excludeIds: Set<String> = state.mode == .edit ? [state.event.id] : []
      let minGapMinutes = state.conflictDetectionThreshold

      return .run { [scheduleConflictClient, clock] send in
        try await clock.sleep(for: .milliseconds(500))
        do {
          let conflicts = try await scheduleConflictClient.checkConflicts(userId, startAt, endAt, excludeIds, minGapMinutes)
          await send(.internal(.conflictsLoaded(conflicts)))
        } catch {
          await send(.internal(.conflictsLoaded([])))
        }
      }
      .cancellable(id: CancelID.conflictCheckDebounce, cancelInFlight: true)
    }
  }
}

// MARK: - Reminder Options

extension CreatePersonalEvent {
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

    /// 분 단위 → 분 이하 옵션
    public static let shortOptions: [ReminderOption] = [
      .atEvent, .fiveMinutes, .tenMinutes, .fifteenMinutes,
      .thirtyMinutes, .oneHour, .twoHours,
    ]

    /// 일 단위 옵션
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
