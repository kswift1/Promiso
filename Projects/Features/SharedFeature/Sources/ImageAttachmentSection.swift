import Nuke
import PhotosUI
import SwiftUI
import PromisoShared

// MARK: - Image Attachment Section

/// 이미지 첨부 섹션 (약속/개인 일정 생성·수정에서 공유 사용)
public struct ImageAttachmentSection: View {
  let existingImageUrls: [String]
  let localImages: [Data]
  let maxCount: Int
  let isUploading: Bool
  let onPhotosSelected: ([PhotosPickerItem]) -> Void
  let onRemoveExisting: (Int) -> Void
  let onRemoveLocal: (Int) -> Void

  public init(
    existingImageUrls: [String] = [],
    localImages: [Data] = [],
    maxCount: Int = 3,
    isUploading: Bool = false,
    onPhotosSelected: @escaping ([PhotosPickerItem]) -> Void,
    onRemoveExisting: @escaping (Int) -> Void,
    onRemoveLocal: @escaping (Int) -> Void
  ) {
    self.existingImageUrls = existingImageUrls
    self.localImages = localImages
    self.maxCount = maxCount
    self.isUploading = isUploading
    self.onPhotosSelected = onPhotosSelected
    self.onRemoveExisting = onRemoveExisting
    self.onRemoveLocal = onRemoveLocal
  }

  private var totalCount: Int {
    existingImageUrls.count + localImages.count
  }

  private var remainingSlots: Int {
    max(0, maxCount - totalCount)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack {
        Image(systemName: "photo")
          .font(.body)
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 24)

        Text("사진")
          .font(.body)
          .foregroundStyle(Color.pmtext.primary)

        Spacer()

        Text("\(totalCount)/\(maxCount)")
          .font(.system(size: 13))
          .foregroundStyle(Color.pmtext.secondary)
      }

      if totalCount > 0 || remainingSlots > 0 {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            // 기존 이미지 (서버에 업로드된)
            ForEach(existingImageUrls.indices, id: \.self) { index in
              RemoteImageThumbnail(url: existingImageUrls[index]) {
                onRemoveExisting(index)
              }
            }

            // 로컬 이미지 (새로 선택된)
            ForEach(localImages.indices, id: \.self) { index in
              LocalImageThumbnail(data: localImages[index]) {
                onRemoveLocal(index)
              }
            }

            // 추가 버튼
            if remainingSlots > 0 {
              AddImageButton(
                remainingSlots: remainingSlots,
                onPhotosSelected: onPhotosSelected
              )
            }
          }
        }
      }

      if isUploading {
        HStack(spacing: 8) {
          ProgressView()
            .scaleEffect(0.8)
          Text("이미지 업로드 중...")
            .font(.system(size: 13))
            .foregroundStyle(Color.pmtext.secondary)
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .adaptiveGlassCard()
  }
}

// MARK: - Remote Image Thumbnail

private struct RemoteImageThumbnail: View {
  let url: String
  let onRemove: () -> Void

  @State private var loadedImage: UIImage?
  @State private var loadFailed = false

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Group {
        if let loadedImage {
          Image(uiImage: loadedImage)
            .resizable()
            .scaledToFill()
        } else if loadFailed {
          imagePlaceholder(systemName: "exclamationmark.triangle")
        } else {
          ProgressView()
            .frame(width: 80, height: 80)
        }
      }
      .frame(width: 80, height: 80)
      .clipShape(RoundedRectangle(cornerRadius: 10))

      removeButton(action: onRemove)
    }
    .task(id: url) {
      guard let imageUrl = URL(string: url) else {
        loadFailed = true
        return
      }
      do {
        loadedImage = try await ImagePipeline.shared.image(for: ImageRequest(url: imageUrl))
      } catch {
        loadFailed = true
      }
    }
  }
}

// MARK: - Local Image Thumbnail

private struct LocalImageThumbnail: View {
  let data: Data
  let onRemove: () -> Void

  var body: some View {
    ZStack(alignment: .topTrailing) {
      if let uiImage = UIImage(data: data) {
        Image(uiImage: uiImage)
          .resizable()
          .scaledToFill()
          .frame(width: 80, height: 80)
          .clipShape(RoundedRectangle(cornerRadius: 10))
      } else {
        imagePlaceholder(systemName: "photo.badge.exclamationmark")
      }

      removeButton(action: onRemove)
    }
  }
}

// MARK: - Add Image Button

private struct AddImageButton: View {
  let remainingSlots: Int
  let onPhotosSelected: ([PhotosPickerItem]) -> Void

  @State private var selectedItems: [PhotosPickerItem] = []

  var body: some View {
    PhotosPicker(
      selection: $selectedItems,
      maxSelectionCount: remainingSlots,
      matching: .images
    ) {
      VStack(spacing: 6) {
        Image(systemName: "plus")
          .font(.system(size: 22, weight: .medium))
          .foregroundStyle(Color.pmindigo.n500)
      }
      .frame(width: 80, height: 80)
      .background(Color(UIColor.systemGray6).opacity(0.5))
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .strokeBorder(
            Color.pmindigo.n500.opacity(0.3),
            style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
          )
      )
    }
    .onChange(of: selectedItems) { _, newItems in
      guard !newItems.isEmpty else { return }
      onPhotosSelected(newItems)
      selectedItems = []
    }
  }
}

// MARK: - Gallery Image Thumbnail (상세 뷰용 공용 컴포넌트)

public struct GalleryImageThumbnail: View {
  let url: String
  let size: CGFloat

  @State private var loadedImage: UIImage?
  @State private var loadFailed = false

  public init(url: String, size: CGFloat = 120) {
    self.url = url
    self.size = size
  }

  public var body: some View {
    Group {
      if let loadedImage {
        Image(uiImage: loadedImage)
          .resizable()
          .scaledToFill()
      } else if loadFailed {
        ZStack {
          Color(UIColor.systemGray5)
          Image(systemName: "exclamationmark.triangle")
            .font(.system(size: 24))
            .foregroundStyle(Color(UIColor.systemGray3))
        }
      } else {
        ProgressView()
      }
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: 12))
    .task(id: url) {
      guard let imageUrl = URL(string: url) else {
        loadFailed = true
        return
      }
      do {
        loadedImage = try await ImagePipeline.shared.image(for: ImageRequest(url: imageUrl))
      } catch {
        loadFailed = true
      }
    }
  }
}

// MARK: - Helpers

private func removeButton(action: @escaping () -> Void) -> some View {
  Button(action: action) {
    Image(systemName: "xmark.circle.fill")
      .font(.system(size: 20))
      .foregroundStyle(.white)
      .shadow(color: .black.opacity(0.3), radius: 2)
  }
  .offset(x: 4, y: -4)
}

private func imagePlaceholder(systemName: String) -> some View {
  ZStack {
    Color(UIColor.systemGray5)
    Image(systemName: systemName)
      .font(.system(size: 24))
      .foregroundStyle(Color(UIColor.systemGray3))
  }
  .frame(width: 80, height: 80)
  .clipShape(RoundedRectangle(cornerRadius: 10))
}
