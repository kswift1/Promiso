//
//  TodayPromiseSection.swift
//  HomeFeature
//

import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared

struct TodayPromiseSection: View {
  private let store: StoreOf<Home.Feature>

  init(store: StoreOf<Home.Feature>) {
    self.store = store
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      SectionHeader(
        title: "오늘 확정된 약속",
        accessoryView: {
          if store.todaysPromisesState.isLoading {
            ProgressView()
              .scaleEffect(0.8)
          } else {
            Text("\(store.todaysPromises.count)개")
              .font(.subheadline)
              .foregroundColor(.secondary)
          }
        }
      )

      if store.todaysPromisesState.isLoading {
        loadingPlaceholder
      } else if store.todaysPromises.isEmpty {
        emptyStateView
      } else {
        ForEach(Array(store.todaysPromises.enumerated()), id: \.element.id) { index, promise in
          let isLast = index == store.todaysPromises.count - 1
          promiseCard(promise, isLast: isLast)
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
          .frame(height: 90)
      }
    }
  }

  private var emptyStateView: some View {
    HStack {
      Image(systemName: "checkmark.circle")
        .font(.system(size: 20))
        .foregroundStyle(.secondary)

      Text("오늘 확정된 약속이 없어요")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Spacer()
    }
    .padding(16)
    .background(Color(.systemGray6).opacity(0.5))
    .cornerRadius(12)
  }

  private func promiseCard(_ promise: PromiseModel, isLast: Bool) -> some View {
    let dotSize: CGFloat = 14

    return HStack {
      // 시간
      VStack(spacing: 2) {
        Text(promise.startAt.formatted(date: .omitted, time: .shortened).components(separatedBy: " ").last ?? "")
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.primary)

        Text(promise.startAt.formatted(date: .omitted, time: .shortened).components(separatedBy: " ").first ?? "")
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.secondary)
      }
      .frame(width: 50)

      // Dot, Border
      VStack(spacing: 4) {
        RoundedRectangle(cornerRadius: dotSize/2)
          .foregroundStyle(.blue)
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
          Text(promise.displayEmoji)
            .font(.system(size: 16))

          Text(promise.title)
            .font(.system(size: 16, weight: .medium))
            .lineLimit(2)
            .truncationMode(.tail)

          Spacer()

          // Live Activity 버튼 (placeholder - 추후 구현)
          if promise.isRealtimeShareable {
            Image(systemName: "play.fill")
              .font(.system(size: 12))
              .foregroundStyle(.blue)
              .frame(width: 24, height: 24)
              .background(.blue.opacity(0.1))
              .clipShape(Circle())
          }
        }

        HStack(spacing: 8) {
          // 장소
          if let location = promise.location {
            HStack(spacing: 4) {
              Image(systemName: "location.fill")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)

              Text(location.name)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            }
          }

          // 실시간 공유
          if let minutes = promise.trackingStartMinutesBefore {
            HStack(spacing: 4) {
              Text("📡")
                .font(.system(size: 10))

              Text("\(minutes)분 전")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            }
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
  // Preview는 currentUser가 필요하므로 간단하게 구성하기 어려움
  Text("TodayPromiseSection Preview")
}
