import Nuke
import SwiftUI

public struct ImageDetailView: View {
  let imageUrl: String?
  let displayName: String
  let onDismiss: () -> Void

  @State private var loadedImage: UIImage?
  @State private var dragOffset: CGFloat = 0
  @State private var isZoomed = false

  private let dismissThreshold: CGFloat = 150
  private let dismissVelocityThreshold: CGFloat = 500

  public init(
    imageUrl: String?,
    displayName: String,
    onDismiss: @escaping () -> Void
  ) {
    self.imageUrl = imageUrl
    self.displayName = displayName
    self.onDismiss = onDismiss
  }

  public var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea()
        .onTapGesture {
          if !isZoomed { onDismiss() }
        }

      GeometryReader { geometry in
        ZStack {
          if let loadedImage {
            ZoomableImageView(
              image: loadedImage,
              onZoomChanged: { zoomed in
                isZoomed = zoomed
              },
              onDismissDrag: { offset in
                dragOffset = offset
              },
              onDismissDragEnded: { translation, velocity in
                if translation > dismissThreshold || velocity > dismissVelocityThreshold {
                  onDismiss()
                } else {
                  withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    dragOffset = 0
                  }
                }
              }
            )
          } else {
            fallbackView(geometry: geometry)
          }

          VStack {
            HStack {
              Spacer()
              closeButton
                .opacity(isZoomed ? 0.0 : 1.0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            Spacer()
          }
        }
        .offset(y: isZoomed ? 0 : dragOffset)
      }
    }
    .background(ClearBackground())
    .task(id: imageUrl) {
      await loadImage()
    }
  }

  // MARK: - Close Button

  private var closeButton: some View {
    Button {
      onDismiss()
    } label: {
      Image(systemName: "xmark")
        .font(.title3)
        .fontWeight(.medium)
        .foregroundStyle(.white)
        .frame(width: 44, height: 44)
        .background(.ultraThinMaterial.opacity(0.5))
        .clipShape(Circle())
    }
  }

  // MARK: - Fallback View

  private func fallbackView(geometry: GeometryProxy) -> some View {
    let size = min(geometry.size.width, geometry.size.height) * 0.5

    return Circle()
      .fill(
        LinearGradient(
          colors: [Color(red: 0.3, green: 0.5, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 0.8)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .frame(width: size, height: size)
      .overlay(
        Text(initials)
          .font(.system(size: size * 0.4, weight: .bold))
          .foregroundColor(.white)
      )
  }

  private var initials: String {
    guard !displayName.isEmpty else { return "?" }
    return String(displayName.prefix(1))
  }

  // MARK: - Load Image

  private func loadImage() async {
    guard let urlString = imageUrl,
          let url = URL(string: urlString) else { return }
    loadedImage = await ImageLoader.loadImage(from: url)
  }
}

// MARK: - Clear Background Helper

struct ClearBackground: UIViewRepresentable {
  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    DispatchQueue.main.async {
      view.superview?.superview?.backgroundColor = .clear
    }
    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {}
}
