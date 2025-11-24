import SwiftUI
import PhotosUI
import ComposableArchitecture
import Domain
import Clients

// MARK: - Feature Namespace

public enum CreateGroup {}

// MARK: - Core Feature Implementation

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
            guard state.canSubmit else { return .none }
            state.isCreating = true
            state.creationError = nil
            let request = state.makeCreateRequest()
            return .run { send in
              do {
                let group = try await groupClient.createGroup(request)
                await send(.internal(.createGroupResponse(.success(group.id))))
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
          }

        case .internal(let internalAction):
          switch internalAction {
          case .photoLoaded(let data):
            state.photoData = data
            return .none

          case .createGroupResponse(.success(let groupId)):
            state.isCreating = false
            return .send(.delegate(.groupCreated(id: groupId)))

          case .createGroupResponse(.failure(let error)):
            state.isCreating = false
            state.creationError = error.localizedDescription
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

