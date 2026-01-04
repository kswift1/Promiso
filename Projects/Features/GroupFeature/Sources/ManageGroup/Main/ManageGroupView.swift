import Clients
import SwiftUI
import ComposableArchitecture

extension ManageGroup {
  public struct RootView: View {
    private let store: StoreOf<ManageGroup.Feature>
    @State private var isCopied = false

    public init(store: StoreOf<ManageGroup.Feature>) {
      self.store = store
    }

    private var deeplinkURL: URL {
      URL(string: "promiso://join/\(store.group.inviteCode)")!
    }

    private var shareMessage: String {
      """
      \(store.group.name) 그룹에 초대합니다! 🎉

      아래 링크를 클릭하여 참여하세요:
      \(deeplinkURL.absoluteString)

      또는 초대 코드를 직접 입력하세요: \(store.group.inviteCode)
      """
    }

    public var body: some View {
      WithViewStore(store, observe: { $0 }) { viewStore in
        ScrollView {
          VStack(spacing: 24) {
            // Group Info
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

            // Group Details
            VStack(spacing: 12) {
              detailRow(title: "멤버", value: "\(viewStore.group.memberCount)명")
              detailRow(title: "진행중 약속", value: "\(viewStore.group.activePromiseCount)개")

              if let maxMembers = viewStore.group.maxMembers {
                detailRow(title: "최대 인원", value: "\(maxMembers)명")
              }

              if let role = viewStore.summary?.role {
                detailRow(title: "내 역할", value: role)
              }

              if let notifications = viewStore.summary?.notifications {
                detailRow(title: "알림", value: notifications ? "켜짐" : "꺼짐")
              }
            }

            // Invite Section
            VStack(spacing: 16) {
              HStack {
                Image(systemName: "link.circle.fill")
                  .font(.system(size: 20))
                  .foregroundStyle(
                    LinearGradient(
                      colors: [.blue, .purple],
                      startPoint: .topLeading,
                      endPoint: .bottomTrailing
                    )
                  )

                Text("초대 코드")
                  .font(.headline)

                Spacer()
              }

              // Code Display with Copy Button
              HStack(spacing: 12) {
                Text(viewStore.group.inviteCode)
                  .font(.system(size: 28, weight: .bold, design: .rounded))
                  .tracking(3)
                  .frame(maxWidth: .infinity)
                  .padding(.vertical, 16)
                  .background(
                    RoundedRectangle(cornerRadius: 16)
                      .fill(Color(.systemGray6))
                      .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
                  )

                Button(action: copyCode) {
                  ZStack {
                    RoundedRectangle(cornerRadius: 16)
                      .fill(
                        isCopied
                        ? LinearGradient(
                          colors: [.green, .green],
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing
                        )
                        : LinearGradient(
                          colors: [.blue, .purple],
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing
                        )
                      )
                      .frame(width: 56, height: 56)
                      .shadow(
                        color: isCopied ? .green.opacity(0.3) : .blue.opacity(0.3),
                        radius: 8,
                        x: 0,
                        y: 4
                      )

                    Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                      .font(.system(size: 20, weight: .semibold))
                      .foregroundStyle(.white)
                  }
                }
                .animation(.spring(response: 0.3), value: isCopied)
              }

              if isCopied {
                HStack(spacing: 8) {
                  Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14))
                  Text("복사되었습니다!")
                    .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
              }

              // Share Button
              ShareLink(item: shareMessage) {
                HStack(spacing: 8) {
                  Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18))
                  Text("초대 링크 공유하기")
                    .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                  LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                  )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(
                  color: .blue.opacity(0.3),
                  radius: 10,
                  x: 0,
                  y: 5
                )
              }
            }
            .padding(20)
            .background(
              RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
            )
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

    private func copyCode() {
      UIPasteboard.general.string = store.group.inviteCode
      withAnimation(.spring()) {
        isCopied = true
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
        withAnimation(.spring()) {
          isCopied = false
        }
      }
    }
  }
}
