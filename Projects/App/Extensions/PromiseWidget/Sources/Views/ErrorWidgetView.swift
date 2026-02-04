import ResourceKit
import SwiftUI

/// 에러 발생 시 표시되는 뷰
struct ErrorWidgetView: View {
  var body: some View {
    VStack(spacing: 10) {
      Image(systemName: "exclamationmark.icloud")
        .font(.system(size: 32, weight: .light))
        .foregroundStyle(Color.pmindigo.n300)
        .symbolRenderingMode(.hierarchical)

      VStack(spacing: 4) {
        Text(WidgetStrings.Error.title)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.primary)

        Text(WidgetStrings.Error.retryHint)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetURL(URL(string: "promiso://home"))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(WidgetStrings.Error.title). \(WidgetStrings.Error.retryHint)")
  }
}

#if DEBUG
#Preview("Error") {
  ErrorWidgetView()
    .frame(width: 155, height: 155)
    .background(Color(.systemBackground))
}
#endif
