//
//  HomeHeader.swift
//  HomeFeatureExample
//
//  Created by 김성원 on 9/12/25.
//

import SwiftUI
import SharedConstants

struct HomeHeader: View {
  private var badgeCount: Int
  
  init(badgeCount: Int) {
    self.badgeCount = badgeCount
  }
  
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text("오늘의 일정")
          .font(.title)
          .fontWeight(.bold)
        
        Text("모든 그룹의 약속을 한눈에")
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      
      Spacer()
      
      Button {
        // 알림 화면으로 이동 또는 알림 목록 표시
        print("알림 버튼 탭됨")
      } label: {
        ZStack {
          Image(systemName: "bell")
            .font(.title2)
            .foregroundStyle(.primary)
          
          // 알림 배지
          if badgeCount > 0 {
            Text("\(badgeCount)")
              .font(.caption2)
              .fontWeight(.semibold)
              .foregroundStyle(.white)
              .frame(minWidth: 16, minHeight: 16)
              .background(.red)
              .clipShape(Circle())
              .offset(x: 12, y: -12)
          }
        }
      }
      .buttonStyle(.plain)
    }
    .padding(.horizontal, AppConstants.UI.safeMargin)
  }
}

#Preview {
  HomeHeader(badgeCount: 3)
}
