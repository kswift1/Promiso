import SwiftUI

struct GroupHeaderView: View {
  let group: CurrentGroup
  let onMenuTap: () -> Void
  let onManageTap: () -> Void
  let onAddPromiseTap: () -> Void

  var body: some View {
    HStack(spacing: 16) {
      // 햄버거 메뉴 버튼 (사이드 드로워 열기)
      Button(action: onMenuTap) {
        Image(systemName: "line.3.horizontal")
          .font(.system(size: 22, weight: .medium))
          .foregroundColor(.primary)
          .frame(width: 44, height: 44)
      }

      // 그룹 정보
      HStack(spacing: 12) {
        Text(group.emoji)
          .font(.system(size: 32))

        VStack(alignment: .leading, spacing: 4) {
          Text(group.name)
            .font(.system(size: 18, weight: .bold))
            .foregroundColor(.primary)

          HStack(spacing: 8) {
            Text("\(group.activeCount)개 진행중")
              .font(.system(size: 13))
              .foregroundColor(.secondary)

            Text("·")
              .foregroundColor(.secondary)

            Text("\(group.pendingCount)개 대기")
              .font(.system(size: 13))
              .foregroundColor(.secondary)
          }
        }
      }

      Spacer()

      // 약속 추가 버튼
      Button(action: onAddPromiseTap) {
        Image(systemName: "plus")
          .font(.system(size: 20, weight: .semibold))
          .foregroundColor(.white)
          .frame(width: 36, height: 36)
          .background(Color.blue)
          .clipShape(Circle())
      }

      // 그룹 관리 버튼
      Button(action: onManageTap) {
        Image(systemName: "gearshape.fill")
          .font(.system(size: 20))
          .foregroundColor(.secondary)
          .frame(width: 44, height: 44)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(Color(.systemBackground))
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 0) {
    GroupHeaderView(
      group: CurrentGroup(
        id: "1",
        name: "지민과 나",
        emoji: "👥",
        activeCount: 2,
        pendingCount: 1,
        memberCount: 2,
        role: .admin,
        notifications: true
      ),
      onMenuTap: {},
      onManageTap: {},
      onAddPromiseTap: {}
    )

    Divider()

    Spacer()
  }
  .background(Color(.systemGray6))
}
