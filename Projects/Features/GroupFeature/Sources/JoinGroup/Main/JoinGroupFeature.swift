import SwiftUI
import ComposableArchitecture

import PromisoShared
import Clients

// MARK: - Feature Namespace

public enum JoinGroup {}

// MARK: - Feature Implementation

extension JoinGroup {

  // MARK: - Step

  public enum Step: Equatable {
    case enterCode
    case preview(GroupPreviewModel)
  }

  // MARK: - Reducer

  @Reducer
  public struct Feature {
    @Dependency(\.groupClient) var groupClient

    public init() {}

    private enum CancelID {
      case previewGroup
      case joinGroup
    }

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      // Step
      var step: Step = .enterCode

      // Invite Code
      var inviteCode: String = ""
      let currentUser: UserPrivateModel

      // Progress & Error
      var isLoadingPreview: Bool = false
      var isJoining: Bool = false
      var previewError: String?
      var joinError: String?
      var joinResult: GroupModel?

      public init(currentUser: UserPrivateModel) {
        self.currentUser = currentUser
      }

      // Validation
      var isValidCode: Bool {
        inviteCode.count == 6 && inviteCode.allSatisfy { $0.isLetter || $0.isNumber }
      }

      var canProceedToPreview: Bool {
        isValidCode && !isLoadingPreview
      }

      var canJoin: Bool {
        !isJoining
      }

      var formattedCode: String {
        inviteCode.uppercased()
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
        case codeChanged(String)
        case nextTapped // 코드 입력 후 "다음" 버튼
        case backTapped // 미리보기에서 "뒤로" 버튼
        case joinGroupTapped // 미리보기에서 "참여하기" 버튼
        case cancelTapped
        case previewErrorAlertDismissed
        case joinErrorAlertDismissed
        case successAcknowledged
      }

      @CasePathable
      public enum Internal: Sendable {
        case previewGroupResponse(Result<GroupPreviewModel, Error>)
        case joinGroupResponse(Result<GroupModel, Error>)
      }

      @CasePathable
      public enum Delegate: Sendable {
        case dismiss
        case groupJoined(GroupModel)
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

          case .codeChanged(let newCode):
            // 영숫자만 허용, 대문자로 변환, 최대 6자리
            let filtered = newCode
              .uppercased()
              .filter { $0.isLetter || $0.isNumber }
              .prefix(6)
            state.inviteCode = String(filtered)
            return .none

          case .nextTapped:
            guard state.canProceedToPreview else { return .none }
            state.isLoadingPreview = true
            state.previewError = nil
            let inviteCode = state.formattedCode
            return .run { send in
              do {
                let result = try await groupClient.previewGroup(inviteCode)
                await send(.internal(.previewGroupResponse(.success(result))))
              } catch {
                await send(.internal(.previewGroupResponse(.failure(error))))
              }
            }
            .cancellable(id: CancelID.previewGroup, cancelInFlight: true)

          case .backTapped:
            state.step = .enterCode
            return .none

          case .joinGroupTapped:
            guard state.canJoin else { return .none }
            guard case .preview = state.step else { return .none }
            state.isJoining = true
            state.joinError = nil
            let inviteCode = state.formattedCode
            return .run { send in
              do {
                let result = try await groupClient.joinGroup(inviteCode)
                await send(.internal(.joinGroupResponse(.success(result))))
              } catch {
                await send(.internal(.joinGroupResponse(.failure(error))))
              }
            }
            .cancellable(id: CancelID.joinGroup, cancelInFlight: true)

          case .cancelTapped:
            return .send(.delegate(.dismiss))

          case .previewErrorAlertDismissed:
            state.previewError = nil
            return .none

          case .joinErrorAlertDismissed:
            state.joinError = nil
            return .none

          case .successAcknowledged:
            guard let result = state.joinResult else { return .none }
            state.joinResult = nil
            return .send(.delegate(.groupJoined(result)))
          }

        case .internal(let internalAction):
          switch internalAction {
          case .previewGroupResponse(.success(let preview)):
            state.isLoadingPreview = false
            print("preview: \(preview)")
            state.step = .preview(preview)
            return .none

          case .previewGroupResponse(.failure(let error)):
            state.isLoadingPreview = false
            state.previewError = error.localizedDescription
            return .none

          case .joinGroupResponse(.success(let group)):
            state.isJoining = false
            state.joinResult = group
            return .none

          case .joinGroupResponse(.failure(let error)):
            state.isJoining = false
            state.joinError = error.localizedDescription
            return .none
          }

        case .binding:
          return .none

        case .delegate:
          state.joinResult = nil
          state.isJoining = false
          return .none
        }
      }
    }
  }
}
