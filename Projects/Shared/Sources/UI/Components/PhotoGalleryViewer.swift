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

  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0

  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero

  @State private var dragOffset: CGSize = .zero

  private let minScale: CGFloat = 1.0
  private let maxScale: CGFloat = 5.0
  private let dismissDragThreshold: CGFloat = 150
  private let dismissVelocityThreshold: CGFloat = 500

  private var isZoomedOut: Bool {
    scale <= minScale
  }

  private var zoomedOffset: CGSize {
    guard !isZoomedOut else { return .zero }
    return CGSize(
      width: offset.width + lastOffset.width,
      height: offset.height + lastOffset.height
    )
  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        if let loadedImage {
          Image(uiImage: loadedImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height * 0.85)
            .scaleEffect(scale)
            .offset(zoomedOffset)
        } else if loadFailed {
          ZStack {
            Color(UIColor.systemGray6).opacity(0.3)
            Image(systemName: "exclamationmark.triangle")
              .font(.system(size: 40))
              .foregroundStyle(Color(UIColor.systemGray3))
          }
          .frame(width: 200, height: 200)
          .clipShape(RoundedRectangle(cornerRadius: 16))
        } else {
          ProgressView()
            .tint(.white)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .offset(y: isZoomedOut ? dragOffset.height : 0)
      .gesture(combinedGesture)
      .onTapGesture(count: 2, perform: handleDoubleTap)
    }
    .task(id: url) {
      await loadImage()
    }
  }

  // MARK: - Gestures

  private var combinedGesture: some Gesture {
    SimultaneousGesture(
      magnificationGesture,
      dragGesture
    )
  }

  private var magnificationGesture: some Gesture {
    MagnificationGesture()
      .onChanged { value in
        let delta = value / lastScale
        lastScale = value
        let newScale = scale * delta
        scale = min(max(newScale, 0.5), maxScale)
      }
      .onEnded { _ in
        lastScale = 1.0
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
          if scale < minScale {
            scale = minScale
            resetOffset()
          }
        }
      }
  }

  private var dragGesture: some Gesture {
    DragGesture()
      .onChanged { value in
        if isZoomedOut {
          let height = max(0, value.translation.height)
          dragOffset = CGSize(width: 0, height: height)
        } else {
          offset = value.translation
        }
      }
      .onEnded { value in
        if isZoomedOut {
          let verticalDrag = value.translation.height
          let velocity = value.predictedEndTranslation.height

          if verticalDrag > dismissDragThreshold || velocity > dismissVelocityThreshold {
            onDismiss()
          } else {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
              dragOffset = .zero
            }
          }
        } else {
          lastOffset = CGSize(
            width: lastOffset.width + offset.width,
            height: lastOffset.height + offset.height
          )
          offset = .zero
        }
      }
  }

  // MARK: - Actions

  private func handleDoubleTap() {
    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
      if scale > minScale {
        scale = minScale
        resetOffset()
      } else {
        scale = 2.5
      }
    }
  }

  private func resetOffset() {
    offset = .zero
    lastOffset = .zero
    dragOffset = .zero
  }

  // MARK: - Load Image

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
