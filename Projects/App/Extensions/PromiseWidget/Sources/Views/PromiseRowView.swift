import PromisoShared
import ResourceKit
import SwiftUI

/// 약속 목록의 행 뷰
struct PromiseRowView: View {
  let promise: WidgetPromiseData

  var body: some View {
    HStack(spacing: 8) {
      Text(promise.emoji)
        .font(.body)

      Text(promise.title)
        .font(.subheadline)
        .lineLimit(1)

      Spacer()

      Text(formatTime(promise.startAt))
        .font(.subheadline.bold())
        .foregroundStyle(Color.pmindigo.n500)

      if let location = promise.location {
        Text(location)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .contentShape(Rectangle())
  }

  private func formatTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }
}
