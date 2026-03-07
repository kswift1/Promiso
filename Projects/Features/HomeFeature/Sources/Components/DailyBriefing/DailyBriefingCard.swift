import PromisoShared
import ResourceKit
import SwiftUI

// MARK: - DailyBriefingCard

struct DailyBriefingCard: View {
  let summary: String?
  let detail: String?
  let isLoading: Bool
  let isExpanded: Bool
  let onTap: () -> Void
  let onRefresh: (() -> Void)?

  var body: some View {
    if isLoading || summary != nil {
      VStack(alignment: .leading, spacing: 0) {
        // 헤더 (탭 가능)
        Button {
          onTap()
        } label: {
          cardHeader
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        // 콘텐츠 (expanded일 때만)
        if isExpanded {
          Divider()
            .padding(.horizontal, 16)

          if isLoading {
            loadingContent
              .padding(.horizontal, 16)
              .padding(.vertical, 16)
          } else if let summary {
            VStack(alignment: .leading, spacing: 8) {
              Text(summary)
                .font(.pmSubheadlineMedium)
                .foregroundStyle(.primary)

              if let detail {
                Text(detail)
                  .font(.pmSubheadline)
                  .foregroundStyle(.secondary)
                  .lineSpacing(4)
                  .fixedSize(horizontal: false, vertical: true)
              }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .transition(.opacity.combined(with: .move(edge: .top)))
          }
        }
      }
      .adaptiveGlassCard(cornerRadius: 20)
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

      Spacer()

      if let onRefresh, !isLoading {
        Button {
          onRefresh()
        } label: {
          Image(systemName: "arrow.clockwise")
            .font(.pmSubheadline)
            .foregroundStyle(Color.pmgray.n400)
        }
        .buttonStyle(.plain)
      }

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
}
