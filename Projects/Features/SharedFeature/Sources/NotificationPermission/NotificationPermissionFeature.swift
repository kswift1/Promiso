import ComposableArchitecture
import Clients
import PromisoShared

public enum NotificationPermission {}

extension NotificationPermission {
  @Reducer
  public struct Feature {
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.analyticsClient) var analyticsClient

    public init() {}

    @ObservableState
    public struct State: Equatable, Sendable {
      var config: Config
      var allowInteractiveDismiss: Bool
      var authorizationStatus: NotificationAuthorizationStatus = .notDetermined

      public init(config: Config = .default, allowInteractiveDismiss: Bool = false) {
        self.config = config
        self.allowInteractiveDismiss = allowInteractiveDismiss
      }

      var primaryButtonTitle: String {
        switch authorizationStatus {
        case .authorized:
          return LocalizedStrings.Common.done
        case .denied:
          return LocalizedStrings.Shared.goToSettings
        default:
          return config.primaryButtonTitle
        }
      }

      var showSecondaryButton: Bool {
        authorizationStatus == .notDetermined
      }
    }

    public struct Config: Equatable, Sendable {
      public var title: String
      public var content: String
      public var notificationTitle: String
      public var notificationContent: String
      public var primaryButtonTitle: String
      public var secondaryButtonTitle: String

      public init(
        title: String,
        content: String,
        notificationTitle: String,
        notificationContent: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String
      ) {
        self.title = title
        self.content = content
        self.notificationTitle = notificationTitle
        self.notificationContent = notificationContent
        self.primaryButtonTitle = primaryButtonTitle
        self.secondaryButtonTitle = secondaryButtonTitle
      }

      public static let `default` = Config(
        title: LocalizedStrings.Shared.permissionTitle,
        content: LocalizedStrings.Shared.notificationSubtitle,
        notificationTitle: LocalizedStrings.Shared.notificationPreviewTitle,
        notificationContent: LocalizedStrings.Shared.notificationPreviewBody,
        primaryButtonTitle: LocalizedStrings.Shared.allowNotification,
        secondaryButtonTitle: LocalizedStrings.Common.laterAction
      )
    }

    @CasePathable
    public enum Action: Sendable {
      case view(ViewAction)
      case `internal`(Internal)
      case delegate(Delegate)

      @CasePathable
      public enum ViewAction: Sendable {
        case onAppear
        case primaryButtonTapped
        case secondaryButtonTapped
      }

      public enum Internal: Sendable {
        case authorizationStatusLoaded(NotificationAuthorizationStatus)
        case permissionRequestCompleted(Bool)
      }

      public enum Delegate: Sendable {
        case permissionChanged(isGranted: Bool)
        case dismissed
      }
    }

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            // 현재 권한 상태만 확인 (알럿 표시 안함)
            return .run { send in
              let status = await notificationClient.getAuthorizationStatus()
              await send(.internal(.authorizationStatusLoaded(status)))
            }

          case .primaryButtonTapped:
            switch state.authorizationStatus {
            case .authorized:
              return .merge(
                .send(.delegate(.permissionChanged(isGranted: true))),
                .send(.delegate(.dismissed))
              )

            case .denied:
              return .run { _ in
                await notificationClient.openNotificationSettings()
              }

            default:
              // Analytics 이벤트 로깅
              analyticsClient.logEvent(AnalyticsClient.EventName.notificationPermissionRequested, nil)

              // 바로 시스템 권한 요청 알럿 표시
              return .run { send in
                do {
                  let granted = try await notificationClient.requestAuthorization()
                  await send(.internal(.permissionRequestCompleted(granted)))
                } catch {
                  await send(.internal(.permissionRequestCompleted(false)))
                }
              }
            }

          case .secondaryButtonTapped:
            return .send(.delegate(.dismissed))
          }

        case .internal(let internalAction):
          switch internalAction {
          case .authorizationStatusLoaded(let status):
            let previousStatus = state.authorizationStatus
            state.authorizationStatus = status
            // 설정에서 돌아와 권한이 부여된 경우 자동으로 닫기
            if previousStatus == .denied && status.isGranted {
              return .merge(
                .send(.delegate(.permissionChanged(isGranted: true))),
                .send(.delegate(.dismissed))
              )
            }
            return .none

          case .permissionRequestCompleted(let granted):
            state.authorizationStatus = granted ? .authorized : .denied

            // Analytics 이벤트 로깅 (허용된 경우만)
            if granted {
              analyticsClient.logEvent(AnalyticsClient.EventName.notificationPermissionGranted, nil)
            }

            // 권한 요청 완료 → 결과 전달 후 화면 닫기
            return .merge(
              .send(.delegate(.permissionChanged(isGranted: granted))),
              .send(.delegate(.dismissed))
            )
          }

        case .delegate:
          return .none
        }
      }
    }
  }
}
