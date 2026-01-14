import Nuke
import SwiftUI

/// 그룹 썸네일 뷰 - 앱 전반에서 사용하는 공통 그룹 이미지 컴포넌트
public struct GroupThumbnailView: View {
  let imageUrl: String?
  let name: String
  let size: CGFloat

  @State private var loadedImage: UIImage?

  public init(
    imageUrl: String?,
    name: String,
    size: CGFloat = 20
  ) {
    self.imageUrl = imageUrl
    self.name = name
    self.size = size
  }

  private var initials: String {
    guard !name.isEmpty else { return "G" }
    return String(name.prefix(1))
  }

  private var fontSize: CGFloat {
    size * 0.45
  }

  private var iconSize: CGFloat {
    size * 0.6
  }

  public var body: some View {
    ZStack {
      fallbackContent

      if let loadedImage {
        Image(uiImage: loadedImage)
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

  private var fallbackContent: some View {
    Circle()
      .fill(
        LinearGradient(
          colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.5)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        Image(systemName: "person.2.fill")
          .font(.system(size: iconSize, weight: .medium))
          .foregroundColor(.white.opacity(0.9))
      )
  }

  private func loadImage() async {
    guard let urlString = imageUrl,
          let url = URL(string: urlString) else { return }
    do {
      let request = ImageRequest(url: url)
      loadedImage = try await ImagePipeline.shared.image(for: request)
    } catch {
      loadedImage = nil
    }
  }
}

// MARK: - Preview

#Preview("Group Thumbnail - With Image") {
  HStack(spacing: 16) {
    GroupThumbnailView(imageUrl: nil, name: "가족", size: 16)
    GroupThumbnailView(imageUrl: nil, name: "친구들", size: 20)
    GroupThumbnailView(imageUrl: nil, name: "동료", size: 24)
    GroupThumbnailView(imageUrl: nil, name: "모임", size: 32)
  }
  .padding()
}
