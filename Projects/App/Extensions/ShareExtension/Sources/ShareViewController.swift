import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    handleSharedText()
  }

  private func handleSharedText() {
    guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
      close()
      return
    }

    for item in items {
      for provider in item.attachments ?? [] {
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
          provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) { [weak self] data, _ in
            DispatchQueue.main.async {
              guard let text = data as? String, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                self?.close()
                return
              }
              self?.saveAndOpenApp(text: String(text.prefix(2000)))
            }
          }
          return
        }
      }
    }
    close()
  }

  private func saveAndOpenApp(text: String) {
    guard
      let appGroupId = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String,
      let scheme = Bundle.main.object(forInfoDictionaryKey: "DEEPLINK_SCHEME") as? String,
      let url = URL(string: "\(scheme)://extractSchedule")
    else {
      close()
      return
    }

    UserDefaults(suiteName: appGroupId)?.set(text, forKey: "pendingExtractionText")

    extensionContext?.open(url) { [weak self] _ in
      self?.close()
    }
  }

  private func close() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}
