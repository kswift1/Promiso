import SwiftUI

struct PromiseCardSkeleton: View {
  @State private var isAnimating = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack(alignment: .top, spacing: 12) {
        // Emoji placeholder
        Circle()
          .fill(Color(.systemGray5))
          .frame(width: 40, height: 40)

        VStack(alignment: .leading, spacing: 8) {
          // Title placeholder
          RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(width: 150, height: 18)

          // Time placeholder
          HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
              .fill(Color(.systemGray5))
              .frame(width: 14, height: 14)
            RoundedRectangle(cornerRadius: 4)
              .fill(Color(.systemGray5))
              .frame(width: 80, height: 14)
          }

          // Location placeholder
          HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
              .fill(Color(.systemGray5))
              .frame(width: 14, height: 14)
            RoundedRectangle(cornerRadius: 4)
              .fill(Color(.systemGray5))
              .frame(width: 120, height: 14)
          }

          // With placeholder
          HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
              .fill(Color(.systemGray5))
              .frame(width: 14, height: 14)
            RoundedRectangle(cornerRadius: 4)
              .fill(Color(.systemGray5))
              .frame(width: 60, height: 14)
          }
        }

        Spacer()
      }

      // Status badge placeholder
      HStack(spacing: 8) {
        Capsule()
          .fill(Color(.systemGray5))
          .frame(width: 80, height: 28)

        Spacer()
      }
    }
    .padding(16)
    .background(Color(.systemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .overlay(
      RoundedRectangle(cornerRadius: 16)
        .stroke(Color(.systemGray5), lineWidth: 1)
    )
    .opacity(isAnimating ? 0.5 : 1.0)
    .animation(
      Animation.easeInOut(duration: 0.8)
        .repeatForever(autoreverses: true),
      value: isAnimating
    )
    .onAppear {
      isAnimating = true
    }
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 16) {
    PromiseCardSkeleton()
    PromiseCardSkeleton()
    PromiseCardSkeleton()
  }
  .padding()
  .background(Color(.systemGray6))
}
