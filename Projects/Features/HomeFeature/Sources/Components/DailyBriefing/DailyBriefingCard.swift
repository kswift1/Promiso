import PromisoShared
import SwiftUI

// MARK: - DailyBriefingCard

struct DailyBriefingCard: View {
  let briefingText: String?
  let isLoading: Bool
  let onRefresh: (() -> Void)?

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // 헤더
      HStack {
        Image(systemName: "sparkles")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color.pmindigo.n500)

        Text("오늘의 브리핑")
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(.secondary)

        Spacer()

        if let onRefresh, !isLoading {
          Button {
            onRefresh()
          } label: {
            Image(systemName: "arrow.clockwise")
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(.tertiary)
          }
          .buttonStyle(.plain)
        }
      }

      // 본문
      if isLoading {
        loadingContent
      } else if let text = briefingText {
        Text(text)
          .font(.system(size: 15, weight: .regular))
          .foregroundStyle(.primary)
          .lineSpacing(4)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .adaptiveGlassCard(cornerRadius: 16)
  }

  @ViewBuilder
  private var loadingContent: some View {
    VStack(alignment: .leading, spacing: 8) {
      RoundedRectangle(cornerRadius: 4)
        .fill(Color(.systemGray5))
        .frame(height: 14)
        .shimmer()

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
