import SwiftUI
import PromisoShared

// MARK: - Today Empty State

/// 오늘 일정이 없을 때 표시하는 뷰
struct TodayEmptyState: View {
  var body: some View {
    VStack(spacing: 12) {
      // 태양 이모지
      Text("☀️")
        .font(.system(size: 48))

      // 텍스트
      VStack(spacing: 4) {
        Text("오늘은 약속이 없어요")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        Text("여유로운 하루 되세요!")
          .font(.caption)
          .foregroundStyle(.tertiary)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 32)
  }
}

// MARK: - Preview

#Preview {
  VStack {
    TodayEmptyState()
  }
  .padding()
  .background(Color(.systemGray6))
  .clipShape(RoundedRectangle(cornerRadius: 20))
  .padding()
  .auroraBackground()
}
