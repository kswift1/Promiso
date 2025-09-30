//
//  PendingResponseSection.swift
//  HomeFeatureExample
//
//  Created by 김성원 on 9/14/25.
//

import SwiftUI
import ComposableArchitecture
import Shared

struct PendingResponseSection: View {
  private let store: StoreOf<Home.Feature>
  
  init(store: StoreOf<Home.Feature>) {
    self.store = store
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {

      SectionHeader(
        title: "답변 필요한 제안",
        accessoryView: {
          Button("모두 보기 →") {
            store.send(.viewPendingResponses)
          }
          .font(.subheadline)
          .foregroundColor(.blue)
        }
      )

      ForEach(store.pendingResponses) { response in
        pendingResponseCard(response)
      }
    }
    .padding(.horizontal, AppConstants.UI.safeMargin)
  }
  
  func pendingResponseCard(_ response: Home.PendingResponse) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(response.emoji)
          .font(.title2)
        
        Text(response.title)
          .font(.headline)
          .fontWeight(.semibold)
        
        Spacer()
        
        // D-Day 태그
        Text("D-\(response.daysLeft)")
          .font(.caption)
          .fontWeight(.bold)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(response.daysLeft == 1 ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
          .foregroundColor(response.daysLeft == 1 ? .orange : .gray)
          .cornerRadius(8)
      }
      
      Text("\(response.from)님이 제안 · \(response.group)")
        .font(.subheadline)
        .foregroundColor(.secondary)
      
      // 답변하기 버튼
      Button("지금 답변하기 →") {
        store.send(.respondToProposal(response.id, true))
      }
      .font(.subheadline)
      .fontWeight(.medium)
      .foregroundColor(.blue)
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
  }
}
