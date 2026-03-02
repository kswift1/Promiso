import SwiftUI
import Nuke

public struct ImageDetailView: View {
  let imageUrl: String?
  let displayName: String
  let onDismiss: () -> Void
  
  @State private var loadedImage: UIImage?
  
  // 줌 상태
  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  
  // 패닝 (줌인 상태에서)
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero
  
  // Dismiss 드래그 (줌아웃 상태에서)
  @State private var dragOffset: CGSize = .zero
  
  private let minScale: CGFloat = 1.0
  private let maxScale: CGFloat = 5.0
  private let dismissDragThreshold: CGFloat = 150
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
      // ✅ 배경 - 항상 검정 유지
      Color.black
        .ignoresSafeArea()
        .onTapGesture {
          onDismiss()
        }
      
      // 콘텐츠 영역
      GeometryReader { geometry in
        ZStack {
          // 이미지 콘텐츠
          imageContent(geometry: geometry)
            .scaleEffect(scale)
            .offset(zoomedOffset)
          
          // 닫기 버튼
          VStack {
            HStack {
              Spacer()
              closeButton
                .opacity(isZoomedOut ? 1.0 : 0.0)
            }
            .padding(.horizontal, 16)
            .padding(.top, SafeArea.topInset + 8)
            Spacer()
          }
        }
        // 콘텐츠만 수직 이동
        .offset(y: isZoomedOut ? dragOffset.height : 0)
        .gesture(combinedGesture)
        .onTapGesture(count: 2, perform: handleDoubleTap)
      }
    }
    .navigationBarBackButtonHidden()
    .toolbar(.hidden, for: .navigationBar)
    .task(id: imageUrl) {
      await loadImage()
    }
  }
  
  // MARK: - Computed Properties
  
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
          // ✅ 아래로 드래그만 허용 (height > 0)
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
          
          // ✅ 아래로 드래그했을 때만 dismiss 판정
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
  
  // MARK: - Image Content
  
  @ViewBuilder
  private func imageContent(geometry: GeometryProxy) -> some View {
    if let loadedImage {
      Image(uiImage: loadedImage)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height * 0.8)
    } else {
      fallbackView(geometry: geometry)
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

