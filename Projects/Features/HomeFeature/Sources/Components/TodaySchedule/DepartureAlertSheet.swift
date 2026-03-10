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
  let onDismiss: () -> Void

  @State private var selection: HomeModels.TransportSelection?
  @State private var bufferMinutes: Int = 10

  /// buffer 적용된 출발시간 계산
  private func adjustedTime(_ raw: Date) -> Date {
    raw.addingTimeInterval(-Double(bufferMinutes * 60))
  }

  /// 도보 10km 이상 비추천 여부
  private func isWalkingNotRecommended(_ walking: HomeModels.TransportOption) -> Bool {
    (walking.distanceMeters ?? 0) >= 10_000
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
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 120)
        }

        // 하단 고정 영역
        VStack(spacing: 0) {
          // 여유 시간 (투명 배경)
          bufferSelector
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

          // 블러 그라데이션 (버튼 바로 위만)
          LinearGradient(
            colors: [Color.clear, Color(.systemBackground).opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(height: 16)

          // 알림 버튼
          confirmButton
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
    .onAppear { selection = nil }
  }

  // MARK: - Header Section

  private var headerSection: some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 8) {
        Text("출발 알림 설정")
          .font(.pmTitle2)
          .foregroundStyle(Color.pmtext.primary)

        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Text(promiseEmoji)
              .font(.pmBody)

            Text(promiseTitle)
              .font(.pmBodySemibold)
              .foregroundStyle(Color.pmtext.primary)
              .lineLimit(1)
          }

          // 출발지 → 도착지
          HStack(spacing: 4) {
            Image(systemName: "location.fill")
              .font(.system(size: 11))
              .foregroundStyle(Color.pmindigo.n400)
            if let departure = departureLocation {
              Text(departure)
                .font(.pmCaption)
                .foregroundStyle(Color.pmtext.secondary)
            } else {
              Text("현재 위치")
                .font(.pmCaption)
                .foregroundStyle(Color.pmtext.secondary)
            }

            Image(systemName: "arrow.right")
              .font(.system(size: 9, weight: .medium))
              .foregroundStyle(Color.pmgray.n400)

            Image(systemName: "mappin")
              .font(.system(size: 11))
              .foregroundStyle(Color.pmerror.n500)
            if let location = promiseLocation {
              Text(location)
                .font(.pmCaption)
                .foregroundStyle(Color.pmtext.secondary)
            }
          }

          // 시간
          HStack(spacing: 4) {
            Image(systemName: "clock")
              .font(.system(size: 11))
              .foregroundStyle(Color.pmtext.secondary)
            Text(promiseStartAt.formattedTime)
              .font(.pmCaption)
              .foregroundStyle(Color.pmtext.secondary)
          }
        }
      }

      Spacer(minLength: 8)

      // 상세 버튼
      Button {
        onDetailTapped()
      } label: {
        HStack(spacing: 2) {
          Text("상세")
            .font(.pmCaption)
            .foregroundStyle(Color.pmindigo.n500)
          Image(systemName: "chevron.right")
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color.pmindigo.n500)
        }
        .padding(.top, 4)
      }
      .buttonStyle(.plain)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
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

      // 섹션 헤더
      sectionHeader(
        iconName: HomeModels.TransportType.driving.iconName,
        label: HomeModels.TransportType.driving.displayName
      )

      // 카드 (아이콘/라벨 없이 정보만)
      transportRow(
        detail: "약 \(driving.durationMinutes)분",
        subDetail: "\(drivingTime.formattedTime) 출발",
        isPast: drivingTime < Date(),
        isSelected: selection == .driving
      ) {
        selection = .driving
      }
    }
  }

  @ViewBuilder
  private func transitSection(data: HomeModels.DepartureTransportData) -> some View {
    if !data.transitRoutes.isEmpty {
      sectionHeader(
        iconName: HomeModels.TransportType.transit.iconName,
        label: HomeModels.TransportType.transit.displayName
      )

      // 대중교통 경로별 로우
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

    // 섹션 헤더
    sectionHeader(
      iconName: HomeModels.TransportType.walking.iconName,
      label: HomeModels.TransportType.walking.displayName
    )

    if walkingNotRecommended {
      walkingNotRecommendedRow(walking: walking, distanceText: walkingDistanceText)
    } else {
      transportRow(
        detail: "약 \(walking.durationMinutes)분",
        subDetail: "\(walkingTime.formattedTime) 출발",
        isPast: walkingTime < Date(),
        isSelected: selection == .walking
      ) {
        selection = .walking
      }
    }
  }

  // MARK: - Section Header

  private func sectionHeader(iconName: String, label: String) -> some View {
    HStack(spacing: 6) {
      Image(systemName: iconName)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.pmtext.secondary)
      Text(label)
        .font(.pmCaptionSemibold)
        .foregroundStyle(Color.pmtext.secondary)
      Spacer()
    }
    .padding(.top, 4)
    .padding(.horizontal, 4)
  }

  // MARK: - Transport Row

  private func transportRow(
    detail: String,
    subDetail: String,
    isPast: Bool,
    isSelected: Bool,
    onTap: @escaping () -> Void
  ) -> some View {
    Button {
      if !isPast { onTap() }
    } label: {
      rowContent(
        detail: detail,
        subDetail: subDetail,
        isPast: isPast,
        isSelected: isSelected,
        isNotRecommended: false
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isPast)
  }

  @ViewBuilder
  private func rowContent(
    detail: String,
    subDetail: String,
    isPast: Bool,
    isSelected: Bool,
    isNotRecommended: Bool
  ) -> some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer {
        rowInner(
          detail: detail,
          subDetail: subDetail,
          isPast: isPast,
          isSelected: isSelected,
          isNotRecommended: isNotRecommended
        )
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
      }
    } else {
      rowInner(
        detail: detail,
        subDetail: subDetail,
        isPast: isPast,
        isSelected: isSelected,
        isNotRecommended: isNotRecommended
      )
      .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .strokeBorder(
            isSelected ? Color.pmindigo.n500.opacity(0.6) : Color.pmgray.n200.opacity(0.5),
            lineWidth: isSelected ? 1.5 : 1
          )
      )
    }
  }

  private func rowInner(
    detail: String,
    subDetail: String,
    isPast: Bool,
    isSelected: Bool,
    isNotRecommended: Bool
  ) -> some View {
    let disabled = isPast || isNotRecommended
    return HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        if isNotRecommended {
          Text(detail)
            .font(.pmCaption)
            .foregroundStyle(Color.pmtext.secondary)
        } else if isPast {
          Text("출발 시간이 지났어요")
            .font(.pmCaption)
            .foregroundStyle(Color.pmtext.secondary)
        } else {
          HStack(spacing: 4) {
            Text(detail)
              .font(.pmCaption)
              .foregroundStyle(Color.pmtext.secondary)
            Text("·")
              .font(.pmCaption)
              .foregroundStyle(Color.pmtext.secondary)
            Text(subDetail)
              .font(.pmCaptionSemibold)
              .foregroundStyle(Color.pmindigo.n500)
          }
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
        Image(systemName: isSelected ? "circle.inset.filled" : "circle")
          .font(.system(size: 20))
          .foregroundStyle(isSelected ? Color.pmindigo.n500 : Color.pmgray.n300)
          .accessibilityLabel(isSelected ? "선택됨" : "선택 안됨")
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .opacity(disabled ? 0.6 : 1.0)
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

  @ViewBuilder
  private func transitRouteContent(
    route: HomeModels.TransitRouteOption,
    adjustedDepartureTime: Date,
    isSelected: Bool,
    isPast: Bool
  ) -> some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer {
        transitRouteInner(route: route, adjustedDepartureTime: adjustedDepartureTime, isSelected: isSelected, isPast: isPast)
          .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
      }
    } else {
      transitRouteInner(route: route, adjustedDepartureTime: adjustedDepartureTime, isSelected: isSelected, isPast: isPast)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(
              isSelected ? Color.pmindigo.n500.opacity(0.6) : Color.pmgray.n200.opacity(0.5),
              lineWidth: isSelected ? 1.5 : 1
            )
        )
    }
  }

  private func transitRouteInner(
    route: HomeModels.TransitRouteOption,
    adjustedDepartureTime: Date,
    isSelected: Bool,
    isPast: Bool
  ) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        // 태그 뱃지
        HStack(spacing: 4) {
          ForEach(route.tags, id: \.self) { tag in
            Text(tag.displayName)
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(Color.pmindigo.n500)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(
                Capsule().fill(Color.pmindigo.n500.opacity(0.12))
              )
          }
        }

        if isPast {
          Text("출발 시간이 지났어요")
            .font(.pmCaption)
            .foregroundStyle(Color.pmtext.secondary)
        } else {
          // "40분 · 1,250원 · 환승1" 형태
          HStack(spacing: 4) {
            Text("약 \(route.totalTime)분")
              .font(.pmCaption)
              .foregroundStyle(Color.pmtext.secondary)

            if route.payment > 0 {
              Text("·")
                .font(.pmCaption)
                .foregroundStyle(Color.pmtext.secondary)
              Text("\(route.payment.formatted())원")
                .font(.pmCaption)
                .foregroundStyle(Color.pmtext.secondary)
            }

            if route.transitCount > 0 {
              Text("·")
                .font(.pmCaption)
                .foregroundStyle(Color.pmtext.secondary)
              Text("환승\(route.transitCount)")
                .font(.pmCaption)
                .foregroundStyle(Color.pmtext.secondary)
            }
          }

          Text("\(adjustedDepartureTime.formattedTime) 출발")
            .font(.pmCaptionSemibold)
            .foregroundStyle(Color.pmindigo.n500)
        }
      }

      Spacer(minLength: 0)

      if !isPast {
        Image(systemName: isSelected ? "circle.inset.filled" : "circle")
          .font(.system(size: 20))
          .foregroundStyle(isSelected ? Color.pmindigo.n500 : Color.pmgray.n300)
          .accessibilityLabel(isSelected ? "선택됨" : "선택 안됨")
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .opacity(isPast ? 0.6 : 1.0)
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

  private var bufferSelector: some View {
    VStack(spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: "clock")
          .font(.pmCaption)
          .foregroundStyle(Color.pmtext.secondary)
        Text("여유 시간")
          .font(.pmCaption)
          .foregroundStyle(Color.pmtext.secondary)
      }
      .frame(maxWidth: .infinity, alignment: .center)

      HStack(spacing: 8) {
        ForEach([0, 10, 20, 30], id: \.self) { minutes in
          bufferChip(minutes: minutes)
        }
      }
      .frame(maxWidth: .infinity, alignment: .center)
    }
    .padding(.top, 4)
  }

  private func bufferChip(minutes: Int) -> some View {
    let isSelected = bufferMinutes == minutes
    return Button {
      bufferMinutes = minutes
    } label: {
      Text(minutes == 0 ? "없음" : "\(minutes)분")
        .font(.pmCaption)
        .foregroundStyle(isSelected ? Color.pmindigo.n500 : Color.pmtext.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
          Capsule()
            .fill(isSelected ? Color.pmindigo.n500.opacity(0.12) : Color.pmgray.n100)
            .overlay(
              Capsule()
                .strokeBorder(
                  isSelected ? Color.pmindigo.n300 : Color.clear,
                  lineWidth: 1
                )
            )
        )
    }
    .buttonStyle(.plain)
    .accessibilityLabel(minutes == 0 ? "여유 시간 없음" : "여유 시간 \(minutes)분")
  }

  // MARK: - Walking Not Recommended Row

  private func walkingNotRecommendedRow(
    walking: HomeModels.TransportOption,
    distanceText: String?
  ) -> some View {
    let detailParts = ["약 \(walking.durationMinutes)분", distanceText]
      .compactMap { $0 }
      .joined(separator: " · ")
    return rowContent(
      detail: detailParts,
      subDetail: "",
      isPast: true,
      isSelected: false,
      isNotRecommended: true
    )
  }

  // MARK: - Loading / Error Views

  private var loadingView: some View {
    VStack(spacing: 12) {
      ProgressView()
        .scaleEffect(1.2)
        .tint(Color.pmindigo.n500)

      Text("소요 시간을 계산하는 중...")
        .font(.pmCaption)
        .foregroundStyle(Color.pmtext.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 40)
  }

  private func errorView(message: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 28))
        .foregroundStyle(Color.pmgray.n400)

      Text(message)
        .font(.pmCaption)
        .foregroundStyle(Color.pmtext.secondary)
        .multilineTextAlignment(.center)
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
        onDismiss: {}
      )
    }
}
