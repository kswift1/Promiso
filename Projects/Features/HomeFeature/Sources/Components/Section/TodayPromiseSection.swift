//
//  TodayPromiseSection.swift
//  HomeFeatureExample
//
//  Created by 김성원 on 9/14/25.
//

import SwiftUI
import ComposableArchitecture

import Shared

struct TodayPromiseSection: View {
  
  private let store: StoreOf<Home.Feature>
  
  init(store: StoreOf<Home.Feature>) {
    self.store = store
  }
  
  var body: some View {
    WithPerceptionTracking {
      VStack(alignment: .leading, spacing: 12) {
        SectionHeader(
          title: "오늘 확정된 약속",
          accessoryView: {
            WithPerceptionTracking {
              Text("\(store.todaysPromises.count)개")
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
          }
        )
        
        ForEach(store.todaysPromises.indices, id: \.self) { index in
          WithPerceptionTracking {
            let promise = store.todaysPromises[index]
            let isLast = index == store.todaysPromises.indices.last
            promiseCard(promise, isLast: isLast)
          }
        }
      }
      .padding(.horizontal, AppConstants.UI.safeMargin)
    }
  }
  
  private func promiseCard(_ promise: Home.PromiseItem, isLast: Bool) -> some View {
    let dotSize: CGFloat = 14
    
    return HStack {
      // 시간
      VStack(spacing: 2) {
        Text("7:00") // "7:00"
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.primary)
        
        Text("오후") // "오후"
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
      }
      
      // Dot, Border
      VStack(spacing: 4) {
        RoundedRectangle(cornerRadius: dotSize/2)
          .foregroundStyle(.blue) // 그룹별 색상
          .frame(width: dotSize, height: dotSize)
        
        if !isLast {
          Rectangle()
            .foregroundStyle(.quaternary)
            .frame(width: 2, height: 32)
        }
      }
      .padding(.horizontal, 12)
      
      // 약속 상세 정보
      VStack(alignment: .leading, spacing: 4) {
        HStack {
          Text(promise.emoji)
            .font(.system(size: 16))
          
          Text(promise.title)
            .font(.system(size: 16, weight: .medium))
            .lineLimit(2)
            .truncationMode(.tail)
          
          Spacer()
          
          // Live Activity 시작 버튼
          if /*promise.canStartLiveActivity*/ true {
            Button {
              store.send(.startLiveActivity(promise.id))
            } label: {
              Image(systemName: "play.fill")
                .font(.system(size: 12))
                .foregroundStyle(.blue)
                .frame(width: 24, height: 24)
                .background(.blue.opacity(0.1))
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
          }
        }
        
        HStack(spacing: 8) {
          HStack(spacing: 4) {
            Image(systemName: "location.fill")
              .font(.system(size: 10))
              .foregroundStyle(.secondary)
            
            Text(promise.location)
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
              .lineLimit(2)
              .truncationMode(.tail)
          }
          
          // 그룹 태그
          Text("지민과 나")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.blue)
            .cornerRadius(8)
        }
      }
    }
    .frame(maxWidth: .infinity, minHeight: 90, maxHeight: 150, alignment: .leading)
    .padding(.horizontal, 14)
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
  }
}

#Preview {
  let store = Store(initialState: Home.Feature.State()) {
    Home.Feature()
  }
  TodayPromiseSection(store: store)
  //  HomeEntry.preview().makeView(.init())
}
