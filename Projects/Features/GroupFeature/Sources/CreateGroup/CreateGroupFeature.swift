import SwiftUI
import PhotosUI
import ComposableArchitecture

// MARK: - Feature Namespace

public enum CreateGroup {}

// MARK: - Core Feature Implementation

extension CreateGroup {

  // MARK: - Reducer

  @Reducer
  public struct Feature {

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      // Photo
      var selectedPhoto: PhotosPickerItem?
      var photoData: Data?

      // Group Info
      var groupName: String = ""
      var themeColor: ThemeColor = .blue
      var description: String = ""

      // Advanced Settings
      var isAdvancedSettingsExpanded: Bool = false
      var maxMembers: MaxMembers = .twenty
      var requireApproval: Bool = false
      var defaultMinParticipants: Int = 2

      public init() {}

      // Validation
      var isValid: Bool {
        groupName.count >= 2
      }

      var characterCount: Int {
        groupName.count
      }

      var descriptionCount: Int {
        description.count
      }
    }

    // MARK: - Action

    public enum Action: Sendable, BindableAction {
      case view(View)
      case binding(BindingAction<State>)
      case `internal`(Internal)
      case delegate(Delegate)

      @CasePathable
      public enum View: Sendable {
        case onAppear
        case photoSelected(PhotosPickerItem?)
        case toggleAdvancedSettings
        case createGroupTapped
        case cancelTapped
      }

      @CasePathable
      public enum Internal: Sendable {
        case photoLoaded(Data?)
        case createGroupResponse(Result<String, Error>)
      }

      @CasePathable
      public enum Delegate: Sendable {
        case dismiss
        case groupCreated(id: String)
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      BindingReducer()

      Reduce { state, action in
        switch action {

        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            return .none

          case .photoSelected(let item):
            state.selectedPhoto = item
            guard let item else {
              state.photoData = nil
              return .none
            }

            return .run { send in
              if let data = try? await item.loadTransferable(type: Data.self) {
                await send(.internal(.photoLoaded(data)))
              }
            }

          case .toggleAdvancedSettings:
            state.isAdvancedSettingsExpanded.toggle()
            return .none

          case .createGroupTapped:
            guard state.isValid else { return .none }
            // TODO: Create group API call
            return .send(.delegate(.groupCreated(id: "temp-id")))

          case .cancelTapped:
            return .send(.delegate(.dismiss))
          }

        case .internal(let internalAction):
          switch internalAction {
          case .photoLoaded(let data):
            state.photoData = data
            return .none

          case .createGroupResponse(.success(let groupId)):
            return .send(.delegate(.groupCreated(id: groupId)))

          case .createGroupResponse(.failure):
            // TODO: Handle error
            return .none
          }

        case .binding:
          return .none

        case .delegate:
          return .none
        }
      }
    }
  }
}

// MARK: - Theme Color

public enum ThemeColor: String, CaseIterable, Equatable, Sendable {
  case blue = "파랑"
  case red = "빨강"
  case green = "초록"
  case purple = "보라"
  case pink = "분홍"
  case orange = "주황"
  case teal = "청록"
  case indigo = "남색"

  var color: Color {
    switch self {
    case .blue: return .blue
    case .red: return .red
    case .green: return .green
    case .purple: return .purple
    case .pink: return .pink
    case .orange: return .orange
    case .teal: return .teal
    case .indigo: return .indigo
    }
  }
}

// MARK: - Max Members

public enum MaxMembers: Int, CaseIterable, Equatable, Sendable {
  case ten = 10
  case twenty = 20
  case thirty = 30
  case fifty = 50
  case hundred = 100

  var displayText: String {
    "\(rawValue)명"
  }
}
