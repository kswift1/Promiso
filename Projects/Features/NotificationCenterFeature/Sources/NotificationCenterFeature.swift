// MARK: - NotificationCenterFeature.swift
// TCA 1.22.2를 사용한 NotificationCenter Feature 구현

import Clients
import PromisoShared
import ResourceKit
import SharedFeature

// MARK: - Feature Namespace

/// NotificationCenter Feature 컴포넌트를 위한 Namespace
public enum NotificationCenter {}

// MARK: - Feature Implementation

extension NotificationCenter {

  // MARK: - Reducer

  @Reducer
  public struct Feature {
    @Dependency(\.notificationClient) var notificationClient

    public init() {}

    // MARK: - State

    @ObservableState
    public struct State: Equatable {
      /// 알림 목록 상태
      var notificationsState: LoadingState<[NotificationModel]> = .idle

      /// 선택된 필터
      var filter: NotificationFilter = .all

      /// 초기 로드 여부
      var hasLoadedOnce: Bool = false

      /// 페이지네이션: 추가 로드 중 여부
      var isLoadingMore: Bool = false

      /// 페이지네이션: 더 불러올 데이터 있음
      var hasMoreData: Bool = true

      /// 편집 모드 여부
      var isEditMode: Bool = false

      /// 선택된 알림 ID 목록
      var selectedNotificationIds: Set<String> = []

      /// 삭제 진행 중 여부
      var isDeleting: Bool = false

      /// 페이지 크기
      static let pageSize: Int = 20

      public init() {}
    }

    // MARK: - Action

    @CasePathable
    public enum Action: Sendable {
      case view(View)
      case `internal`(Internal)
      case delegate(Delegate)

      @CasePathable
      public enum View: Sendable {
        /// 화면 나타남
        case onAppear
        /// Pull to refresh
        case refreshTriggered
        /// 필터 변경
        case filterChanged(NotificationFilter)
        /// 알림 탭
        case notificationTapped(NotificationModel)
        /// 전체 읽음 처리 버튼 탭
        case markAllAsReadTapped
        /// 추가 로드 (무한 스크롤)
        case loadMoreTriggered
        /// 닫기 버튼 탭
        case dismissTapped
        /// 편집 모드 토글
        case editButtonTapped
        /// 편집 모드 취소
        case cancelEditTapped
        /// 알림 선택/해제 토글
        case notificationSelected(String)
        /// 전체 선택
        case selectAllTapped
        /// 선택한 알림 삭제
        case deleteSelectedTapped
        /// 전체 알림 삭제
        case deleteAllTapped
      }

      @CasePathable
      public enum Internal: Sendable {
        /// 알림 목록 조회
        case fetchNotifications(isRefresh: Bool)
        /// 알림 목록 응답
        case notificationsResponse(Result<[NotificationModel], Error>, isRefresh: Bool)
        /// 읽음 처리 완료
        case markAsReadCompleted(notificationId: String, Result<Void, Error>)
        /// 전체 읽음 처리 완료
        case markAllAsReadCompleted(Result<Void, Error>)
        /// 삭제 완료
        case deleteCompleted(deletedIds: [String], Result<Void, Error>)
      }

      @CasePathable
      public enum Delegate: Sendable {
        /// 약속 상세로 이동
        case navigateToPromise(promiseId: String, groupId: String)
        /// 그룹 상세로 이동
        case navigateToGroup(groupId: String)
        /// 닫기
        case dismiss
      }
    }

    // MARK: - Reducer Body

    public var body: some ReducerOf<Self> {
      Reduce { state, action in
        switch action {
        // MARK: - View Actions
        case .view(let viewAction):
          switch viewAction {
          case .onAppear:
            guard !state.hasLoadedOnce else { return .none }
            state.hasLoadedOnce = true
            state.notificationsState = .loading
            return .send(.internal(.fetchNotifications(isRefresh: true)))

          case .refreshTriggered:
            return .send(.internal(.fetchNotifications(isRefresh: true)))

          case .filterChanged(let filter):
            guard state.filter != filter else { return .none }
            state.filter = filter
            // 클라이언트 필터링만 적용, API 호출 없음
            return .none

          case .notificationTapped(let notification):
            // 읽음 처리
            let markAsReadEffect: Effect<Action> = notification.isRead
              ? .none
              : .run { [notificationClient] send in
                  do {
                    try await notificationClient.markAsRead(notification.notificationId)
                    await send(.internal(.markAsReadCompleted(
                      notificationId: notification.notificationId,
                      .success(())
                    )))
                  } catch {
                    await send(.internal(.markAsReadCompleted(
                      notificationId: notification.notificationId,
                      .failure(error)
                    )))
                  }
                }

            // 딥링크 이동
            let navigateEffect: Effect<Action>
            switch notification.deeplinkType {
            case .promise(let promiseId, let groupId):
              navigateEffect = .send(.delegate(.navigateToPromise(promiseId: promiseId, groupId: groupId)))
            case .group(let groupId):
              navigateEffect = .send(.delegate(.navigateToGroup(groupId: groupId)))
            case .none:
              navigateEffect = .none
            }

            return .merge(markAsReadEffect, navigateEffect)

          case .markAllAsReadTapped:
            return .run { [notificationClient] send in
              do {
                try await notificationClient.markAllAsRead()
                await send(.internal(.markAllAsReadCompleted(.success(()))))
              } catch {
                await send(.internal(.markAllAsReadCompleted(.failure(error))))
              }
            }

          case .loadMoreTriggered:
            guard !state.isLoadingMore,
                  state.hasMoreData,
                  case .loaded = state.notificationsState else {
              return .none
            }
            state.isLoadingMore = true
            return .send(.internal(.fetchNotifications(isRefresh: false)))

          case .dismissTapped:
            return .send(.delegate(.dismiss))

          case .editButtonTapped:
            state.isEditMode = true
            state.selectedNotificationIds = []
            return .none

          case .cancelEditTapped:
            state.isEditMode = false
            state.selectedNotificationIds = []
            return .none

          case .notificationSelected(let notificationId):
            if state.selectedNotificationIds.contains(notificationId) {
              state.selectedNotificationIds.remove(notificationId)
            } else {
              state.selectedNotificationIds.insert(notificationId)
            }
            return .none

          case .selectAllTapped:
            let allIds = Set(state.notifications.map(\.notificationId))
            if state.selectedNotificationIds == allIds {
              // 이미 전체 선택이면 전체 해제
              state.selectedNotificationIds = []
            } else {
              // 전체 선택
              state.selectedNotificationIds = allIds
            }
            return .none

          case .deleteSelectedTapped:
            guard !state.selectedNotificationIds.isEmpty else { return .none }
            state.isDeleting = true
            let idsToDelete = Array(state.selectedNotificationIds)
            return .run { [notificationClient] send in
              do {
                try await notificationClient.deleteNotifications(idsToDelete)
                await send(.internal(.deleteCompleted(deletedIds: idsToDelete, .success(()))))
              } catch {
                await send(.internal(.deleteCompleted(deletedIds: idsToDelete, .failure(error))))
              }
            }

          case .deleteAllTapped:
            state.isDeleting = true
            let allIds = state.notifications.map(\.notificationId)
            return .run { [notificationClient] send in
              do {
                try await notificationClient.deleteAllNotifications()
                await send(.internal(.deleteCompleted(deletedIds: allIds, .success(()))))
              } catch {
                await send(.internal(.deleteCompleted(deletedIds: allIds, .failure(error))))
              }
            }
          }

        // MARK: - Internal Actions
        case .internal(let internalAction):
          switch internalAction {
          case .fetchNotifications(let isRefresh):
            let lastCreatedAt: Date?
            if isRefresh {
              lastCreatedAt = nil
            } else if case .loaded(let notifications) = state.notificationsState {
              lastCreatedAt = notifications.last?.createdAt
            } else {
              lastCreatedAt = nil
            }

            return .run { [notificationClient] send in
              do {
                // 항상 전체 알림을 가져오고, 필터는 클라이언트에서 적용
                let notifications = try await notificationClient.getNotifications(
                  .all,
                  State.pageSize,
                  lastCreatedAt
                )
                await send(.internal(.notificationsResponse(.success(notifications), isRefresh: isRefresh)))
              } catch {
                await send(.internal(.notificationsResponse(.failure(error), isRefresh: isRefresh)))
              }
            }

          case .notificationsResponse(let result, let isRefresh):
            state.isLoadingMore = false

            switch result {
            case .success(let newNotifications):
              if isRefresh {
                state.notificationsState = .loaded(newNotifications)
              } else if case .loaded(var existing) = state.notificationsState {
                existing.append(contentsOf: newNotifications)
                state.notificationsState = .loaded(existing)
              }
              state.hasMoreData = newNotifications.count >= State.pageSize

            case .failure(let error):
              if isRefresh {
                state.notificationsState = .failed(error)
              }
              // 추가 로드 실패는 무시 (기존 데이터 유지)
            }
            return .none

          case .markAsReadCompleted(let notificationId, let result):
            if case .success = result,
               case .loaded(var notifications) = state.notificationsState,
               let index = notifications.firstIndex(where: { $0.notificationId == notificationId }) {
              let updated = NotificationModel(
                notificationId: notifications[index].notificationId,
                userId: notifications[index].userId,
                type: notifications[index].type,
                title: notifications[index].title,
                body: notifications[index].body,
                promiseId: notifications[index].promiseId,
                groupId: notifications[index].groupId,
                relatedUserId: notifications[index].relatedUserId,
                isRead: true,
                createdAt: notifications[index].createdAt,
                readAt: Date()
              )
              notifications[index] = updated
              state.notificationsState = .loaded(notifications)
            }
            return .none

          case .markAllAsReadCompleted(let result):
            if case .success = result,
               case .loaded(var notifications) = state.notificationsState {
              notifications = notifications.map { notification in
                guard !notification.isRead else { return notification }
                return NotificationModel(
                  notificationId: notification.notificationId,
                  userId: notification.userId,
                  type: notification.type,
                  title: notification.title,
                  body: notification.body,
                  promiseId: notification.promiseId,
                  groupId: notification.groupId,
                  relatedUserId: notification.relatedUserId,
                  isRead: true,
                  createdAt: notification.createdAt,
                  readAt: Date()
                )
              }
              state.notificationsState = .loaded(notifications)
            }
            return .none

          case .deleteCompleted(let deletedIds, let result):
            state.isDeleting = false
            if case .success = result,
               case .loaded(var notifications) = state.notificationsState {
              notifications.removeAll { deletedIds.contains($0.notificationId) }
              state.notificationsState = .loaded(notifications)
              state.selectedNotificationIds = []
              state.isEditMode = false
            }
            return .none
          }

        // MARK: - Delegate Actions
        case .delegate:
          return .none
        }
      }
    }
  }
}

// MARK: - Computed Properties

extension NotificationCenter.Feature.State {
  /// 현재 알림 목록 (필터 적용)
  var notifications: [NotificationModel] {
    guard case .loaded(let allNotifications) = notificationsState else {
      return []
    }
    switch filter {
    case .all:
      return allNotifications
    case .unread:
      return allNotifications.filter { !$0.isRead }
    }
  }

  /// 안 읽은 알림 개수
  var unreadCount: Int {
    notifications.filter { !$0.isRead }.count
  }

  /// 빈 상태 여부
  var isEmpty: Bool {
    notifications.isEmpty && notificationsState.isLoaded
  }

  /// 로딩 중 여부
  var isLoading: Bool {
    notificationsState.isLoading
  }

  /// 에러 여부
  var error: Error? {
    notificationsState.error
  }

  /// 전체 선택 여부
  var isAllSelected: Bool {
    !notifications.isEmpty && selectedNotificationIds.count == notifications.count
  }

  /// 선택 개수
  var selectedCount: Int {
    selectedNotificationIds.count
  }
}
