import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

  private var sharedText: String = ""

  // UI
  private let previewTextView = UITextView()
  private let personalButton = UIButton(type: .system)
  private let charCountLabel = UILabel()

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    handleSharedText()
  }

  // MARK: - UI Setup

  private func setupUI() {
    view.backgroundColor = .systemBackground

    // 네비게이션 바 영역
    let navBar = UIView()
    navBar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(navBar)

    let titleLabel = UILabel()
    titleLabel.text = "일정 추출"
    titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    navBar.addSubview(titleLabel)

    let closeButton = UIButton(type: .system)
    closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
    closeButton.tintColor = .tertiaryLabel
    closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    navBar.addSubview(closeButton)

    // 구분선
    let separator = UIView()
    separator.backgroundColor = .separator
    separator.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(separator)

    // 텍스트 미리보기
    previewTextView.isEditable = true
    previewTextView.isScrollEnabled = true
    previewTextView.font = .systemFont(ofSize: 15)
    previewTextView.textColor = .secondaryLabel
    previewTextView.backgroundColor = .secondarySystemBackground
    previewTextView.layer.cornerRadius = 12
    previewTextView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
    previewTextView.text = "텍스트를 가져오는 중..."
    previewTextView.delegate = self
    previewTextView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(previewTextView)

    // 글자 수
    charCountLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    charCountLabel.textColor = .tertiaryLabel
    charCountLabel.textAlignment = .right
    charCountLabel.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(charCountLabel)

    // 버튼
    var config = UIButton.Configuration.filled()
    config.cornerStyle = .large
    config.baseBackgroundColor = .systemIndigo
    config.baseForegroundColor = .white
    config.image = UIImage(systemName: "sparkles")
    config.imagePadding = 8
    config.imagePlacement = .leading
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
    var titleAttr = AttributedString("개인 일정으로 추출")
    titleAttr.font = .systemFont(ofSize: 16, weight: .semibold)
    config.attributedTitle = titleAttr
    personalButton.configuration = config
    personalButton.isEnabled = false
    personalButton.addTarget(self, action: #selector(personalTapped), for: .touchUpInside)
    personalButton.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(personalButton)

    NSLayoutConstraint.activate([
      navBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      navBar.heightAnchor.constraint(equalToConstant: 44),

      titleLabel.centerXAnchor.constraint(equalTo: navBar.centerXAnchor),
      titleLabel.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),

      closeButton.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -16),
      closeButton.centerYAnchor.constraint(equalTo: navBar.centerYAnchor),
      closeButton.widthAnchor.constraint(equalToConstant: 30),
      closeButton.heightAnchor.constraint(equalToConstant: 30),

      separator.topAnchor.constraint(equalTo: navBar.bottomAnchor),
      separator.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),

      previewTextView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 16),
      previewTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      previewTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      previewTextView.bottomAnchor.constraint(equalTo: charCountLabel.topAnchor, constant: -4),

      charCountLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      charCountLabel.bottomAnchor.constraint(equalTo: personalButton.topAnchor, constant: -16),

      personalButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      personalButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      personalButton.heightAnchor.constraint(equalToConstant: 52),
      personalButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -12),
    ])
  }

  // MARK: - Actions

  @objc private func personalTapped() {
    guard !sharedText.isEmpty else { return }

    guard
      let appGroupId = Bundle.main.object(forInfoDictionaryKey: "APP_GROUP_ID") as? String,
      let scheme = Bundle.main.object(forInfoDictionaryKey: "DEEPLINK_SCHEME") as? String,
      let url = URL(string: "\(scheme)://extractSchedule")
    else {
      close()
      return
    }

    personalButton.isEnabled = false
    var config = personalButton.configuration
    config?.showsActivityIndicator = true
    config?.title = ""
    config?.image = nil
    personalButton.configuration = config

    UserDefaults(suiteName: appGroupId)?.set(sharedText, forKey: "pendingExtractionText")
    OpenURLHelper.open(url, from: self)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      self?.close()
    }
  }

  @objc private func closeTapped() {
    close()
  }

  // MARK: - Text Handling

  private func handleSharedText() {
    guard let items = extensionContext?.inputItems as? [NSExtensionItem], !items.isEmpty else {
      previewTextView.text = "공유된 텍스트를 찾을 수 없습니다"
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
        showText(String(attrText.prefix(2000)))
        return
      }
    }
    previewTextView.text = "공유된 텍스트를 찾을 수 없습니다"
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
          self?.previewTextView.text = "빈 텍스트입니다"
          return
        }
        self?.showText(String(text.prefix(2000)))
      }
    }
  }

  private func showText(_ text: String) {
    sharedText = text
    previewTextView.text = text
    previewTextView.textColor = .label
    charCountLabel.text = "\(text.count)자"
    personalButton.isEnabled = true
  }

  private func close() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}

// MARK: - UITextViewDelegate

extension ShareViewController: UITextViewDelegate {
  func textViewDidChange(_ textView: UITextView) {
    let text = String(textView.text.prefix(2000))
    sharedText = text
    charCountLabel.text = "\(text.count)자"
    personalButton.isEnabled = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
