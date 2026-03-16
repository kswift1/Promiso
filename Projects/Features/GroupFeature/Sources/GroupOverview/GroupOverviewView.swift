import SwiftUI
import ComposableArchitecture
import PromisoShared
import Clients

extension GroupOverview {
  public struct View: SwiftUI.View {
    @Bindable private var store: StoreOf<GroupOverview.Feature>

    public init(store: StoreOf<GroupOverview.Feature>) {
      self.store = store
    }

    public var body: some SwiftUI.View {
      ScrollView {
        VStack(spacing: 24) {
          // 내 그룹 섹션
          VStack(alignment: .leading, spacing: 10) {
            Text("내 그룹")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 4)

            LazyVStack(spacing: 8) {
              ForEach(store.groups) { group in
                GroupOverviewRow(group: group) {
                  store.send(.view(.groupTapped(group)))
                }
              }
            }
          }

          // 그룹 관리 섹션
          VStack(alignment: .leading, spacing: 10) {
            Text("그룹 관리")
              .font(.system(size: 16, weight: .semibold))
              .foregroundStyle(.secondary)
              .padding(.horizontal, 4)

            VStack(spacing: 8) {
              actionRow(
                title: "그룹 만들기",
                systemImage: "plus.circle.fill",
                color: Color.pmindigo.n500
              ) {
                store.send(.view(.createGroupTapped))
              }
              actionRow(
                title: "그룹 합류하기",
                systemImage: "person.badge.plus",
                color: Color.pmindigo.n500
              ) {
                store.send(.view(.joinGroupTapped))
              }
            }
          }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
      }
      .navigationTitle("그룹 설정")
      .navigationBarTitleDisplayMode(.large)
      .auroraBackground()
    }

    @ViewBuilder
    private func actionRow(
      title: String,
      systemImage: String,
      color: Color,
      action: @escaping () -> Void
    ) -> some SwiftUI.View {
      Button(action: action) {
        HStack(spacing: 12) {
          Image(systemName: systemImage)
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(color)
            .frame(width: 28, height: 28)

          Text(title)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.primary)

          Spacer()

          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .adaptiveGlassCard(cornerRadius: 14)
      }
      .buttonStyle(.plain)
    }
  }
}

// MARK: - GroupOverviewRow

private struct GroupOverviewRow: SwiftUI.View {
  let group: UserGroupInfo
  let onTap: () -> Void

  var body: some SwiftUI.View {
    Button(action: onTap) {
      HStack(spacing: 0) {
        // 컬러바
        colorBar

        HStack(spacing: 12) {
          // 썸네일
          GroupThumbnailView(imageUrl: group.imageUrl, name: group.name, size: 40)

          // 그룹 이름
          Text(group.name)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)

          Spacer()

          // 호스트 배지
          if group.role == .admin {
            hostBadge
          }

          // 새 활동 dot
          if group.hasNewActivity {
            newActivityDot
          }

          // 알림 아이콘
          notificationIcon

          // 네비게이션 화살표
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
      }
      .contentShape(Rectangle())
      .adaptiveGlassCard(cornerRadius: 14)
    }
    .buttonStyle(.plain)
  }

  @ViewBuilder
  private var colorBar: some SwiftUI.View {
    RoundedRectangle(cornerRadius: 2)
      .fill(group.groupColor?.color ?? Color.pmgray.n300)
      .frame(width: 3)
      .padding(.vertical, 8)
      .padding(.leading, 4)
  }

  @ViewBuilder
  private var hostBadge: some SwiftUI.View {
    Text("호스트")
      .font(.system(size: 11, weight: .medium))
      .foregroundStyle(Color.pmindigo.n500)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Color.pmindigo.n500.opacity(0.12))
      .clipShape(Capsule())
  }

  @ViewBuilder
  private var newActivityDot: some SwiftUI.View {
    Circle()
      .fill(Color.pmerror.n500)
      .frame(width: 8, height: 8)
  }

  @ViewBuilder
  private var notificationIcon: some SwiftUI.View {
    let isEnabled = group.notifications?.enabled ?? true
    Image(systemName: isEnabled ? "bell.fill" : "bell.slash.fill")
      .font(.system(size: 14))
      .foregroundStyle(isEnabled ? Color.pmindigo.n400 : .secondary)
  }
}
