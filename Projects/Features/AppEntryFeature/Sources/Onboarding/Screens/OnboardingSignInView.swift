// MARK: - OnboardingSignInView.swift
// Screen 7: 타이핑 애니메이션 + 로그인 버튼

import AuthenticationServices
import PromisoShared
import ResourceKit
import SwiftUI

struct OnboardingSignInView: View {
  let isLoading: Bool
  let errorMessage: String?
  let onAppleTapped: () -> Void
  let onGoogleTapped: () -> Void

  @State private var displayedText: String = ""
  @State private var showCallToAction: Bool = false
  @State private var showButtons: Bool = false

  private let fullText = "다음 약속부터\n달라질 거예요."
  private let typingSpeed: TimeInterval = 0.07

  var body: some View {
    VStack(spacing: 0) {
      Spacer()

      // 타이핑 애니메이션 텍스트
      VStack(alignment: .center, spacing: 16) {
        Text(displayedText)
          .font(.system(size: 32, weight: .bold))
          .foregroundStyle(Color.pmtext.primary)
          .multilineTextAlignment(.center)
          .frame(maxWidth: .infinity)

        if showCallToAction {
          Text("시작해볼까요?")
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(Color.pmtext.secondary)
            .multilineTextAlignment(.center)
            .transition(.opacity)
        }
      }
      .padding(.horizontal, 32)

      Spacer()
        .frame(height: 48)

      // 로그인 버튼 영역
      if showButtons {
        VStack(spacing: 14) {
          // Apple 버튼
          Button(action: onAppleTapped) {
            HStack(spacing: 12) {
              Image(systemName: "apple.logo")
                .font(.system(size: 20, weight: .medium))
              Text("Apple로 계속하기")
                .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
          }
          .background(Color.black)
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
          .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
          .disabled(isLoading)

          // Google 버튼
          Button(action: onGoogleTapped) {
            HStack(spacing: 12) {
              ResourceKitAsset.googleLogo.swiftUIImage
                .resizable()
                .frame(width: 20, height: 20)
              Text("Google로 계속하기")
                .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Color.pmtext.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
          }
          .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .fill(Color(.systemBackground))
              .opacity(0.9)
          )
          .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .stroke(Color.pmgray.n200, lineWidth: 1)
          )
          .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
          .disabled(isLoading)

          // 로딩 / 에러
          if isLoading {
            ProgressView()
              .padding(.top, 4)
          } else if let errorMessage {
            Text(errorMessage)
              .font(.system(size: 14))
              .foregroundStyle(.red)
              .multilineTextAlignment(.center)
              .padding(.top, 4)
          }
        }
        .padding(.horizontal, 24)
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      }

      Spacer()
    }
    .task {
      // 타이핑 애니메이션
      for char in fullText {
        displayedText.append(char)
        try? await Task.sleep(for: .seconds(typingSpeed))
      }
      try? await Task.sleep(for: .seconds(0.5))
      withAnimation(.easeOut(duration: 0.4)) {
        showCallToAction = true
      }
      try? await Task.sleep(for: .seconds(0.5))
      withAnimation(.spring(response: 0.6, dampingFraction: 0.85)) {
        showButtons = true
      }
    }
  }
}
