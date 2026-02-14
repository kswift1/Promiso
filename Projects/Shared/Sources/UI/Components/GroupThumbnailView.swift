import Nuke
import SwiftUI

/// 이미지 로딩 상태
private enum ImageLoadingState {
  case idle
  case loading
  case loaded(UIImage)
  case failed
}

/// 그룹 썸네일 뷰 - 앱 전반에서 사용하는 공통 그룹 이미지 컴포넌트
public struct GroupThumbnailView: View {
  let imageUrl: String?
  let name: String
  let size: CGFloat

  @State private var loadingState: ImageLoadingState = .idle

  public init(
    imageUrl: String?,
    name: String,
    size: CGFloat = 20
  ) {
    self.imageUrl = imageUrl
    self.name = name
    self.size = size
  }

  private var iconSize: CGFloat {
    size * 0.45
  }

  public var body: some View {
    ZStack {
      // 배경 (항상 표시)
      backgroundGradient

      // 상태별 컨텐츠
      switch loadingState {
      case .idle, .failed:
        fallbackIcon
      case .loading:
        ProgressView()
          .progressViewStyle(.circular)
          .scaleEffect(size / 56)
          .tint(.white.opacity(0.9))
      case .loaded(let image):
        Image(uiImage: image)
          .resizable()
          .aspectRatio(contentMode: .fill)
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .task(id: imageUrl) {
      await loadImage()
    }
  }

  private var backgroundGradient: some View {
    Circle()
      .fill(
        LinearGradient(
          colors: [Color.pmindigo.n100, Color.pmindigo.n200],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
  }

  private var fallbackIcon: some View {
    Image(systemName: "person.2.fill")
      .font(.system(size: iconSize, weight: .medium))
      .foregroundStyle(Color.pmindigo.n500)
  }

  private func loadImage() async {
    guard let urlString = imageUrl,
          let url = URL(string: urlString) else {
      loadingState = .idle
      return
    }
    loadingState = .loading
    if let image = await ImageLoader.loadImage(from: url) {
      loadingState = .loaded(image)
    } else {
      loadingState = .failed
    }
  }
}

// MARK: - Preview

#Preview("Group Thumbnail - Sizes") {
  VStack(spacing: 20) {
    Text("Fallback (no image)")
      .font(.caption)
    HStack(spacing: 16) {
      GroupThumbnailView(imageUrl: nil, name: "가족", size: 32)
      GroupThumbnailView(imageUrl: nil, name: "친구들", size: 44)
      GroupThumbnailView(imageUrl: nil, name: "동료", size: 56)
      GroupThumbnailView(imageUrl: nil, name: "모임", size: 60)
    }

    Text("With Image URL")
      .font(.caption)
    HStack(spacing: 16) {
      GroupThumbnailView(imageUrl: "https://picsum.photos/seed/g1/200", name: "러닝", size: 32)
      GroupThumbnailView(imageUrl: "https://picsum.photos/seed/g2/200", name: "독서", size: 44)
      GroupThumbnailView(imageUrl: "https://picsum.photos/seed/g3/200", name: "요리", size: 56)
      GroupThumbnailView(imageUrl: "https://picsum.photos/seed/g4/200", name: "여행", size: 60)
    }
  }
  .padding()
}
