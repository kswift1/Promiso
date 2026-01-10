//
//  UpcomingPromiseSection.swift
//  HomeFeature
//

import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared

struct UpcomingPromiseSection: View {
  private let store: StoreOf<Home.Feature>

  init(store: StoreOf<Home.Feature>) {
    self.store = store
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "다가오는 약속",
        accessoryView: {
          if store.upcomingPromisesState.isLoading {
            ProgressView()
              .scaleEffect(0.8)
          } else if !store.upcomingPromises.isEmpty {
            Text("\(store.upcomingPromises.count)개")
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        }
      )

      if store.upcomingPromisesState.isLoading {
        loadingPlaceholder
      } else if store.upcomingPromises.isEmpty {
        emptyStateView
      } else {
        ForEach(store.upcomingPromises) { promise in
          upcomingPromiseCard(promise)
            .onTapGesture {
              store.send(.view(.promiseTapped(promise)))
            }
        }
      }
    }
    .padding(.horizontal, AppConstants.UI.safeMargin)
  }

  private var loadingPlaceholder: some View {
    VStack(spacing: 8) {
      ForEach(0..<2, id: \.self) { _ in
        RoundedRectangle(cornerRadius: 12)
          .fill(Color(.systemGray6))
          .frame(height: 70)
      }
    }
  }

  private var emptyStateView: some View {
    HStack {
      Image(systemName: "calendar")
        .font(.system(size: 20))
        .foregroundStyle(.secondary)

      Text("다가오는 약속이 없어요")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Spacer()
    }
    .padding(16)
    .background(Color(.systemGray6).opacity(0.5))
    .cornerRadius(12)
  }

  private func upcomingPromiseCard(_ promise: PromiseModel) -> some View {
    HStack(spacing: 12) {
      // 날짜
      Text(promise.dateText)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
        .frame(width: 50, alignment: .leading)

      // 이모지
      Text(promise.displayEmoji)
        .font(.system(size: 20))

      // 약속 정보
      VStack(alignment: .leading, spacing: 2) {
        Text(promise.title)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(1)

        Text(promise.timeText)
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
      }

      Spacer()

      // 확정 여부 또는 참석자 수
      if promise.isConfirmed {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 16))
          .foregroundStyle(.green)
      } else {
        Text("\(promise.votes.acceptedCount)/\(promise.minimumParticipants)")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
      }

      // 그룹 태그
      if let groupName = promise.group?.name {
        Text(groupName)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(.blue)
          .cornerRadius(8)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.all, 16)
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
  }
}

#Preview {
  Text("UpcomingPromiseSection Preview")
}
