import Clients
import ComposableArchitecture
import PromisoShared
import SwiftUI

// MARK: - TransportDetail Root View

extension TransportDetail {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>

    // MARK: - Sheet Drag State
    private static let collapsedHeight: CGFloat = 130
    private static var expandedHeight: CGFloat { UIScreen.main.bounds.height * 0.55 }

    @State private var sheetHeight: CGFloat = RootView.collapsedHeight
    @State private var sheetBaseHeight: CGFloat = RootView.collapsedHeight
    @State private var bottomInset: CGFloat = 0
    @State private var scrollEnabled = false
    @State private var scrollAtTop = true
    @State private var isDraggingSheet = false
    @State private var dragStartOffset: CGFloat = 0
    @State private var moveToMyLocation = false
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    private func adjustedTime(_ raw: Date) -> Date {
      raw.addingTimeInterval(-Double(store.bufferMinutes * 60))
    }

    private var sheetDragGesture: some Gesture {
      DragGesture(minimumDistance: 5, coordinateSpace: .global)
        .onChanged { value in
          let isExpanded = sheetBaseHeight == Self.expandedHeight
          let pullingDown = value.translation.height > 0

          // expanded 상태에서 스크롤 맨 위 + 아래로 드래그 → 시트 이동
          if isExpanded && !isDraggingSheet {
            if scrollAtTop && pullingDown {
              isDraggingSheet = true
              dragStartOffset = value.translation.height
              scrollEnabled = false
            } else {
              return
            }
          }

          // collapsed 상태에서는 항상 시트 이동
          if !isExpanded && !isDraggingSheet {
            isDraggingSheet = true
            dragStartOffset = value.translation.height
          }

          let delta = value.translation.height - dragStartOffset
          let proposed = sheetBaseHeight - delta
          sheetHeight = max(Self.collapsedHeight, min(Self.expandedHeight, proposed))
        }
        .onEnded { value in
          guard isDraggingSheet else { return }
          let predictedDelta = value.predictedEndTranslation.height - dragStartOffset
          let projected = sheetBaseHeight - predictedDelta
          let mid = (Self.collapsedHeight + Self.expandedHeight) / 2
          let target = projected > mid ? Self.expandedHeight : Self.collapsedHeight
          withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            sheetHeight = target
          }
          sheetBaseHeight = target
          scrollEnabled = (target == Self.expandedHeight)
          isDraggingSheet = false
        }
    }

    public var body: some View {
      VStack(spacing: -20) {
        // Layer 1: Map (fills remaining space above sheet)
        ZStack(alignment: .bottom) {
          mapLayer

          // Floating controls
          HStack {
            if store.selectedSegment == .transit && store.transportData.transitRoutes.count > 1 {
              routeSelector
            }
            Spacer()
            myLocationButton
          }
          .padding(.bottom, 28)
        }

        // Layer 2: Bottom panel
        bottomPanel
      }
      .ignoresSafeArea(edges: .bottom)
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.safeAreaInsets.bottom
      } action: { value in
        if bottomInset == 0 { bottomInset = value }
      }
      .navigationBarTitleDisplayMode(.inline)
      .navigationBarBackButtonHidden()
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            dismiss()
          } label: {
            Image(systemName: "chevron.left")
              .font(.system(size: 16, weight: .semibold))
          }
        }
        ToolbarItem(placement: .principal) {
          transportMenu
        }
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            ForEach(store.availableMapApps, id: \.self) { app in
              Button {
                store.send(.view(.mapAppSelected(app)))
              } label: {
                Text(app.displayName)
              }
            }
          } label: {
            Image(systemName: "arrow.triangle.turn.up.right.diamond")
              .font(.system(size: 16, weight: .semibold))
          }
        }
      }
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Map Layer

    private var mapLayer: some View {
      let originLat = store.originCoordinate?.latitude ?? store.destinationCoordinate.latitude
      let originLng = store.originCoordinate?.longitude ?? store.destinationCoordinate.longitude

      return KakaoTransportMapView(
        data: transportMapData,
        originLatitude: originLat,
        originLongitude: originLng,
        destinationLatitude: store.destinationCoordinate.latitude,
        destinationLongitude: store.destinationCoordinate.longitude,
        moveToOrigin: $moveToMyLocation
      )
    }

    private var transportMapData: TransportMapData {
      switch store.selectedSegment {
      case .driving:
        if let driving = store.transportData.driving {
          return .driving(routePoints: driving.routePoints)
        }
        return .walking
      case .transit:
        if let route = store.selectedTransitRoute {
          let segments = route.subPaths.compactMap { subPath -> TransitRouteSegmentData? in
            guard !subPath.passStopCoords.isEmpty else { return nil }
            return TransitRouteSegmentData(
              coords: subPath.passStopCoords,
              color: subPath.laneColor,
              trafficType: subPath.trafficType
            )
          }
          return .transit(segments: segments)
        }
        return .walking
      case .walking:
        return .walking
      }
    }

    // MARK: - My Location Button

    private var myLocationButton: some View {
      Button {
        moveToMyLocation.toggle()
      } label: {
        Image(systemName: "location.fill")
          .font(.system(size: 14))
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 40, height: 40)
          .background(.ultraThinMaterial, in: Circle())
          .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
      }
      .buttonStyle(.plain)
      .padding(.trailing, 16)
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
      VStack(spacing: 0) {
        // Drag handle
        Capsule()
          .fill(Color.pmgray.n300)
          .frame(width: 36, height: 5)
          .padding(.top, 10)
          .padding(.bottom, 8)
          .frame(maxWidth: .infinity)

        // Scrollable content
        ScrollView {
          VStack(spacing: 12) {
            bottomInfoContent

            if store.selectedSegment == .transit,
               let route = store.selectedTransitRoute,
               !route.subPaths.isEmpty {
              subPathTimeline(subPaths: route.subPaths)
            }

            bufferSelector

            alertButton
              .padding(.bottom, bottomInset + 16)
          }
          .padding(.horizontal, 20)
        }
        .scrollDisabled(!scrollEnabled)
        .onScrollGeometryChange(for: Bool.self) { geo in
          geo.contentOffset.y <= 0
        } action: { _, atTop in
          scrollAtTop = atTop
        }
      }
      .frame(height: sheetHeight + bottomInset)
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
      .simultaneousGesture(sheetDragGesture)
      .background(
        UnevenRoundedRectangle(topLeadingRadius: 20, topTrailingRadius: 20)
          .fill(.ultraThinMaterial)
      )
      .shadow(color: .black.opacity(0.1), radius: 10, y: -2)
      .animation(.spring(response: 0.24, dampingFraction: 0.88), value: store.selectedSegment)
    }


    // MARK: - Bottom Info Content

    @ViewBuilder
    private var bottomInfoContent: some View {
      switch store.selectedSegment {
      case .driving:
        if let driving = store.transportData.driving {
          infoCard {
            VStack(spacing: 12) {
              infoRow(iconName: "clock", label: LocalizedStrings.Home.transportDuration, value: approximateMinutes(driving.durationMinutes))
              Divider()
              infoRow(iconName: "car.fill", label: LocalizedStrings.Home.transportExpectedDeparture, value: adjustedTime(driving.departureTime).formattedTime)
              if let info = driving.additionalInfo {
                Divider()
                infoRow(iconName: "wonsign.circle", label: LocalizedStrings.Home.transportToll, value: info)
              }
            }
          }
        }
      case .transit:
        if let route = store.selectedTransitRoute {
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
        }
      case .walking:
        let walking = store.transportData.walking
        VStack(spacing: 12) {
          infoCard {
            VStack(spacing: 12) {
              infoRow(iconName: "clock", label: LocalizedStrings.Home.transportDuration, value: approximateMinutes(walking.durationMinutes))
              Divider()
              infoRow(iconName: "figure.walk", label: LocalizedStrings.Home.transportExpectedDeparture, value: adjustedTime(walking.departureTime).formattedTime)
              if let meters = walking.distanceMeters, meters > 0 {
                Divider()
                infoRow(iconName: "map", label: LocalizedStrings.Home.transportDistance, value: "\((Double(meters) / 1000.0).formatted(.number.precision(.fractionLength(1))))km")
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
    }

    // MARK: - Transport Menu

    private var availableTransportTypes: [HomeModels.TransportType] {
      var types: [HomeModels.TransportType] = []
      if store.transportData.driving != nil { types.append(.driving) }
      if !store.transportData.transitRoutes.isEmpty { types.append(.transit) }
      types.append(.walking)
      return types
    }

    private var transportMenu: some View {
      Menu {
        ForEach(availableTransportTypes, id: \.self) { type in
          Button {
            store.send(.view(.segmentChanged(type)))
          } label: {
            Label(type.displayName, systemImage: transportIcon(type))
          }
        }
      } label: {
        HStack(spacing: 4) {
          Text(store.selectedSegment.displayName)
            .font(.pmBodySemibold)
            .foregroundStyle(Color.pmtext.primary)
          Image(systemName: "chevron.down")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color.pmtext.secondary)
        }
      }
    }

    private func transportIcon(_ type: HomeModels.TransportType) -> String {
      switch type {
      case .driving: return "car.fill"
      case .transit: return "tram.fill"
      case .walking: return "figure.walk"
      }
    }

    // MARK: - Route Selector

    private var routeSelector: some View {
      ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
          ForEach(store.transportData.transitRoutes) { route in
            routeSelectorChip(route: route)
          }
        }
        .padding(.horizontal, 20)
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
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        RoundedRectangle(cornerRadius: 14)
          .fill(Color.pmgray.n100)
      )
    }

    private func subPathRow(subPath: HomeModels.TransportSubPath, isLast: Bool) -> some View {
      let lineColor: Color = if let hex = subPath.laneColor {
        Color(hex: hex)
      } else if subPath.trafficType == 3 {
        Color.pmgray.n300
      } else {
        subPathIconColor(trafficType: subPath.trafficType)
      }

      return HStack(alignment: .top, spacing: 12) {
        // 타임라인 세로선 + 노드
        VStack(spacing: 0) {
          subPathIcon(trafficType: subPath.trafficType, laneColor: subPath.laneColor)
            .frame(width: 28, height: 28)

          if !isLast {
            Rectangle()
              .fill(lineColor.opacity(0.4))
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

    private func subPathIcon(trafficType: Int, laneColor: String? = nil) -> some View {
      let iconName = subPathIconName(trafficType: trafficType)
      let color: Color = if let hex = laneColor {
        Color(hex: hex)
      } else {
        subPathIconColor(trafficType: trafficType)
      }
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
        HStack(spacing: 6) {
          if let color = subPath.laneColor {
            Circle()
              .fill(Color(hex: color))
              .frame(width: 8, height: 8)
          }
          Text("\(laneName) \(stationText)")
            .font(.pmCaptionSemibold)
            .foregroundStyle(Color.pmtext.primary)
        }
        if let way = subPath.way {
          Text("\(way) 방면")
            .font(.pmCaption)
            .foregroundStyle(subPath.laneColor.map { Color(hex: $0) } ?? Color.pmindigo.n400)
        }
        if !routeText.isEmpty {
          Text(routeText)
            .font(.pmCaption)
            .foregroundStyle(Color.pmtext.secondary)
        }
        Text(minutesOnly(subPath.sectionTime))
          .font(.pmCaption)
          .foregroundStyle(Color.pmtext.secondary)
        if let exitNo = subPath.endExitNo {
          Text("\(exitNo)번 출구")
            .font(.pmCaption)
            .foregroundStyle(Color.pmtext.secondary)
        }
      }
    }

    private func busLabel(subPath: HomeModels.TransportSubPath) -> some View {
      let busNo = subPath.laneName ?? LocalizedStrings.Home.transportBus
      let stopText = subPath.stationCount.map(stopCountText) ?? ""
      let routeText = [subPath.startName, subPath.endName].compactMap { $0 }.joined(separator: " → ")
      return VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 6) {
          if let color = subPath.laneColor {
            Circle()
              .fill(Color(hex: color))
              .frame(width: 8, height: 8)
          }
          Text("\(busNo) \(stopText)")
            .font(.pmCaptionSemibold)
            .foregroundStyle(Color.pmtext.primary)
        }
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

    // MARK: - Info Card / Row

    private func infoCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
      content()
        .padding(16)
        .frame(maxWidth: .infinity)
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

    // MARK: - Alert Button

    private var isAlertDisabled: Bool {
      store.selectedSegment == .walking && (store.transportData.walking.distanceMeters ?? 0) >= 10_000
    }

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
              .fill(isAlertDisabled ? Color.pmgray.n300 : Color.pmindigo.n500)
          )
      }
      .buttonStyle(.plain)
      .disabled(isAlertDisabled)
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
          scheduleItemId: "preview-1",
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
