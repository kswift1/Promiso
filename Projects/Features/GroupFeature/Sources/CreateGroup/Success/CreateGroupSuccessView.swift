//
//  CreateGroupSuccessView.swift
//  GroupFeature
//
//  Created by 김성원 on 11/25/25.
//

import SwiftUI
import Lottie

import Clients
import PromisoShared
import ResourceKit

struct CreateGroupSuccessView: View {
  let result: GroupCreationResultModel
  let isKakaoSharing: Bool
  let onKakaoShareTapped: () -> Void
  let onConfirm: () -> Void
  @State private var toast: ToastMessage?
  @State private var showConfetti = false
  @State private var showInviteTooltip = true

  var body: some View {
    ZStack {
      ScrollView {
        VStack(spacing: 32) {
          Spacer()
            .frame(height: 20)

          // Success Icon & Message
          VStack(spacing: 16) {
            ZStack {
              Circle()
                .fill(Color.pmindigo.n100.opacity(0.5))
                .frame(width: 100, height: 100)

              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Color.pmindigo.n500)
            }

            VStack(spacing: 8) {
              Text(LocalizedStrings.CreateGroup.successTitle)
                .font(.title2.bold())

              Text(LocalizedStrings.CreateGroup.successSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
            }
          }

          // Invite Code Section
          VStack(spacing: 12) {
            HStack {
              Image(systemName: "link.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)

              Text(LocalizedStrings.CreateGroup.inviteCode)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

              Spacer()
            }

            // Code Display with Copy & Share Buttons
            HStack(spacing: 10) {
              Text(result.inviteCode)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .tracking(4)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .staticGlassBackground(cornerRadius: 12)

              Button(action: copyCode) {
                ZStack {
                  RoundedRectangle(cornerRadius: 12)
                    .fill(Color.pmindigo.n500)
                    .frame(width: 50, height: 50)

                  Image(systemName: "doc.on.doc")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                }
              }

              GroupInviteShareMessage.shareLink(groupName: result.name, inviteCode: result.inviteCode) {
                ZStack {
                  RoundedRectangle(cornerRadius: 12)
                    .fill(Color.pmindigo.n500.opacity(0.12))
                    .frame(width: 50, height: 50)

                  Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.pmindigo.n500)
                }
              }
            }
          }
          .padding(20)
          .staticGlassBackground(cornerRadius: 20)

          Spacer()
            .frame(height: 80)
        }
        .padding(.horizontal, 24)
      }
      .scrollIndicators(.hidden)

      // Confetti Lottie
      if showConfetti {
        LottieView(animation: LottieAsset.fanfare.animation)
          .playing(loopMode: .playOnce)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .allowsHitTesting(false)
          .ignoresSafeArea()
      }
    }
    .safeAreaInset(edge: .bottom) {
      bottomButtons
    }
    .navigationBarBackButtonHidden()
    .toast($toast)
    .onAppear {
      showConfetti = true
      // 툴팁 자동 숨김
      DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
        withAnimation(.easeOut(duration: 0.3)) {
          showInviteTooltip = false
        }
      }
    }
  }

  // MARK: - Bottom Buttons

  private var bottomButtons: some View {
    VStack(spacing: 12) {
      // 초대장 보내기 추천 툴팁
      if showInviteTooltip {
        HStack(spacing: 6) {
          Image(systemName: "sparkles")
            .font(.system(size: 12))
          Text(LocalizedStrings.CreateGroup.inviteTooltip)
            .font(.caption)
        }
        .foregroundStyle(Color.pmindigo.n600)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
          Capsule()
            .fill(Color.pmindigo.n100.opacity(0.8))
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
      }

      // 그룹 초대장 보내기
      Button {
        onKakaoShareTapped()
      } label: {
        HStack(spacing: 8) {
          ResourceKitAsset.kakaoLogo.swiftUIImage
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
          Text(LocalizedStrings.CreateGroup.kakaoInviteButton)
            .font(.headline)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .background(Color(red: 254 / 255, green: 229 / 255, blue: 0 / 255))
        .foregroundStyle(.black)
        .clipShape(RoundedRectangle(cornerRadius: 16))
      }
      .buttonStyle(.scale)
      .disabled(isKakaoSharing)
      .opacity(isKakaoSharing ? 0.6 : 1)

      // 완료
      Button(action: onConfirm) {
        Text(LocalizedStrings.Common.done)
          .font(.headline)
          .frame(maxWidth: .infinity)
          .frame(height: 56)
          .background(Color.pmindigo.n100)
          .foregroundStyle(Color.pmindigo.n700)
          .clipShape(RoundedRectangle(cornerRadius: 16))
      }
    }
    .padding(.horizontal, 24)
    .padding(.top, 16)
    .padding(.bottom, 16)
    .background(
      LinearGradient(
        stops: [
          .init(color: Color(.systemBackground).opacity(0), location: 0),
          .init(color: Color(.systemBackground).opacity(0.8), location: 0.15),
          .init(color: Color(.systemBackground), location: 0.3),
        ],
        startPoint: .top,
        endPoint: .bottom
      )
      .ignoresSafeArea(.container, edges: .bottom)
    )
  }

  private func copyCode() {
    UIPasteboard.general.string = result.inviteCode
    toast = ToastMessage(
      type: .success,
      title: LocalizedStrings.CreateGroup.copied,
      position: .top
    )
  }
}
