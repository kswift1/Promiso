import ComposableArchitecture
import _PhotosUI_SwiftUI
import Clients
import PhotosUI
import PromisoShared

public enum EditPromise {}

extension EditPromise {
  @Reducer
  public struct Feature {
    @Dependency(\.continuousClock) var clock
    @Dependency(\.promiseClient) var promiseClient
    @Dependency(\.imageUploadClient) var imageUploadClient
    @Dependency(\.emojiClient) var emojiClient
    @Dependency(\.scheduleConflictClient) var scheduleConflictClient
    @Dependency(\.userSettingsClient) var userSettingsClient

    private enum CancelID: Hashable {
      case emojiSuggestDebounce
      case conflictCheckDebounce
    }

    public init() {}

    @ObservableState
    public struct State: Equatable {
      var originalPromise: PromiseModel
      var editedPromise: PromiseModel
      var isUpdating: Bool = false
      var updateError: Clients.PromiseClientError?

      /// 그룹 최대 멤버 수 (minimumParticipants 상한)
      var maxMembers: Int

      @Presents var locationPicker: LocationPicker.Feature.State?

      // 이미지 첨부
      var localImageData: [Data] = []
      var removedImageUrls: [String] = []
      var isUploadingImages: Bool = false

      // 충돌 감지
      var currentUserId: String = ""
      var conflicts: [ScheduleConflict] = []
      var isCheckingConflicts: Bool = false
      var hasCheckedConflicts: Bool = false
      var conflictCheckTrigger: ConflictCheckTrigger = .initial
      var conflictDetectionThreshold: Int = 0
      @Shared(.inMemory(AppConstants.SharedState.isPro)) var isPro: Bool = false

      public init(
        promise: PromiseModel,
        maxMembers: Int,
        currentUserId: String = ""
      ) {
        self.originalPromise = promise
        self.editedPromise = promise
        self.maxMembers = maxMembers
        self.currentUserId = currentUserId
      }

      /// 변경 사항 있는지 확인
      var hasChanges: Bool {
        originalPromise.title != editedPromise.title ||
        originalPromise.emoji != editedPromise.emoji ||
        originalPromise.description != editedPromise.description ||
        originalPromise.startAt != editedPromise.startAt ||
        originalPromise.endAt != editedPromise.endAt ||
        originalPromise.minimumParticipants != editedPromise.minimumParticipants ||
        originalPromise.trackingStartMinutesBefore != editedPromise.trackingStartMinutesBefore ||
        originalPromise.location != editedPromise.location ||
        !localImageData.isEmpty ||
        !removedImageUrls.isEmpty
      }

      /// 저장 가능 여부
      var canSave: Bool {
        hasChanges &&
        editedPromise.isTitleValid &&
        editedPromise.isStartTimeValid &&
        editedPromise.isEndTimeValid &&
        editedPromise.isMinimumParticipantsValid
      }

      /// 종료 시간 사용 여부
      var useEndTime: Bool {
        editedPromise.endAt != nil
      }

      /// 실시간 공유 사용 여부
      var useRealtimeShare: Bool {
        editedPromise.trackingStartMinutesBefore != nil
      }
    }

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(Internal)
      case delegate(Delegate)
      case locationPicker(PresentationAction<LocationPicker.Feature.Action>)

      @CasePathable
      public enum ViewAction: Sendable {
        case onAppear
        case setTitle(String)
        case setEmoji(String)
        case setDescription(String)
        case setStartDate(Date)
        case setEndDate(Date?)
        case toggleUseEndTime
        case incrementParticipants
        case decrementParticipants
        case toggleUseRealtimeShare
        case setTrackingMinutes(Int)
        case locationTapped
        case removeLocation
        case saveTapped
        case cancelTapped
        case clearError
        // 이미지 첨부
        case photosSelected([PhotosPickerItem])
        case removeLocalImage(Int)
        case removeExistingImage(Int)
      }

      @CasePathable
      public enum Internal: Sendable {
        case titleDebounced(String)
        case emojiGenerationResponse(Result<String, Error>)
        case photosLoaded([Data])
        case updatePromiseResponse(Result<PromiseModel, Clients.PromiseClientError>)
        case conflictsLoaded([ScheduleConflict])
        case settingsLoaded(UserSettings)
        case refreshProFeatures(debounce: Bool)
      }

      @CasePathable
      public enum Delegate: Sendable {
        case cancelled
        case promiseUpdated(PromiseModel)
      }
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .run { [userSettingsClient, state] send in
              guard !state.currentUserId.isEmpty else { return }
              if let settings = try? await userSettingsClient.fetchSettings(state.currentUserId) {
                await send(.internal(.settingsLoaded(settings)))
              }
            }

          case .setTitle(let title):
            let sanitizedTitle = String(title.prefix(30))
            state.editedPromise.title = sanitizedTitle
            return .merge(
              .cancel(id: CancelID.emojiSuggestDebounce),
              .run { [clock, sanitizedTitle] send in
                try await clock.sleep(for: .milliseconds(1_000))
                await send(.internal(.titleDebounced(sanitizedTitle)))
              }
              .cancellable(id: CancelID.emojiSuggestDebounce, cancelInFlight: true)
            )

          case .setEmoji(let emoji):
            state.editedPromise.emoji = emoji.isEmpty ? nil : emoji
            return .none

          case .setDescription(let description):
            let trimmed = String(description.prefix(500))
            state.editedPromise.description = trimmed.isEmpty ? nil : trimmed
            return .none

          case .setStartDate(let date):
            state.editedPromise.startAt = date
            if let end = state.editedPromise.endAt, end <= date {
              state.editedPromise.endAt = date.addingTimeInterval(7200)
            }
            state.conflictCheckTrigger = .startTimeChanged
            return .send(.internal(.refreshProFeatures(debounce: true)))

          case .setEndDate(let date):
            state.editedPromise.endAt = date
            state.conflictCheckTrigger = .endTimeChanged
            return .send(.internal(.refreshProFeatures(debounce: true)))

          case .toggleUseEndTime:
            if state.editedPromise.endAt == nil {
              state.editedPromise.endAt = state.editedPromise.startAt.addingTimeInterval(7200)
            } else {
              state.editedPromise.endAt = nil
            }
            state.conflictCheckTrigger = .endTimeChanged
            return .send(.internal(.refreshProFeatures(debounce: true)))

          case .incrementParticipants:
            let current = state.editedPromise.minimumParticipants
            if current < state.maxMembers {
              state.editedPromise.minimumParticipants = current + 1
            }
            return .none

          case .decrementParticipants:
            let current = state.editedPromise.minimumParticipants
            if current > 2 {
              state.editedPromise.minimumParticipants = current - 1
            }
            return .none

          case .toggleUseRealtimeShare:
            if state.editedPromise.trackingStartMinutesBefore == nil {
              state.editedPromise.trackingStartMinutesBefore = 30  // 기본값 30분
            } else {
              state.editedPromise.trackingStartMinutesBefore = nil
            }
            return .none

          case .setTrackingMinutes(let minutes):
            state.editedPromise.trackingStartMinutesBefore = minutes
            return .none

          case .locationTapped:
            state.locationPicker = LocationPicker.Feature.State()
            return .none

          case .removeLocation:
            state.editedPromise.location = nil
            return .none

          case .saveTapped:
            guard state.canSave else { return .none }
            state.isUpdating = true
            state.updateError = nil
            let localImages = state.localImageData
            let removedUrls = state.removedImageUrls
            state.isUploadingImages = !localImages.isEmpty
            return .run { [promise = state.editedPromise, promiseClient, imageUploadClient] send in
              do {
                var finalPromise = promise

                // 이미지 처리
                if !localImages.isEmpty || !removedUrls.isEmpty {
                  var finalImageUrls = promise.imageUrls.filter { !removedUrls.contains($0) }

                  if !localImages.isEmpty {
                    do {
                      let newUrls = try await imageUploadClient.uploadImages(localImages, "promise_images/\(promise.groupId)/\(promise.id)")
                      finalImageUrls.append(contentsOf: newUrls)
                    } catch {
                      AppLogger.general.error("이미지 업로드 실패: \(error.localizedDescription)")
                      // 이미지 업로드 실패 시 기존 이미지만 유지
                    }
                  }

                  finalPromise.imageUrls = Array(finalImageUrls.prefix(3))
                }

                try await promiseClient.updatePromise(finalPromise)

                // 삭제된 이미지 Storage에서 제거 (best-effort)
                if !removedUrls.isEmpty {
                  await imageUploadClient.deleteImages(removedUrls)
                }

                await send(.internal(.updatePromiseResponse(.success(finalPromise))))
              } catch let e as Clients.PromiseClientError {
                await send(.internal(.updatePromiseResponse(.failure(e))))
              } catch {
                await send(.internal(.updatePromiseResponse(.failure(.unknown(nil)))))
              }
            }

          case .cancelTapped:
            return .send(.delegate(.cancelled))

          case .clearError:
            state.updateError = nil
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
            let visibleUrls = state.editedPromise.imageUrls.filter { !state.removedImageUrls.contains($0) }
            guard index < visibleUrls.count else { return .none }
            state.removedImageUrls.append(visibleUrls[index])
            return .none
          }

        case .internal(let internalAction):
          switch internalAction {
          case .titleDebounced(let title):
            guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .none }
            // 제목이 원본과 다를 때만 이모지 추천
            guard title != state.originalPromise.title else { return .none }
            return .run { [emojiClient, title] send in
              do {
                let emoji = try await emojiClient.generate(title)
                await send(.internal(.emojiGenerationResponse(.success(emoji))))
              } catch {
                await send(.internal(.emojiGenerationResponse(.failure(error))))
              }
            }

          case .emojiGenerationResponse(.success(let emoji)):
            state.editedPromise.emoji = emoji
            return .none

          case .emojiGenerationResponse(.failure):
            return .none

          case .photosLoaded(let data):
            let totalExisting = state.editedPromise.imageUrls.count - state.removedImageUrls.count
            let remaining = 3 - totalExisting - state.localImageData.count
            let toAdd = Array(data.prefix(max(0, remaining)))
            state.localImageData.append(contentsOf: toAdd)
            return .none

          case .updatePromiseResponse(.success(let updatedPromise)):
            state.isUpdating = false
            state.isUploadingImages = false
            return .send(.delegate(.promiseUpdated(updatedPromise)))

          case .updatePromiseResponse(.failure(let error)):
            state.isUpdating = false
            state.isUploadingImages = false
            state.updateError = error
            return .none

          case .conflictsLoaded(let conflicts):
            state.conflicts = conflicts
            state.isCheckingConflicts = false
            state.hasCheckedConflicts = true
            return .none

          case .settingsLoaded(let settings):
            state.conflictDetectionThreshold = settings.conflictDetectionThreshold
            return .send(.internal(.refreshProFeatures(debounce: false)))

          case .refreshProFeatures(let debounce):
            guard state.isPro else {
              state.isCheckingConflicts = false
              state.conflicts = []
              state.hasCheckedConflicts = false
              return .none
            }
            return checkConflictsEffect(state: &state)
          }

        case .locationPicker(.presented(.delegate(.locationSelected(let location)))):
          state.editedPromise.location = location
          state.locationPicker = nil
          return .none

        case .locationPicker(.presented(.delegate(.dismissed))):
          state.locationPicker = nil
          return .none

        case .locationPicker:
          return .none

        case .delegate:
          return .none
        }
      }
      .ifLet(\.$locationPicker, action: \.locationPicker) {
        LocationPicker.Feature()
      }
    }

    private func checkConflictsEffect(state: inout State) -> Effect<Action> {
      guard !state.currentUserId.isEmpty else { return .none }
      guard state.conflictDetectionThreshold >= 0 else {
        state.isCheckingConflicts = false
        state.conflicts = []
        return .none
      }

      state.isCheckingConflicts = true

      let userId = state.currentUserId
      let startAt = state.editedPromise.startAt
      let endAt = state.editedPromise.endAt
      let excludeIds: Set<String> = [state.editedPromise.id]
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
