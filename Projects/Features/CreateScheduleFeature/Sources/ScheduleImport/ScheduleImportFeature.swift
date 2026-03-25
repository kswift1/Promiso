import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared
import PhotosUI

// MARK: - Namespace

public enum ScheduleImport {}

// MARK: - Reducer

extension ScheduleImport {
  @Reducer
  public struct Feature {
    @Dependency(\.scheduleExtractionClient) var scheduleExtractionClient
    @Dependency(\.hapticFeedback) var hapticFeedback

    public init() {}

    // MARK: - Cancel IDs

    private enum CancelID { case extraction }

    // MARK: - Input Mode

    public enum InputMode: Equatable, Sendable {
      case text
      case image
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable, Sendable {
      public var inputText: String = ""
      public var selectedImage: Data? = nil
      var isExtracting: Bool = false
      var extractionError: String?
      var inputMode: InputMode = .text

      public init(inputText: String = "") {
        self.inputText = inputText
        self.inputMode = .text
      }

      var canExtract: Bool {
        !isExtracting && (
          !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
          selectedImage != nil
        )
      }
    }

    // MARK: - Action

    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)
    }

    @CasePathable
    public enum View: Sendable {
      case inputModeChanged(InputMode)
      case textChanged(String)
      case pasteFromClipboardTapped
      case photoSelected(PhotosPickerItem?)
      case removeImage
      case extractTapped
      case dismissTapped
      case dismissError
    }

    @CasePathable
    public enum Internal: Sendable {
      case photoLoaded(Data?)
      case extractionSuccess(PersonalEventModel)
      case extractionFailed(String)
    }

    @CasePathable
    public enum Delegate: Sendable {
      case extracted(PersonalEventModel)
      case dismiss
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {

        // MARK: - View Actions

        case let .view(viewAction):
          switch viewAction {
          case .inputModeChanged(let mode):
            state.inputMode = mode
            return .none

          case .textChanged(let text):
            state.inputText = String(text.prefix(2000))
            return .none

          case .pasteFromClipboardTapped:
            if let text = UIPasteboard.general.string {
              state.inputText = String(text.prefix(2000))
            }
            return .none

          case .photoSelected(let item):
            guard let item else { return .none }
            return .run { send in
              if let data = try? await item.loadTransferable(type: Data.self) {
                await send(.internal(.photoLoaded(data)))
              }
            }

          case .removeImage:
            state.selectedImage = nil
            return .run { _ in await hapticFeedback.selection() }

          case .extractTapped:
            guard state.canExtract else { return .none }
            state.isExtracting = true
            state.extractionError = nil
            let text = state.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            let imageData = state.selectedImage
            return .run { [scheduleExtractionClient] send in
              do {
                let event: PersonalEventModel
                if let imageData {
                  event = try await scheduleExtractionClient.extractFromImage(imageData)
                } else {
                  event = try await scheduleExtractionClient.extractFromText(text)
                }
                await send(.internal(.extractionSuccess(event)))
              } catch let error as ScheduleExtractionError {
                await send(.internal(.extractionFailed(error.localizedDescription)))
              } catch {
                await send(.internal(.extractionFailed(LocalizedStrings.Error.extractionFailed)))
              }
            }
            .cancellable(id: CancelID.extraction, cancelInFlight: true)

          case .dismissTapped:
            return .send(.delegate(.dismiss))

          case .dismissError:
            state.extractionError = nil
            return .none
          }

        // MARK: - Internal Actions

        case let .internal(internalAction):
          switch internalAction {
          case .photoLoaded(let data):
            state.selectedImage = data
            if data != nil {
              state.inputMode = .image
            }
            return .run { _ in await hapticFeedback.selection() }

          case .extractionSuccess(let event):
            state.isExtracting = false
            return .merge(
              .run { _ in await hapticFeedback.success() },
              .send(.delegate(.extracted(event)))
            )

          case .extractionFailed(let message):
            state.isExtracting = false
            state.extractionError = message
            return .run { _ in await hapticFeedback.error() }
          }

        // MARK: - Delegate

        case .delegate:
          return .none
        }
      }
    }
  }
}
