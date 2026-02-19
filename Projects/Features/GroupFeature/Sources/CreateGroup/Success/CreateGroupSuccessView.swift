//
//  CreateGroupSuccessView.swift
//  GroupFeature
//
//  Created by 김성원 on 11/25/25.
//

import SwiftUI

import Clients
import PromisoShared
import ResourceKit

struct CreateGroupSuccessView: View {
  let result: GroupCreationResultModel
  let isKakaoSharing: Bool
  let onKakaoShareTapped: () -> Void
  let onConfirm: () -> Void
  @State private var isCopied = false
  
  var body: some View {
    ScrollView {
      VStack(spacing: 32) {
        Spacer()
          .frame(height: 20)

        // Success Icon & Message
        VStack(spacing: 20) {
          // Icon with gradient background
          ZStack {
            Circle()
              .fill(
                LinearGradient(
                  colors: [Color.blue.opacity(0.15), Color.purple.opacity(0.1)],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
              .frame(width: 120, height: 120)

            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 60))
              .foregroundStyle(
                LinearGradient(
                  colors: [.blue, .purple],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                )
              )
          }

          VStack(spacing: 12) {
            Text(LocalizedStrings.CreateGroup.successTitle)
              .font(.title.bold())

            Text(LocalizedStrings.CreateGroup.successSubtitle)
              .font(.body)
              .foregroundStyle(.secondary)
              .multilineTextAlignment(.center)
              .lineSpacing(4)
          }
        }

        // Invite Code Section
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

            Text(LocalizedStrings.CreateGroup.inviteCode)
              .font(.headline)

            Spacer()
          }

          // Code Display with Copy Button
          HStack(spacing: 12) {
            Text(result.inviteCode)
              .font(.system(size: 32, weight: .bold, design: .rounded))
              .tracking(4)
              .frame(maxWidth: .infinity)
              .padding(.vertical, 20)
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
                  .frame(width: 60, height: 60)
                  .shadow(
                    color: isCopied ? .green.opacity(0.3) : .blue.opacity(0.3),
                    radius: 8,
                    x: 0,
                    y: 4
                  )

                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                  .font(.system(size: 22, weight: .semibold))
                  .foregroundStyle(.white)
              }
            }
            .animation(.spring(response: 0.3), value: isCopied)
          }

          if isCopied {
            HStack(spacing: 8) {
              Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14))
              Text(LocalizedStrings.CreateGroup.copied)
                .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(.green)
            .transition(.scale.combined(with: .opacity))
          }
        }
        .padding(24)
        .background(
          RoundedRectangle(cornerRadius: 20)
            .fill(Color(.systemBackground))
            .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 8)
        )

        // Action Buttons
        VStack(spacing: 12) {
          // 카카오톡으로 초대장 보내기
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
            .background(Color(red: 254/255, green: 229/255, blue: 0/255))
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 16))
          }
          .buttonStyle(.scale)
          .disabled(isKakaoSharing)
          .opacity(isKakaoSharing ? 0.6 : 1)

          // 다른 앱으로 공유
          GroupInviteShareMessage.shareLink(groupName: result.name, inviteCode: result.inviteCode) {
            HStack(spacing: 8) {
              Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18))
              Text(LocalizedStrings.CreateGroup.share)
                .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(Color.pmindigo.n500.opacity(0.12))
            .foregroundStyle(Color.pmindigo.n500)
            .clipShape(RoundedRectangle(cornerRadius: 16))
          }
          .buttonStyle(.scale)

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

        Spacer()
          .frame(height: 20)
      }
      .padding(.horizontal, 24)
    }
    .navigationBarBackButtonHidden()
  }
  
  private func copyCode() {
    UIPasteboard.general.string = result.inviteCode
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
