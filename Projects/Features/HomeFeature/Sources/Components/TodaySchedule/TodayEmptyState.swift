import SwiftUI
import PromisoShared

// MARK: - Today Empty State

/// 오늘 일정이 없을 때 표시하는 뷰
struct TodayEmptyState: View {
  var body: some View {
    HStack(spacing: 16) {
      // 아이콘 영역
      ZStack {
        Circle()
          .fill(Color.pmindigo.n500.opacity(0.1))
          .frame(width: 56, height: 56)

        Text("☀️")
          .font(.system(size: 28))
      }

      // 텍스트 영역
      VStack(alignment: .leading, spacing: 4) {
        Text("오늘은 약속이 없어요")
          .font(.subheadline)
          .fontWeight(.semibold)
          .foregroundStyle(.primary)

        Text("여유로운 하루 되세요!")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(.vertical, 8)
  }
}

// MARK: - Preview

#Preview {
  VStack {
    TodayEmptyState()
  }
  .padding()
  .auroraBackground()
}
