import SwiftUI
import PromisoShared

struct NeedResponseBanner: View {
  let count: Int
  let onTap: () -> Void

  var body: some View {
    Button(action: onTap) {
      HStack(spacing: 12) {
        Image(systemName: "envelope.badge.fill")
          .font(.title3)
          .foregroundStyle(.white)

        VStack(alignment: .leading, spacing: 2) {
          Text(LocalizedStrings.Home.responseNeeded)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)

          Text(LocalizedStrings.Home.promisesToRespond(count))
            .font(.caption)
            .foregroundStyle(.white.opacity(0.9))
        }

        Spacer()

        Image(systemName: "chevron.down")
          .font(.callout)
          .foregroundStyle(.white)
      }
      .padding(14)
      .background(
        LinearGradient(
          colors: [Color.orange, Color.orange.opacity(0.8)],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .cornerRadius(12)
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 16) {
    NeedResponseBanner(count: 3) { }

    NeedResponseBanner(count: 1) { }

    NeedResponseBanner(count: 10) { }
  }
  .padding()
  .auroraBackground()
}
