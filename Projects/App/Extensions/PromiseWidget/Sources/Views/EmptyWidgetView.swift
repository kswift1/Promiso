import ResourceKit
import SwiftUI

/// 약속이 없을 때 표시되는 뷰
struct EmptyWidgetView: View {
  let icon: String
  let message: String
  var hint: String? = nil

  init(icon: String = "calendar", message: String, hint: String? = nil) {
    self.icon = icon
    self.message = message
    self.hint = hint
  }

  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: icon)
        .font(.system(size: 32, weight: .light))
        .foregroundStyle(Color.pmindigo.n300)
        .symbolRenderingMode(.hierarchical)

      VStack(spacing: 4) {
        Text(message)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.primary)

        if let hint {
          Text(hint)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetURL(URL(string: "promiso://home"))
  }
}

#if DEBUG
#Preview("Empty - Simple") {
  EmptyWidgetView(message: "예정된 약속이 없어요")
    .frame(width: 155, height: 155)
    .background(Color(.systemBackground))
}

#Preview("Empty - With Hint") {
  EmptyWidgetView(
    icon: "calendar.badge.plus",
    message: "예정된 약속이 없어요",
    hint: "새 약속을 만들어보세요"
  )
  .frame(width: 155, height: 155)
  .background(Color(.systemBackground))
}
#endif
