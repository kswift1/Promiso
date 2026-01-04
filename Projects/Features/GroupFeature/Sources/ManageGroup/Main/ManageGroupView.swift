import Clients
import SwiftUI
import ComposableArchitecture

extension ManageGroup {
  public struct RootView: View {
    private let store: StoreOf<ManageGroup.Feature>

    public init(store: StoreOf<ManageGroup.Feature>) {
      self.store = store
    }

    public var body: some View {
      WithViewStore(store, observe: { $0 }) { viewStore in
        ScrollView {
          VStack(spacing: 24) {
            VStack(spacing: 12) {
              Text(viewStore.group.emoji)
                .font(.system(size: 80))

              Text(viewStore.group.name)
                .font(.system(size: 24, weight: .bold))

              if let description = viewStore.group.description, description.isEmpty == false {
                Text(description)
                  .font(.system(size: 14))
                  .foregroundStyle(.secondary)
                  .multilineTextAlignment(.center)
              }
            }
            .padding(.top, 12)

            VStack(spacing: 12) {
              detailRow(title: "멤버", value: "\(viewStore.group.memberCount)명")
              detailRow(title: "진행중 약속", value: "\(viewStore.group.activePromiseCount)개")

              if let maxMembers = viewStore.group.maxMembers {
                detailRow(title: "최대 인원", value: "\(maxMembers)명")
              }

              detailRow(title: "초대 코드", value: viewStore.group.inviteCode)

              if let role = viewStore.summary?.role {
                detailRow(title: "내 역할", value: role)
              }

              if let notifications = viewStore.summary?.notifications {
                detailRow(title: "알림", value: notifications ? "켜짐" : "꺼짐")
              }
            }
          }
          .padding(16)
        }
        .navigationTitle("그룹 관리")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewStore.send(.view(.onAppear)) }
      }
    }

    private func detailRow(title: String, value: String) -> some View {
      HStack {
        Text(title)
          .font(.system(size: 14))
          .foregroundStyle(.secondary)

        Spacer()

        Text(value)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(.primary)
      }
      .padding(12)
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 12))
    }
  }
}
