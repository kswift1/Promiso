import ResourceKit
import SwiftUI

/// 로그인이 필요할 때 표시되는 뷰
struct NotLoggedInView: View {
  var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "person.crop.circle.badge.questionmark")
        .font(.system(size: 36, weight: .light))
        .foregroundStyle(Color.pmindigo.n300)
        .symbolRenderingMode(.hierarchical)

      VStack(spacing: 4) {
        Text("로그인이 필요해요")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.primary)

        Text("탭하여 앱 열기")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetURL(URL(string: "promiso://home"))
  }
}

#if DEBUG
#Preview("Not Logged In") {
  NotLoggedInView()
    .frame(width: 155, height: 155)
    .background(Color(.systemBackground))
}
#endif
