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

    // iOS 18+: 3-arg open(_:options:completionHandler:) via IMP casting
    openURL(url)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      self?.close()
    }
  }

  /// Responder chain → UIApplication.open(_:options:completionHandler:) 호출
  /// iOS 18에서는 deprecated 1-arg openURL: 대신 3-arg 버전을 사용해야 동작함
  private func openURL(_ url: URL) {
    let selector = NSSelectorFromString("openURL:options:completionHandler:")
    var responder: UIResponder? = self as UIResponder
    while let current = responder {
      if current.responds(to: selector) {
        let target = current as NSObject
        let imp = target.method(for: selector)
        // open(_:options:completionHandler:) → (self, _cmd, URL, [String:Any], ((Bool)->Void)?)
        typealias OpenURLFunc = @convention(c) (
          AnyObject, Selector, Any, Any, Any?
        ) -> Void
        let function = unsafeBitCast(imp, to: OpenURLFunc.self)
        function(target, selector, url, [:] as [String: Any], nil)
        return
      }
      responder = current.next
    }
  }

  private func close() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}
