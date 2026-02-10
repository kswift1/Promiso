// MARK: - OnboardingStartView.swift
// Screen 10: 첫 약속 CTA - "준비 완료!"

import ComposableArchitecture
import PromisoShared
import SwiftUI

extension AppEntry.OnboardingStart {
  public struct View: SwiftUI.View {
    let store: StoreOf<AppEntry.OnboardingStart>

    public init(store: StoreOf<AppEntry.OnboardingStart>) {
      self.store = store
    }

    @SwiftUI.State private var showEmoji: Bool = false
    @SwiftUI.State private var showTitle: Bool = false
    @SwiftUI.State private var showDescription: Bool = false
    @SwiftUI.State private var showButtons: Bool = false

    public var body: some SwiftUI.View {
      VStack(spacing: 0) {
        Spacer()

        // 이모지
        if showEmoji {
          Text("🎉")
            .font(.system(size: 64))
            .transition(.scale.combined(with: .opacity))
            .padding(.bottom, 24)
        }

        // 타이틀
        if showTitle {
          Text("준비 완료!")
            .font(.largeTitle.bold())
            .foregroundStyle(Color.pmtext.primary)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .padding(.bottom, 12)
        }

        // 설명
        if showDescription {
          Text("\(store.nickname)님의 첫 약속을\n만들어볼까요?")
            .font(.title3)
            .foregroundStyle(Color.pmtext.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
        }

        Spacer()

        // CTA 버튼
        if showButtons {
          VStack(spacing: 16) {
            GlassActionButton(
              title: "첫 약속 만들기",
              leadingSystemImage: "arrow.right",
              isPrimary: true,
              action: { store.send(.view(.createFirstPromiseTapped)) }
            )

            Button {
              store.send(.view(.skipTapped))
            } label: {
              Text("나중에 둘러볼게요")
                .font(.callout.weight(.medium))
                .foregroundStyle(Color.pmtext.secondary)
            }
          }
          .padding(.horizontal, 24)
          .padding(.bottom, 40)
          .transition(.opacity.combined(with: .move(edge: .bottom)))
        }
      }
      .auroraBackground()
      .onAppear {
        Task {
          await runAnimationSequence()
        }
      }
    }

    // MARK: - Animation Sequence

    private func runAnimationSequence() async {
      try? await Task.sleep(for: .seconds(0.3))
      withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
        showEmoji = true
      }

      try? await Task.sleep(for: .seconds(0.3))
      withAnimation(.easeOut(duration: 0.4)) {
        showTitle = true
      }

      try? await Task.sleep(for: .seconds(0.3))
      withAnimation(.easeOut(duration: 0.4)) {
        showDescription = true
      }

      try? await Task.sleep(for: .seconds(0.4))
      withAnimation(.easeOut(duration: 0.4)) {
        showButtons = true
      }
    }
  }
}
