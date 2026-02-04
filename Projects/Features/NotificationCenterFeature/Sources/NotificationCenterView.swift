// MARK: - NotificationCenterView.swift
// 알림센터 View 구현

import Clients
import PromisoShared
import ResourceKit
import SharedFeature
import SwiftUI

// MARK: - Root View

extension NotificationCenter {
  public struct RootView: View {
    private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        // 헤더
        headerView

        // 컨텐츠
        contentView
      }
      .auroraBackground()
      .navigationTitle("알림")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        // 편집 모드일 때만 취소 버튼 표시
        if store.isEditMode {
          ToolbarItem(placement: .topBarLeading) {
            Button {
              store.send(.view(.cancelEditTapped))
            } label: {
              Text("취소")
                .font(.subheadline)
                .foregroundStyle(Color.pmindigo.n500)
            }
          }
        }

        // 모두 읽음 버튼 (안 읽은 알림이 있고, 편집 모드가 아닐 때)
        if !store.isEditMode && store.unreadCount > 0 {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              store.send(.view(.markAllAsReadTapped))
            } label: {
              Text("모두 읽음")
                .font(.subheadline)
                .foregroundStyle(Color.pmindigo.n500)
            }
          }
        }

        // 편집 버튼 (로딩 완료 후, 알림이 있을 때만)
        if !store.isLoading && !store.isEmpty {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              if store.isEditMode {
                store.send(.view(.cancelEditTapped))
              } else {
                store.send(.view(.editButtonTapped))
              }
            } label: {
              Image(systemName: store.isEditMode ? "xmark" : "gearshape")
                .font(.system(size: 16))
                .foregroundStyle(Color.pmindigo.n500)
            }
          }
        }
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Header View

    @ViewBuilder
    private var headerView: some View {
      HStack(spacing: 8) {
        ForEach(NotificationFilter.allCases, id: \.self) { filter in
          FilterChip(
            title: filter.rawValue,
            isSelected: store.filter == filter,
            action: {
              store.send(.view(.filterChanged(filter)))
            }
          )
        }
        Spacer()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
    }

    // MARK: - Content View

    @ViewBuilder
    private var contentView: some View {
      if store.isLoading && !store.hasLoadedOnce {
        loadingView
      } else if let error = store.error {
        errorView(error: error)
      } else if store.isEmpty {
        emptyView
      } else {
        notificationListView
      }
    }

    // MARK: - Notification List

    @ViewBuilder
    private var notificationListView: some View {
      ZStack(alignment: .bottom) {
        ScrollView {
          LazyVStack(spacing: 0) {
            // 편집 모드일 때 전체 선택 행
            if store.isEditMode {
              selectAllRow
              Divider()
            }

            ForEach(store.notifications) { notification in
              if store.isEditMode {
                editModeCell(notification: notification)
              } else {
                NotificationCell(notification: notification) {
                  store.send(.view(.notificationTapped(notification)))
                }
              }

              if notification.id != store.notifications.last?.id {
                Divider()
                  .padding(.leading, store.isEditMode ? 68 : 68)
              }
            }

            // 무한 스크롤 트리거
            if store.hasMoreData && !store.isEditMode {
              ProgressView()
                .frame(height: 50)
                .onAppear {
                  store.send(.view(.loadMoreTriggered))
                }
            }
          }
          .padding(.bottom, store.isEditMode ? 120 : 100)
        }
        .refreshable {
          guard !store.isEditMode else { return }
          store.send(.view(.refreshTriggered))
        }

        // 편집 모드일 때 하단 삭제 버튼
        if store.isEditMode {
          deleteActionBar
        }
      }
    }

    // MARK: - Select All Row

    @ViewBuilder
    private var selectAllRow: some View {
      Button {
        store.send(.view(.selectAllTapped))
      } label: {
        HStack(spacing: 12) {
          Image(systemName: store.isAllSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24))
            .foregroundStyle(store.isAllSelected ? Color.pmindigo.n500 : Color.pmgray.n300)

          Text("전체 선택")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.pmgray.n700)

          Spacer()

          if store.selectedCount > 0 {
            Text("\(store.selectedCount)개 선택됨")
              .font(.caption)
              .foregroundStyle(Color.pmgray.n500)
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }

    // MARK: - Edit Mode Cell

    @ViewBuilder
    private func editModeCell(notification: NotificationModel) -> some View {
      let isSelected = store.selectedNotificationIds.contains(notification.notificationId)

      Button {
        store.send(.view(.notificationSelected(notification.notificationId)))
      } label: {
        HStack(spacing: 12) {
          // 체크박스
          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 24))
            .foregroundStyle(isSelected ? Color.pmindigo.n500 : Color.pmgray.n300)

          // 기존 셀 내용
          NotificationCellContent(notification: notification)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }

    // MARK: - Delete Action Bar

    @ViewBuilder
    private var deleteActionBar: some View {
      VStack(spacing: 0) {
        Divider()

        HStack(spacing: 16) {
          // 선택 삭제 버튼
          Button {
            store.send(.view(.deleteSelectedTapped))
          } label: {
            HStack(spacing: 8) {
              if store.isDeleting {
                ProgressView()
                  .tint(.white)
              } else {
                Image(systemName: "trash")
              }
              Text(store.selectedCount > 0 ? "\(store.selectedCount)개 삭제" : "삭제")
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background {
              RoundedRectangle(cornerRadius: 12)
                .fill(store.selectedCount > 0 ? Color.pmerror.n500 : Color.pmgray.n300)
            }
          }
          .disabled(store.selectedCount == 0 || store.isDeleting)

          // 전체 삭제 버튼
          Button {
            store.send(.view(.deleteAllTapped))
          } label: {
            Text("전체 삭제")
              .font(.subheadline.weight(.medium))
              .foregroundStyle(Color.pmerror.n500)
              .padding(.horizontal, 20)
              .padding(.vertical, 14)
              .background {
                RoundedRectangle(cornerRadius: 12)
                  .stroke(Color.pmerror.n500, lineWidth: 1)
              }
          }
          .disabled(store.isDeleting)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
          if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: .rect)
          } else {
            Rectangle()
              .fill(.ultraThinMaterial)
          }
        }
      }
    }

    // MARK: - Loading View

    @ViewBuilder
    private var loadingView: some View {
      VStack(spacing: 0) {
        ForEach(0..<5, id: \.self) { _ in
          NotificationCellSkeleton()
          Divider()
            .padding(.leading, 68)
        }
        Spacer()
      }
      .shimmer()
    }

    // MARK: - Empty View

    @ViewBuilder
    private var emptyView: some View {
      VStack(spacing: 16) {
        Spacer()

        Image(systemName: "bell.slash")
          .font(.system(size: 48))
          .foregroundStyle(Color.pmgray.n300)

        Text("알림이 없어요")
          .font(.headline)
          .foregroundStyle(Color.pmgray.n500)

        Text("새로운 약속이나 그룹 소식이 있으면\n여기서 알려드릴게요")
          .font(.subheadline)
          .foregroundStyle(Color.pmgray.n400)
          .multilineTextAlignment(.center)

        Spacer()
      }
      .padding()
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(error: Error) -> some View {
      VStack(spacing: 16) {
        Spacer()

        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 48))
          .foregroundStyle(Color.pmerror.n500)

        Text("알림을 불러올 수 없어요")
          .font(.headline)
          .foregroundStyle(Color.pmgray.n500)

        Text(error.localizedDescription)
          .font(.subheadline)
          .foregroundStyle(Color.pmgray.n400)
          .multilineTextAlignment(.center)

        Button {
          store.send(.view(.refreshTriggered))
        } label: {
          Text("다시 시도")
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Color.pmindigo.n500)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background {
              if #available(iOS 26.0, *) {
                Color.clear.glassEffect(.regular.interactive(), in: .capsule)
              } else {
                Capsule()
                  .fill(.ultraThinMaterial)
              }
            }
        }

        Spacer()
      }
      .padding()
    }
  }
}

// MARK: - Filter Chip

private struct FilterChip: View {
  let title: String
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Text(title)
        .font(.subheadline.weight(isSelected ? .semibold : .regular))
        .foregroundStyle(isSelected ? Color.white : Color.pmgray.n600)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background {
          if isSelected {
            Capsule()
              .fill(Color.pmindigo.n500)
          } else {
            if #available(iOS 26.0, *) {
              Color.clear.glassEffect(.regular, in: .capsule)
            } else {
              Capsule()
                .fill(.ultraThinMaterial)
            }
          }
        }
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Notification Cell

struct NotificationCell: View {
  let notification: NotificationModel
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      NotificationCellContent(notification: notification)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Notification Cell Content

struct NotificationCellContent: View {
  let notification: NotificationModel

  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // 아이콘
      iconView

      // 내용
      VStack(alignment: .leading, spacing: 4) {
        Text(notification.title)
          .font(.subheadline.weight(notification.isRead ? .regular : .semibold))
          .foregroundStyle(notification.isRead ? Color.pmgray.n500 : Color.pmgray.n800)
          .lineLimit(1)

        Text(notification.body)
          .font(.footnote)
          .foregroundStyle(Color.pmgray.n500)
          .lineLimit(2)

        Text(notification.relativeTimeString)
          .font(.caption)
          .foregroundStyle(Color.pmgray.n400)
      }

      Spacer(minLength: 0)

      // 안 읽음 표시
      if !notification.isRead {
        Circle()
          .fill(Color.pmindigo.n500)
          .frame(width: 8, height: 8)
      }
    }
  }

  @ViewBuilder
  private var iconView: some View {
    ZStack {
      Circle()
        .fill(iconBackgroundColor.opacity(0.15))
        .frame(width: 44, height: 44)

      Image(systemName: notification.type.iconName)
        .font(.system(size: 18))
        .foregroundStyle(iconBackgroundColor)
    }
  }

  private var iconBackgroundColor: Color {
    switch notification.type.iconColorName {
    case "pmindigo": return Color.pmindigo.n500
    case "pmorange": return Color.pmwarning.n500
    case "pmgreen": return Color.pmsuccess.n500
    case "pmred": return Color.pmerror.n500
    case "pmblue": return Color.pminfo.n500
    case "pmpurple": return Color.pmpurple.n500
    case "pmteal": return Color.pminfo.n500
    case "pmyellow": return Color.pmwarning.n500
    default: return Color.pmgray.n500
    }
  }
}

// MARK: - Skeleton

private struct NotificationCellSkeleton: View {
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      Circle()
        .fill(Color(.systemGray5))
        .frame(width: 44, height: 44)

      VStack(alignment: .leading, spacing: 8) {
        RoundedRectangle(cornerRadius: 4)
          .fill(Color(.systemGray5))
          .frame(width: 120, height: 16)

        RoundedRectangle(cornerRadius: 4)
          .fill(Color(.systemGray5))
          .frame(height: 14)

        RoundedRectangle(cornerRadius: 4)
          .fill(Color(.systemGray5))
          .frame(width: 60, height: 12)
      }

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    NotificationCenter.RootView(
      store: .init(
        initialState: NotificationCenter.Feature.State()
      ) {
        NotificationCenter.Feature()
      }
    )
  }
}
