import SwiftUI
import ComposableArchitecture
import Clients
import PromisoShared
import SharedFeature

// MARK: - OverlayScheduleDetail View

extension OverlayScheduleDetail {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        // MARK: 오버레이 스타일 헤더
        overlayHeader
          .padding(.horizontal, 20)
          .padding(.bottom, 16)

        ScrollView {
          VStack(spacing: 16) {
            emojiBadge
            timeContextCard

            if let promise = store.promise {
              if !promise.isPast {
                quickResponseSection
              }
              participationSection
            }

            if store.personalEvent != nil {
              descriptionCard
            }

            locationWeatherCard
            fullDetailButton
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 16)
        }
      }
      .onAppear { store.send(.view(.onAppear)) }
      .toast(Binding(
        get: { store.toastMessage },
        set: { _ in store.send(.view(.toastDismissed)) }
      ))
    }

    // MARK: - Overlay Header

    private var overlayHeader: some View {
      HStack(alignment: .top) {
        Button {
          store.send(.view(.backTapped))
        } label: {
          Image(systemName: "chevron.left")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }

        VStack(alignment: .leading, spacing: 0) {
          Text(store.item.title)
            .font(.system(size: 28, weight: .bold))
            .foregroundStyle(.primary)
            .lineLimit(1)

          if let promise = store.promise, let group = promise.group {
            Text(group.name)
              .font(.system(size: 20, weight: .semibold))
              .foregroundStyle(.secondary)
          } else if store.personalEvent != nil {
            Text("개인 일정")
              .font(.system(size: 20, weight: .semibold))
              .foregroundStyle(.secondary)
          }
        }

        Spacer()
      }
      .frame(height: 56)
    }

    // MARK: - Time Context Card

    @ViewBuilder
    private var timeContextCard: some View {
      HStack {
        switch store.timeContext {
        case .todayUpcoming:
          VStack(alignment: .leading, spacing: 4) {
            Text(store.countdownText)
              .font(.system(size: 28, weight: .bold, design: .rounded))
              .foregroundStyle(Color.pmindigo.n500)
              .contentTransition(.numericText())
            Text("후 시작")
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
          }

        case .inProgress:
          HStack(spacing: 8) {
            Text("NOW")
              .font(.system(size: 11, weight: .black))
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.pmindigo.n500)
              .foregroundStyle(.white)
              .clipShape(Capsule())
            Text("진행 중")
              .font(.system(size: 15, weight: .medium))
              .foregroundStyle(.secondary)
          }

        case .upcoming(let dDay):
          VStack(alignment: .leading, spacing: 4) {
            Text("D-\(dDay)")
              .font(.system(size: 28, weight: .bold, design: .rounded))
              .foregroundStyle(Color.pmindigo.n500)
            Text(store.item.startAt, format: .dateTime.month().day().weekday(.wide))
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
          }

        case .past:
          if store.promise != nil {
            PromiseDetailStatusBadgeView(status: store.responseStatus)
          } else {
            Text("지난 일정")
              .font(.system(size: 15, weight: .medium))
              .foregroundStyle(.secondary)
          }
        }

        Spacer()

        // 시간 표시 (오른쪽)
        VStack(alignment: .trailing, spacing: 2) {
          Text(store.item.startAt, format: .dateTime.hour().minute())
            .font(.system(size: 15, weight: .semibold))
          if let endAt = store.item.endAt {
            Text("~ " + endAt.formatted(.dateTime.hour().minute()))
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding(16)
      .adaptiveGlassCard()
    }

    // MARK: - Emoji Badge

    @ViewBuilder
    private var emojiBadge: some View {
      let emoji = store.item.displayEmoji
      if !emoji.isEmpty {
        Text(emoji)
          .font(.system(size: 40))
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }

    // MARK: - Quick Response Section (약속 + 미래만)

    @ViewBuilder
    private var quickResponseSection: some View {
      HStack(spacing: 10) {
        quickResponseButton(
          title: "수락",
          icon: "checkmark",
          color: .green,
          isSelected: store.myVoteStatus == .accepted,
          isLoading: store.respondingState == .accepting
        ) {
          store.send(.view(.acceptTapped))
        }

        quickResponseButton(
          title: "미정",
          icon: "minus",
          color: Color(.systemGray),
          isSelected: store.myVoteStatus == .pending,
          isLoading: store.respondingState == .resetting
        ) {
          store.send(.view(.resetTapped))
        }

        quickResponseButton(
          title: "거절",
          icon: "xmark",
          color: .red,
          isSelected: store.myVoteStatus == .declined,
          isLoading: store.respondingState == .rejecting
        ) {
          store.send(.view(.rejectTapped))
        }
      }
      .padding(12)
      .adaptiveGlassCard()
    }

    private func quickResponseButton(
      title: String,
      icon: String,
      color: Color,
      isSelected: Bool,
      isLoading: Bool,
      action: @escaping () -> Void
    ) -> some View {
      Button(action: action) {
        HStack(spacing: 6) {
          if isLoading {
            ProgressView()
              .controlSize(.small)
          } else {
            Image(systemName: icon)
              .font(.system(size: 12, weight: .bold))
          }
          Text(title)
            .font(.system(size: 13, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(isSelected ? color.opacity(0.15) : Color(.tertiarySystemBackground))
        .foregroundStyle(isSelected ? color : .secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
          RoundedRectangle(cornerRadius: 10)
            .strokeBorder(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1.5)
        )
      }
      .buttonStyle(.plain)
      .contentShape(Rectangle())
      .disabled(isLoading)
    }

    // MARK: - Participation Section (약속만)

    @ViewBuilder
    private var participationSection: some View {
      if let promise = store.promise {
        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text("참여 현황")
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(.secondary)

            Spacer()

            CircularProgressView(
              current: store.acceptedCount,
              total: max(promise.minimumParticipants, store.totalMemberCount),
              size: 28,
              lineWidth: 2.5
            )
          }

          // 프로그레스 바
          GeometryReader { geo in
            ZStack(alignment: .leading) {
              Capsule()
                .fill(Color(.systemGray5))
              Capsule()
                .fill(store.acceptedCount >= promise.minimumParticipants ? Color.green : Color.pmindigo.n500)
                .frame(width: max(0, geo.size.width * progressRatio))
                .animation(.spring(response: 0.4), value: store.acceptedCount)
            }
          }
          .frame(height: 6)

          HStack {
            VoteDotsView(
              accepted: promise.votes.accepted.count,
              declined: promise.votes.declined.count,
              pending: max(0, store.totalMemberCount - promise.votes.accepted.count - promise.votes.declined.count),
              dotSize: 8
            )

            Spacer()

            Text(store.confirmationProgress)
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
          }
        }
        .padding(16)
        .adaptiveGlassCard()
      }
    }

    private var progressRatio: Double {
      guard let promise = store.promise else { return 0 }
      let total = max(promise.minimumParticipants, store.totalMemberCount)
      guard total > 0 else { return 0 }
      return Double(store.acceptedCount) / Double(total)
    }

    // MARK: - Description Card (개인 일정)

    @ViewBuilder
    private var descriptionCard: some View {
      if let desc = store.personalEvent?.description, !desc.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text("메모")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.secondary)
          Text(desc)
            .font(.system(size: 14))
            .foregroundStyle(.primary)
            .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .adaptiveGlassCard()
      }
    }

    // MARK: - Location Weather Card

    @ViewBuilder
    private var locationWeatherCard: some View {
      let hasLocation = store.item.location != nil
      let hasWeather = store.weatherInfo != nil

      if hasLocation || hasWeather {
        VStack(spacing: 12) {
          if let location = store.item.location {
            Button {
              store.send(.view(.directionsTapped))
            } label: {
              HStack(spacing: 8) {
                Image(systemName: "mappin.circle.fill")
                  .font(.system(size: 16))
                  .foregroundStyle(Color.pmindigo.n500)

                VStack(alignment: .leading, spacing: 2) {
                  Text(location.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.primary)
                  if let address = location.address, !address.isEmpty {
                    Text(address)
                      .font(.system(size: 12))
                      .foregroundStyle(.secondary)
                      .lineLimit(1)
                  }
                }

                Spacer()

                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                  .font(.system(size: 14))
                  .foregroundStyle(.secondary)
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
          }

          if let weather = store.weatherInfo,
             let forecast = weather.forecast(for: store.item.startAt) {
            if hasLocation { Divider() }

            HStack(spacing: 8) {
              Image(systemName: forecast.condition.sfSymbolName)
                .font(.system(size: 16))
                .foregroundStyle(forecast.condition.iconColor)

              Text("\(Int(forecast.temperature))°")
                .font(.system(size: 14, weight: .semibold))

              Text(forecast.condition.description)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

              Spacer()

              if forecast.precipitationProbability > 0 {
                HStack(spacing: 2) {
                  Image(systemName: "umbrella.fill")
                    .font(.system(size: 11))
                  Text("\(forecast.precipitationProbability)%")
                    .font(.system(size: 12))
                }
                .foregroundStyle(.blue)
              }
            }
          }
        }
        .padding(16)
        .adaptiveGlassCard()
      }
    }

    // MARK: - Full Detail Button

    @ViewBuilder
    private var fullDetailButton: some View {
      Button {
        store.send(.view(.openFullDetailTapped))
      } label: {
        HStack {
          Text("전체 상세 보기")
            .font(.system(size: 15, weight: .medium))
          Spacer()
          Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(Color.pmindigo.n500)
        .padding(16)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .adaptiveGlassCard()
    }
  }
}

// MARK: - Preview

#Preview {
  OverlayScheduleDetail.RootView(
    store: Store(
      initialState: OverlayScheduleDetail.Feature.State(
        item: .personalEvent(PersonalEventModel.mock()),
        currentUserId: "preview-user"
      )
    ) {
      OverlayScheduleDetail.Feature()
    }
  )
  .auroraBackground()
}
