import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

  private let statusLabel = UILabel()
  private let iconView = UIImageView()

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    handleSharedText()
  }

  // MARK: - UI

  private func setupUI() {
    view.backgroundColor = UIColor.black.withAlphaComponent(0.4)

    let card = UIView()
    card.backgroundColor = .systemBackground
    card.layer.cornerRadius = 16
    card.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(card)

    iconView.image = UIImage(systemName: "text.viewfinder")
    iconView.tintColor = .systemIndigo
    iconView.contentMode = .scaleAspectFit
    iconView.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(iconView)

    statusLabel.text = "텍스트를 가져오는 중..."
    statusLabel.font = .systemFont(ofSize: 15, weight: .medium)
    statusLabel.textColor = .label
    statusLabel.textAlignment = .center
    statusLabel.numberOfLines = 0
    statusLabel.translatesAutoresizingMaskIntoConstraints = false
    card.addSubview(statusLabel)

    NSLayoutConstraint.activate([
      card.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      card.centerYAnchor.constraint(equalTo: view.centerYAnchor),
      card.widthAnchor.constraint(equalToConstant: 260),

      iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
      iconView.centerXAnchor.constraint(equalTo: card.centerXAnchor),
      iconView.widthAnchor.constraint(equalToConstant: 36),
      iconView.heightAnchor.constraint(equalToConstant: 36),

      statusLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 12),
      statusLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
      statusLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
      statusLabel.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
    ])
  }

  // MARK: - Text Handling

  private func handleSharedText() {
    guard let items = extensionContext?.inputItems as? [NSExtensionItem], !items.isEmpty else {
      showResult(success: false, message: "공유된 텍스트를 찾을 수 없습니다")
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
        saveText(String(attrText.prefix(2000)))
        return
      }
    }

    showResult(success: false, message: "공유된 텍스트를 찾을 수 없습니다")
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
          self?.showResult(success: false, message: "빈 텍스트입니다")
          return
        }
        self?.saveText(String(text.prefix(2000)))
      }
    }
  }

  private func saveText(_ text: String) {
    guard let appGroupId = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String else {
      showResult(success: false, message: "저장에 실패했습니다")
      return
    }

    UserDefaults(suiteName: appGroupId)?.set(text, forKey: "pendingExtractionText")
    showResult(success: true, message: "Promiso를 열면\n일정이 자동으로 추출됩니다")
  }

  // MARK: - Result

  private func showResult(success: Bool, message: String) {
    iconView.image = UIImage(systemName: success ? "checkmark.circle.fill" : "xmark.circle.fill")
    iconView.tintColor = success ? .systemGreen : .systemRed
    statusLabel.text = message

    DispatchQueue.main.asyncAfter(deadline: .now() + (success ? 1.5 : 2.0)) { [weak self] in
      self?.extensionContext?.completeRequest(returningItems: nil)
    }
  }
}
