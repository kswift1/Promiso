import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

  private enum SharedContent {
    case text(String)
    case image(Data)
  }

  private var content: SharedContent?

  // UI
  private let previewTextView = UITextView()
  private let previewImageView = UIImageView()
  private let personalButton = UIButton(type: .system)
  private let charCountLabel = UILabel()

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    handleSharedContent()
  }

  // MARK: - UI Setup

  private func setupUI() {
    view.backgroundColor = .systemBackground

    // 네비게이션 바
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

    let separator = UIView()
    separator.backgroundColor = .separator
    separator.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(separator)

    // 텍스트 미리보기 (텍스트 모드)
    previewTextView.isEditable = true
    previewTextView.isScrollEnabled = true
    previewTextView.font = .systemFont(ofSize: 15)
    previewTextView.textColor = .secondaryLabel
    previewTextView.backgroundColor = .secondarySystemBackground
    previewTextView.layer.cornerRadius = 12
    previewTextView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
    previewTextView.text = "콘텐츠를 가져오는 중..."
    previewTextView.delegate = self
    previewTextView.translatesAutoresizingMaskIntoConstraints = false
    previewTextView.isHidden = true
    view.addSubview(previewTextView)

    // 이미지 미리보기 (이미지 모드)
    previewImageView.contentMode = .scaleAspectFit
    previewImageView.backgroundColor = .secondarySystemBackground
    previewImageView.layer.cornerRadius = 12
    previewImageView.clipsToBounds = true
    previewImageView.translatesAutoresizingMaskIntoConstraints = false
    previewImageView.isHidden = true
    view.addSubview(previewImageView)

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

      previewImageView.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 16),
      previewImageView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
      previewImageView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
      previewImageView.bottomAnchor.constraint(equalTo: charCountLabel.topAnchor, constant: -4),

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
    guard content != nil else { return }

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

    let defaults = UserDefaults(suiteName: appGroupId)

    switch content {
    case .text(let text):
      defaults?.set(text, forKey: "pendingExtractionText")
    case .image(let data):
      // App Group 공유 컨테이너에 파일로 저장
      guard let containerURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId) else {
        showError("공유 저장소에 접근할 수 없습니다")
        return
      }
      let fileURL = containerURL.appendingPathComponent("pendingExtractionImage.jpg")
      do {
        try data.write(to: fileURL)
      } catch {
        showError("이미지를 공유하는 데 실패했습니다")
        return
      }
    case .none:
      break
    }

    OpenURLHelper.open(url, from: self)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      self?.close()
    }
  }

  @objc private func closeTapped() {
    close()
  }

  // MARK: - Content Handling

  private func handleSharedContent() {
    guard let items = extensionContext?.inputItems as? [NSExtensionItem], !items.isEmpty else {
      showError("공유된 콘텐츠를 찾을 수 없습니다")
      return
    }

    for item in items {
      guard let attachments = item.attachments else { continue }

      for provider in attachments {
        // 텍스트 우선
        if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
          loadText(from: provider, typeIdentifier: UTType.plainText.identifier)
          return
        }
        if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
          loadText(from: provider, typeIdentifier: UTType.text.identifier)
          return
        }
        // 이미지
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
          loadImage(from: provider)
          return
        }
      }

      if let attrText = item.attributedContentText?.string,
         !attrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        showText(String(attrText.prefix(2000)))
        return
      }
    }
    showError("공유된 콘텐츠를 찾을 수 없습니다")
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
          self?.showError("빈 텍스트입니다")
          return
        }
        self?.showText(String(text.prefix(2000)))
      }
    }
  }

  private func loadImage(from provider: NSItemProvider) {
    provider.loadItem(forTypeIdentifier: UTType.image.identifier) { [weak self] data, _ in
      // URL인 경우 백그라운드에서 비동기 로드
      if let url = data as? URL {
        URLSession.shared.dataTask(with: url) { fileData, _, error in
          DispatchQueue.main.async {
            guard let fileData, error == nil else {
              self?.showError("이미지를 불러올 수 없습니다")
              return
            }
            self?.processImageData(fileData)
          }
        }.resume()
        return
      }

      DispatchQueue.main.async {
        var imageData: Data?
        if let data = data as? Data {
          imageData = data
        } else if let image = data as? UIImage {
          imageData = image.jpegData(compressionQuality: 0.8)
        }

        guard let imageData else {
          self?.showError("이미지를 불러올 수 없습니다")
          return
        }
        self?.processImageData(imageData)
      }
    }
  }

  private func processImageData(_ imageData: Data) {
    guard let image = UIImage(data: imageData) else {
      showError("이미지를 불러올 수 없습니다")
      return
    }

    // 4MB 초과 시 리사이즈
    var finalData = imageData
    if finalData.count > 4 * 1024 * 1024 {
      finalData = image.jpegData(compressionQuality: 0.5) ?? imageData
    }

    showImage(finalData, image: image)
  }

  // MARK: - Display

  private func showText(_ text: String) {
    content = .text(text)
    previewTextView.isHidden = false
    previewImageView.isHidden = true
    previewTextView.text = text
    previewTextView.textColor = .label
    charCountLabel.text = "\(text.count)자"
    personalButton.isEnabled = true
  }

  private func showImage(_ data: Data, image: UIImage) {
    content = .image(data)
    previewTextView.isHidden = true
    previewImageView.isHidden = false
    previewImageView.image = image
    charCountLabel.text = ""
    personalButton.isEnabled = true
  }

  private func showError(_ message: String) {
    previewTextView.isHidden = false
    previewImageView.isHidden = true
    previewTextView.text = message
    previewTextView.isEditable = false
  }

  private func close() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}

// MARK: - UITextViewDelegate

extension ShareViewController: UITextViewDelegate {
  func textViewDidChange(_ textView: UITextView) {
    let text = String(textView.text.prefix(2000))
    content = .text(text)
    charCountLabel.text = "\(text.count)자"
    personalButton.isEnabled = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
