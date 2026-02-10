import ComposableArchitecture
import Clients

public enum NotificationPermission {}

extension NotificationPermission {
  @Reducer
  public struct Feature {
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.analyticsClient) var analyticsClient

    public init() {}

    @ObservableState
    public struct State: Equatable {
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
          return "완료"
        case .denied:
          return "설정으로 이동"
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
        title: "알림을 켜고\n약속을 놓치지 마세요",
        content: "새로운 약속 초대, 응답 현황, 약속 확정 알림을\n실시간으로 받아보세요.",
        notificationTitle: "약속 확정! 🎉",
        notificationContent: "점심 약속 확정! 1월 25일 오후 1시에 만나요",
        primaryButtonTitle: "알림 허용",
        secondaryButtonTitle: "나중에 하기"
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
            state.authorizationStatus = status
            // 권한 상태만 업데이트하고 화면은 유지 (사용자가 버튼을 눌러야 dismiss)
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
