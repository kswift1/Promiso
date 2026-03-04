import SwiftUI
import UIKit

// MARK: - ZoomableImageView

/// UIScrollView 기반 줌 가능 이미지 뷰
/// - 핀치 줌 (1x ~ 5x)
/// - 더블탭 줌 토글 (1x ↔ 2.5x)
/// - 줌인 상태: UIScrollView 팬으로 이미지 이동
/// - 줌아웃 상태: 수직 드래그 dismiss (수평은 패스스루 → TabView 페이징)
struct ZoomableImageView: UIViewRepresentable {
  let image: UIImage
  let onZoomChanged: (Bool) -> Void
  let onDismissDrag: (CGFloat) -> Void
  let onDismissDragEnded: (CGFloat, CGFloat) -> Void

  func makeUIView(context: Context) -> ZoomableImageContainer {
    ZoomableImageContainer(
      image: image,
      onZoomChanged: onZoomChanged,
      onDismissDrag: onDismissDrag,
      onDismissDragEnded: onDismissDragEnded
    )
  }

  func updateUIView(_ container: ZoomableImageContainer, context: Context) {
    container.updateCallbacks(
      onZoomChanged: onZoomChanged,
      onDismissDrag: onDismissDrag,
      onDismissDragEnded: onDismissDragEnded
    )
  }
}

// MARK: - ZoomableImageContainer

final class ZoomableImageContainer: UIView {
  private let scrollView = UIScrollView()
  private let imageView = UIImageView()
  private var dismissPan: UIPanGestureRecognizer!

  var onZoomChanged: (Bool) -> Void
  var onDismissDrag: (CGFloat) -> Void
  var onDismissDragEnded: (CGFloat, CGFloat) -> Void

  private var lastBoundsSize: CGSize = .zero

  init(
    image: UIImage,
    onZoomChanged: @escaping (Bool) -> Void,
    onDismissDrag: @escaping (CGFloat) -> Void,
    onDismissDragEnded: @escaping (CGFloat, CGFloat) -> Void
  ) {
    self.onZoomChanged = onZoomChanged
    self.onDismissDrag = onDismissDrag
    self.onDismissDragEnded = onDismissDragEnded
    super.init(frame: .zero)
    setupScrollView()
    setupImageView(with: image)
    setupGestures()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  func updateCallbacks(
    onZoomChanged: @escaping (Bool) -> Void,
    onDismissDrag: @escaping (CGFloat) -> Void,
    onDismissDragEnded: @escaping (CGFloat, CGFloat) -> Void
  ) {
    self.onZoomChanged = onZoomChanged
    self.onDismissDrag = onDismissDrag
    self.onDismissDragEnded = onDismissDragEnded
  }

  // MARK: - Setup

  private func setupScrollView() {
    scrollView.delegate = self
    scrollView.minimumZoomScale = 1.0
    scrollView.maximumZoomScale = 5.0
    scrollView.showsHorizontalScrollIndicator = false
    scrollView.showsVerticalScrollIndicator = false
    scrollView.bouncesZoom = true
    scrollView.contentInsetAdjustmentBehavior = .never
    scrollView.translatesAutoresizingMaskIntoConstraints = false

    // 1x 줌: pan 비활성화 → 수평 터치가 TabView로 전달
    scrollView.panGestureRecognizer.isEnabled = false

    addSubview(scrollView)
    NSLayoutConstraint.activate([
      scrollView.topAnchor.constraint(equalTo: topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
      scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
    ])
  }

  private func setupImageView(with image: UIImage) {
    imageView.image = image
    imageView.contentMode = .scaleAspectFit
    scrollView.addSubview(imageView)
  }

  private func setupGestures() {
    let doubleTap = UITapGestureRecognizer(
      target: self, action: #selector(handleDoubleTap(_:))
    )
    doubleTap.numberOfTapsRequired = 2
    scrollView.addGestureRecognizer(doubleTap)

    dismissPan = UIPanGestureRecognizer(
      target: self, action: #selector(handleDismissPan(_:))
    )
    dismissPan.delegate = self
    addGestureRecognizer(dismissPan)
  }

  // MARK: - Layout

  override func layoutSubviews() {
    super.layoutSubviews()
    guard bounds.size != .zero, bounds.size != lastBoundsSize else { return }
    lastBoundsSize = bounds.size
    scrollView.zoomScale = 1.0
    updateImageLayout()
  }

  private func updateImageLayout() {
    guard let imageSize = imageView.image?.size,
          imageSize.width > 0, imageSize.height > 0
    else { return }

    let widthRatio = bounds.width / imageSize.width
    let heightRatio = bounds.height / imageSize.height
    let fitScale = min(widthRatio, heightRatio)
    let fittedSize = CGSize(
      width: imageSize.width * fitScale,
      height: imageSize.height * fitScale
    )

    imageView.frame = CGRect(origin: .zero, size: fittedSize)
    scrollView.contentSize = fittedSize
    centerImage()
  }

  private func centerImage() {
    let scaledWidth = scrollView.contentSize.width * scrollView.zoomScale
    let scaledHeight = scrollView.contentSize.height * scrollView.zoomScale
    let offsetX = max((bounds.width - scaledWidth) / 2, 0)
    let offsetY = max((bounds.height - scaledHeight) / 2, 0)
    scrollView.contentInset = UIEdgeInsets(
      top: offsetY, left: offsetX, bottom: offsetY, right: offsetX
    )
  }

  // MARK: - Gesture Handlers

  @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
    if scrollView.zoomScale > scrollView.minimumZoomScale {
      scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
    } else {
      let point = gesture.location(in: imageView)
      let targetScale: CGFloat = 2.5
      let size = CGSize(
        width: scrollView.bounds.width / targetScale,
        height: scrollView.bounds.height / targetScale
      )
      let origin = CGPoint(
        x: point.x - size.width / 2,
        y: point.y - size.height / 2
      )
      scrollView.zoom(to: CGRect(origin: origin, size: size), animated: true)
    }
  }

  @objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
    let translation = gesture.translation(in: self)
    switch gesture.state {
    case .changed:
      onDismissDrag(max(0, translation.y))
    case .ended, .cancelled:
      onDismissDragEnded(translation.y, gesture.velocity(in: self).y)
    default:
      break
    }
  }

  private func updateGestureState(isZoomed: Bool) {
    scrollView.panGestureRecognizer.isEnabled = isZoomed
    dismissPan.isEnabled = !isZoomed
  }
}

// MARK: - UIScrollViewDelegate

extension ZoomableImageContainer: UIScrollViewDelegate {
  func viewForZooming(in scrollView: UIScrollView) -> UIView? {
    imageView
  }

  func scrollViewDidZoom(_ scrollView: UIScrollView) {
    centerImage()
    let isZoomed = scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
    updateGestureState(isZoomed: isZoomed)
    onZoomChanged(isZoomed)
  }

  func scrollViewDidEndZooming(
    _ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat
  ) {
    let isZoomed = scale > scrollView.minimumZoomScale + 0.01
    updateGestureState(isZoomed: isZoomed)
    onZoomChanged(isZoomed)
  }
}

// MARK: - UIGestureRecognizerDelegate

extension ZoomableImageContainer: UIGestureRecognizerDelegate {
  override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard gestureRecognizer === dismissPan else { return true }
    let velocity = dismissPan.velocity(in: self)
    return velocity.y > 0 && abs(velocity.y) > abs(velocity.x)
  }
}
