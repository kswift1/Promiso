import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {

  private var sharedText: String = ""

  // UI
  private let containerView = UIView()
  private let handleBar = UIView()
  private let titleLabel = UILabel()
  private let previewTextView = UITextView()
  private let personalButton = UIButton(type: .system)
  private let cancelButton = UIButton(type: .system)

  override func viewDidLoad() {
    super.viewDidLoad()
    setupUI()
    handleSharedText()
  }

  // MARK: - UI Setup

  private func setupUI() {
    // 반투명 배경 (탭하면 닫기)
    view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
    tapGesture.delegate = self
    view.addGestureRecognizer(tapGesture)

    // 하단 시트 컨테이너
    containerView.backgroundColor = .systemBackground
    containerView.layer.cornerRadius = 20
    containerView.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    containerView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(containerView)

    // 핸들 바
    handleBar.backgroundColor = UIColor.tertiaryLabel
    handleBar.layer.cornerRadius = 2.5
    handleBar.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(handleBar)

    // 타이틀
    titleLabel.text = "일정 추출"
    titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
    titleLabel.textAlignment = .center
    titleLabel.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(titleLabel)

    // 텍스트 미리보기
    previewTextView.isEditable = false
    previewTextView.isScrollEnabled = true
    previewTextView.font = .systemFont(ofSize: 14)
    previewTextView.textColor = .secondaryLabel
    previewTextView.backgroundColor = .secondarySystemBackground
    previewTextView.layer.cornerRadius = 12
    previewTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
    previewTextView.text = "텍스트를 가져오는 중..."
    previewTextView.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(previewTextView)

    // 개인 일정 추출 버튼
    var personalConfig = UIButton.Configuration.filled()
    personalConfig.title = "개인 일정으로 추출"
    personalConfig.image = UIImage(systemName: "person.fill")
    personalConfig.imagePadding = 8
    personalConfig.cornerStyle = .large
    personalConfig.baseBackgroundColor = .systemIndigo
    personalButton.configuration = personalConfig
    personalButton.isEnabled = false
    personalButton.addTarget(self, action: #selector(personalTapped), for: .touchUpInside)
    personalButton.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(personalButton)

    // 취소 버튼
    var cancelConfig = UIButton.Configuration.plain()
    cancelConfig.title = "취소"
    cancelButton.configuration = cancelConfig
    cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
    cancelButton.translatesAutoresizingMaskIntoConstraints = false
    containerView.addSubview(cancelButton)

    NSLayoutConstraint.activate([
      containerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      containerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      containerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

      handleBar.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 8),
      handleBar.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      handleBar.widthAnchor.constraint(equalToConstant: 36),
      handleBar.heightAnchor.constraint(equalToConstant: 5),

      titleLabel.topAnchor.constraint(equalTo: handleBar.bottomAnchor, constant: 12),
      titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
      titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),

      previewTextView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
      previewTextView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
      previewTextView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
      previewTextView.heightAnchor.constraint(equalToConstant: 120),

      personalButton.topAnchor.constraint(equalTo: previewTextView.bottomAnchor, constant: 20),
      personalButton.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 20),
      personalButton.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -20),
      personalButton.heightAnchor.constraint(equalToConstant: 50),

      cancelButton.topAnchor.constraint(equalTo: personalButton.bottomAnchor, constant: 8),
      cancelButton.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
      cancelButton.bottomAnchor.constraint(equalTo: containerView.safeAreaLayoutGuide.bottomAnchor, constant: -8),
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

    UserDefaults(suiteName: appGroupId)?.set(sharedText, forKey: "pendingExtractionText")
    OpenURLHelper.open(url, from: self)

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
      self?.close()
    }
  }

  @objc private func cancelTapped() {
    close()
  }

  @objc private func backgroundTapped() {
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
    personalButton.isEnabled = true
  }

  private func close() {
    extensionContext?.completeRequest(returningItems: nil)
  }
}

// MARK: - UIGestureRecognizerDelegate

extension ShareViewController: UIGestureRecognizerDelegate {
  func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
    // 컨테이너 내부 탭은 무시
    let location = touch.location(in: containerView)
    return !containerView.bounds.contains(location)
  }
}
