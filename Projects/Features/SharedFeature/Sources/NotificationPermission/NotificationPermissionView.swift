import SwiftUI
import ComposableArchitecture
import ResourceKit

extension NotificationPermission {
  public struct View: SwiftUI.View {
    @Bindable var store: StoreOf<Feature>
    @State private var animateNotification: Bool = false
    @State private var loopContinues: Bool = true
    @Environment(\.colorScheme) private var colorScheme

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    /// 현재 시간 + 1시간 00분 기준으로 동적 알림 내용 생성
    private var dynamicNotificationContent: String {
      let calendar = Calendar.current
      let now = Date()
      // 현재 시간 + 1시간, 분은 00으로 설정
      var components = calendar.dateComponents([.year, .month, .day, .hour], from: now)
      components.hour = (components.hour ?? 0) + 1
      components.minute = 0

      guard let targetDate = calendar.date(from: components) else {
        return store.config.notificationContent
      }

      let dateString = KoreanDateFormatters.monthDayHour.string(from: targetDate)

      return "점심 약속 확정! \(dateString)에 만나요"
    }

    public var body: some SwiftUI.View {
      VStack(spacing: 0) {
          iPhonePreview()
            .padding(.top, 15)

          VStack(spacing: 20) {
            Text(store.config.title)
              .font(.largeTitle.bold())
              .multilineTextAlignment(.center)
              .lineLimit(2)
              .fixedSize(horizontal: false, vertical: true)

            Text(store.config.content)
              .font(.callout)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .lineLimit(3)
              .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            // Primary Button
            Button {
              store.send(.view(.primaryButtonTapped))
            } label: {
              Text(store.primaryButtonTitle)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .foregroundStyle(.white)
                .frame(height: 56)
                .background(Color.pmindigo.n500, in: .rect(cornerRadius: 16))
            }

            // Secondary Button (나중에 하기)
            if store.showSecondaryButton {
              Button {
                store.send(.view(.secondaryButtonTapped))
              } label: {
                Text(store.config.secondaryButtonTitle)
                  .fontWeight(.medium)
                  .foregroundStyle(Color.pmindigo.n500.opacity(0.8))
              }
            }
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 30)
        }
      .onAppear {
        store.send(.view(.onAppear))
      }
      .onDisappear {
        loopContinues = false
      }
      .interactiveDismissDisabled()
    }

    // MARK: - iPhone Preview

    @ViewBuilder
    private func iPhonePreview() -> some SwiftUI.View {
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
              ForEach(1...12, id: \.self) { _ in
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
          notificationView()
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

    @ViewBuilder
    private func notificationView() -> some SwiftUI.View {
      HStack(alignment: .center, spacing: 8) {
        // App Logo
        ResourceKitAsset.notificationLogo.swiftUIImage
          .resizable()
          .scaledToFit()
          .frame(width: 40, height: 40)
          .clipShape(.rect(cornerRadius: 10))

        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Text(store.config.notificationTitle)
              .font(.callout)
              .fontWeight(.medium)
              .lineLimit(1)

            Spacer(minLength: 0)

            Text("지금")
              .font(.caption2)
              .fontWeight(.medium)
              .foregroundStyle(.gray)
          }

          Text(dynamicNotificationContent)
            .font(.caption2)
            .fontWeight(.medium)
            .foregroundStyle(.gray)
            .lineLimit(2)
        }
      }
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
      try? await Task.sleep(for: .seconds(0.5))

      withAnimation(.smooth(duration: 1)) {
        animateNotification = true
      }

      try? await Task.sleep(for: .seconds(4))

      withAnimation(.smooth(duration: 1)) {
        animateNotification = false
      }

      guard loopContinues else { return }
      try? await Task.sleep(for: .seconds(1.3))
      await loopAnimation()
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
