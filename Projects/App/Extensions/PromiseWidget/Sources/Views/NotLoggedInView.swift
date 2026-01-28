import SwiftUI

/// 로그인이 필요할 때 표시되는 뷰
struct NotLoggedInView: View {
  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "person.crop.circle.badge.questionmark")
        .font(.largeTitle)
        .foregroundStyle(.secondary)

      Text("로그인이 필요해요")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Text("탭하여 앱 열기")
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .widgetURL(URL(string: "promiso://home"))
  }
}
