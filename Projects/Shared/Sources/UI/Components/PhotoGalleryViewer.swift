import Nuke
import SwiftUI

// MARK: - PhotoGalleryViewer

/// 공통 풀스크린 이미지 갤러리 뷰어
/// 좌우 스와이프 페이징, 핀치 줌, 더블탭 줌, 아래로 드래그 dismiss 지원
public struct PhotoGalleryViewer: View {
  let imageUrls: [String]
  let initialIndex: Int
  let onDismiss: () -> Void

  @State private var currentIndex: Int

  public init(
    imageUrls: [String],
    initialIndex: Int = 0,
    onDismiss: @escaping () -> Void
  ) {
    self.imageUrls = imageUrls
    self.initialIndex = initialIndex
    self.onDismiss = onDismiss
    self._currentIndex = State(initialValue: initialIndex)
  }

  public var body: some View {
    ZStack {
      Color.black
        .ignoresSafeArea()

      TabView(selection: $currentIndex) {
        ForEach(imageUrls.indices, id: \.self) { index in
          ZoomableImagePage(
            url: imageUrls[index],
            onDismiss: onDismiss
          )
          .tag(index)
        }
      }
      .tabViewStyle(.page(indexDisplayMode: imageUrls.count > 1 ? .automatic : .never))
      .indexViewStyle(.page(backgroundDisplayMode: .automatic))

      // 닫기 버튼
      VStack {
        HStack {
          Spacer()
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
        .padding(.horizontal, 16)
        .padding(.top, 8)
        Spacer()
      }
    }
    .background(ClearBackground())
  }
}

// MARK: - Zoomable Image Page

private struct ZoomableImagePage: View {
  let url: String
  let onDismiss: () -> Void

  @State private var loadedImage: UIImage?
  @State private var loadFailed = false
  @State private var dragOffset: CGFloat = 0
  @State private var isZoomed = false

  private let dismissThreshold: CGFloat = 150
  private let dismissVelocityThreshold: CGFloat = 500

  var body: some View {
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
      } else if loadFailed {
        ZStack {
          Color(.systemGray6).opacity(0.3)
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 40))
            .foregroundStyle(Color(.systemGray3))
        }
        .frame(width: 200, height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 16))
      } else {
        ProgressView()
          .tint(.white)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .offset(y: isZoomed ? 0 : dragOffset)
    .task(id: url) {
      await loadImage()
    }
  }

  private func loadImage() async {
    guard let imageUrl = URL(string: url) else {
      loadFailed = true
      return
    }
    if let image = await ImageLoader.loadImage(from: imageUrl) {
      loadedImage = image
    } else {
      loadFailed = true
    }
  }
}
