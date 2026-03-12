import SwiftUI
import Clients
import PromisoShared
import ResourceKit

// MARK: - Timeline Item View

/// 오늘의 일정 타임라인 개별 아이템 (일정 + 개인 일정 + 반복 일정 통합)
struct TimelineItemView: View {
  let item: HomeModels.ScheduleItem
  let isFirst: Bool
  let isLast: Bool
  let weather: WeatherInfo?
  let groupColor: Color?
  let departureAlert: HomeModels.DepartureAlertInfo?
  let isPro: Bool
  let onTap: () -> Void
  let onDepartureAlertTap: () -> Void
  let onDepartureAlertCancel: () -> Void

  @State private var showLiveActivityInfo = false

  var body: some View {
    Button(action: onTap) {
      HStack(alignment: .top, spacing: 0) {
        // 타임라인 인디케이터 (가장 왼쪽, 패딩 영향 없음)
        timelineIndicator

        // 시간 + 콘텐츠 + Divider (패딩 적용)
        VStack(spacing: 0) {
          HStack(alignment: .top, spacing: 0) {
            timeLabel
              .frame(width: 80, alignment: .center)
              .padding(.leading, 8)

            itemContent
              .padding(.leading, 8)

            Spacer(minLength: 0)
          }
          .padding(.vertical, 8)

          // Pro 혜택 영역 (날씨 + 출발 알림)
          proBenefitSection

          // Divider (마지막 아이템 제외)
          if !isLast {
            Rectangle()
              .fill(Color.pmgray.n200)
              .frame(height: 0.5)
              .padding(.leading, 8)
              .padding(.trailing, 16)
          }
        }
      }
      .opacity(isPast ? 0.7 : 1.0)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Timeline Indicator

  private var timelineIndicator: some View {
    VStack(spacing: 0) {
      // 상단 라인 (첫 번째가 아니면 표시)
      Rectangle()
        .fill(isFirst ? Color.clear : Color.pmindigo.n300.opacity(0.5))
        .frame(width: 2, height: 10)

      // 점 (상태에 따라 색상 변경)
      Circle()
        .fill(dotColor)
        .frame(width: 10, height: 10)
        .overlay {
          if isNow {
            Circle()
              .stroke(Color.pmindigo.n500.opacity(0.3), lineWidth: 3)
              .frame(width: 16, height: 16)
          }
        }

      // 하단 라인 (마지막이 아니면 표시, 남은 공간 채움)
      Rectangle()
        .fill(isLast ? Color.clear : Color.pmindigo.n300.opacity(0.5))
        .frame(width: 2)
        .frame(maxHeight: .infinity)
    }
    .frame(width: 16)
    .frame(maxHeight: .infinity, alignment: .top)
  }

  // MARK: - Item Content

  @ViewBuilder
  private var itemContent: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Row 1: 이모지 + 제목 + 타입 캡슐
      HStack(spacing: 6) {
        Text(item.displayEmoji)
          .font(.pmTitle3)

        Text(item.title)
          .font(.pmBodySemibold)
          .foregroundStyle(.primary)
          .lineLimit(1)

        Spacer(minLength: 4)

        typeBadge
      }

      // Row 2: 타입별 메타 정보
      switch item {
      case .schedule(let schedule):
        scheduleMetaRow(schedule)
      case .personalEvent(let event):
        personalEventMetaRow(event)
      case .recurringPersonalEvent(let event):
        recurringEventMetaRow(event)
      }

      // Row 3: 장소 (schedule만, 개인/반복은 Row 2에 포함)
      if case .schedule(let schedule) = item, let location = schedule.location {
        locationRow(location)
      }

      // Row 4: 추가 정보 (타입별)
      switch item {
      case .schedule(let schedule):
        if let minutes = schedule.trackingStartMinutesBefore {
          liveActivityRow(schedule: schedule, minutes: minutes)
        }
      case .personalEvent(let event):
        personalEventDetailRow(event)
      case .recurringPersonalEvent(let event):
        recurringEventDetailRow(event)
      }

    }
  }

  // MARK: - Type Badge

  @ViewBuilder
  private var typeBadge: some View {
    switch item {
    case .schedule(let schedule):
      if let group = schedule.group {
        HStack(spacing: 3) {
          GroupThumbnailView(
            imageUrl: group.imageUrl,
            name: group.name,
            size: 14
          )
          Text(group.name)
            .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(groupColor ?? Color.pmindigo.n500)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background((groupColor ?? Color.pmindigo.n500).opacity(0.1))
        .clipShape(Capsule())
      }
    case .personalEvent:
      HStack(spacing: 3) {
        Image(systemName: "person.fill")
          .font(.system(size: 9))
        Text(LocalizedStrings.Home.personalLabel)
          .font(.system(size: 11, weight: .medium))
      }
      .foregroundStyle(Color.pmindigo.n500)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Color.pmindigo.n500.opacity(0.1))
      .clipShape(Capsule())
    case .recurringPersonalEvent:
      HStack(spacing: 3) {
        Image(systemName: "arrow.trianglehead.2.counterclockwise.rotate.90")
          .font(.system(size: 9))
        Text(LocalizedStrings.Personal.filterRecurring)
          .font(.system(size: 11, weight: .medium))
      }
      .foregroundStyle(Color.pmindigo.n500)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(Color.pmindigo.n500.opacity(0.1))
      .clipShape(Capsule())
    }
  }

  // MARK: - Type-Specific Meta Rows

  private func scheduleMetaRow(_ schedule: ScheduleModel) -> some View {
    HStack(spacing: 6) {
      // 확정/미확정 배지
      HStack(spacing: 3) {
        Image(systemName: schedule.isConfirmed ? "checkmark.circle.fill" : "clock.badge")
          .font(.system(size: 10))
        Text(schedule.isConfirmed ? LocalizedStrings.Calendar.statusConfirmed : LocalizedStrings.Calendar.statusFailed)
          .font(.system(size: 11, weight: .semibold))
      }
      .foregroundStyle(schedule.isConfirmed ? Color.green : Color.orange)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background((schedule.isConfirmed ? Color.green : Color.orange).opacity(0.1))
      .clipShape(Capsule())

      Text(LocalizedStrings.Home.participantsConfirmed(schedule.votes.accepted.count))
        .font(.pmCaption)
        .foregroundStyle(.secondary)
    }
  }

  @ViewBuilder
  private func personalEventMetaRow(_ event: PersonalEventModel) -> some View {
    if let location = event.location {
      locationBadge(location)
    }
  }

  @ViewBuilder
  private func recurringEventMetaRow(_ event: ExpandedEventInstance) -> some View {
    if let location = event.location {
      locationBadge(location)
    }
  }

  // MARK: - Location Helpers

  private func locationRow(_ location: LocationInfoModel) -> some View {
    HStack(spacing: 4) {
      ResourceKitAsset.locationIcon.swiftUIImage
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 14, height: 14)

      Text(location.name)
        .font(.pmCaption)
        .lineLimit(1)
    }
    .foregroundStyle(.secondary)
  }

  private func locationBadge(_ location: LocationInfoModel) -> some View {
    HStack(spacing: 3) {
      ResourceKitAsset.locationIcon.swiftUIImage
        .renderingMode(.template)
        .resizable()
        .scaledToFit()
        .frame(width: 12, height: 12)

      Text(location.name)
        .font(.pmCaption)
        .lineLimit(1)
    }
    .foregroundStyle(.secondary)
  }

  // MARK: - Live Activity Row

  private func liveActivityRow(schedule: ScheduleModel, minutes: Int) -> some View {
    HStack(spacing: 4) {
      Image(systemName: "antenna.radiowaves.left.and.right")
        .font(.pmCaption2)

      Text(liveStartTimeString(schedule: schedule, minutes: minutes))
        .font(.pmCaption)

      Button {
        showLiveActivityInfo = true
      } label: {
        Image(systemName: "info.circle")
          .font(.pmCaption2)
      }
      .popover(isPresented: $showLiveActivityInfo, arrowEdge: .top) {
        LiveActivityInfoPopover(
          emoji: schedule.displayEmoji,
          title: schedule.title,
          location: schedule.location?.name,
          scheduleTime: schedule.startAt
        )
      }
    }
    .foregroundStyle(.secondary)
  }

  // MARK: - Personal / Recurring Detail Rows

  @ViewBuilder
  private func personalEventDetailRow(_ event: PersonalEventModel) -> some View {
    if event.reminderMinutesBefore != nil || hasDescription(event) {
      HStack(spacing: 8) {
        if let minutes = event.reminderMinutesBefore {
          HStack(spacing: 3) {
            Image(systemName: "bell.fill")
              .font(.system(size: 10))

            Text(reminderText(minutes: minutes))
              .font(.pmCaption)
          }
          .foregroundStyle(.secondary)
        }

        if hasDescription(event) {
          Text(event.description ?? "")
            .font(.pmCaption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
        }
      }
    }
  }

  @ViewBuilder
  private func recurringEventDetailRow(_ event: ExpandedEventInstance) -> some View {
    if let minutes = event.reminderMinutesBefore {
      HStack(spacing: 3) {
        Image(systemName: "bell.fill")
          .font(.system(size: 10))

        Text(reminderText(minutes: minutes))
          .font(.pmCaption)
      }
      .foregroundStyle(.secondary)
    }
  }

  // MARK: - Pro Benefit Section (날씨 + 출발 알림 통합)

  @ViewBuilder
  private var proBenefitSection: some View {
    let hasWeather = weatherForecast != nil || weatherShouldShowSkeleton
    let hasDepartureAlert = departureAlert != nil
    let hasDepartureCTA = isPro && !hasDepartureAlert && location != nil && isFuture

    if hasWeather || hasDepartureAlert || hasDepartureCTA {
      VStack(alignment: .leading, spacing: 6) {
        ProBadge()

        // 날씨 (schedule만)
        if let forecast = weatherForecast {
          ProWeatherRow(
            forecast: forecast,
            rangeForecasts: weatherRangeForecasts,
            forecastSource: weatherForecastSource,
            referenceTimeText: item.startAt.formattedMonthDayTime
          )
        }

        // 출발 알림 (설정됨)
        if let departureAlert = departureAlert {
          departureAlertRow(departureAlert)
        }
        // 출발 알림 CTA
        else if hasDepartureCTA {
          Button {
            onDepartureAlertTap()
          } label: {
            HStack(spacing: 6) {
              Image(systemName: "figure.walk.departure")
                .font(.system(size: 12))
                .frame(width: 22, height: 22)
                .background(
                  Circle()
                    .fill(Color.pmindigo.n500.opacity(0.12))
                )

              Text(LocalizedStrings.Home.departurePrompt)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

              Spacer(minLength: 0)

              Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .frame(maxWidth: .infinity, alignment: .leading)
      .proGlassCard(cornerRadius: 12)
      .padding(.horizontal, 8)
      .padding(.bottom, 8)
    }
  }

  /// 출발 알림 행 (설정된 상태)
  private func departureAlertRow(_ alert: HomeModels.DepartureAlertInfo) -> some View {
    let isAlertPassed = alert.departureTime < Date()
    let accentColor = isAlertPassed ? Color.pmgray.n400 : Color.pmindigo.n500

    return HStack(spacing: 6) {
      Image(systemName: alert.selectedTransport.iconName)
        .font(.system(size: 12))
        .frame(width: 22, height: 22)
        .background(
          Circle()
            .fill(accentColor.opacity(0.12))
        )

      if isAlertPassed {
        Text(LocalizedStrings.Home.departureAlertDone(alert.departureTime.formattedTime))
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.secondary)
      } else {
        Text(LocalizedStrings.Home.departureAlertUpcoming(alert.departureTime.formattedTime))
          .font(.system(size: 13, weight: .semibold))
          .foregroundStyle(.primary)
      }

      Spacer(minLength: 0)

      if isAlertPassed {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 12))
          .foregroundStyle(Color.pmgray.n400)
      } else {
        Button {
          onDepartureAlertCancel()
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 12))
            .foregroundStyle(Color.pmgray.n400)
        }
        .buttonStyle(.plain)
      }
    }
    .opacity(isAlertPassed ? 0.7 : 1.0)
  }

  // MARK: - Weather Helpers

  private var weatherForecast: HourlyForecast? {
    guard case .schedule(let schedule) = item else { return nil }
    return weather?.forecast(for: schedule.startAt)
  }

  private var weatherRangeForecasts: [HourlyForecast] {
    guard case .schedule(let schedule) = item else { return [] }
    return weather?.forecasts(from: schedule.startAt, to: schedule.endAt) ?? []
  }

  private var weatherForecastSource: ForecastSource {
    guard case .schedule(let schedule) = item else { return .shortTerm }
    return weather?.forecastSource(for: schedule.startAt) ?? .shortTerm
  }

  private var weatherShouldShowSkeleton: Bool {
    guard case .schedule(let schedule) = item else { return false }
    return shouldShowWeatherSkeleton(schedule)
  }

  // MARK: - Time Label

  private var timeLabel: some View {
    VStack(alignment: .center, spacing: 2) {
      Text(item.startAt.formattedTime)
        .font(.pmSubheadlineSemibold)
        .foregroundStyle(isNow ? Color.pmindigo.n500 : .primary)

      if let endAt = item.endAt {
        VStack(alignment: .center, spacing: 0) {
          Text("~")
            .font(.pmCaption)
            .foregroundStyle(.secondary)
          Text(LocalizedDateFormatters.endTimeString(from: endAt))
            .font(.pmCaption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
      } else if isNow {
        Text(LocalizedStrings.Home.timelineNow)
          .font(.pmCaption2Semibold)
          .foregroundStyle(Color.pmindigo.n500)
      }
    }
  }

  // MARK: - Computed Properties

  private var startAt: Date { item.startAt }
  private var endAt: Date? { item.endAt }
  private var effectiveEndAt: Date { item.effectiveEndAt }
  private var location: LocationInfoModel? { item.location }

  /// 현재 진행 중인 일정인지
  private var isNow: Bool {
    let now = Date()
    return now >= startAt && now <= effectiveEndAt
  }

  /// 이미 종료된 일정인지
  var isPast: Bool {
    Date() > effectiveEndAt
  }

  /// 아직 시작 전인 일정인지
  var isFuture: Bool {
    Date() < startAt
  }

  /// dot 색상 (진행 중: 파랑, 종료: 회색, 대기: 연한 파랑)
  private var dotColor: Color {
    if isNow {
      return Color.pmindigo.n500
    } else if isPast {
      return Color.pmgray.n400
    } else {
      return Color.pmindigo.n300
    }
  }

  /// 날씨 조회가 진행 중인 경우 스켈레톤 노출
  private func shouldShowWeatherSkeleton(_ schedule: ScheduleModel) -> Bool {
    guard weather == nil else { return false }
    guard let location = schedule.location,
          location.latitude != nil,
          location.longitude != nil else { return false }

    let now = Date()
    let maxDate = now.addingTimeInterval(10 * 24 * 3600)
    return schedule.startAt >= now && schedule.startAt < maxDate
  }

  private var weatherLoadingPlaceholder: some View {
    HStack(spacing: 8) {
      Circle()
        .fill(Color.pmgray.n300.opacity(0.45))
        .frame(width: 16, height: 16)

      RoundedRectangle(cornerRadius: 4)
        .fill(Color.pmgray.n300.opacity(0.35))
        .frame(width: 52, height: 10)

      RoundedRectangle(cornerRadius: 4)
        .fill(Color.pmgray.n300.opacity(0.30))
        .frame(height: 10)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.pmgray.n100.opacity(0.55))
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.pmgray.n200.opacity(0.7), lineWidth: 1)
    )
    .shimmer()
  }

  /// 실시간 공유 시작 시간 문자열
  private func liveStartTimeString(schedule: ScheduleModel, minutes: Int) -> String {
    let liveStartTime = schedule.startAt.addingTimeInterval(-Double(minutes * 60))
    return "\(liveStartTime.formattedTime) \(LocalizedStrings.Home.startLiveSharing)"
  }

  /// 리마인더 시간 텍스트
  private func reminderText(minutes: Int) -> String {
    if minutes == 0 { return LocalizedStrings.Personal.reminderAtEvent }
    if minutes >= 10080 && minutes % (1440 * 7) == 0 {
      let weeks = minutes / (1440 * 7)
      return LocalizedStrings.Personal.reminderWeeks(weeks)
    }
    if minutes >= 1440 {
      let days = minutes / 1440
      return LocalizedStrings.Personal.reminderDays(days)
    }
    if minutes >= 60 {
      return LocalizedStrings.Personal.reminderHours(minutes / 60)
    }
    return LocalizedStrings.Personal.reminderMinutes(minutes)
  }

  private func hasDescription(_ event: PersonalEventModel) -> Bool {
    guard let description = event.description else { return false }
    return !description.isEmpty
  }
}

// MARK: - Preview

#Preview("일정") {
  VStack(spacing: 0) {
    TimelineItemView(
      item: .schedule(ScheduleModel.mock(
        id: "1",
        title: "점심 모임",
        startAt: Date().addingTimeInterval(1800)
      )),
      isFirst: true,
      isLast: false,
      weather: nil,
      groupColor: nil,
      departureAlert: nil,
      isPro: false,
      onTap: {},
      onDepartureAlertTap: {},
      onDepartureAlertCancel: {}
    )

    TimelineItemView(
      item: .schedule(ScheduleModel.mock(
        id: "2",
        title: "카페 미팅",
        startAt: Date().addingTimeInterval(7200)
      )),
      isFirst: false,
      isLast: true,
      weather: nil,
      groupColor: nil,
      departureAlert: nil,
      isPro: false,
      onTap: {},
      onDepartureAlertTap: {},
      onDepartureAlertCancel: {}
    )
  }
  .padding()
  .auroraBackground()
}

#Preview("개인 일정") {
  VStack(spacing: 0) {
    TimelineItemView(
      item: .personalEvent(PersonalEventModel.mock(
        id: "pe-1",
        title: "아침 운동",
        emoji: "🏃",
        description: "한강 러닝 5km",
        startAt: Date().addingTimeInterval(1800),
        endAt: Date().addingTimeInterval(5400),
        location: LocationInfoModel(name: "여의도 한강공원"),
        reminderMinutesBefore: 30
      )),
      isFirst: true,
      isLast: false,
      weather: nil,
      groupColor: nil,
      departureAlert: nil,
      isPro: false,
      onTap: {},
      onDepartureAlertTap: {},
      onDepartureAlertCancel: {}
    )

    TimelineItemView(
      item: .personalEvent(PersonalEventModel.mock(
        id: "pe-2",
        title: "카페에서 공부",
        emoji: "☕️",
        startAt: Date().addingTimeInterval(7200)
      )),
      isFirst: false,
      isLast: true,
      weather: nil,
      groupColor: nil,
      departureAlert: nil,
      isPro: false,
      onTap: {},
      onDepartureAlertTap: {},
      onDepartureAlertCancel: {}
    )
  }
  .padding()
  .auroraBackground()
}

#Preview("반복 일정") {
  VStack(spacing: 0) {
    TimelineItemView(
      item: .recurringPersonalEvent(ExpandedEventInstance(
        recurringEventId: "r-1",
        dateKey: "2026-03-11",
        startAt: Date().addingTimeInterval(3600),
        endAt: Date().addingTimeInterval(7200),
        title: "주간 팀 미팅",
        emoji: "📅",
        location: LocationInfoModel(name: "회의실 A"),
        reminderMinutesBefore: 15,
        isOverridden: false
      )),
      isFirst: true,
      isLast: true,
      weather: nil,
      groupColor: nil,
      departureAlert: nil,
      isPro: false,
      onTap: {},
      onDepartureAlertTap: {},
      onDepartureAlertCancel: {}
    )
  }
  .padding()
  .auroraBackground()
}

#Preview("과거 일정") {
  VStack(spacing: 0) {
    TimelineItemView(
      item: .personalEvent(PersonalEventModel.mock(
        id: "pe-past",
        title: "아침 운동",
        emoji: "🏃",
        startAt: Date().addingTimeInterval(-7200),
        endAt: Date().addingTimeInterval(-3600),
        location: LocationInfoModel(name: "여의도 한강공원")
      )),
      isFirst: true,
      isLast: true,
      weather: nil,
      groupColor: nil,
      departureAlert: nil,
      isPro: false,
      onTap: {},
      onDepartureAlertTap: {},
      onDepartureAlertCancel: {}
    )
  }
  .padding()
  .auroraBackground()
}
