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
            timeContextCard

            if let schedule = store.schedule {
              scheduleStatusCard(schedule)
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

          if let schedule = store.schedule, let group = schedule.group {
            Text(group.name)
              .font(.system(size: 20, weight: .semibold))
              .foregroundStyle(.secondary)
          } else if store.personalEvent != nil {
            Text(LocalizedStrings.OverlayScheduleDetail.personalEvent)
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
      HStack(spacing: 12) {
        let emoji = store.item.displayEmoji
        if !emoji.isEmpty {
          Text(emoji)
            .font(.system(size: 36))
        }

        switch store.timeContext {
        case .todayUpcoming:
          VStack(alignment: .leading, spacing: 4) {
            Text(store.countdownText)
              .font(.system(size: 28, weight: .bold, design: .rounded))
              .foregroundStyle(Color.pmindigo.n500)
              .contentTransition(.numericText())
            Text(LocalizedStrings.OverlayScheduleDetail.startsAfter)
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
          }

        case .inProgress:
          HStack(spacing: 8) {
            Text(LocalizedStrings.OverlayScheduleDetail.now)
              .font(.system(size: 11, weight: .black))
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color.pmindigo.n500)
              .foregroundStyle(.white)
              .clipShape(Capsule())
            Text(LocalizedStrings.OverlayScheduleDetail.inProgress)
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
          if store.schedule != nil {
            ScheduleDetailStatusBadgeView(status: store.responseStatus)
          } else {
            Text(LocalizedStrings.OverlayScheduleDetail.pastEvent)
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

    // MARK: - Schedule Status Card (응답 + 참여 현황 통합)

    @ViewBuilder
    private func scheduleStatusCard(_ schedule: ScheduleModel) -> some View {
      let total = max(store.totalMemberCount, schedule.minimumParticipants)
      let accepted = store.acceptedCount
      let declined = store.declinedCount
      let confirm = schedule.minimumParticipants

      VStack(spacing: 12) {
        // 빠른 응답 (미래 일정만)
        if !schedule.isPast {
          HStack(spacing: 10) {
            quickResponseButton(
              title: LocalizedStrings.OverlayScheduleDetail.accept,
              icon: "checkmark",
              color: .green,
              isSelected: store.myVoteStatus == .accepted,
              isLoading: store.respondingState == .accepting
            ) {
              store.send(.view(.acceptTapped))
            }

            quickResponseButton(
              title: LocalizedStrings.OverlayScheduleDetail.pending,
              icon: "minus",
              color: Color(.systemGray),
              isSelected: store.myVoteStatus == .pending,
              isLoading: store.respondingState == .resetting
            ) {
              store.send(.view(.resetTapped))
            }

            quickResponseButton(
              title: LocalizedStrings.OverlayScheduleDetail.reject,
              icon: "xmark",
              color: .red,
              isSelected: store.myVoteStatus == .declined,
              isLoading: store.respondingState == .rejecting
            ) {
              store.send(.view(.rejectTapped))
            }
          }
        }

        // 프로그레스 바
        GeometryReader { geometry in
          let barWidth = geometry.size.width
          let acceptedRatio = min(1.0, CGFloat(accepted) / CGFloat(max(total, 1)))
          let declinedRatio = min(1.0 - acceptedRatio, CGFloat(declined) / CGFloat(max(total, 1)))
          let confirmRatio = min(1.0, CGFloat(confirm) / CGFloat(max(total, 1)))

          ZStack(alignment: .leading) {
            Capsule()
              .fill(Color.gray.opacity(0.15))

            HStack(spacing: 0) {
              Rectangle()
                .fill(accepted >= confirm ? Color.green : Color.green.opacity(0.7))
                .frame(width: max(0, barWidth * acceptedRatio))
              Rectangle()
                .fill(Color.red.opacity(0.5))
                .frame(width: max(0, barWidth * declinedRatio))
            }
            .clipShape(Capsule())

            if total > 1 {
              ForEach(1..<total, id: \.self) { i in
                let x = barWidth * CGFloat(i) / CGFloat(total)
                RoundedRectangle(cornerRadius: 0.5)
                  .fill(Color.gray.opacity(0.35))
                  .frame(width: 1, height: 6)
                  .offset(x: x - 0.5)
              }
            }

            if confirm < total {
              RoundedRectangle(cornerRadius: 1)
                .fill(Color.pmindigo.n500)
                .frame(width: 2, height: 10)
                .offset(x: barWidth * confirmRatio - 1)
            }
          }
          .animation(.easeInOut(duration: 0.35), value: accepted)
          .animation(.easeInOut(duration: 0.35), value: declined)
        }
        .frame(height: 6)

        // 범례
        HStack(spacing: 0) {
          HStack(spacing: 3) {
            Circle()
              .fill(Color.green)
              .frame(width: 6, height: 6)
            Text(LocalizedStrings.OverlayScheduleDetail.participationCount(accepted))
              .contentTransition(.numericText())
              .foregroundStyle(.green)
          }

          Text(" · ")
            .foregroundStyle(.secondary.opacity(0.5))

          HStack(spacing: 3) {
            Circle()
              .fill(Color.red.opacity(0.7))
              .frame(width: 6, height: 6)
            Text(LocalizedStrings.OverlayScheduleDetail.declinedCount(declined))
              .contentTransition(.numericText())
              .foregroundStyle(.red)
          }

          Text(" · ")
            .foregroundStyle(.secondary.opacity(0.5))

          HStack(spacing: 3) {
            RoundedRectangle(cornerRadius: 0.5)
              .fill(Color.pmindigo.n500)
              .frame(width: 2, height: 8)
            Text(LocalizedStrings.OverlayScheduleDetail.confirmThreshold(confirm))
              .foregroundStyle(Color.pmindigo.n500)
          }

          Text(" · ")
            .foregroundStyle(.secondary.opacity(0.5))

          HStack(spacing: 3) {
            Circle()
              .fill(Color.gray.opacity(0.3))
              .frame(width: 6, height: 6)
            Text(LocalizedStrings.OverlayScheduleDetail.totalCount(store.totalMemberCount))
              .foregroundStyle(.secondary)
          }

          Spacer()

          if store.myVoteStatus != .pending {
            HStack(spacing: 4) {
              Circle()
                .fill(store.myVoteStatus == .accepted ? Color.green : Color.red)
                .frame(width: 5, height: 5)
              Text(store.myVoteStatus == .accepted ? LocalizedStrings.OverlayScheduleDetail.participated : LocalizedStrings.OverlayScheduleDetail.declined)
                .foregroundStyle(store.myVoteStatus == .accepted ? .green : .red)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.8)))
          }
        }
        .font(.system(size: 11, weight: .medium))
        .minimumScaleFactor(0.8)
        .lineLimit(1)
        .animation(.easeInOut(duration: 0.35), value: accepted)
        .animation(.easeInOut(duration: 0.35), value: declined)
        .animation(.easeInOut(duration: 0.3), value: store.myVoteStatus)
      }
      .padding(16)
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

    // MARK: - Description Card (개인 일정)

    @ViewBuilder
    private var descriptionCard: some View {
      if let desc = store.personalEvent?.description, !desc.isEmpty {
        VStack(alignment: .leading, spacing: 8) {
          Text(LocalizedStrings.OverlayScheduleDetail.memo)
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

            WeatherCardStrip(
              forecast: forecast,
              rangeForecasts: weather.forecasts(from: store.item.startAt, to: store.item.endAt),
              referenceTimeText: store.item.startAt.formattedMonthDayTime,
              forecastSource: weather.forecastSource(for: store.item.startAt)
            )
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
          Text(LocalizedStrings.OverlayScheduleDetail.viewFullDetail)
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
