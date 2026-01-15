import Nuke
import SwiftUI

/// 프로필 아바타 뷰 - 앱 전반에서 사용하는 공통 프로필 이미지 컴포넌트
public struct ProfileAvatarView: View {
  let profileImageUrl: String?
  let displayName: String
  let isCurrentUser: Bool
  let size: CGFloat
  let borderWidth: CGFloat
  let onTap: (() -> Void)?

  @State private var loadedImage: UIImage?

  public init(
    profileImageUrl: String?,
    displayName: String,
    isCurrentUser: Bool = false,
    size: CGFloat = 32,
    borderWidth: CGFloat = 2,
    onTap: (() -> Void)? = nil
  ) {
    self.profileImageUrl = profileImageUrl
    self.displayName = displayName
    self.isCurrentUser = isCurrentUser
    self.size = size
    self.borderWidth = borderWidth
    self.onTap = onTap
  }

  private var initials: String {
    if isCurrentUser { return "나" }
    guard !displayName.isEmpty else { return "?" }
    return String(displayName.prefix(1))
  }

  private var fontSize: CGFloat {
    size * 0.4
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
    .overlay(
      Circle()
        .stroke(Color.white, lineWidth: borderWidth)
    )
    .contentShape(Circle())
    .onTapGesture {
      onTap?()
    }
    .task(id: profileImageUrl) {
      await loadImage()
    }
  }

  private var fallbackContent: some View {
    Circle()
      .fill(
        LinearGradient(
          colors: [Color(red: 0.3, green: 0.5, blue: 0.9), Color(red: 0.6, green: 0.4, blue: 0.8)],
          startPoint: .topLeading,
          endPoint: .bottomTrailing
        )
      )
      .overlay(
        Text(initials)
          .font(.system(size: fontSize, weight: .bold))
          .foregroundColor(.white)
      )
  }

  private func loadImage() async {
    guard let urlString = profileImageUrl,
          let url = URL(string: urlString) else { return }
    do {
      let request = ImageRequest(url: url)
      loadedImage = try await ImagePipeline.shared.image(for: request)
    } catch {
      loadedImage = nil
    }
  }
}
