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
        Text("데이터를 불러올 수 없어요")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.primary)

        Text("탭하여 다시 시도")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetURL(URL(string: "promiso://home"))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("데이터를 불러올 수 없어요. 탭하여 다시 시도")
  }
}

#if DEBUG
#Preview("Error") {
  ErrorWidgetView()
    .frame(width: 155, height: 155)
    .background(Color(.systemBackground))
}
#endif
