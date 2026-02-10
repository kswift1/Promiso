import SwiftUI
import ComposableArchitecture
import PromisoShared

extension NotificationPermission {
  public struct View: SwiftUI.View {
    @Bindable var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    private let benefits: [(icon: String, text: String)] = [
      ("envelope.badge", "새로운 약속 초대"),
      ("checkmark.circle", "약속 확정 알림"),
      ("clock", "약속 시작 전 리마인더"),
      ("person.2", "친구 상태 업데이트"),
    ]

    public var body: some SwiftUI.View {
      VStack(spacing: 0) {
        Spacer()

        // 아이콘
        Image(systemName: "bell.badge.fill")
          .font(.system(size: 56))
          .foregroundStyle(
            LinearGradient(
              colors: [Color.pmindigo.n500, Color.pmpurple.n600],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .padding(.bottom, 24)

        // 타이틀
        Text("약속을 놓치지 않으려면\n알림을 켜주세요")
          .font(.title2.bold())
          .multilineTextAlignment(.center)
          .foregroundStyle(Color.pmtext.primary)
          .padding(.bottom, 32)

        // 체크리스트
        VStack(alignment: .leading, spacing: 16) {
          ForEach(benefits, id: \.text) { benefit in
            HStack(spacing: 12) {
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.green)
                .font(.system(size: 20))
              Text(benefit.text)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.pmtext.primary)
            }
          }
        }
        .padding(.horizontal, 40)

        Spacer()

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
          .padding(.top, 16)
        }

        Spacer()
          .frame(height: 40)
      }
      .auroraBackground()
      .onAppear {
        store.send(.view(.onAppear))
      }
      .interactiveDismissDisabled()
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
