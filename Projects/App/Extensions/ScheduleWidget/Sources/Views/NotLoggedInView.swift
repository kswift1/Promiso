import PromisoShared
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
        Text(LocalizedStrings.Widget.authNotLoggedInTitle)
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.primary)

        Text(LocalizedStrings.Widget.authOpenAppHint)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetURL(AppConstants.Deeplink.url(path: "home"))
    .accessibilityElement(children: .combine)
    .accessibilityLabel("\(LocalizedStrings.Widget.authNotLoggedInTitle). \(LocalizedStrings.Widget.authOpenAppHint)")
  }
}

#if DEBUG
#Preview("Not Logged In") {
  NotLoggedInView()
    .frame(width: 155, height: 155)
    .background(Color(.systemBackground))
}
#endif
