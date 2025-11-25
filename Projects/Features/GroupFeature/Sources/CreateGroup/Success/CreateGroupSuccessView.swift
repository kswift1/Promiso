//
//  CreateGroupSuccessView.swift
//  GroupFeature
//
//  Created by 김성원 on 11/25/25.
//

import SwiftUI

import Clients

struct CreateGroupSuccessView: View {
  let result: GroupCreationResult
  let onConfirm: () -> Void
  @State private var isCopied = false
  
  private var shareMessage: String {
    "\(result.name) 그룹 초대 코드: \(result.inviteCode)"
  }
  
  var body: some View {
    ScrollView {
      VStack(spacing: 28) {
        VStack(spacing: 12) {
          Image(systemName: "checkmark.seal.fill")
            .font(.system(size: 60))
            .foregroundStyle(Color.blue)
          
          Text("그룹이 만들어졌어요!")
            .font(.system(size: 26, weight: .bold))
            .multilineTextAlignment(.center)
          
          Text("친구들에게 초대 코드를 공유해\n함께 약속을 만들어보세요.")
            .font(.system(size: 16))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        
        VStack(spacing: 16) {
          Text("초대 코드")
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
          
          HStack(spacing: 12) {
            Text(result.inviteCode)
              .font(.system(size: 34, weight: .heavy, design: .monospaced))
              .frame(maxWidth: .infinity, alignment: .center)
              .padding(.vertical, 14)
              .background(Color(.systemGray6))
              .cornerRadius(16)
            
            Button(action: copyCode) {
              Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 56, height: 56)
                .background(isCopied ? Color.green.opacity(0.2) : Color(.systemGray6))
                .foregroundColor(isCopied ? .green : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
          }
          
          if isCopied {
            Text("복사되었습니다!")
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(.green)
              .frame(maxWidth: .infinity, alignment: .leading)
              .transition(.opacity)
          }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(20)
        .shadow(color: .black.opacity(0.05), radius: 15, x: 0, y: 8)
        
        VStack(spacing: 12) {
          ShareLink(item: shareMessage) {
            Label("공유하기", systemImage: "square.and.arrow.up")
              .font(.system(size: 17, weight: .semibold))
              .frame(maxWidth: .infinity)
          }
          .buttonStyle(.borderedProminent)
          
          Button(action: onConfirm) {
            Text("완료")
              .font(.system(size: 17, weight: .semibold))
              .frame(maxWidth: .infinity)
              .padding(.vertical, 14)
              .background(Color(.systemGray6))
              .cornerRadius(14)
          }
        }
      }
      .padding(.horizontal, 24)
      .padding(.bottom, 40)
    }
    .navigationBarBackButtonHidden()
    .toolbar {
      ToolbarItem(placement: .topBarTrailing) {
        Button(action: onConfirm) {
          Image(systemName: "xmark")
        }
      }
    }
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
