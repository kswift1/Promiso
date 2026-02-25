import PromisoShared
import SwiftUI
import UIKit
import UniformTypeIdentifiers

// MARK: - ShareViewController

@objc(ShareViewController)
class ShareViewController: UIViewController {

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    embedShareView()
  }

  // MARK: - Private: Embed SwiftUI View

  private func embedShareView() {
    let shareView = ShareExtensionView(
      onSend: { [weak self] in
        self?.processAndOpenApp()
      },
      onCancel: { [weak self] in
        self?.cancel()
      }
    )
    let hostingController = UIHostingController(rootView: shareView)
    addChild(hostingController)
    view.addSubview(hostingController.view)
    hostingController.view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
      hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
    ])
    hostingController.didMove(toParent: self)
  }

  // MARK: - Process & Open App

  private func processAndOpenApp() {
    Task {
      await extractAndSaveContent()
      openMainApp()
      extensionContext?.completeRequest(returningItems: nil)
    }
  }

  private func extractAndSaveContent() async {
    guard let inputItems = extensionContext?.inputItems as? [NSExtensionItem] else { return }

    var extractedText: String?
    var extractedImageData: Data?

    // Collect all attachments across all input items
    var providers: [NSItemProvider] = []
    for item in inputItems {
      if let attachments = item.attachments {
        providers.append(contentsOf: attachments)
      }
    }

    // Priority: plainText > URL (non-file) > image
    for provider in providers {
      if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
        if let text = await loadText(from: provider, typeIdentifier: UTType.plainText.identifier) {
          extractedText = text
          break
        }
      }
    }

    if extractedText == nil {
      for provider in providers {
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
          if let text = await loadText(from: provider, typeIdentifier: UTType.url.identifier),
             !text.hasPrefix("file://") {
            extractedText = text
            break
          }
        }
      }
    }

    if extractedText == nil {
      for provider in providers {
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
          if let data = await loadImageData(from: provider) {
            extractedImageData = data
            break
          }
        }
      }
    }

    // Save to App Group UserDefaults
    guard let defaults = UserDefaults(suiteName: LiveActivityIntentKey.suiteName) else { return }

    defaults.set(Date().timeIntervalSince1970, forKey: AppConstants.ShareExtension.sharedTimestampKey)

    if let text = extractedText {
      defaults.set("text", forKey: AppConstants.ShareExtension.contentTypeKey)
      defaults.set(text, forKey: AppConstants.ShareExtension.sharedTextKey)
      defaults.removeObject(forKey: AppConstants.ShareExtension.sharedImageDataKey)
    } else if let imageData = extractedImageData {
      defaults.set("image", forKey: AppConstants.ShareExtension.contentTypeKey)
      defaults.set(imageData, forKey: AppConstants.ShareExtension.sharedImageDataKey)
      defaults.removeObject(forKey: AppConstants.ShareExtension.sharedTextKey)
    }

    defaults.synchronize()
  }

  // MARK: - Open Main App via Deeplink

  private func openMainApp() {
    guard let url = URL(string: "\(AppConstants.Deeplink.scheme)://share") else { return }
    openURL(url)
  }

  // MARK: - Cancel

  private func cancel() {
    extensionContext?.cancelRequest(withError: NSError(
      domain: "ShareExtension",
      code: NSUserCancelledError,
      userInfo: nil
    ))
  }

  // MARK: - Open URL via Responder Chain

  private func openURL(_ url: URL) {
    let selector = #selector(UIApplication.open(_:options:completionHandler:))
    var responder: UIResponder? = self
    while let current = responder {
      if current.responds(to: selector) {
        let application = current as AnyObject
        application.perform(selector, with: url, with: [:])
        return
      }
      responder = current.next
    }
  }

  // MARK: - Content Extraction Helpers

  private func loadText(from provider: NSItemProvider, typeIdentifier: String) async -> String? {
    await withCheckedContinuation { continuation in
      provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
        guard error == nil else {
          continuation.resume(returning: nil)
          return
        }
        if let text = item as? String {
          continuation.resume(returning: text)
        } else if let url = item as? URL {
          continuation.resume(returning: url.absoluteString)
        } else {
          continuation.resume(returning: nil)
        }
      }
    }
  }

  private func loadImageData(from provider: NSItemProvider) async -> Data? {
    await withCheckedContinuation { continuation in
      provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, error in
        guard error == nil else {
          continuation.resume(returning: nil)
          return
        }

        var image: UIImage?
        if let uiImage = item as? UIImage {
          image = uiImage
        } else if let url = item as? URL,
                  let data = try? Data(contentsOf: url) {
          image = UIImage(data: data)
        } else if let data = item as? Data {
          image = UIImage(data: data)
        }

        guard let resolvedImage = image else {
          continuation.resume(returning: nil)
          return
        }

        continuation.resume(returning: compressImage(resolvedImage))
      }
    }
  }

  // MARK: - Image Compression

  private func compressImage(_ image: UIImage) -> Data? {
    let maxBytes = 5 * 1024 * 1024  // 5MB

    // Try progressive JPEG compression
    let qualities: [CGFloat] = [0.7, 0.5, 0.3, 0.1]
    for quality in qualities {
      if let data = image.jpegData(compressionQuality: quality), data.count <= maxBytes {
        return data
      }
    }

    // Still too large — resize to fit within 1024pt on the longer side
    let resized = resizeImage(image, maxDimension: 1024)
    let resizedQualities: [CGFloat] = [0.7, 0.5, 0.3, 0.1]
    for quality in resizedQualities {
      if let data = resized.jpegData(compressionQuality: quality) {
        return data
      }
    }

    return image.jpegData(compressionQuality: 0.1)
  }

  private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
    let size = image.size
    let longerSide = max(size.width, size.height)
    guard longerSide > maxDimension else { return image }

    let scale = maxDimension / longerSide
    let newSize = CGSize(width: size.width * scale, height: size.height * scale)

    let renderer = UIGraphicsImageRenderer(size: newSize)
    return renderer.image { _ in
      image.draw(in: CGRect(origin: .zero, size: newSize))
    }
  }
}
