import Clients
import ComposableArchitecture
import PromisoShared
import SwiftUI

// MARK: - TransportDetail Root View

extension TransportDetail {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    private func adjustedTime(_ raw: Date) -> Date {
      raw.addingTimeInterval(-Double(store.bufferMinutes * 60))
    }

    public var body: some View {
      VStack(spacing: 0) {
        // 일정 정보 헤더
        scheduleHeader
          .padding(.horizontal, 20)
          .padding(.top, 20)
          .padding(.bottom, 12)

        // 경로 요약 카드
        routeSummaryCard
          .padding(.horizontal, 20)
          .padding(.bottom, 16)

        // 세그먼트 컨트롤
        segmentControl
          .padding(.horizontal, 20)
          .padding(.bottom, 16)

        Divider()
          .padding(.horizontal, 20)

        // 컨텐츠 영역
        ScrollView {
          contentArea
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }

        // 여유시간 선택
        bufferSelector
          .padding(.horizontal, 20)
          .padding(.top, 8)

        // 지도에서 경로보기 버튼
        openMapButton
          .padding(.horizontal, 20)
          .padding(.top, 12)

        // 하단 알림 버튼
        alertButton
          .padding(.horizontal, 20)
          .padding(.bottom, 32)
          .padding(.top, 8)
      }
      .auroraBackground()
      .navigationTitle(LocalizedStrings.Home.transportTitle)
      .navigationBarTitleDisplayMode(.inline)
      .onAppear {
        store.send(.view(.onAppear))
      }
      .confirmationDialog(
        LocalizedStrings.Home.transportMapAppDialog,
        isPresented: Binding(
          get: { store.isMapAppSheetPresented },
          set: { _ in store.send(.view(.mapAppSheetDismissed)) }
        )
      ) {
        ForEach(store.availableMapApps, id: \.self) { app in
          Button(app.displayName) {
            store.send(.view(.mapAppSelected(app)))
          }
        }
      }
    }

    // MARK: - Schedule Header

    private var scheduleHeader: some View {
      HStack(spacing: 8) {
        Text(store.scheduleEmoji)
          .font(.pmTitle2)

        VStack(alignment: .leading, spacing: 2) {
          Text(store.scheduleTitle)
            .font(.pmBodySemibold)
            .foregroundStyle(Color.pmtext.primary)
            .lineLimit(1)

          Text(store.scheduleStartAt.formattedTime)
            .font(.pmCaption)
            .foregroundStyle(Color.pmtext.secondary)
        }

        Spacer()
      }
    }

    // MARK: - Route Summary Card

    private var routeSummaryCard: some View {
      VStack(spacing: 12) {
        // 출발지
        HStack(spacing: 8) {
          Circle()
            .fill(Color.pmindigo.n500)
            .frame(width: 8, height: 8)
          Text(store.originName ?? LocalizedStrings.Home.transportCurrentLocation)
            .font(.pmCaption)
            .foregroundStyle(Color.pmtext.secondary)
          Spacer()
        }

        // 연결선
        HStack(spacing: 8) {
          Rectangle()
            .fill(Color.pmgray.n300)
            .frame(width: 2, height: 16)
            .padding(.leading, 3)
          Spacer()
        }

        // 도착지
        HStack(spacing: 8) {
          Circle()
            .fill(Color.pmerror.n500)
            .frame(width: 8, height: 8)
          Text(store.destinationName)
            .font(.pmCaptionSemibold)
            .foregroundStyle(Color.pmtext.primary)
          Spacer()
        }
      }
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(Color.pmgray.n100)
      )
    }

    // MARK: - Segment Control

    private var segmentControl: some View {
      let availableTypes: [HomeModels.TransportType] = {
        var types: [HomeModels.TransportType] = []
        if store.transportData.driving != nil { types.append(.driving) }
        if !store.transportData.transitRoutes.isEmpty { types.append(.transit) }
        types.append(.walking)
        return types
      }()

      return Picker(LocalizedStrings.SettingsStrings.briefingTransport, selection: Binding(
        get: { store.selectedSegment },
        set: { store.send(.view(.segmentChanged($0))) }
      )) {
        ForEach(availableTypes, id: \.self) { type in
          Text(type.displayName).tag(type)
        }
      }
      .pickerStyle(.segmented)
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
      switch store.selectedSegment {
      case .driving:
        if let driving = store.transportData.driving {
          drivingContent(driving: driving)
        }
      case .transit:
        transitContent
      case .walking:
        walkingContent
      }
    }

    // MARK: - Driving Content

    private func drivingContent(driving: HomeModels.TransportOption) -> some View {
      VStack(spacing: 16) {
        infoCard {
          VStack(spacing: 12) {
            infoRow(
              iconName: "clock",
              label: LocalizedStrings.Home.transportDuration,
              value: approximateMinutes(driving.durationMinutes)
            )
            Divider()
            infoRow(
              iconName: "car.fill",
              label: LocalizedStrings.Home.transportExpectedDeparture,
              value: adjustedTime(driving.departureTime).formattedTime
            )
            if let info = driving.additionalInfo {
              Divider()
              infoRow(
                iconName: "wonsign.circle",
                label: LocalizedStrings.Home.transportToll,
                value: info
              )
            }
          }
        }
      }
    }

    // MARK: - Transit Content

    private var transitContent: some View {
      VStack(spacing: 16) {
        // 경로 선택 (여러 경로가 있을 때)
        if store.transportData.transitRoutes.count > 1 {
          routeSelector
        }

        // 선택된 경로 상세
        if let route = store.selectedTransitRoute {
          transitRouteDetail(route: route)
        }
      }
    }

    private var routeSelector: some View {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(store.transportData.transitRoutes) { route in
            routeSelectorChip(route: route)
          }
        }
        .padding(.horizontal, 2)
      }
    }

    private func routeSelectorChip(route: HomeModels.TransitRouteOption) -> some View {
      let isSelected = store.selectedTransitIndex == route.id
      let labelColor: Color = isSelected ? Color.pmindigo.n500 : Color.pmtext.secondary
      let subColor: Color = isSelected ? Color.pmindigo.n400 : Color.pmtext.secondary
      let bgColor: Color = isSelected ? Color.pmindigo.n50 : Color.pmgray.n100
      let borderColor: Color = isSelected ? Color.pmindigo.n300 : Color.clear

      return Button {
        store.send(.view(.transitRouteChanged(route.id)))
      } label: {
        VStack(spacing: 4) {
          Text(routeTitle(route.id + 1))
            .font(.pmCaptionSemibold)
            .foregroundStyle(labelColor)
          Text(approximateMinutes(route.totalTime))
            .font(.pmCaption)
            .foregroundStyle(subColor)
          if !route.tags.isEmpty {
            HStack(spacing: 4) {
              ForEach(route.tags, id: \.self) { tag in
                Text(tag.displayName)
                  .font(.pmMicro2Medium)
                  .foregroundStyle(Color.pmindigo.n500)
                  .padding(.horizontal, 6)
                  .padding(.vertical, 2)
                  .background(Capsule().fill(Color.pmindigo.n500.opacity(0.1)))
              }
            }
          }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .fill(bgColor)
            .overlay(
              RoundedRectangle(cornerRadius: 10)
                .strokeBorder(borderColor, lineWidth: 1)
            )
        )
      }
      .buttonStyle(.plain)
      .accessibilityLabel(routeAccessibilityLabel(isSelected: isSelected, routeIndex: route.id + 1, minutes: route.totalTime))
    }

    private func transitRouteDetail(route: HomeModels.TransitRouteOption) -> some View {
      VStack(spacing: 16) {
        // 요약 카드
        infoCard {
          VStack(spacing: 12) {
            infoRow(iconName: "clock", label: LocalizedStrings.Home.transportTotalDuration, value: approximateMinutes(route.totalTime))
            Divider()
            infoRow(iconName: "tram.fill", label: LocalizedStrings.Home.transportExpectedDeparture, value: adjustedTime(route.departureTime).formattedTime)
            if route.payment > 0 {
              Divider()
              infoRow(iconName: "wonsign.circle", label: LocalizedStrings.Home.transportFare, value: wonAmount(route.payment))
            }
            if route.transitCount > 0 {
              Divider()
              infoRow(iconName: "arrow.triangle.2.circlepath", label: LocalizedStrings.Home.transportTransfers, value: transferCount(route.transitCount))
            }
          }
        }

        // 경로 타임라인
        if !route.subPaths.isEmpty {
          subPathTimeline(subPaths: route.subPaths)
        }
      }
    }

    // MARK: - SubPath Timeline

    private func subPathTimeline(subPaths: [HomeModels.TransportSubPath]) -> some View {
      VStack(alignment: .leading, spacing: 0) {
        Text(LocalizedStrings.Home.transportRouteDetailTitle)
          .font(.pmCaptionSemibold)
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.bottom, 12)

        ForEach(Array(subPaths.enumerated()), id: \.offset) { index, subPath in
          subPathRow(subPath: subPath, isLast: index == subPaths.count - 1)
        }
      }
      .padding(16)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(Color.pmgray.n100)
      )
    }

    private func subPathRow(subPath: HomeModels.TransportSubPath, isLast: Bool) -> some View {
      HStack(alignment: .top, spacing: 12) {
        // 타임라인 세로선 + 노드
        VStack(spacing: 0) {
          subPathIcon(trafficType: subPath.trafficType)
            .frame(width: 28, height: 28)

          if !isLast {
            Rectangle()
              .fill(Color.pmgray.n300)
              .frame(width: 2, height: 32)
          }
        }

        // 구간 정보
        VStack(alignment: .leading, spacing: 4) {
          subPathLabel(subPath: subPath)

          if !isLast {
            Spacer().frame(height: 20)
          }
        }
        .padding(.top, 4)
      }
    }

    private func subPathIconName(trafficType: Int) -> String {
      switch trafficType {
      case 1: return "tram.fill"
      case 2: return "bus.fill"
      default: return "figure.walk"
      }
    }

    private func subPathIconColor(trafficType: Int) -> Color {
      switch trafficType {
      case 1: return Color.pmindigo.n500
      case 2: return Color.pmsuccess.n500
      default: return Color.pmgray.n500
      }
    }

    private func subPathIcon(trafficType: Int) -> some View {
      let iconName = subPathIconName(trafficType: trafficType)
      let color = subPathIconColor(trafficType: trafficType)
      return ZStack {
        Circle()
          .fill(color.opacity(0.12))
        Image(systemName: iconName)
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(color)
      }
    }

    @ViewBuilder
    private func subPathLabel(subPath: HomeModels.TransportSubPath) -> some View {
      if subPath.trafficType == 1 {
        subwayLabel(subPath: subPath)
      } else if subPath.trafficType == 2 {
        busLabel(subPath: subPath)
      } else {
        walkLabel(sectionTime: subPath.sectionTime)
      }
    }

    private func subwayLabel(subPath: HomeModels.TransportSubPath) -> some View {
      let laneName = subPath.laneName ?? LocalizedStrings.Home.transportSubway
      let stationText = subPath.stationCount.map(stationCountText) ?? ""
      let routeText = [subPath.startName, subPath.endName].compactMap { $0 }.joined(separator: " → ")
      return VStack(alignment: .leading, spacing: 2) {
        Text("\(laneName) \(stationText)")
          .font(.pmCaptionSemibold)
          .foregroundStyle(Color.pmtext.primary)
        if !routeText.isEmpty {
          Text(routeText)
            .font(.pmCaption)
            .foregroundStyle(Color.pmtext.secondary)
        }
        Text(minutesOnly(subPath.sectionTime))
          .font(.pmCaption)
          .foregroundStyle(Color.pmtext.secondary)
      }
    }

    private func busLabel(subPath: HomeModels.TransportSubPath) -> some View {
      let busNo = subPath.laneName ?? LocalizedStrings.Home.transportBus
      let stopText = subPath.stationCount.map(stopCountText) ?? ""
      let routeText = [subPath.startName, subPath.endName].compactMap { $0 }.joined(separator: " → ")
      return VStack(alignment: .leading, spacing: 2) {
        Text("\(busNo) \(stopText)")
          .font(.pmCaptionSemibold)
          .foregroundStyle(Color.pmtext.primary)
        if !routeText.isEmpty {
          Text(routeText)
            .font(.pmCaption)
            .foregroundStyle(Color.pmtext.secondary)
        }
        Text(minutesOnly(subPath.sectionTime))
          .font(.pmCaption)
          .foregroundStyle(Color.pmtext.secondary)
      }
    }

    private func walkLabel(sectionTime: Int) -> some View {
      Text(walkingTime(sectionTime))
        .font(.pmCaption)
        .foregroundStyle(Color.pmtext.secondary)
    }

    // MARK: - Walking Content

    private var walkingContent: some View {
      let walking = store.transportData.walking
      return VStack(spacing: 16) {
        infoCard {
          VStack(spacing: 12) {
            infoRow(iconName: "clock", label: LocalizedStrings.Home.transportDuration, value: approximateMinutes(walking.durationMinutes))
            Divider()
            infoRow(iconName: "figure.walk", label: LocalizedStrings.Home.transportExpectedDeparture, value: adjustedTime(walking.departureTime).formattedTime)
            if let meters = walking.distanceMeters, meters > 0 {
              Divider()
              infoRow(
                iconName: "map",
                label: LocalizedStrings.Home.transportDistance,
                value: String(format: "%.1fkm", Double(meters) / 1000.0)
              )
            }
          }
        }
        if (walking.distanceMeters ?? 0) >= 10_000 {
          HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
              .font(.system(size: 13))
              .foregroundStyle(Color.pmwarning.n500)
            Text(LocalizedStrings.Home.transportWalkingNotRecommended)
              .font(.pmCaption)
              .foregroundStyle(Color.pmtext.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 4)
        }
      }
    }

    // MARK: - Info Card / Row

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
      content()
        .padding(16)
        .background(
          RoundedRectangle(cornerRadius: 14)
            .fill(Color.pmgray.n100)
        )
    }

    private func infoRow(iconName: String, label: String, value: String) -> some View {
      HStack {
        Image(systemName: iconName)
          .font(.system(size: 14))
          .foregroundStyle(Color.pmindigo.n400)
          .frame(width: 20)

        Text(label)
          .font(.pmCaption)
          .foregroundStyle(Color.pmtext.secondary)

        Spacer()

        Text(value)
          .font(.pmCaptionSemibold)
          .foregroundStyle(Color.pmtext.primary)
      }
    }

    // MARK: - Buffer Selector

    private var bufferSelector: some View {
      HStack(spacing: 0) {
        HStack(spacing: 6) {
          Image(systemName: "clock")
            .font(.pmCaption)
            .foregroundStyle(Color.pmtext.secondary)
          Text(LocalizedStrings.Home.transportBufferTime)
            .font(.pmCaption)
            .foregroundStyle(Color.pmtext.secondary)
        }

        Spacer()

        HStack(spacing: 6) {
          ForEach([0, 10, 20, 30], id: \.self) { minutes in
            bufferChip(minutes: minutes)
          }
        }
      }
    }

    private func bufferChip(minutes: Int) -> some View {
      let isSelected = store.bufferMinutes == minutes
      return Button {
        store.send(.view(.bufferChanged(minutes)))
      } label: {
        Text(bufferText(minutes))
          .font(.pmCaption)
          .foregroundStyle(isSelected ? Color.pmindigo.n500 : Color.pmtext.secondary)
          .padding(.horizontal, 12)
          .padding(.vertical, 5)
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
      .accessibilityLabel(bufferAccessibilityLabel(minutes))
    }

    // MARK: - Open Map Button

    private var openMapButton: some View {
      Button {
        store.send(.view(.openMapTapped))
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "map")
            .font(.system(size: 14))
          Text(LocalizedStrings.Home.transportOpenInMap)
            .font(.pmCaptionSemibold)
        }
        .foregroundStyle(Color.pmindigo.n500)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
          RoundedRectangle(cornerRadius: 14)
            .strokeBorder(Color.pmindigo.n300, lineWidth: 1)
        )
      }
      .buttonStyle(.plain)
    }

    // MARK: - Alert Button

    private var alertButton: some View {
      Button {
        store.send(.view(.alertButtonTapped))
      } label: {
        Text(LocalizedStrings.Home.transportNotifyWithThis)
          .font(.pmBodySemibold)
          .foregroundStyle(Color.white)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 16)
          .background(
            RoundedRectangle(cornerRadius: 14)
              .fill(Color.pmindigo.n500)
          )
      }
      .buttonStyle(.plain)
    }

    private func approximateMinutes(_ minutes: Int) -> String {
      String(localized: "home.transport.approxMinutes", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }

    private func minutesOnly(_ minutes: Int) -> String {
      String(localized: "home.transport.minutesOnly", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }

    private func wonAmount(_ amount: Int) -> String {
      String(localized: "home.transport.wonAmount", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%@", with: amount.formatted())
    }

    private func transferCount(_ count: Int) -> String {
      String(localized: "home.transport.transferCount", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }

    private func routeTitle(_ index: Int) -> String {
      String(localized: "home.transport.route", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(index)")
    }

    private func routeAccessibilityLabel(isSelected: Bool, routeIndex: Int, minutes: Int) -> String {
      let key = isSelected ? "home.transport.route.accessibility.selected" : "home.transport.route.accessibility"
      return String(localized: String.LocalizationValue(key), bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%1$lld", with: "\(routeIndex)")
        .replacingOccurrences(of: "%2$lld", with: "\(minutes)")
    }

    private func stationCountText(_ count: Int) -> String {
      String(localized: "home.transport.stationCount", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }

    private func stopCountText(_ count: Int) -> String {
      String(localized: "home.transport.stopCount", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(count)")
    }

    private func walkingTime(_ minutes: Int) -> String {
      String(localized: "home.transport.walkingTime", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }

    private func bufferText(_ minutes: Int) -> String {
      guard minutes > 0 else { return LocalizedStrings.Home.transportNoBuffer }
      return String(localized: "home.transport.buffer.minutes", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }

    private func bufferAccessibilityLabel(_ minutes: Int) -> String {
      guard minutes > 0 else { return LocalizedStrings.Home.transportNoBufferAccessibility }
      return String(localized: "home.transport.buffer.minutes.accessibility", bundle: LocalizedStrings.bundle)
        .replacingOccurrences(of: "%lld", with: "\(minutes)")
    }
  }
}

// MARK: - Preview

#Preview {
  let now = Date()
  let startAt = Calendar.current.date(bySettingHour: 14, minute: 0, second: 0, of: now) ?? now

  NavigationStack {
    TransportDetail.RootView(
      store: Store(
        initialState: TransportDetail.Feature.State(
          scheduleTitle: "점심 모임",
          scheduleEmoji: "🍕",
          scheduleStartAt: startAt,
          transportData: HomeModels.DepartureTransportData(
            driving: HomeModels.TransportOption(
              type: .driving,
              durationMinutes: 25,
              departureTime: Calendar.current.date(bySettingHour: 13, minute: 25, second: 0, of: now) ?? now
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
                subPaths: [
                  HomeModels.TransportSubPath(trafficType: 3, sectionTime: 5, distance: 400, startName: nil, endName: "강남역", stationCount: nil, laneName: nil),
                  HomeModels.TransportSubPath(trafficType: 1, sectionTime: 28, distance: 18000, startName: "강남역", endName: "홍대입구역", stationCount: 6, laneName: "2호선"),
                  HomeModels.TransportSubPath(trafficType: 3, sectionTime: 7, distance: 550, startName: "홍대입구역", endName: nil, stationCount: nil, laneName: nil),
                ],
                tags: [.fastest]
              ),
            ],
            walking: HomeModels.TransportOption(
              type: .walking,
              durationMinutes: 55,
              departureTime: Calendar.current.date(bySettingHour: 12, minute: 55, second: 0, of: now) ?? now
            )
          ),
          originCoordinate: Coordinate(latitude: 37.498095, longitude: 127.027610),
          originName: "강남역",
          destinationCoordinate: Coordinate(latitude: 37.556, longitude: 126.923),
          destinationName: "홍대입구역"
        )
      ) {
        TransportDetail.Feature()
      }
    )
  }
}
