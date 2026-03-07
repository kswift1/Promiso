import PromisoShared
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
      Button {
        onTap()
      } label: {
        cardContent
      }
      .buttonStyle(.plain)
      .contentShape(Rectangle())
    }
  }

  private var cardContent: some View {
    VStack(alignment: .leading, spacing: 10) {
      // 헤더 행
      HStack(spacing: 6) {
        // Pro 뱃지
        proBadge

        Spacer()

        if let onRefresh, !isLoading {
          Button {
            onRefresh()
          } label: {
            Image(systemName: "arrow.clockwise")
              .font(.system(size: 11, weight: .medium))
              .foregroundStyle(.tertiary)
          }
          .buttonStyle(.plain)
        }
      }

      // 본문
      if isLoading {
        loadingContent
      } else if let summary {
        // Summary (항상 표시)
        Text(summary)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(isExpanded ? nil : 1)

        // Detail (expand 시)
        if isExpanded, let detail {
          Text(detail)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(.secondary)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
      }
    }
    .padding(14)
    .frame(maxWidth: .infinity, alignment: .leading)
    .adaptiveGlassCard(cornerRadius: 16)
  }

  // MARK: - Pro Badge

  private var proBadge: some View {
    HStack(spacing: 4) {
      Image(systemName: "sparkles")
        .font(.system(size: 10, weight: .bold))

      Text("PRO")
        .font(.system(size: 10, weight: .bold))
    }
    .foregroundStyle(.white)
    .padding(.horizontal, 8)
    .padding(.vertical, 3)
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
    HStack(spacing: 0) {
      RoundedRectangle(cornerRadius: 4)
        .fill(Color(.systemGray5))
        .frame(height: 14)
        .shimmer()
    }
  }
}
