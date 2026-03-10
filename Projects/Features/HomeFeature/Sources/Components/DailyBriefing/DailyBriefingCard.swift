import PromisoShared
import ResourceKit
import SwiftUI

// MARK: - DailyBriefingCard

struct DailyBriefingCard: View {
  let summary: String?
  let detail: String?
  let isLoading: Bool
  let isExpanded: Bool
  let isUpdated: Bool
  let isPro: Bool
  let isNotificationDenied: Bool
  let isLocationDenied: Bool
  let onTap: () -> Void
  let onOpenNotificationSettings: (() -> Void)?
  let onOpenLocationSettings: (() -> Void)?
  let onReportError: (() -> Void)?
  let onProUpgradeTapped: (() -> Void)?

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
                      .blur(radius: 6)

                    Button {
                      onProUpgradeTapped?()
                    } label: {
                      HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                          .font(.system(size: 13, weight: .semibold))
                        Text("PRO로 전체 보기")
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

      Text("데일리 브리핑")
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
          message: "알림이 꺼져 있어 매일 브리핑을 받아볼 수 없어요",
          onTap: onOpenNotificationSettings
        )
      }
      if isLocationDenied {
        permissionRow(
          icon: "location.slash",
          message: "현재 위치 권한이 꺼져 있어 날씨와 이동시간을 알려드리기 어려워요",
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
        Text("브리핑 내용이 이상한가요?")
          .font(.pmCaption)
      }
      .foregroundStyle(Color.pmgray.n400)
      .frame(maxWidth: .infinity, alignment: .center)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
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
        Text("변경")
          .font(.pmCaptionMedium)
          .foregroundStyle(Color.pmindigo.n500)
      }
      .buttonStyle(.plain)
    }
  }
}
