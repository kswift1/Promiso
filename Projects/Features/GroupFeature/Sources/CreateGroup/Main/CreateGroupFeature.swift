import SwiftUI
import PhotosUI
import ComposableArchitecture
import Shared
import Clients

// MARK: - Feature Namespace

public enum CreateGroup {}

// MARK: - Feature Implementation

extension CreateGroup {

  // MARK: - Reducer

  @Reducer
  public struct Feature {
    @Dependency(\.groupClient) var groupClient

    public init() {}
    
    private enum CancelID {
      case createGroup
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      // Photo
      var selectedPhoto: PhotosPickerItem?
      var photoData: Data?

      // Group Info
      var groupName: String = ""
      var maxMembers: MaxMembers = .five
      let currentUser: UserModel
      
      // Progress & Error
      var isCreating: Bool = false
      var creationError: String?
      var creationResult: GroupCreationResult?

      public init(currentUser: UserModel) {
        self.currentUser = currentUser
      }

      // Validation
      var isValid: Bool {
        trimmedGroupName.count >= 2
      }
      
      var canSubmit: Bool {
        isValid && !isCreating
      }
      
      var trimmedGroupName: String {
        groupName.trimmingCharacters(in: .whitespacesAndNewlines)
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
        case errorAlertDismissed
        case successAcknowledged
      }

      @CasePathable
      public enum Internal: Sendable {
        case photoLoaded(Data?)
        case createGroupResponse(Result<GroupCreationResult, Error>)
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
            guard state.canSubmit else { return .none }
            state.isCreating = true
            state.creationError = nil
            let request = state.makeCreateRequest()
            return .run { send in
              do {
                let result = try await groupClient.createGroup(request)
                await send(.internal(.createGroupResponse(.success(result))))
              } catch {
                await send(.internal(.createGroupResponse(.failure(error))))
              }
            }
            .cancellable(id: CancelID.createGroup, cancelInFlight: true)

          case .cancelTapped:
            return .send(.delegate(.dismiss))
            
          case .errorAlertDismissed:
            state.creationError = nil
            return .none
            
          case .successAcknowledged:
            guard let result = state.creationResult else { return .none }
            state.creationResult = nil
            return .send(.delegate(.groupCreated(id: result.id)))
          }

        case .internal(let internalAction):
          switch internalAction {
          case .photoLoaded(let data):
            state.photoData = data
            return .none

          case .createGroupResponse(.success(let result)):
            state.isCreating = false
            state.creationResult = result
            return .none

          case .createGroupResponse(.failure(let error)):
            state.isCreating = false
            state.creationError = error.localizedDescription
            return .none
          }

        case .binding:
          return .none

        case .delegate:
          state.creationResult = nil
          state.isCreating = false
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

private extension CreateGroup.Feature.State {
  func makeCreateRequest() -> CreateGroupRequest {
    CreateGroupRequest(
      name: trimmedGroupName,
      maxMembers: maxMembers.rawValue,
      creatorId: currentUser.id,
      creatorName: currentUser.displayName,
      creatorNickname: currentUser.nickname,
      creatorProfileImageURL: currentUser.profileImageUrl,
      photoData: photoData
    )
  }
}
