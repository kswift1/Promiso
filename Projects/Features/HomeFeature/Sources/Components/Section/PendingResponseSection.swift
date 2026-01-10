//
//  PendingResponseSection.swift
//  HomeFeature
//

import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared

struct PendingResponseSection: View {
  private let store: StoreOf<Home.Feature>

  init(store: StoreOf<Home.Feature>) {
    self.store = store
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "응답 필요",
        accessoryView: {
          if store.pendingResponsesState.isLoading {
            ProgressView()
              .scaleEffect(0.8)
          } else if !store.pendingResponses.isEmpty {
            Text("\(store.pendingResponses.count)개")
              .font(.subheadline)
              .foregroundColor(.orange)
          }
        }
      )

      if store.pendingResponsesState.isLoading {
        loadingPlaceholder
      } else if store.pendingResponses.isEmpty {
        emptyStateView
      } else {
        ForEach(store.pendingResponses) { promise in
          pendingResponseCard(promise)
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
          .frame(height: 100)
      }
    }
  }

  private var emptyStateView: some View {
    HStack {
      Image(systemName: "checkmark.circle")
        .font(.system(size: 20))
        .foregroundStyle(.secondary)

      Text("응답이 필요한 약속이 없어요")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Spacer()
    }
    .padding(16)
    .background(Color(.systemGray6).opacity(0.5))
    .cornerRadius(12)
  }

  private func pendingResponseCard(_ promise: PromiseModel) -> some View {
    let daysLeft = Calendar.current.dateComponents([.day], from: Date(), to: promise.votes.until).day ?? 0
    let isUrgent = daysLeft <= 1

    return VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text(promise.displayEmoji)
          .font(.title2)

        Text(promise.title)
          .font(.headline)
          .fontWeight(.semibold)

        Spacer()

        // D-Day 태그
        Text(daysLeft <= 0 ? "오늘 마감" : "D-\(daysLeft)")
          .font(.caption)
          .fontWeight(.bold)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(isUrgent ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2))
          .foregroundColor(isUrgent ? .orange : .gray)
          .cornerRadius(8)
      }

      // 그룹 정보
      HStack(spacing: 4) {
        if let groupName = promise.group?.name {
          Text(groupName)
            .font(.subheadline)
            .foregroundColor(.secondary)
        }

        Text("·")
          .foregroundColor(.secondary)

        Text(promise.dateText)
          .font(.subheadline)
          .foregroundColor(.secondary)

        Text(promise.timeText)
          .font(.subheadline)
          .foregroundColor(.secondary)
      }

      // 답변하기 버튼
      Button {
        store.send(.view(.respondTapped(promise)))
      } label: {
        Text("지금 답변하기 →")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundColor(.blue)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(16)
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(isUrgent ? Color.orange.opacity(0.3) : Color.clear, lineWidth: 1)
    )
    .onTapGesture {
      store.send(.view(.promiseTapped(promise)))
    }
  }
}

#Preview {
  Text("PendingResponseSection Preview")
}
