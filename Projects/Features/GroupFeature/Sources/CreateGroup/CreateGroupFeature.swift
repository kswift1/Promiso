import SwiftUI
import PhotosUI
import ComposableArchitecture

// MARK: - Feature Namespace

public enum CreateGroup {}

// MARK: - Core Feature Implementation

extension CreateGroup {

  // MARK: - Reducer

  @Reducer
  public struct Feature: Equatable {

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      // Photo
      var selectedPhoto: PhotosPickerItem?
      var photoData: Data?

      // Group Info
      var groupName: String = ""
      var maxMembers: MaxMembers = .five

      public init() {}

      // Validation
      var isValid: Bool {
        groupName.count >= 2
      }

      var characterCount: Int {
        groupName.count
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

// MARK: - Max Members

public enum MaxMembers: Int, CaseIterable, Equatable, Sendable {
  case two = 2
  case three = 3
  case four = 4
  case five = 5
  case six = 6
  case seven = 7
  case eight = 8
  case nine = 9
  case ten = 10

  var displayText: String {
    "\(rawValue)명"
  }
}
