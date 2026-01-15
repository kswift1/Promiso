import Nuke
import SwiftUI

/// 이미지 상세 보기 뷰 - 프로필 이미지 등을 전체화면으로 확대해서 볼 수 있는 뷰
public struct ImageDetailView: View {
  let imageUrl: String?
  let displayName: String
  let onDismiss: () -> Void

  @State private var loadedImage: UIImage?
  @State private var scale: CGFloat = 1.0
  @State private var lastScale: CGFloat = 1.0
  @State private var offset: CGSize = .zero
  @State private var lastOffset: CGSize = .zero

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
    GeometryReader { geometry in
      ZStack {
        // 배경
        Color.black
          .ignoresSafeArea()
          .onTapGesture {
            onDismiss()
          }

        // 이미지 콘텐츠
        VStack(spacing: 0) {
          // 상단 헤더
          headerView
            .padding(.horizontal, 16)
            .padding(.top, 8)

          Spacer()

          // 이미지
          imageContent(geometry: geometry)

          Spacer()

          // 하단 이름
          if !displayName.isEmpty {
            Text(displayName)
              .font(.headline)
              .foregroundStyle(.white)
              .padding(.bottom, 32)
          }
        }
      }
    }
    .task(id: imageUrl) {
      await loadImage()
    }
  }

  // MARK: - Header View

  private var headerView: some View {
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
          .contentShape(Rectangle())
      }
    }
  }

  // MARK: - Image Content

  @ViewBuilder
  private func imageContent(geometry: GeometryProxy) -> some View {
    if let loadedImage {
      Image(uiImage: loadedImage)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .scaleEffect(scale)
        .offset(offset)
        .gesture(
          MagnificationGesture()
            .onChanged { value in
              let delta = value / lastScale
              lastScale = value
              scale = min(max(scale * delta, 1.0), 4.0)
            }
            .onEnded { _ in
              lastScale = 1.0
              if scale <= 1.0 {
                withAnimation(.spring(response: 0.3)) {
                  offset = .zero
                }
              }
            }
        )
        .simultaneousGesture(
          DragGesture()
            .onChanged { value in
              if scale > 1.0 {
                offset = CGSize(
                  width: lastOffset.width + value.translation.width,
                  height: lastOffset.height + value.translation.height
                )
              }
            }
            .onEnded { _ in
              lastOffset = offset
            }
        )
        .onTapGesture(count: 2) {
          withAnimation(.spring(response: 0.3)) {
            if scale > 1.0 {
              scale = 1.0
              offset = .zero
              lastOffset = .zero
            } else {
              scale = 2.0
            }
          }
        }
        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height * 0.7)
    } else {
      // 로딩 또는 fallback
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
    do {
      let request = ImageRequest(url: url)
      loadedImage = try await ImagePipeline.shared.image(for: request)
    } catch {
      loadedImage = nil
    }
  }
}

// MARK: - Preview

#Preview("Image Detail View") {
  ImageDetailView(
    imageUrl: "https://picsum.photos/400",
    displayName: "홍길동",
    onDismiss: {}
  )
}

#Preview("Image Detail View - No Image") {
  ImageDetailView(
    imageUrl: nil,
    displayName: "김철수",
    onDismiss: {}
  )
}
