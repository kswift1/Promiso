import SwiftUI
import Clients
import ComposableArchitecture
import PromisoShared
import ResourceKit

extension NotificationPermission {
  public struct View: SwiftUI.View {
    @Bindable var store: StoreOf<Feature>
    @State private var animateNotification: Bool = false
    @State private var loopContinues: Bool = true
    @State private var currentNotificationIndex: Int = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    private let notifications: [(title: String, body: String)] = [
      (LocalizedStrings.Shared.notificationPreviewTitle, LocalizedStrings.Shared.notificationPreviewBody),
      (LocalizedStrings.Shared.notificationPreviewTitle, LocalizedStrings.Shared.notificationPreviewBody),
      (LocalizedStrings.Shared.notificationPreviewTitle, LocalizedStrings.Shared.notificationPreviewBody),
      (LocalizedStrings.Shared.notificationPreviewTitle, LocalizedStrings.Shared.notificationPreviewBody),
    ]

    private let benefits: [String] = [
      LocalizedStrings.Shared.benefitInvite,
      LocalizedStrings.Shared.benefitConfirm,
      LocalizedStrings.Shared.benefitMember,
      LocalizedStrings.Shared.benefitChange,
    ]

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some SwiftUI.View {
      VStack(spacing: 0) {
        // iPhone 프리뷰 + 푸시 알림 애니메이션
        iPhonePreview
          .frame(maxHeight: .infinity)

        // 하단 컨텐츠
        VStack(spacing: 16) {
          // 타이틀
          Text(LocalizedStrings.Shared.notificationTitle)
            .font(.title3.bold())
            .multilineTextAlignment(.center)
            .foregroundStyle(Color.pmtext.primary)

          // 체크리스트 (한 줄 태그 스타일)
          HStack(spacing: 8) {
            ForEach(benefits, id: \.self) { benefit in
              HStack(spacing: 4) {
                Image(systemName: "checkmark")
                  .font(.system(size: 9, weight: .bold))
                  .foregroundStyle(Color.green)
                Text(benefit)
                  .font(.system(size: 13, weight: .medium))
                  .foregroundStyle(Color.pmtext.secondary)
                  .lineLimit(1)
                  .minimumScaleFactor(0.85)
              }
              .padding(.horizontal, 10)
              .padding(.vertical, 6)
              .background {
                Capsule()
                  .fill(Color.pmtext.primary.opacity(0.06))
              }
            }
          }

          // Primary Button
          GlassActionButton(
            title: store.primaryButtonTitle,
            isPrimary: true,
            action: { store.send(.view(.primaryButtonTapped)) }
          )
          .padding(.horizontal, 24)

          // Secondary Button (나중에 하기)
          if store.showSecondaryButton {
            Button {
              store.send(.view(.secondaryButtonTapped))
            } label: {
              Text(store.config.secondaryButtonTitle)
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.pmtext.secondary)
            }
          }
        }
        .padding(.bottom, UIScreen.main.bounds.height < 700 ? 20 : 40)
      }
      .auroraBackground()
      .analyticsScreen(
        name: AnalyticsClient.ScreenName.notificationPermission.rawValue,
        class: "NotificationPermissionView"
      )
      .onAppear {
        store.send(.view(.onAppear))
      }
      .onDisappear {
        loopContinues = false
      }
      .onChange(of: scenePhase) { oldPhase, newPhase in
        // 백그라운드에서 복귀할 때만 권한 상태 재확인
        if oldPhase != .active && newPhase == .active {
          store.send(.view(.onAppear))
        }
      }
      .interactiveDismissDisabled(!store.allowInteractiveDismiss)
    }

    // MARK: - iPhone Preview

    private var iPhonePreview: some SwiftUI.View {
      GeometryReader { geometry in
        let size = geometry.size
        let scale = min(size.height / 340, 1)
        let width: CGFloat = 320
        let cornerRadius: CGFloat = 30

        ZStack(alignment: .top) {
          RoundedRectangle(cornerRadius: cornerRadius)
            .fill(backgroundColor.opacity(0.06))

          RoundedRectangle(cornerRadius: cornerRadius)
            .stroke(.gray.opacity(0.5), lineWidth: 1.5)

          // Mock Widgets & Apps
          VStack(spacing: 15) {
            HStack(spacing: 15) {
              RoundedRectangle(cornerRadius: 20)
              RoundedRectangle(cornerRadius: 20)
            }
            .frame(height: 130)

            LazyVGrid(
              columns: Array(repeating: GridItem(spacing: 15), count: 4),
              spacing: 15
            ) {
              ForEach(1...4, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                  .frame(height: 55)
              }
            }
          }
          .padding(20)
          .padding(.top, 20)
          .foregroundStyle(backgroundColor.opacity(0.1))

          // Status Bar
          HStack(spacing: 4) {
            Text("9:41")
              .fontWeight(.bold)

            Spacer()

            Image(systemName: "cellularbars")
            Image(systemName: "wifi")
            Image(systemName: "battery.50percent")
          }
          .font(.caption2)
          .padding(.horizontal, 20)
          .padding(.top, 15)

          // Notification View
          notificationView
        }
        .frame(width: width)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .mask {
          LinearGradient(
            stops: [
              .init(color: .white, location: 0),
              .init(color: .clear, location: 0.9)
            ],
            startPoint: .top,
            endPoint: .bottom
          )
          .padding(-1)
        }
        .scaleEffect(scale, anchor: .top)
      }
    }

    // MARK: - Notification View

    private var notificationView: some SwiftUI.View {
      let current = notifications[currentNotificationIndex]

      return HStack(alignment: .center, spacing: 8) {
        ResourceKitAsset.notificationLogo.swiftUIImage
          .resizable()
          .scaledToFit()
          .frame(width: 40, height: 40)
          .clipShape(.rect(cornerRadius: 10))

        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(current.title)
              .font(.callout)
              .fontWeight(.medium)
              .lineLimit(1)

            Spacer(minLength: 0)

            Text(LocalizedStrings.Shared.now)
              .font(.caption2)
              .fontWeight(.medium)
              .foregroundStyle(.gray)
          }

          Text(current.body)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.gray)
            .lineLimit(2)
        }
      }
      .id(currentNotificationIndex)
      .padding(12)
      .background(.background)
      .clipShape(.rect(cornerRadius: 20))
      .shadow(color: .gray.opacity(0.3), radius: 2)
      .padding(.horizontal, 12)
      .padding(.top, 40)
      .offset(y: animateNotification ? 0 : -200)
      .clipped()
      .task {
        await loopAnimation()
      }
    }

    // MARK: - Animation

    private func loopAnimation() async {
      do {
        try await Task.sleep(for: .seconds(0.5))

        withAnimation(.smooth(duration: 1)) {
          animateNotification = true
        }

        try await Task.sleep(for: .seconds(4))

        withAnimation(.smooth(duration: 1)) {
          animateNotification = false
        }

        guard loopContinues else { return }
        try await Task.sleep(for: .seconds(1.3))
        currentNotificationIndex = (currentNotificationIndex + 1) % notifications.count
        await loopAnimation()
      } catch {
        // Task 취소 시 안전하게 종료
      }
    }

    // MARK: - Colors

    private var backgroundColor: Color {
      colorScheme == .dark ? .white : .black
    }
  }
}

// MARK: - Preview

#Preview {
  NotificationPermission.View(
    store: Store(
      initialState: NotificationPermission.Feature.State()
    ) {
      NotificationPermission.Feature()
    }
  )
}
