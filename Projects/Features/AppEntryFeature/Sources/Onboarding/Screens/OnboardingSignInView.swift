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

  @State private var indicatorProgress: CGFloat = 0
  @State private var showTyping: Bool = false
  @State private var showLoginSheet: Bool = false

  var body: some View {
    ZStack(alignment: .bottom) {
      VStack(alignment: .leading, spacing: 0) {

        VStack(alignment: .leading, spacing: 16) {
          // 인디케이터 바
          RoundedRectangle(cornerRadius: 2)
            .fill(
              LinearGradient(
                colors: [
                  Color.pmbrand.primary,
                  Color.pmbrand.secondary
                ],
                startPoint: .leading,
                endPoint: .trailing
              )
            )
            .frame(width: 40, height: 4)
            .scaleEffect(x: indicatorProgress, y: 1, anchor: .leading)
            .opacity(indicatorProgress == 0 ? 0 : 1)

          if showTyping {
            TypewriterLinesView(
              animated: true,
              lines: [
                .init(
                  text: "일정을",
                  font: .system(size: 48, weight: .black),
                  style: AnyShapeStyle(Color.pmtext.primary)
                ),
                .init(
                  text: "더 특별하게.",
                  font: .system(size: 48, weight: .black),
                  style: AnyShapeStyle(
                    LinearGradient(
                      colors: [
                        Color.pmindigo.n600,
                        Color.pmpurple.n600
                      ],
                      startPoint: .leading,
                      endPoint: .trailing
                    )
                  )
                ),
                .init(
                  text: "소중한 순간들을",
                  font: .system(size: 18, weight: .medium),
                  style: AnyShapeStyle(Color.pmtext.secondary)
                ),
                .init(
                  text: "Promiso와 함께하세요.",
                  font: .system(size: 18, weight: .medium),
                  style: AnyShapeStyle(Color.pmtext.secondary)
                )
              ],
              typingAnimationCompleted: {
                Task {
                  try? await Task.sleep(for: .seconds(1))
                  withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
                    showLoginSheet = true
                  }
                }
              },
              lineSpacingProvider: { index in
                switch index {
                case 0: return 4
                case 1: return 24
                case 2: return 4
                default: return 0
                }
              },
              typingSpeed: 0.05,
              lineDelayProvider: { line in
                return line == 1 ? 1.0 : 0.3
              }
            )
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .padding(.top, 80)

        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .overlay(alignment: .bottom) {
        if showLoginSheet {
          LoginSheetView(
            isLoading: isLoading,
            errorMessage: errorMessage,
            onAppleTapped: onAppleTapped,
            onGoogleTapped: onGoogleTapped
          )
          .transition(.move(edge: .bottom).combined(with: .opacity))
        }
      }
    }
    .task {
      try? await Task.sleep(for: .seconds(1.5))

      withAnimation(.easeOut(duration: 0.6)) {
        indicatorProgress = 1
      }

      try? await Task.sleep(for: .seconds(1))
      showTyping = true
    }
  }
}

// MARK: - LoginSheetView

private struct LoginSheetView: View {
  let isLoading: Bool
  let errorMessage: String?
  let onAppleTapped: () -> Void
  let onGoogleTapped: () -> Void

  var body: some View {
    VStack(spacing: 20) {
      Text("계속하기")
        .font(.system(size: 14, weight: .medium))
        .tracking(2)
        .foregroundStyle(.secondary)

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
    .padding(.vertical, 28)
    .frame(maxWidth: .infinity)
    .background(loginSheetBackground)
    .shadow(color: .black.opacity(0.15), radius: 30, x: 0, y: -10)
    .padding(.horizontal, 16)
    .padding(.bottom, 40)
  }

  @ViewBuilder
  private var loginSheetBackground: some View {
    if #available(iOS 26.0, *) {
      Color.clear
        .glassEffect(
          .regular
            .tint(.white.opacity(0.1)),
          in: .rect(cornerRadius: 36)
        )
    } else {
      ZStack {
        RoundedRectangle(cornerRadius: 36, style: .continuous)
          .fill(.ultraThinMaterial)

        RoundedRectangle(cornerRadius: 36, style: .continuous)
          .fill(
            LinearGradient(
              colors: [
                Color.white.opacity(0.25),
                Color.white.opacity(0.1)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )

        RoundedRectangle(cornerRadius: 36, style: .continuous)
          .strokeBorder(
            LinearGradient(
              colors: [
                Color.white.opacity(0.4),
                Color.white.opacity(0.2)
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
            lineWidth: 1
          )
      }
    }
  }
}
