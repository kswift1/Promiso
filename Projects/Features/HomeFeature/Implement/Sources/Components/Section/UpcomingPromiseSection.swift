//
//  UpcomingPromiseSection.swift
//  HomeFeatureImplement
//
//  Created by 김성원 on 9/15/25.
//

import SwiftUI
import ComposableArchitecture
import SharedConstants

struct UpcomingPromiseSection: View {
  private let store: StoreOf<Home.Feature>
  
  init(store: StoreOf<Home.Feature>) {
    self.store = store
  }
  
  var body: some View {
    WithPerceptionTracking {
      VStack(alignment: .leading, spacing: 12) {
        SectionHeader(title: "다가오는 약속")
        
        ForEach(store.pendingResponses) { response in
          WithPerceptionTracking {
            upcomingPromiseCard()
          }
        }
      }
      .padding(.horizontal, AppConstants.UI.safeMargin)
    }
  }
  
  // FIXME:
  func upcomingPromiseCard() -> some View {
    HStack {
      Text("내일")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
      
      Text("🥐")
        .font(.system(size: 16))
        .padding(.leading, 16)
      
      VStack {
        Text("주말 브런치")
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.primary)
        
        Text("오전 11:00")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
      }
      
      Spacer()
      
      // FIXME: 완료 여부 따라서 완료 체크 아이콘 or 2/4 여부 표시 필요
      
      
      Text("지민과 나")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.blue)
        .cornerRadius(8)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.all, 16)
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
  }
}

import HomeFeatureInterface

#Preview {
  let store = Store(initialState: Home.Feature.State()) {
    Home.Feature()
  }
  UpcomingPromiseSection(store: store).upcomingPromiseCard()
}
