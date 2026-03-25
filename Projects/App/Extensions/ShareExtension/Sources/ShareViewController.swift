import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .clear
    handleSharedText()
  }

  // MARK: - Text Handling

  private func handleSharedText() {
    guard let items = extensionContext?.inputItems as? [NSExtensionItem], !items.isEmpty else {
      close()
      return
    }

    for item in items {
      if let attachments = item.attachments {
        for provider in attachments {
          if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
            loadText(from: provider, typeIdentifier: UTType.plainText.identifier)
            return
          }
          if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
            loadText(from: provider, typeIdentifier: UTType.text.identifier)
            return
          }
        }
      }

      if let attrText = item.attributedContentText?.string,
         !attrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        saveAndOpen(String(attrText.prefix(2000)))
        return
      }
    }
    close()
  }

  private func loadText(from provider: NSItemProvider, typeIdentifier: String) {
    provider.loadItem(forTypeIdentifier: typeIdentifier) { [weak self] data, _ in
      DispatchQueue.main.async {
        var text: String?
        if let string = data as? String {
          text = string
        } else if let data = data as? Data {
          text = String(data: data, encoding: .utf8)
        }

        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
          self?.close()
          return
        }
        self?.saveAndOpen(String(text.prefix(2000)))
      }
    }
  }

  // MARK: - Save & Open

  private func saveAndOpen(_ text: String) {
    guard
      let appGroupId = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String,
      let scheme = Bundle.main.object(forInfoDictionaryKey: "DEEPLINK_SCHEME") as? String,
      let url = URL(string: "\(scheme)://extractSchedule")
    else {
      close()
      return
    }

    UserDefaults(suiteName: appGroupId)?.set(text, forKey: "pendingExtractionText")

    // Obj-C helper로 UIApplication.open(_:options:completionHandler:) 호출
    OpenURLHelper.open(url, from: self)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      self?.close()
    }
  }

  private func close() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}
