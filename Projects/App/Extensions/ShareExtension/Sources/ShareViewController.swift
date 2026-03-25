import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

  private var sharedText: String = ""

  // UI
  private let containerView = UIView()
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
    view.backgroundColor = UIColor.black.withAlphaComponent(0.35)
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
    tapGesture.delegate = self
    view.addGestureRecognizer(tapGesture)

    // 하단 시트
    containerView.backgroundColor = .systemBackground
    containerView.layer.cornerRadius = 24
    containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    containerView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(containerView)

    // 핸들 바
    let handleBar = UIView()
    handleBar.backgroundColor = UIColor.tertiaryLabel
    handleBar.layer.cornerRadius = 2.5
    handleBar.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(handleBar)

    // 헤더: 아이콘 + 타이틀
    let headerStack = UIStackView()
    headerStack.axis = .horizontal
    headerStack.spacing = 8
    headerStack.alignment = .center
    headerStack.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(headerStack)

    let iconView = UIImageView(image: UIImage(systemName: "text.viewfinder"))
    iconView.tintColor = .systemIndigo
    iconView.contentMode = .scaleAspectFit
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.widthAnchor.constraint(equalToConstant: 22).isActive = true
    iconView.heightAnchor.constraint(equalToConstant: 22).isActive = true
    headerStack.addArrangedSubview(iconView)

    let titleLabel = UILabel()
    titleLabel.text = "텍스트에서 일정 추출"
    titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
    headerStack.addArrangedSubview(titleLabel)

    let closeButton = UIButton(type: .system)
    closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
    closeButton.tintColor = .tertiaryLabel
    closeButton.addTarget(self, action: #selector(backgroundTapped), for: .touchUpInside)
    closeButton.translatesAutoresizingMaskIntoConstraints = false
    closeButton.widthAnchor.constraint(equalToConstant: 30).isActive = true
    closeButton.heightAnchor.constraint(equalToConstant: 30).isActive = true
    containerView.addSubview(closeButton)

    // 텍스트 미리보기
    previewTextView.isEditable = false
    previewTextView.isScrollEnabled = true
    previewTextView.font = .systemFont(ofSize: 14)
    previewTextView.textColor = .secondaryLabel
    previewTextView.backgroundColor = UIColor.secondarySystemBackground
    previewTextView.layer.cornerRadius = 12
    previewTextView.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
    previewTextView.text = "텍스트를 가져오는 중..."
    previewTextView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(previewTextView)

    // 글자 수
    charCountLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    charCountLabel.textColor = .tertiaryLabel
    charCountLabel.textAlignment = .right
    charCountLabel.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(charCountLabel)

    // 개인 일정 추출 버튼
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
    containerView.addSubview(personalButton)

    NSLayoutConstraint.activate([
      containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      handleBar.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
      handleBar.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      handleBar.widthAnchor.constraint(equalToConstant: 36),
      handleBar.heightAnchor.constraint(equalToConstant: 5),

      headerStack.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 16),
      headerStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),

      closeButton.centerYAnchor.constraint(equalTo: headerStack.centerYAnchor),
      closeButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),

      previewTextView.topAnchor.constraint(equalTo: headerStack.bottomAnchor, constant: 16),
      previewTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
      previewTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
      previewTextView.heightAnchor.constraint(equalToConstant: 140),

      charCountLabel.topAnchor.constraint(equalTo: previewTextView.bottomAnchor, constant: 4),
      charCountLabel.trailingAnchor.constraint(equalTo: previewTextView.trailingAnchor),

      personalButton.topAnchor.constraint(equalTo: charCountLabel.bottomAnchor, constant: 12),
      personalButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
      personalButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
      personalButton.heightAnchor.constraint(equalToConstant: 52),
      personalButton.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -12),
    ])

    // 시트 등장 애니메이션
    containerView.transform = CGAffineTransform(translationX: 0, y: 400)
    UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.5) {
      self.containerView.transform = .identity
    }
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

    // 버튼 로딩 상태
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

  @objc private func backgroundTapped() {
    // 닫기 애니메이션
    UIView.animate(withDuration: 0.25, animations: {
      self.containerView.transform = CGAffineTransform(translationX: 0, y: 400)
      self.view.backgroundColor = .clear
    }) { _ in
      self.close()
    }
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

// MARK: - UIGestureRecognizerDelegate

extension ShareViewController: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    let location = touch.location(in: containerView)
    return !containerView.bounds.contains(location)
  }
}
