import SwiftUI

/// 약속이 없을 때 표시되는 뷰
struct EmptyWidgetView: View {
  let message: String

  var body: some View {
    VStack(spacing: 8) {
      Image(systemName: "calendar")
        .font(.largeTitle)
        .foregroundStyle(.secondary)

      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
