import PromisoShared
import SwiftUI

// MARK: - Departure Alert Sheet

/// 출발 알림 설정 시트
/// 교통수단별 소요시간과 예상 출발시간을 보여주고 알림을 설정
struct DepartureAlertSheet: View {
  let promiseEmoji: String
  let promiseTitle: String
  let promiseStartAt: Date
  let promiseLocation: String?
  let departureLocation: String?
  let transportData: HomeModels.DepartureTransportData?
  let loadError: String?
  let onSelect: (HomeModels.TransportSelection, Int) -> Void
  let onDetailTapped: () -> Void
  let onRetry: () -> Void
  let onDismiss: () -> Void

  @State private var selection: HomeModels.TransportSelection?
  @State private var bufferMinutes: Int = 10
  @State private var remainingTimeText: String = ""

  /// buffer 적용된 출발시간 계산
  private func adjustedTime(_ raw: Date) -> Date {
    raw.addingTimeInterval(-Double(bufferMinutes * 60))
  }

  /// 선택된 교통수단 설명 텍스트
  private var selectionDescription: String? {
    guard let sel = selection, let data = transportData else { return nil }

    let transportName: String
    let departureTime: Date?

    switch sel {
    case .driving:
      transportName = "자동차"
      departureTime = data.driving?.departureTime
    case .transit(let index):
      transportName = "대중교통"
      departureTime = data.transitRoutes.first(where: { $0.id == index })?.departureTime
    case .walking:
      transportName = "도보"
      departureTime = data.walking.departureTime
    }

    guard let dep = departureTime else { return nil }
    let adjusted = adjustedTime(dep)

    if bufferMinutes > 0 {
      return "\(transportName)으로 \(adjusted.formattedTime) — \(bufferMinutes)분 여유 포함해 알림을 드려요"
    } else {
      return "\(transportName)으로 \(adjusted.formattedTime)에 출발 알림을 드려요"
    }
  }

  /// 도보 10km 이상 비추천 여부
  private func isWalkingNotRecommended(_ walking: HomeModels.TransportOption) -> Bool {
    (walking.distanceMeters ?? 0) >= 10_000
  }

  /// 표시 순서에 따른 첫 번째 선택 가능한 교통수단
  private func defaultSelection(for data: HomeModels.DepartureTransportData) -> HomeModels.TransportSelection? {
    let now = Date()

    // 표시 순서에 맞춰 후보 생성
    var candidates: [HomeModels.TransportSelection] = []

    if data.preferredTransport == .transit {
      // 대중교통 먼저
      for route in data.transitRoutes {
        candidates.append(.transit(index: route.id))
      }
      if data.driving != nil { candidates.append(.driving) }
    } else {
      // 자동차 먼저
      if data.driving != nil { candidates.append(.driving) }
      for route in data.transitRoutes {
        candidates.append(.transit(index: route.id))
      }
    }

    // 도보 (비추천 아닌 경우만)
    if !isWalkingNotRecommended(data.walking) {
      candidates.append(.walking)
    }

    // 첫 번째 선택 가능한 (시간이 지나지 않은) 후보 반환
    for candidate in candidates {
      let departureTime: Date?
      switch candidate {
      case .driving:
        departureTime = data.driving?.departureTime
      case .transit(let index):
        departureTime = data.transitRoutes.first(where: { $0.id == index })?.departureTime
      case .walking:
        departureTime = data.walking.departureTime
      }
      if let dep = departureTime, adjustedTime(dep) >= now {
        return candidate
      }
    }
    return nil
  }

  var body: some View {
    VStack(spacing: 0) {
      // 드래그 인디케이터
      Capsule()
        .fill(Color.pmgray.n300)
        .frame(width: 36, height: 4)
        .padding(.top, 12)
        .padding(.bottom, 20)

      ZStack(alignment: .bottom) {
        ScrollView {
          VStack(spacing: 16) {
            headerSection
            contentSection
            bufferSelector
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 100)
        }

        // 하단 고정 영역 (버튼만)
        VStack(spacing: 0) {
          LinearGradient(
            colors: [Color.clear, Color(.systemBackground).opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(height: 20)

          VStack(spacing: 8) {
            confirmButton

            // 선택된 수단 설명
            if let description = selectionDescription {
              Text(description)
                .font(.system(size: 11))
                .foregroundStyle(Color.pmtext.secondary)
                .multilineTextAlignment(.center)
            }
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 32)
          .padding(.top, 4)
          .background(Color(.systemBackground).opacity(0.9))
        }
      }
    }
    .auroraBackground()
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.hidden)
    .presentationCornerRadius(24)
    .onAppear {
      remainingTimeText = computeRemainingTimeText()
      if let data = transportData {
        selection = defaultSelection(for: data)
      }
    }
    .onChange(of: transportData) { _, newData in
      if let data = newData, selection == nil {
        selection = defaultSelection(for: data)
      }
    }
  }

  // MARK: - Remaining Time

  private func computeRemainingTimeText() -> String {
    let diff = promiseStartAt.timeIntervalSince(Date())
    if diff <= 0 {
      return "약속 시간이 지났어요"
    }
    let totalMinutes = Int(diff / 60)
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours >= 1 {
      if minutes == 0 {
        return "약속까지 \(hours)시간 남았어요"
      } else {
        return "약속까지 \(hours)시간 \(minutes)분 남았어요"
      }
    } else {
      return "약속까지 \(minutes)분 남았어요"
    }
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 타이틀: 이모지 + 약속명
      Text("\(promiseEmoji) \(promiseTitle)")
        .font(.pmTitle3)
        .foregroundStyle(Color.pmtext.primary)
        .lineLimit(1)

      // 서브타이틀: 동적 카운트다운
      Text(remainingTimeText)
        .font(.pmFootnote)
        .foregroundStyle(Color.pmtext.secondary)

      // 경로 정보 카드 (탭 가능)
      routeInfoCard
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var routeInfoCard: some View {
    Button {
      onDetailTapped()
    } label: {
      VStack(alignment: .leading, spacing: 0) {
        HStack(spacing: 12) {
          // 출발 → 도착 점선 연결
          VStack(spacing: 3) {
            Circle()
              .fill(Color.pmindigo.n400)
              .frame(width: 8, height: 8)
            ForEach(0..<3, id: \.self) { _ in
              Circle()
                .fill(Color.pmgray.n300)
                .frame(width: 3, height: 3)
            }
            Circle()
              .fill(Color.pmerror.n500)
              .frame(width: 8, height: 8)
          }
          .padding(.vertical, 2)

          // 출발지 / 도착지 텍스트
          VStack(alignment: .leading, spacing: 10) {
            // 출발지
            VStack(alignment: .leading, spacing: 1) {
              Text("출발")
                .font(.pmMicroMedium)
                .foregroundStyle(Color.pmindigo.n400)
              Text(departureLocation ?? "현재 위치")
                .font(.pmCaptionSemibold)
                .foregroundStyle(Color.pmtext.primary)
            }

            // 도착지
            VStack(alignment: .leading, spacing: 1) {
              Text("도착")
                .font(.pmMicroMedium)
                .foregroundStyle(Color.pmerror.n500)
              HStack(spacing: 4) {
                Text(promiseEmoji)
                  .font(.system(size: 12))
                Text(promiseTitle)
                  .font(.pmCaptionSemibold)
                  .foregroundStyle(Color.pmtext.primary)
                  .lineLimit(1)
              }
              if let location = promiseLocation {
                Text(location)
                  .font(.pmMicro)
                  .foregroundStyle(Color.pmtext.secondary)
              }
            }
          }

          Spacer(minLength: 8)

          // 약속시간 뱃지
          Group {
            if LocalizedDateFormatters.use24HourFormat {
              Text(promiseStartAt.formattedTime)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Color.pmindigo.n500)
            } else {
              VStack(spacing: 0) {
                Text(LocalizedDateFormatters.amPm.string(from: promiseStartAt))
                  .font(.pmCaption2)
                  .foregroundStyle(Color.pmindigo.n400)
                Text(LocalizedDateFormatters.time12Hour.string(from: promiseStartAt))
                  .font(.system(size: 22, weight: .bold, design: .rounded))
                  .foregroundStyle(Color.pmindigo.n500)
              }
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(
            RoundedRectangle(cornerRadius: 12)
              .fill(Color.pmindigo.n500.opacity(0.08))
          )
        }

        // 카드 우하단 "상세 >" 텍스트
        HStack {
          Spacer()
          HStack(spacing: 2) {
            Text("상세")
              .font(.pmCaption)
              .foregroundStyle(Color.pmindigo.n500)
            Image(systemName: "chevron.right")
              .font(.system(size: 10, weight: .semibold))
              .foregroundStyle(Color.pmindigo.n500)
          }
        }
        .padding(.top, 8)
      }
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color(.systemBackground).opacity(0.6))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .strokeBorder(Color.pmgray.n200.opacity(0.3), lineWidth: 1)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Content Section

  @ViewBuilder
  private var contentSection: some View {
    if let error = loadError {
      errorView(message: error)
    } else if let data = transportData {
      transportList(data: data)
    } else {
      loadingView
    }
  }

  // MARK: - Transport List

  private func transportList(data: HomeModels.DepartureTransportData) -> some View {
    VStack(spacing: 10) {
      // 이동 수단 섹션 라벨
      HStack {
        Text("이동 수단")
          .font(.pmCaptionSemibold)
          .foregroundStyle(Color.pmtext.secondary)
        Spacer()
      }
      .padding(.horizontal, 4)

      if data.preferredTransport == .transit {
        // 대중교통 먼저
        transitSection(data: data)
        drivingSection(data: data)
      } else {
        // 자동차 먼저 (기본)
        drivingSection(data: data)
        transitSection(data: data)
      }
      // 도보는 항상 마지막
      walkingSection(data: data)
    }
  }

  @ViewBuilder
  private func drivingSection(data: HomeModels.DepartureTransportData) -> some View {
    if let driving = data.driving {
      let drivingTime = adjustedTime(driving.departureTime)
      let isPast = drivingTime < Date()
      let isSelected = selection == .driving
      let distanceText: String? = {
        guard let meters = driving.distanceMeters, meters > 0 else { return nil }
        let km = Double(meters) / 1000.0
        return String(format: "약 %.0fkm", km)
      }()
      let detail = ["약 \(driving.durationMinutes)분", distanceText]
        .compactMap { $0 }
        .joined(separator: " · ")

      Button {
        if !isPast { selection = .driving }
      } label: {
        transportCard(
          iconName: HomeModels.TransportType.driving.iconName,
          label: HomeModels.TransportType.driving.displayName,
          detail: detail,
          departureTime: drivingTime,
          isPast: isPast,
          isSelected: isSelected,
          isNotRecommended: false
        )
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(isPast)
    }
  }

  @ViewBuilder
  private func transitSection(data: HomeModels.DepartureTransportData) -> some View {
    if !data.transitRoutes.isEmpty {
      // 대중교통 경로별 카드
      ForEach(data.transitRoutes) { route in
        transitRouteRow(route: route, index: route.id)
      }
    }
  }

  @ViewBuilder
  private func walkingSection(data: HomeModels.DepartureTransportData) -> some View {
    let walking = data.walking
    let walkingNotRecommended = isWalkingNotRecommended(walking)
    let walkingTime = adjustedTime(walking.departureTime)
    let walkingDistanceText: String? = {
      guard let meters = walking.distanceMeters, meters > 0 else { return nil }
      let km = Double(meters) / 1000.0
      return String(format: "%.1fkm", km)
    }()

    if walkingNotRecommended {
      walkingNotRecommendedRow(walking: walking, distanceText: walkingDistanceText)
    } else {
      let isPast = walkingTime < Date()
      let isSelected = selection == .walking

      Button {
        if !isPast { selection = .walking }
      } label: {
        transportCard(
          iconName: HomeModels.TransportType.walking.iconName,
          label: HomeModels.TransportType.walking.displayName,
          detail: "약 \(walking.durationMinutes)분",
          departureTime: walkingTime,
          isPast: isPast,
          isSelected: isSelected,
          isNotRecommended: false
        )
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(isPast)
    }
  }

  // MARK: - Transport Card

  private func transportCard(
    iconName: String,
    label: String,
    detail: String,
    departureTime: Date,
    isPast: Bool,
    isSelected: Bool,
    isNotRecommended: Bool
  ) -> some View {
    let disabled = isPast || isNotRecommended
    return HStack(spacing: 12) {
      // 아이콘
      Image(systemName: iconName)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(isSelected ? Color.white : (disabled ? Color.pmgray.n400 : Color.pmindigo.n500))
        .frame(width: 32, height: 32)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.pmindigo.n500 : Color.pmindigo.n500.opacity(0.08))
        )

      // 라벨 + 상세
      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .font(.pmCaptionSemibold)
          .foregroundStyle(disabled ? Color.pmtext.secondary : Color.pmtext.primary)

        if isNotRecommended {
          Text(detail)
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
        } else if isPast {
          Text("출발 시간이 지났어요")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
        } else {
          Text(detail)
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
        }
      }

      Spacer(minLength: 0)

      if isNotRecommended {
        Text("비추천")
          .font(.system(size: 11, weight: .medium))
          .foregroundStyle(Color.pmgray.n500)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(Capsule().fill(Color.pmgray.n200))
      } else if !isPast {
        Text(departureTime.formattedTime)
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(isSelected ? Color.white : Color.pmindigo.n500)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(isSelected ? Color.pmindigo.n500 : Color.pmindigo.n500.opacity(0.1))
          )
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(isSelected ? Color.pmindigo.n500.opacity(0.1) : Color(.systemBackground).opacity(0.5))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(
          isSelected ? Color.pmindigo.n500.opacity(0.5) : Color.pmgray.n200.opacity(0.3),
          lineWidth: isSelected ? 2 : 1
        )
    )
    .opacity(disabled ? 0.5 : 1.0)
  }

  // MARK: - Transit Route Row

  private func transitRouteRow(route: HomeModels.TransitRouteOption, index: Int) -> some View {
    let sel = HomeModels.TransportSelection.transit(index: index)
    let isSelected = selection == sel
    let adjustedDep = adjustedTime(route.departureTime)
    let isPast = adjustedDep < Date()

    return Button {
      if !isPast { selection = sel }
    } label: {
      transitRouteContent(route: route, adjustedDepartureTime: adjustedDep, isSelected: isSelected, isPast: isPast)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isPast)
  }

  private func transitRouteContent(
    route: HomeModels.TransitRouteOption,
    adjustedDepartureTime: Date,
    isSelected: Bool,
    isPast: Bool
  ) -> some View {
    HStack(spacing: 12) {
      // 아이콘
      Image(systemName: HomeModels.TransportType.transit.iconName)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(isSelected ? Color.white : (isPast ? Color.pmgray.n400 : Color.pmindigo.n500))
        .frame(width: 32, height: 32)
        .background(
          RoundedRectangle(cornerRadius: 8)
            .fill(isSelected ? Color.pmindigo.n500 : Color.pmindigo.n500.opacity(0.08))
        )

      VStack(alignment: .leading, spacing: 3) {
        // 대중교통 라벨 + 태그 뱃지
        HStack(spacing: 4) {
          Text("대중교통")
            .font(.pmCaptionSemibold)
            .foregroundStyle(isPast ? Color.pmtext.secondary : Color.pmtext.primary)
          ForEach(route.tags, id: \.self) { tag in
            Text(tag.displayName)
              .font(.system(size: 9, weight: .semibold))
              .foregroundStyle(isSelected ? Color.pmindigo.n600 : Color.pmindigo.n500)
              .padding(.horizontal, 5)
              .padding(.vertical, 1.5)
              .background(
                Capsule().fill(Color.pmindigo.n500.opacity(isSelected ? 0.2 : 0.1))
              )
          }
        }

        if isPast {
          Text("출발 시간이 지났어요")
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)
        } else {
          HStack(spacing: 4) {
            Text("약 \(route.totalTime)분")
              .font(.system(size: 11))
              .foregroundStyle(Color.pmtext.secondary)

            if route.payment > 0 {
              Text("·")
                .font(.system(size: 11))
                .foregroundStyle(Color.pmtext.secondary)
              Text("\(route.payment.formatted())원")
                .font(.system(size: 11))
                .foregroundStyle(Color.pmtext.secondary)
            }

            if route.transitCount > 0 {
              Text("·")
                .font(.system(size: 11))
                .foregroundStyle(Color.pmtext.secondary)
              Text("환승 \(route.transitCount)")
                .font(.system(size: 11))
                .foregroundStyle(Color.pmtext.secondary)
            }
          }
        }
      }

      Spacer(minLength: 0)

      if !isPast {
        Text(adjustedDepartureTime.formattedTime)
          .font(.system(size: 15, weight: .bold, design: .rounded))
          .foregroundStyle(isSelected ? Color.white : Color.pmindigo.n500)
          .padding(.horizontal, 10)
          .padding(.vertical, 6)
          .background(
            RoundedRectangle(cornerRadius: 8)
              .fill(isSelected ? Color.pmindigo.n500 : Color.pmindigo.n500.opacity(0.1))
          )
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(isSelected ? Color.pmindigo.n500.opacity(0.1) : Color(.systemBackground).opacity(0.5))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(
          isSelected ? Color.pmindigo.n500.opacity(0.5) : Color.pmgray.n200.opacity(0.3),
          lineWidth: isSelected ? 2 : 1
        )
    )
    .opacity(isPast ? 0.5 : 1.0)
  }

  // MARK: - Confirm Button

  private var confirmButton: some View {
    Button {
      if let sel = selection {
        onSelect(sel, bufferMinutes)
        onDismiss()
      }
    } label: {
      Text("알림 받기")
        .font(.pmBodySemibold)
        .foregroundStyle(selection != nil ? Color.white : Color.pmtext.secondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
          RoundedRectangle(cornerRadius: 14)
            .fill(selection != nil ? Color.pmindigo.n500 : Color.pmgray.n200)
        )
    }
    .buttonStyle(.plain)
    .disabled(selection == nil)
    .animation(.easeInOut(duration: 0.2), value: selection)
  }

  // MARK: - Buffer Selector

  private static let bufferOptions = [0, 5, 10, 15, 20, 30]

  private var bufferSelector: some View {
    HStack {
      Text("여유 시간")
        .font(.pmCaptionSemibold)
        .foregroundStyle(Color.pmtext.secondary)

      Spacer()

      Menu {
        ForEach(Self.bufferOptions, id: \.self) { minutes in
          Button {
            bufferMinutes = minutes
          } label: {
            if bufferMinutes == minutes {
              Label(
                minutes == 0 ? "없음" : "\(minutes)분",
                systemImage: "checkmark"
              )
            } else {
              Text(minutes == 0 ? "없음" : "\(minutes)분")
            }
          }
        }
      } label: {
        HStack(spacing: 4) {
          Text(bufferMinutes == 0 ? "없음" : "\(bufferMinutes)분")
            .font(.pmCaptionSemibold)
            .foregroundStyle(Color.pmindigo.n500)
          Image(systemName: "chevron.up.chevron.down")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.pmindigo.n500)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .fill(Color.pmindigo.n500.opacity(0.08))
        )
      }
    }
    .padding(.horizontal, 4)
  }

  // MARK: - Walking Not Recommended Row

  private func walkingNotRecommendedRow(
    walking: HomeModels.TransportOption,
    distanceText: String?
  ) -> some View {
    let detailParts = ["약 \(walking.durationMinutes)분", distanceText]
      .compactMap { $0 }
      .joined(separator: " · ")
    return transportCard(
      iconName: HomeModels.TransportType.walking.iconName,
      label: HomeModels.TransportType.walking.displayName,
      detail: detailParts,
      departureTime: walking.departureTime,
      isPast: true,
      isSelected: false,
      isNotRecommended: true
    )
  }

  // MARK: - Loading Skeleton

  private var loadingView: some View {
    VStack(spacing: 10) {
      // 이동 수단 라벨 스켈레톤
      HStack {
        skeletonRect(width: 60, height: 14)
        Spacer()
      }
      .padding(.horizontal, 4)

      // 카드 스켈레톤 3개
      ForEach(0..<3, id: \.self) { _ in
        skeletonCard
      }
    }
  }

  private var skeletonCard: some View {
    HStack(spacing: 12) {
      skeletonRect(width: 32, height: 32, cornerRadius: 8)

      VStack(alignment: .leading, spacing: 4) {
        skeletonRect(width: 50, height: 13)
        skeletonRect(width: 80, height: 11)
      }

      Spacer(minLength: 0)

      skeletonRect(width: 60, height: 30, cornerRadius: 8)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(Color(.systemBackground).opacity(0.5))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 14)
        .strokeBorder(Color.pmgray.n200.opacity(0.3), lineWidth: 1)
    )
  }

  private func skeletonRect(
    width: CGFloat,
    height: CGFloat,
    cornerRadius: CGFloat = 4
  ) -> some View {
    RoundedRectangle(cornerRadius: cornerRadius)
      .fill(Color.pmgray.n200.opacity(0.5))
      .frame(width: width, height: height)
      .shimmer()
  }

  // MARK: - Error View

  private func errorView(message: String) -> some View {
    VStack(spacing: 16) {
      VStack(spacing: 8) {
        Image(systemName: "exclamationmark.triangle")
          .font(.system(size: 28))
          .foregroundStyle(Color.pmgray.n400)

        Text(message)
          .font(.pmCaption)
          .foregroundStyle(Color.pmtext.secondary)
          .multilineTextAlignment(.center)
      }

      Button {
        onRetry()
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 12, weight: .medium))
          Text("다시 시도")
            .font(.pmCaptionSemibold)
        }
        .foregroundStyle(Color.pmindigo.n500)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
          Capsule()
            .fill(Color.pmindigo.n500.opacity(0.1))
        )
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }
}

// MARK: - Preview

#Preview("로드 완료") {
  let now = Date()
  let startAt = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now

  Color.clear
    .sheet(isPresented: .constant(true)) {
      DepartureAlertSheet(
        promiseEmoji: "🍕",
        promiseTitle: "점심 모임",
        promiseStartAt: startAt,
        promiseLocation: "강남역 2번 출구",
        departureLocation: "서울 강남구",
        transportData: HomeModels.DepartureTransportData(
          driving: HomeModels.TransportOption(
            type: .driving,
            durationMinutes: 25,
            departureTime: Calendar.current.date(bySettingHour: 13, minute: 25, second: 0, of: now) ?? now,
            additionalInfo: nil
          ),
          transitRoutes: [
            HomeModels.TransitRouteOption(
              id: 0,
              totalTime: 40,
              payment: 1250,
              busTransitCount: 0,
              subwayTransitCount: 1,
              pathType: 1,
              departureTime: Calendar.current.date(bySettingHour: 13, minute: 10, second: 0, of: now) ?? now,
              subPaths: []
            ),
            HomeModels.TransitRouteOption(
              id: 1,
              totalTime: 45,
              payment: 1250,
              busTransitCount: 1,
              subwayTransitCount: 0,
              pathType: 2,
              departureTime: Calendar.current.date(bySettingHour: 13, minute: 5, second: 0, of: now) ?? now,
              subPaths: []
            ),
          ],
          walking: HomeModels.TransportOption(
            type: .walking,
            durationMinutes: 55,
            departureTime: Calendar.current.date(bySettingHour: 12, minute: 55, second: 0, of: now) ?? now,
            additionalInfo: nil,
            distanceMeters: 4000
          )
        ),
        loadError: nil,
        onSelect: { _, _ in },
        onDetailTapped: {},
        onRetry: {},
        onDismiss: {}
      )
    }
}

#Preview("도보 비추천") {
  let now = Date()
  let startAt = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now

  Color.clear
    .sheet(isPresented: .constant(true)) {
      DepartureAlertSheet(
        promiseEmoji: "🏢",
        promiseTitle: "부산 출장",
        promiseStartAt: startAt,
        promiseLocation: "부산역",
        departureLocation: "서울 서초구",
        transportData: HomeModels.DepartureTransportData(
          driving: HomeModels.TransportOption(
            type: .driving,
            durationMinutes: 40,
            departureTime: Calendar.current.date(bySettingHour: 13, minute: 10, second: 0, of: now) ?? now
          ),
          transitRoutes: [],
          walking: HomeModels.TransportOption(
            type: .walking,
            durationMinutes: 170,
            departureTime: Calendar.current.date(bySettingHour: 11, minute: 10, second: 0, of: now) ?? now,
            distanceMeters: 12300
          )
        ),
        loadError: nil,
        onSelect: { _, _ in },
        onDetailTapped: {},
        onRetry: {},
        onDismiss: {}
      )
    }
}

#Preview("로딩 중") {
  Color.clear
    .sheet(isPresented: .constant(true)) {
      DepartureAlertSheet(
        promiseEmoji: "☕",
        promiseTitle: "카페 미팅",
        promiseStartAt: Date().addingTimeInterval(3600),
        promiseLocation: nil,
        departureLocation: nil,
        transportData: nil,
        loadError: nil,
        onSelect: { _, _ in },
        onDetailTapped: {},
        onRetry: {},
        onDismiss: {}
      )
    }
}

#Preview("에러") {
  Color.clear
    .sheet(isPresented: .constant(true)) {
      DepartureAlertSheet(
        promiseEmoji: "🎉",
        promiseTitle: "생일 파티",
        promiseStartAt: Date().addingTimeInterval(7200),
        promiseLocation: "홍대입구역",
        departureLocation: "서울 마포구",
        transportData: nil,
        loadError: "경로를 불러오지 못했어요",
        onSelect: { _, _ in },
        onDetailTapped: {},
        onRetry: {},
        onDismiss: {}
      )
    }
}

#Preview("대중교통만") {
  let now = Date()
  let startAt = now.addingTimeInterval(5400) // 1.5시간 뒤

  Color.clear
    .sheet(isPresented: .constant(true)) {
      DepartureAlertSheet(
        promiseEmoji: "📚",
        promiseTitle: "스터디 모임",
        promiseStartAt: startAt,
        promiseLocation: "합정역 3번 출구",
        departureLocation: "서울 종로구",
        transportData: HomeModels.DepartureTransportData(
          driving: nil,
          transitRoutes: [
            HomeModels.TransitRouteOption(
              id: 0,
              totalTime: 35,
              payment: 1250,
              busTransitCount: 0,
              subwayTransitCount: 1,
              pathType: 1,
              departureTime: startAt.addingTimeInterval(-35 * 60),
              subPaths: [],
              tags: [.fastest, .cheapest]
            ),
            HomeModels.TransitRouteOption(
              id: 1,
              totalTime: 42,
              payment: 1250,
              busTransitCount: 1,
              subwayTransitCount: 0,
              pathType: 2,
              departureTime: startAt.addingTimeInterval(-42 * 60),
              subPaths: [],
              tags: [.leastTransfers]
            ),
          ],
          walking: HomeModels.TransportOption(
            type: .walking,
            durationMinutes: 90,
            departureTime: startAt.addingTimeInterval(-90 * 60),
            distanceMeters: 6500
          )
        ),
        loadError: nil,
        onSelect: { _, _ in },
        onDetailTapped: {},
        onRetry: {},
        onDismiss: {}
      )
    }
}

#Preview("자동차만") {
  let now = Date()
  let startAt = now.addingTimeInterval(7200) // 2시간 뒤

  Color.clear
    .sheet(isPresented: .constant(true)) {
      DepartureAlertSheet(
        promiseEmoji: "⛳",
        promiseTitle: "골프 라운딩",
        promiseStartAt: startAt,
        promiseLocation: "용인 골프장",
        departureLocation: "서울 강남구",
        transportData: HomeModels.DepartureTransportData(
          driving: HomeModels.TransportOption(
            type: .driving,
            durationMinutes: 55,
            departureTime: startAt.addingTimeInterval(-55 * 60),
            distanceMeters: 48000
          ),
          transitRoutes: [],
          walking: HomeModels.TransportOption(
            type: .walking,
            durationMinutes: 300,
            departureTime: startAt.addingTimeInterval(-300 * 60),
            distanceMeters: 22000
          )
        ),
        loadError: nil,
        onSelect: { _, _ in },
        onDetailTapped: {},
        onRetry: {},
        onDismiss: {}
      )
    }
}

#Preview("단일 대중교통 경로") {
  let now = Date()
  let startAt = now.addingTimeInterval(3600)

  Color.clear
    .sheet(isPresented: .constant(true)) {
      DepartureAlertSheet(
        promiseEmoji: "🎬",
        promiseTitle: "영화 관람",
        promiseStartAt: startAt,
        promiseLocation: "CGV 용산아이파크몰",
        departureLocation: "서울 용산구",
        transportData: HomeModels.DepartureTransportData(
          driving: HomeModels.TransportOption(
            type: .driving,
            durationMinutes: 10,
            departureTime: startAt.addingTimeInterval(-10 * 60),
            distanceMeters: 3200
          ),
          transitRoutes: [
            HomeModels.TransitRouteOption(
              id: 0,
              totalTime: 15,
              payment: 1250,
              busTransitCount: 0,
              subwayTransitCount: 0,
              pathType: 1,
              departureTime: startAt.addingTimeInterval(-15 * 60),
              subPaths: [],
              tags: [.fastest, .leastTransfers, .cheapest]
            ),
          ],
          walking: HomeModels.TransportOption(
            type: .walking,
            durationMinutes: 25,
            departureTime: startAt.addingTimeInterval(-25 * 60),
            distanceMeters: 1800
          )
        ),
        loadError: nil,
        onSelect: { _, _ in },
        onDetailTapped: {},
        onRetry: {},
        onDismiss: {}
      )
    }
}

#Preview("도보 가능 근거리") {
  let now = Date()
  let startAt = now.addingTimeInterval(2400) // 40분 뒤

  Color.clear
    .sheet(isPresented: .constant(true)) {
      DepartureAlertSheet(
        promiseEmoji: "☕",
        promiseTitle: "커피챗",
        promiseStartAt: startAt,
        promiseLocation: "스타벅스 성수역점",
        departureLocation: "서울 성동구",
        transportData: HomeModels.DepartureTransportData(
          driving: HomeModels.TransportOption(
            type: .driving,
            durationMinutes: 5,
            departureTime: startAt.addingTimeInterval(-5 * 60),
            distanceMeters: 800
          ),
          transitRoutes: [
            HomeModels.TransitRouteOption(
              id: 0,
              totalTime: 10,
              payment: 1250,
              busTransitCount: 0,
              subwayTransitCount: 0,
              pathType: 1,
              departureTime: startAt.addingTimeInterval(-10 * 60),
              subPaths: [],
              tags: [.fastest]
            ),
          ],
          walking: HomeModels.TransportOption(
            type: .walking,
            durationMinutes: 12,
            departureTime: startAt.addingTimeInterval(-12 * 60),
            distanceMeters: 850
          )
        ),
        loadError: nil,
        onSelect: { _, _ in },
        onDetailTapped: {},
        onRetry: {},
        onDismiss: {}
      )
    }
}

#Preview("긴 장소명") {
  let now = Date()
  let startAt = now.addingTimeInterval(10800) // 3시간 뒤

  Color.clear
    .sheet(isPresented: .constant(true)) {
      DepartureAlertSheet(
        promiseEmoji: "🎂",
        promiseTitle: "민지 생일파티 + 동창회 겸 모임",
        promiseStartAt: startAt,
        promiseLocation: "서울특별시 송파구 올림픽로 300 롯데월드타워 31층 시그니엘 레스토랑",
        departureLocation: "경기 수원시 영통구",
        transportData: HomeModels.DepartureTransportData(
          driving: HomeModels.TransportOption(
            type: .driving,
            durationMinutes: 65,
            departureTime: startAt.addingTimeInterval(-65 * 60),
            distanceMeters: 42000
          ),
          transitRoutes: [
            HomeModels.TransitRouteOption(
              id: 0,
              totalTime: 80,
              payment: 2450,
              busTransitCount: 0,
              subwayTransitCount: 2,
              pathType: 1,
              departureTime: startAt.addingTimeInterval(-80 * 60),
              subPaths: [],
              tags: [.fastest]
            ),
            HomeModels.TransitRouteOption(
              id: 1,
              totalTime: 85,
              payment: 1850,
              busTransitCount: 1,
              subwayTransitCount: 0,
              pathType: 2,
              departureTime: startAt.addingTimeInterval(-85 * 60),
              subPaths: [],
              tags: [.cheapest]
            ),
            HomeModels.TransitRouteOption(
              id: 2,
              totalTime: 90,
              payment: 2050,
              busTransitCount: 0,
              subwayTransitCount: 1,
              pathType: 1,
              departureTime: startAt.addingTimeInterval(-90 * 60),
              subPaths: [],
              tags: [.leastTransfers]
            ),
          ],
          walking: HomeModels.TransportOption(
            type: .walking,
            durationMinutes: 480,
            departureTime: startAt.addingTimeInterval(-480 * 60),
            distanceMeters: 35000
          )
        ),
        loadError: nil,
        onSelect: { _, _ in },
        onDetailTapped: {},
        onRetry: {},
        onDismiss: {}
      )
    }
}

#Preview("출발지 없음") {
  let now = Date()
  let startAt = now.addingTimeInterval(3600)

  Color.clear
    .sheet(isPresented: .constant(true)) {
      DepartureAlertSheet(
        promiseEmoji: "🍻",
        promiseTitle: "회식",
        promiseStartAt: startAt,
        promiseLocation: "을지로 노가리 골목",
        departureLocation: nil,
        transportData: HomeModels.DepartureTransportData(
          driving: HomeModels.TransportOption(
            type: .driving,
            durationMinutes: 20,
            departureTime: startAt.addingTimeInterval(-20 * 60),
            distanceMeters: 8500
          ),
          transitRoutes: [
            HomeModels.TransitRouteOption(
              id: 0,
              totalTime: 30,
              payment: 1250,
              busTransitCount: 0,
              subwayTransitCount: 1,
              pathType: 1,
              departureTime: startAt.addingTimeInterval(-30 * 60),
              subPaths: [],
              tags: [.fastest, .leastTransfers]
            ),
          ],
          walking: HomeModels.TransportOption(
            type: .walking,
            durationMinutes: 45,
            departureTime: startAt.addingTimeInterval(-45 * 60),
            distanceMeters: 3200
          )
        ),
        loadError: nil,
        onSelect: { _, _ in },
        onDetailTapped: {},
        onRetry: {},
        onDismiss: {}
      )
    }
}

#Preview("목적지 없음") {
  let now = Date()
  let startAt = now.addingTimeInterval(5400)

  Color.clear
    .sheet(isPresented: .constant(true)) {
      DepartureAlertSheet(
        promiseEmoji: "📞",
        promiseTitle: "전화 미팅",
        promiseStartAt: startAt,
        promiseLocation: nil,
        departureLocation: "서울 강남구",
        transportData: nil,
        loadError: nil,
        onSelect: { _, _ in },
        onDetailTapped: {},
        onRetry: {},
        onDismiss: {}
      )
    }
}
