import PromisoShared
import SwiftUI

// MARK: - Departure Alert Sheet

/// 출발 알림 설정 시트
/// 교통수단별 소요시간과 예상 출발시간을 보여주고 알림을 설정
struct DepartureAlertSheet: View {
  let promiseEmoji: String
  let promiseTitle: String
  let promiseStartAt: Date
  let options: [HomeModels.TransportOption]?
  let loadError: String?
  let onSelect: (HomeModels.TransportType) -> Void
  let onDismiss: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      // 드래그 인디케이터
      Capsule()
        .fill(Color.pmgray.n300)
        .frame(width: 36, height: 4)
        .padding(.top, 12)
        .padding(.bottom, 20)

      ScrollView {
        VStack(spacing: 16) {
          headerSection
          contentSection
          footerNote
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
      }
    }
    .background(Color.pmgray.n50)
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.hidden)
    .presentationCornerRadius(24)
  }

  // MARK: - Header Section

  private var headerSection: some View {
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
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Content Section

  @ViewBuilder
  private var contentSection: some View {
    if let error = loadError {
      errorView(message: error)
    } else if let options = options {
      if options.isEmpty {
        loadingView
      } else {
        VStack(spacing: 10) {
          ForEach(options, id: \.type) { option in
            transportOptionCard(option: option)
          }
        }
      }
    } else {
      loadingView
    }
  }

  // MARK: - Transport Option Card

  private func transportOptionCard(option: HomeModels.TransportOption) -> some View {
    let isPast = option.departureTime < Date()

    return Button {
      if !isPast {
        onSelect(option.type)
        onDismiss()
      }
    } label: {
      cardContent(option: option, isPast: isPast)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(isPast)
  }

  @ViewBuilder
  private func cardContent(option: HomeModels.TransportOption, isPast: Bool) -> some View {
    if #available(iOS 26.0, *) {
      GlassEffectContainer {
        cardInner(option: option, isPast: isPast)
          .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
      }
    } else {
      cardInner(option: option, isPast: isPast)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color.pmgray.n200.opacity(0.5), lineWidth: 1)
        )
    }
  }

  private func cardInner(option: HomeModels.TransportOption, isPast: Bool) -> some View {
    HStack(spacing: 12) {
      // 교통수단 아이콘
      Image(systemName: option.type.iconName)
        .font(.system(size: 20, weight: .medium))
        .foregroundStyle(isPast ? Color.pmgray.n400 : Color.pmindigo.n500)
        .frame(width: 32, height: 32)

      // 교통수단 정보
      VStack(alignment: .leading, spacing: 3) {
        Text(option.type.displayName)
          .font(.pmBodySemibold)
          .foregroundStyle(isPast ? Color.pmtext.secondary : Color.pmtext.primary)

        if isPast {
          Text("출발 시간이 지났어요")
            .font(.pmCaption)
            .foregroundStyle(Color.pmtext.secondary)
        } else {
          HStack(spacing: 4) {
            Text("약 \(option.durationMinutes)분")
              .font(.pmCaption)
              .foregroundStyle(Color.pmtext.secondary)

            Text("·")
              .font(.pmCaption)
              .foregroundStyle(Color.pmtext.secondary)

            Text("\(option.departureTime.formattedTime) 출발")
              .font(.pmCaptionSemibold)
              .foregroundStyle(Color.pmindigo.n500)
          }

          if let additionalInfo = option.additionalInfo {
            Text(additionalInfo)
              .font(.pmCaption)
              .foregroundStyle(Color.pmtext.secondary)
          }
        }
      }

      Spacer(minLength: 0)

      // 선택 인디케이터
      if !isPast {
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Color.pmgray.n400)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
    .opacity(isPast ? 0.6 : 1.0)
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
  Color.clear
    .sheet(isPresented: .constant(true)) {
      DepartureAlertSheet(
        promiseEmoji: "🍕",
        promiseTitle: "점심 모임",
        promiseStartAt: Calendar.current.date(
          bySettingHour: 14, minute: 0, second: 0, of: Date()
        ) ?? Date(),
        options: [
          HomeModels.TransportOption(
            type: .driving,
            durationMinutes: 25,
            departureTime: Calendar.current.date(
              bySettingHour: 13, minute: 25, second: 0, of: Date()
            ) ?? Date(),
            additionalInfo: "통행료 1,200원"
          ),
          HomeModels.TransportOption(
            type: .transit,
            durationMinutes: 40,
            departureTime: Calendar.current.date(
              bySettingHour: 13, minute: 10, second: 0, of: Date()
            ) ?? Date(),
            additionalInfo: "요금 1,250원 · 환승 2회"
          ),
          HomeModels.TransportOption(
            type: .walking,
            durationMinutes: 55,
            departureTime: Calendar.current.date(
              bySettingHour: 12, minute: 55, second: 0, of: Date()
            ) ?? Date(),
            additionalInfo: nil
          ),
        ],
        loadError: nil,
        onSelect: { _ in },
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
        options: nil,
        loadError: nil,
        onSelect: { _ in },
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
        options: [],
        loadError: "경로를 불러오지 못했어요",
        onSelect: { _ in },
        onDismiss: {}
      )
    }
}
