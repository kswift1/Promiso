import Clients
import PromisoShared
import ResourceKit
import SwiftUI

// MARK: - DailyBriefingCard

private enum Constants {
  static let proBlurRadius: CGFloat = 6
}

struct DailyBriefingCard: View {
  let summary: String?
  let detail: String?
  let isLoading: Bool
  let isExpanded: Bool
  let isUpdated: Bool
  let isPro: Bool
  let isNotificationDenied: Bool
  let isLocationDenied: Bool
  let briefingStyle: BriefingStyle?
  let availableTransports: Set<AvailableTransport>?
  let briefingNotificationHour: Int?
  let onTap: () -> Void
  let onOpenNotificationSettings: (() -> Void)?
  let onOpenLocationSettings: (() -> Void)?
  let onReportError: (() -> Void)?
  let onProUpgradeTapped: (() -> Void)?
  let onSettingsChipTapped: (() -> Void)?

  var body: some View {
    if isLoading || summary != nil {
      VStack(alignment: .leading, spacing: 0) {
        // 헤더 + 요약 (탭 가능)
        Button {
          onTap()
        } label: {
          VStack(alignment: .leading, spacing: 0) {
            cardHeader
              .padding(.horizontal, 16)
              .padding(.top, 16)
              .padding(.bottom, summary != nil && !isLoading ? 8 : 12)

            if isLoading {
              loadingContent
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            } else if let summary, !isExpanded {
              Text(summary)
                .font(.pmSubheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        // 콘텐츠 (expanded일 때만)
        if isExpanded, !isLoading {
          Divider()
            .padding(.horizontal, 16)

          if let summary {
            VStack(alignment: .leading, spacing: 8) {
              Text(summary)
                .font(.pmSubheadlineMedium)
                .foregroundStyle(.primary)

              if let detail {
                if isPro {
                  Text(detail)
                    .font(.pmSubheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                } else {
                  ZStack {
                    Text(detail)
                      .font(.pmSubheadline)
                      .foregroundStyle(.secondary)
                      .lineSpacing(4)
                      .fixedSize(horizontal: false, vertical: true)
                      .blur(radius: Constants.proBlurRadius)

                    Button {
                      onProUpgradeTapped?()
                    } label: {
                      HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                          .font(.system(size: 13, weight: .semibold))
                        Text(LocalizedStrings.Home.briefingProUpgrade)
                          .font(.pmSubheadlineSemibold)
                      }
                      .foregroundStyle(.white)
                      .padding(.horizontal, 16)
                      .padding(.vertical, 10)
                      .background(
                        LinearGradient(
                          colors: [Color.pmindigo.n500, Color.pmpurple.n500],
                          startPoint: .leading,
                          endPoint: .trailing
                        ),
                        in: Capsule()
                      )
                    }
                    .buttonStyle(.plain)
                  }
                }
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .transition(.opacity.combined(with: .move(edge: .top)))

            // 설정 칩 - Pro만, briefingStyle이 있을 때만
            if isPro, let briefingStyle {
              Divider()
                .padding(.horizontal, 16)

              settingsChips(briefingStyle: briefingStyle)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 권한 안내 배너 - Pro만
            if isPro, isNotificationDenied || isLocationDenied {
              Divider()
                .padding(.horizontal, 16)

              permissionBanner
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // 오류 제보 - Pro만
            if isPro {
              Divider()
                .padding(.horizontal, 16)

              reportErrorButton
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
          }
        }
      }
      .proGlassCard(cornerRadius: 20)
    }
  }

  // MARK: - Header

  private var cardHeader: some View {
    HStack(spacing: 8) {
      // Pro 뱃지
      proBadge

      Text(LocalizedStrings.Home.briefingTitle)
        .font(.pmHeadline)
        .foregroundStyle(.primary)

      // 업데이트됨 뱃지
      if isUpdated {
        Text(LocalizedStrings.Home.briefingUpdatedBadge)
          .font(.pmCaption)
          .foregroundStyle(Color.pmindigo.n500)
          .transition(.opacity)
      }

      Spacer()

      // Chevron (회전 애니메이션)
      Image(systemName: "chevron.right")
        .font(.pmSubheadlineSemibold)
        .foregroundStyle(Color.pmgray.n400)
        .rotationEffect(.degrees(isExpanded ? 90 : 0))
    }
  }

  // MARK: - Pro Badge

  private var proBadge: some View {
    HStack(spacing: 3) {
      Image(systemName: "sparkles")
        .font(.system(size: 9, weight: .bold))

      Text("PRO")
        .font(.system(size: 9, weight: .bold))
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(
      LinearGradient(
        colors: [Color.pmindigo.n500, Color.pmpurple.n500],
        startPoint: .leading,
        endPoint: .trailing
      ),
      in: Capsule()
    )
  }

  // MARK: - Loading

  @ViewBuilder
  private var loadingContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      RoundedRectangle(cornerRadius: 4)
        .fill(Color(.systemGray5))
        .frame(height: 14)
        .shimmer()

      RoundedRectangle(cornerRadius: 4)
        .fill(Color(.systemGray5))
        .frame(width: 200, height: 14)
        .shimmer()
    }
  }

  // MARK: - Permission Banner

  @ViewBuilder
  private var permissionBanner: some View {
    VStack(alignment: .leading, spacing: 6) {
      if isNotificationDenied {
        permissionRow(
          icon: "bell.slash",
          message: LocalizedStrings.Home.briefingNotificationOffMessage,
          onTap: onOpenNotificationSettings
        )
      }
      if isLocationDenied {
        permissionRow(
          icon: "location.slash",
          message: LocalizedStrings.Home.briefingLocationOffMessage,
          onTap: onOpenLocationSettings
        )
      }
    }
  }

  // MARK: - Report Error

  private var reportErrorButton: some View {
    Button {
      onReportError?()
    } label: {
      HStack(spacing: 4) {
        Image(systemName: "exclamationmark.bubble")
          .font(.pmCaption)
        Text(LocalizedStrings.Home.briefingReportIssue)
          .font(.pmCaption)
      }
      .foregroundStyle(Color.pmgray.n400)
      .frame(maxWidth: .infinity, alignment: .center)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  // MARK: - Settings Chips

  private func settingsChips(briefingStyle: BriefingStyle) -> some View {
    Button {
      onSettingsChipTapped?()
    } label: {
      HStack(spacing: 8) {
        // 톤 칩
        settingsChip(icon: "face.smiling", label: briefingStyle.displayName)

        // 이동수단 칩
        if let transports = availableTransports {
          transportChip(transports)
        }

        // 알림 시간 칩
        if let hour = briefingNotificationHour {
          settingsChip(icon: "bell.fill", label: notificationHourText(hour))
        }

        Spacer()
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func transportChip(_ transports: Set<AvailableTransport>) -> some View {
    let (icon, label) = transportChipContent(transports)
    return settingsChip(icon: icon, label: label)
  }

  private func settingsChip(icon: String, label: String) -> some View {
    HStack(spacing: 4) {
      Image(systemName: icon)
        .font(.pmCaption)
      Text(label)
        .font(.pmCaption)
    }
    .foregroundStyle(Color.pmgray.n500)
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .background(Color.pmgray.n100.opacity(0.55), in: Capsule())
  }

  private func transportChipContent(_ transports: Set<AvailableTransport>) -> (String, String) {
    let hasCar = transports.contains(.car)
    let hasTransit = transports.contains(.transit)
    if hasCar && hasTransit {
      return ("car.fill", "자동차 포함")
    } else if hasCar {
      return ("car.fill", "자동차")
    } else {
      return ("bus.fill", "대중교통")
    }
  }

  private func notificationHourText(_ hour: Int) -> String {
    let clampedHour = hour % 24
    if clampedHour < 12 {
      let displayHour = clampedHour == 0 ? 12 : clampedHour
      return "매일 오전 \(displayHour)시"
    } else {
      let displayHour = clampedHour == 12 ? 12 : clampedHour - 12
      return "매일 오후 \(displayHour)시"
    }
  }

  private func permissionRow(icon: String, message: String, onTap: (() -> Void)?) -> some View {
    HStack(spacing: 6) {
      Image(systemName: icon)
        .font(.pmCaption)
        .foregroundStyle(Color.pmgray.n400)

      Text(message)
        .font(.pmCaption)
        .foregroundStyle(Color.pmgray.n500)

      Spacer()

      Button {
        onTap?()
      } label: {
        Text(LocalizedStrings.Common.change)
          .font(.pmCaptionMedium)
          .foregroundStyle(Color.pmindigo.n500)
      }
      .buttonStyle(.plain)
    }
  }
}
