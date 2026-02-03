import AppIntents
import ResourceKit
import SwiftUI

/// 위젯 하단 푸터 (업데이트 시간 + 새로고침 버튼)
struct WidgetFooterView: View {
  let updatedAt: Date

  var body: some View {
    HStack(spacing: 6) {
      // 업데이트 시간
      Text(formatUpdatedTime(updatedAt))
        .font(.caption2)
        .foregroundStyle(.tertiary)

      // 새로고침 버튼
      Button(intent: RefreshWidgetIntent()) {
        Image(systemName: "arrow.clockwise")
          .font(.system(size: 10, weight: .medium))
          .foregroundStyle(.secondary)
          .frame(width: 22, height: 22)
          .background(Color.secondary.opacity(0.12), in: Circle())
      }
      .buttonStyle(.plain)
    }
  }

  private func formatUpdatedTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }
}

#if DEBUG
#Preview("Footer") {
  WidgetFooterView(updatedAt: Date())
    .padding()
    .background(Color(.systemBackground))
}
#endif
