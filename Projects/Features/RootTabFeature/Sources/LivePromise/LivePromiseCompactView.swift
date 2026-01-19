//
//  LivePromiseCompactView.swift
//  RootTabFeature
//
//  Created by Promiso on 2026-01-19.
//

import ComposableArchitecture
import Lottie
import ResourceKit
import SwiftUI
import UIKit
import PromisoShared

extension LivePromise {
  /// 하단 컴팩트 뷰 (약속 추적 바) - tabViewBottomAccessory / overlay에서 사용
  public struct CompactView: View {
    @Bindable var store: StoreOf<Feature>
    @Environment(\.colorScheme) private var colorScheme

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      Group {
        if #available(iOS 26.0, *) {
          AdaptiveContent(store: store)
        } else {
          expandedContent
        }
      }
      .contentShape(.rect)
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Expanded Content (iOS 26 미만 또는 확장 상태)

    private var expandedContent: some View {
      HStack(spacing: 10) {
        leftContent
        Spacer(minLength: 0)
        rightContent
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity)
    }

    // MARK: - Left Content (이모지 + 제목 + 메타)

    private var leftContent: some View {
      HStack(spacing: 10) {
        // 이모지 아이콘
        emojiIcon

        // 제목 + 메타 정보
        VStack(alignment: .leading, spacing: 2) {
          Text(store.data.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(primaryTextColor)
            .lineLimit(1)

          // 📍강남역 • 4명
          HStack(spacing: 3) {
            if let location = store.data.location {
              Text("📍")
                .font(.system(size: 9))
              Text(location)
                .font(.caption2)
              Text("•")
                .font(.system(size: 8))
            }
            Text("\(store.data.participants.count)명")
              .font(.caption2)
          }
          .foregroundStyle(secondaryTextColor)
          .lineLimit(1)
        }
      }
    }

    // MARK: - Emoji Icon

    private var emojiIcon: some View {
      Text(store.data.emoji)
        .font(.system(size: 24))
    }

    // MARK: - Right Content (시간 + 공유중 뱃지)

    private var rightContent: some View {
      HStack(spacing: 10) {
        // 시간 표기
        timeDisplay

        // 공유중 뱃지
        liveBadge
      }
    }

    // MARK: - Live Badge (이퀄라이저 + 공유중)

    private var liveBadge: some View {
      HStack(spacing: 3) {
        LottieView(animation: LottieAsset.live.animation)
          .playing(loopMode: .loop)
          .frame(width: 14, height: 10)

        Text("실시간")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(badgeTextColor)
      }
      .padding(.horizontal, 6)
      .padding(.vertical, 3)
      .background(badgeBackgroundColor, in: Capsule())
    }

    // MARK: - Time Display (V5 스타일 - 가로 배치)

    private var timeDisplay: some View {
      HStack(alignment: .firstTextBaseline, spacing: 2) {
        if let time = store.data.scheduledTime {
          Text(formatPeriod(time))
            .font(.caption2.weight(.medium))
            .foregroundStyle(secondaryTextColor)

          Text(formatTime(time))
            .font(.title3.weight(.bold).monospacedDigit())
            .foregroundStyle(primaryTextColor)
        }
      }
    }

    // MARK: - Colors (다크/라이트 모드 대응)

    private var primaryTextColor: Color {
      colorScheme == .dark ? .white : Color.pmgray.n900
    }

    private var secondaryTextColor: Color {
      colorScheme == .dark ? Color.pmgray.n400 : Color.pmgray.n500
    }

    private var badgeTextColor: Color {
      colorScheme == .dark ? Color.pmindigo.n200 : Color.pmindigo.n600
    }

    private var badgeBackgroundColor: Color {
      colorScheme == .dark
        ? Color.pmindigo.n800.opacity(0.6)
        : Color.pmindigo.n100.opacity(0.8)
    }

    // MARK: - Formatters

    private func formatTime(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "h:mm"
      return formatter.string(from: date)
    }

    private func formatPeriod(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "a"
      formatter.locale = Locale(identifier: "en_US")
      return formatter.string(from: date)
    }
  }

  // MARK: - Adaptive Content (iOS 26+)

  @available(iOS 26.0, *)
  private struct AdaptiveContent: View {
    @Bindable var store: StoreOf<Feature>
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
      switch placement {
      case .inline:
        inlineContent

      case .expanded:
        expandedContent

      default:
        // 기본 (nil 등)
        expandedContent
      }
    }

    // MARK: - Inline Content (축소 상태)

    private var inlineContent: some View {
      HStack(spacing: 10) {
        // 이모지
        Text(store.data.emoji)
          .font(.system(size: 24))

        // 제목 + 메타 정보
        VStack(alignment: .leading, spacing: 2) {
          Text(store.data.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(colorScheme == .dark ? .white : Color.pmgray.n900)
            .lineLimit(1)

          HStack(spacing: 3) {
            if let location = store.data.location {
              Text("📍")
                .font(.system(size: 9))
              Text(location)
                .font(.caption2)
              Text("•")
                .font(.system(size: 8))
            }
            Text("\(store.data.participants.count)명")
              .font(.caption2)
          }
          .foregroundStyle(colorScheme == .dark ? Color.pmgray.n400 : Color.pmgray.n500)
        }

        Spacer(minLength: 0)

        // 시간 표기
        if let time = store.data.scheduledTime {
          HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(formatPeriod(time))
              .font(.caption2.weight(.medium))
              .foregroundStyle(colorScheme == .dark ? Color.pmgray.n400 : Color.pmgray.n500)
            Text(formatTime(time))
              .font(.title3.weight(.bold).monospacedDigit())
              .foregroundStyle(colorScheme == .dark ? .white : Color.pmgray.n900)
          }
        }

        // 실시간 뱃지
        HStack(spacing: 3) {
          LottieView(animation: LottieAsset.live.animation)
            .playing(loopMode: .loop)
            .frame(width: 14, height: 10)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
          colorScheme == .dark
            ? Color.pmindigo.n800.opacity(0.6)
            : Color.pmindigo.n100.opacity(0.8),
          in: Capsule()
        )
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity)
    }

    // MARK: - Expanded Content (확장 상태)

    private var expandedContent: some View {
      HStack(spacing: 10) {
        // 이모지
        Text(store.data.emoji)
          .font(.system(size: 24))

        // 제목 + 메타 정보
        VStack(alignment: .leading, spacing: 2) {
          Text(store.data.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(colorScheme == .dark ? .white : Color.pmgray.n900)
            .lineLimit(1)

          HStack(spacing: 3) {
            if let location = store.data.location {
              Text("📍")
                .font(.system(size: 9))
              Text(location)
                .font(.caption2)
              Text("•")
                .font(.system(size: 8))
            }
            Text("\(store.data.participants.count)명")
              .font(.caption2)
          }
          .foregroundStyle(colorScheme == .dark ? Color.pmgray.n400 : Color.pmgray.n500)
        }

        Spacer(minLength: 0)

        // 시간 표기
        if let time = store.data.scheduledTime {
          HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(formatPeriod(time))
              .font(.caption2.weight(.medium))
              .foregroundStyle(colorScheme == .dark ? Color.pmgray.n400 : Color.pmgray.n500)
            Text(formatTime(time))
              .font(.title3.weight(.bold).monospacedDigit())
              .foregroundStyle(colorScheme == .dark ? .white : Color.pmgray.n900)
          }
        }

        // 실시간 뱃지
        HStack(spacing: 3) {
          LottieView(animation: LottieAsset.live.animation)
            .playing(loopMode: .loop)
            .frame(width: 14, height: 10)
          Text("실시간")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(colorScheme == .dark ? Color.pmindigo.n200 : Color.pmindigo.n600)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
          colorScheme == .dark
            ? Color.pmindigo.n800.opacity(0.6)
            : Color.pmindigo.n100.opacity(0.8),
          in: Capsule()
        )
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity)
    }

    // MARK: - Formatters

    private func formatTime(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "h:mm"
      return formatter.string(from: date)
    }

    private func formatPeriod(_ date: Date) -> String {
      let formatter = DateFormatter()
      formatter.dateFormat = "a"
      formatter.locale = Locale(identifier: "en_US")
      return formatter.string(from: date)
    }
  }
}

// MARK: - Preview

#Preview("LivePromise Compact - Light") {
  VStack {
    LivePromise.CompactView(
      store: Store(
        initialState: LivePromise.Feature.State(
          emoji: "🍜",
          title: "점심 모임",
          location: "강남역 11번 출구",
          scheduledTime: Calendar.current.date(
            bySettingHour: 12,
            minute: 30,
            second: 0,
            of: Date()
          ),
          participants: [
            ParticipantState(id: "user1", name: "김철수", estimatedArrivalMinutes: 0),
            ParticipantState(id: "user2", name: "이영희", estimatedArrivalMinutes: 5),
            ParticipantState(id: "user3", name: "박민수", estimatedArrivalMinutes: nil),
            ParticipantState(id: "user4", name: "최지은", estimatedArrivalMinutes: 10)
          ],
          currentUserId: "user2"
        )
      ) {
        LivePromise.Feature()
      } withDependencies: {
        $0.liveActivityClient = .previewValue
      }
    )
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    .padding(.horizontal)
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.pmgray.n100)
  .preferredColorScheme(.light)
}

#Preview("LivePromise Compact - Dark") {
  VStack {
    LivePromise.CompactView(
      store: Store(
        initialState: LivePromise.Feature.State(
          emoji: "🎂",
          title: "생일 파티",
          location: "강남역",
          scheduledTime: Calendar.current.date(
            bySettingHour: 18,
            minute: 0,
            second: 0,
            of: Date()
          ),
          participants: [
            ParticipantState(id: "user1", name: "김철수", estimatedArrivalMinutes: 0),
            ParticipantState(id: "user2", name: "이영희", estimatedArrivalMinutes: 5),
            ParticipantState(id: "user3", name: "박민수", estimatedArrivalMinutes: nil),
            ParticipantState(id: "user4", name: "최지은", estimatedArrivalMinutes: 10)
          ],
          currentUserId: "user2"
        )
      ) {
        LivePromise.Feature()
      } withDependencies: {
        $0.liveActivityClient = .previewValue
      }
    )
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    .padding(.horizontal)
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color.pmgray.n900)
  .preferredColorScheme(.dark)
}
