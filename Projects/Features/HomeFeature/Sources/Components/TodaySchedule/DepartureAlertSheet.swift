import PromisoShared
import SwiftUI

// MARK: - Departure Alert Sheet

/// 출발 알림 설정 시트
/// 교통수단별 소요시간과 예상 출발시간을 보여주고 알림을 설정
struct DepartureAlertSheet: View {
  let promiseEmoji: String
  let promiseTitle: String
  let promiseStartAt: Date
  let transportData: HomeModels.DepartureTransportData?
  let loadError: String?
  let onSelect: (HomeModels.TransportSelection) -> Void
  let onDetailTapped: () -> Void
  let onDismiss: () -> Void

  @State private var selection: HomeModels.TransportSelection?

  var body: some View {
    VStack(spacing: 0) {
      // 드래그 인디케이터
      Capsule()
        .fill(Color.pmgray.n300)
        .frame(width: 36, height: 4)
        .padding(.top, 12)
        .padding(.bottom, 20)

      VStack(spacing: 0) {
        ScrollView {
          VStack(spacing: 16) {
            headerSection
            contentSection
            footerNote
          }
          .padding(.horizontal, 20)
          .padding(.bottom, 16)
        }

        // 하단 고정 버튼
        confirmButton
          .padding(.horizontal, 20)
          .padding(.bottom, 32)
          .padding(.top, 12)
      }
    }
    .background(Color.pmgray.n50)
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

        HStack(spacing: 6) {
          Text(promiseEmoji)
            .font(.pmBody)

          Text(promiseTitle)
            .font(.pmBodySemibold)
            .foregroundStyle(Color.pmtext.primary)
            .lineLimit(1)

          Text("·")
            .font(.pmBody)
            .foregroundStyle(Color.pmtext.secondary)

          Text(promiseStartAt.formattedTime)
            .font(.pmBody)
            .foregroundStyle(Color.pmtext.secondary)
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
      // 자동차 로우
      if let driving = data.driving {
        transportRow(
          iconName: HomeModels.TransportType.driving.iconName,
          label: HomeModels.TransportType.driving.displayName,
          detail: "약 \(driving.durationMinutes)분",
          subDetail: "\(driving.departureTime.formattedTime) 출발",
          isPast: driving.departureTime < Date(),
          isSelected: selection == .driving
        ) {
          selection = .driving
        }
      }

      // 대중교통 섹션 헤더
      if !data.transitRoutes.isEmpty {
        HStack {
          Image(systemName: HomeModels.TransportType.transit.iconName)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.pmtext.secondary)
          Text(HomeModels.TransportType.transit.displayName)
            .font(.pmCaptionSemibold)
            .foregroundStyle(Color.pmtext.secondary)
          Spacer()
        }
        .padding(.top, 4)
        .padding(.horizontal, 4)

        // 대중교통 경로별 로우
        ForEach(data.transitRoutes) { route in
          transitRouteRow(route: route, index: route.id)
        }
      }

      // 도보 로우
      let walking = data.walking
      transportRow(
        iconName: HomeModels.TransportType.walking.iconName,
        label: HomeModels.TransportType.walking.displayName,
        detail: "약 \(walking.durationMinutes)분",
        subDetail: "\(walking.departureTime.formattedTime) 출발",
        isPast: walking.departureTime < Date(),
        isSelected: selection == .walking
      ) {
        selection = .walking
      }
    }
  }

  // MARK: - Transport Row

  private func transportRow(
    iconName: String,
    label: String,
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
        iconName: iconName,
        label: label,
        detail: detail,
        subDetail: subDetail,
        isPast: isPast,
        isSelected: isSelected
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isPast)
  }

  @ViewBuilder
  private func rowContent(
    iconName: String,
    label: String,
    detail: String,
    subDetail: String,
    isPast: Bool,
    isSelected: Bool
  ) -> some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer {
        rowInner(
          iconName: iconName,
          label: label,
          detail: detail,
          subDetail: subDetail,
          isPast: isPast,
          isSelected: isSelected
        )
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
      }
    } else {
      rowInner(
        iconName: iconName,
        label: label,
        detail: detail,
        subDetail: subDetail,
        isPast: isPast,
        isSelected: isSelected
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
    iconName: String,
    label: String,
    detail: String,
    subDetail: String,
    isPast: Bool,
    isSelected: Bool
  ) -> some View {
    HStack(spacing: 12) {
      Image(systemName: iconName)
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(isPast ? Color.pmgray.n400 : (isSelected ? Color.pmindigo.n500 : Color.pmindigo.n400))
        .frame(width: 28, height: 28)

      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .font(.pmBodySemibold)
          .foregroundStyle(isPast ? Color.pmtext.secondary : Color.pmtext.primary)

        if isPast {
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

      // 라디오 버튼
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

  // MARK: - Transit Route Row

  private func transitRouteRow(route: HomeModels.TransitRouteOption, index: Int) -> some View {
    let sel = HomeModels.TransportSelection.transit(index: index)
    let isSelected = selection == sel
    let isPast = route.departureTime < Date()

    return Button {
      if !isPast { selection = sel }
    } label: {
      transitRouteContent(route: route, isSelected: isSelected, isPast: isPast)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isPast)
  }

  @ViewBuilder
  private func transitRouteContent(
    route: HomeModels.TransitRouteOption,
    isSelected: Bool,
    isPast: Bool
  ) -> some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer {
        transitRouteInner(route: route, isSelected: isSelected, isPast: isPast)
          .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
      }
    } else {
      transitRouteInner(route: route, isSelected: isSelected, isPast: isPast)
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
    isSelected: Bool,
    isPast: Bool
  ) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 3) {
        // 경로 번호
        Text("경로 \(route.id + 1)")
          .font(.pmCaptionSemibold)
          .foregroundStyle(isPast ? Color.pmtext.secondary : (isSelected ? Color.pmindigo.n500 : Color.pmtext.primary))

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

          Text("\(route.departureTime.formattedTime) 출발")
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
        onSelect(sel)
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

  // MARK: - Footer Note

  private var footerNote: some View {
    HStack(spacing: 6) {
      Image(systemName: "clock")
        .font(.pmCaption)
        .foregroundStyle(Color.pmtext.secondary)

      Text("여유 시간 10분 포함")
        .font(.pmCaption)
        .foregroundStyle(Color.pmtext.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .center)
    .padding(.top, 4)
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
            additionalInfo: nil
          )
        ),
        loadError: nil,
        onSelect: { _ in },
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
        transportData: nil,
        loadError: nil,
        onSelect: { _ in },
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
        transportData: nil,
        loadError: "경로를 불러오지 못했어요",
        onSelect: { _ in },
        onDetailTapped: {},
        onDismiss: {}
      )
    }
}
