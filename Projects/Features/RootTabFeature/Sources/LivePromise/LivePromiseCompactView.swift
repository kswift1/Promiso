//
//  LivePromiseCompactView.swift
//  RootTabFeature
//
//  Created by Promiso on 2026-01-19.
//

import ComposableArchitecture
import SwiftUI
import PromisoShared

extension LivePromise {
  /// 하단 컴팩트 뷰 (약속 추적 바) - tabViewBottomAccessory / overlay에서 사용
  public struct CompactView: View {
    @Bindable var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      HStack(spacing: 12) {
        // 왼쪽: 이모지 + 제목 + 참가자
        playerInfo

        Spacer(minLength: 0)

        // 오른쪽: 액션 버튼들
        actionButtons
      }
      .foregroundStyle(Color.primary)
      .padding(.horizontal, 15)
      .contentShape(.rect) // 전체 영역 탭 가능
      .onTapGesture {
        store.send(.view(.tapped))
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Player Info (음악 앱 스타일)

    private var playerInfo: some View {
      HStack(spacing: 12) {
        // 이모지 아이콘 (앨범 아트 대체)
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.blue.gradient)
          .frame(width: 40, height: 40)
          .overlay {
            Text(store.data.emoji)
              .font(.title3)
          }

        VStack(alignment: .leading, spacing: 4) {
          Text(store.data.title)
            .font(.callout.weight(.semibold))
            .lineLimit(1)

          Text(statusText)
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
      HStack(spacing: 12) {
        // ETA 버튼
        Button {
          store.send(.view(.etaButtonTapped(0)))
        } label: {
          Text(etaButtonText)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(etaButtonColor, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(store.data.isProcessingETAUpdate)

        // 시간
        if let time = store.data.scheduledTime {
          Text(formatTime(time))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    }

    // MARK: - Computed Properties

    private var statusText: String {
      let arrived = store.data.arrivedCount
      let total = store.data.participants.count
      if arrived == total && total > 0 {
        return "모두 도착!"
      }
      return "\(arrived)/\(total)명 도착"
    }

    private var etaButtonText: String {
      if let eta = store.data.currentUserETA {
        return eta == 0 ? "도착 완료" : "\(eta)분"
      }
      return "도착"
    }

    private var etaButtonColor: Color {
      if let eta = store.data.currentUserETA, eta == 0 {
        return .green
      }
      return .blue
    }

    private func formatTime(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "a h:mm"
      formatter.locale = Locale(identifier: "ko_KR")
      return formatter.string(from: date)
    }
  }
}

// MARK: - Preview

#Preview("LivePromise Compact") {
  LivePromise.CompactView(
    store: Store(
      initialState: LivePromise.Feature.State(
        emoji: "🎂",
        title: "생일 파티",
        location: "강남역 11번 출구",
        scheduledTime: Date().addingTimeInterval(3600),
        participants: [
          ParticipantState(id: "user1", name: "김철수", estimatedArrivalMinutes: 0),
          ParticipantState(id: "user2", name: "이영희", estimatedArrivalMinutes: 5),
          ParticipantState(id: "user3", name: "박민수", estimatedArrivalMinutes: nil)
        ],
        currentUserId: "user2"
      )
    ) {
      LivePromise.Feature()
    } withDependencies: {
      $0.liveActivityClient = .previewValue
    }
  )
  .padding()
  .background(.ultraThinMaterial, in: .rect(cornerRadius: 15))
  .padding()
}
