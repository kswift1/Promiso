import SwiftUI
import PromisoShared

// MARK: - Today Empty State

/// 오늘 일정이 없을 때 표시하는 뷰
struct TodayEmptyState: View {
  var body: some View {
    VStack(spacing: 12) {
      // 이모지
      Text("☀️")
        .font(.system(size: 40))

      // 메시지
      VStack(spacing: 4) {
        Text("오늘은 약속이 없어요")
          .font(.subheadline)
          .fontWeight(.medium)
          .foregroundStyle(.primary)

        Text("여유로운 하루 보내세요")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 8)
  }
}

// MARK: - Preview

#Preview {
  TodayEmptyState()
    .padding()
    .auroraBackground()
}
