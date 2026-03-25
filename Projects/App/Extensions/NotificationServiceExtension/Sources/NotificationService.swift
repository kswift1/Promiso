import UserNotifications

final class NotificationService: UNNotificationServiceExtension {

  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var bestAttemptContent: UNMutableNotificationContent?
  private var isHandled = false

  override func didReceive(
    _ request: UNNotificationRequest,
    withContentHandler contentHandler:
      @escaping (UNNotificationContent) -> Void
  ) {
    self.contentHandler = contentHandler
    bestAttemptContent =
      request.content.mutableCopy() as? UNMutableNotificationContent

    guard let bestAttemptContent = bestAttemptContent else {
      deliverContent(request.content)
      return
    }

    guard
      let imageUrlString = bestAttemptContent.userInfo["imageUrl"] as? String,
      let imageUrl = URL(string: imageUrlString)
    else {
      deliverContent(bestAttemptContent)
      return
    }

    downloadImage(from: imageUrl) { [weak self] attachment in
      if let attachment = attachment {
        bestAttemptContent.attachments = [attachment]
      }
      self?.deliverContent(bestAttemptContent)
    }
  }

  override func serviceExtensionTimeWillExpire() {
    if let bestAttemptContent = bestAttemptContent {
      deliverContent(bestAttemptContent)
    }
  }

  private func deliverContent(_ content: UNNotificationContent) {
    guard !isHandled else { return }
    isHandled = true
    contentHandler?(content)
  }

  private func downloadImage(
    from url: URL,
    completion: @escaping (UNNotificationAttachment?) -> Void
  ) {
    var request = URLRequest(url: url)
    request.timeoutInterval = 15

    let task = URLSession.shared.downloadTask(with: request) { location, response, error in
      guard
        error == nil,
        let location = location
      else {
        completion(nil)
        return
      }

      let filename = response?.suggestedFilename
        ?? UUID().uuidString + ".jpg"
      let fileExtension = URL(fileURLWithPath: filename).pathExtension
      let tempDir = FileManager.default.temporaryDirectory
      let tempFile = tempDir
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension(fileExtension.isEmpty ? "jpg" : fileExtension)

      do {
        try? FileManager.default.removeItem(at: tempFile)
        try FileManager.default.moveItem(at: location, to: tempFile)
        let attachment = try UNNotificationAttachment(
          identifier: "image",
          url: tempFile,
          options: nil
        )
        completion(attachment)
      } catch {
        try? FileManager.default.removeItem(at: tempFile)
        completion(nil)
      }
    }
    task.resume()
  }
}
