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

        // 하단 알림 버튼
        alertButton
          .padding(.horizontal, 20)
          .padding(.bottom, 32)
          .padding(.top, 12)
      }
      .auroraBackground()
      .navigationTitle("교통 수단 상세")
      .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - Segment Control

    private var segmentControl: some View {
      let availableTypes: [HomeModels.TransportType] = {
        var types: [HomeModels.TransportType] = []
        if store.transportData.driving != nil { types.append(.driving) }
        if !store.transportData.transitRoutes.isEmpty { types.append(.transit) }
        types.append(.walking)
        return types
      }()

      return Picker("교통수단", selection: Binding(
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
              label: "소요시간",
              value: "약 \(driving.durationMinutes)분"
            )
            Divider()
            infoRow(
              iconName: "car.fill",
              label: "예상 출발",
              value: adjustedTime(driving.departureTime).formattedTime
            )
            if let info = driving.additionalInfo {
              Divider()
              infoRow(
                iconName: "wonsign.circle",
                label: "통행료",
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
        VStack(spacing: 2) {
          Text("경로 \(route.id + 1)")
            .font(.pmCaptionSemibold)
            .foregroundStyle(labelColor)
          Text("약 \(route.totalTime)분")
            .font(.pmCaption)
            .foregroundStyle(subColor)
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
      .accessibilityLabel("\(isSelected ? "선택됨, " : "")경로 \(route.id + 1), 약 \(route.totalTime)분")
    }

    private func transitRouteDetail(route: HomeModels.TransitRouteOption) -> some View {
      VStack(spacing: 16) {
        // 요약 카드
        infoCard {
          VStack(spacing: 12) {
            infoRow(iconName: "clock", label: "총 소요시간", value: "약 \(route.totalTime)분")
            Divider()
            infoRow(iconName: "tram.fill", label: "예상 출발", value: adjustedTime(route.departureTime).formattedTime)
            if route.payment > 0 {
              Divider()
              infoRow(iconName: "wonsign.circle", label: "요금", value: "\(route.payment.formatted())원")
            }
            if route.transitCount > 0 {
              Divider()
              infoRow(iconName: "arrow.triangle.2.circlepath", label: "환승", value: "\(route.transitCount)회")
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
        Text("상세 경로")
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
      let laneName = subPath.laneName ?? "지하철"
      let stationText = subPath.stationCount.map { "(\($0)개역)" } ?? ""
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
        Text("\(subPath.sectionTime)분")
          .font(.pmCaption)
          .foregroundStyle(Color.pmtext.secondary)
      }
    }

    private func busLabel(subPath: HomeModels.TransportSubPath) -> some View {
      let busNo = subPath.laneName ?? "버스"
      let stopText = subPath.stationCount.map { "(\($0)정류장)" } ?? ""
      let routeText = [subPath.startName, subPath.endName].compactMap { $0 }.joined(separator: " → ")
      return VStack(alignment: .leading, spacing: 2) {
        Text("\(busNo)번 \(stopText)")
          .font(.pmCaptionSemibold)
          .foregroundStyle(Color.pmtext.primary)
        if !routeText.isEmpty {
          Text(routeText)
            .font(.pmCaption)
            .foregroundStyle(Color.pmtext.secondary)
        }
        Text("\(subPath.sectionTime)분")
          .font(.pmCaption)
          .foregroundStyle(Color.pmtext.secondary)
      }
    }

    private func walkLabel(sectionTime: Int) -> some View {
      Text("도보 \(sectionTime)분")
        .font(.pmCaption)
        .foregroundStyle(Color.pmtext.secondary)
    }

    // MARK: - Walking Content

    private var walkingContent: some View {
      let walking = store.transportData.walking
      return VStack(spacing: 16) {
        infoCard {
          VStack(spacing: 12) {
            infoRow(iconName: "clock", label: "소요시간", value: "약 \(walking.durationMinutes)분")
            Divider()
            infoRow(iconName: "figure.walk", label: "예상 출발", value: adjustedTime(walking.departureTime).formattedTime)
            if let meters = walking.distanceMeters, meters > 0 {
              Divider()
              infoRow(
                iconName: "map",
                label: "예상 거리",
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
            Text("10km 이상으로 도보는 비추천이에요")
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
          Text("여유 시간")
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
        Text(minutes == 0 ? "없음" : "\(minutes)분")
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
      .accessibilityLabel(minutes == 0 ? "여유 시간 없음" : "여유 시간 \(minutes)분")
    }

    // MARK: - Alert Button

    private var alertButton: some View {
      Button {
        store.send(.view(.alertButtonTapped))
      } label: {
        Text("이 수단으로 알림 받기")
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
                ]
              ),
            ],
            walking: HomeModels.TransportOption(
              type: .walking,
              durationMinutes: 55,
              departureTime: Calendar.current.date(bySettingHour: 12, minute: 55, second: 0, of: now) ?? now
            )
          )
        )
      ) {
        TransportDetail.Feature()
      }
    )
  }
}
