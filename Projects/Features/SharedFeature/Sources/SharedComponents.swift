// MARK: - SharedComponents.swift
// SharedFeature에서 사용되는 공통 컴포넌트들

import SwiftUI
import PromisoShared

// MARK: - ShareSheet

public struct ShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  public init(items: [Any]) {
    self.items = items
  }

  public func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - PromiseResponseStatus Extensions

public extension PromiseResponseStatus {
  var iconName: String {
    switch self {
    case .needResponse: return "exclamationmark.circle.fill"
    case .responded: return "clock.fill"
    case .confirmed: return "checkmark.circle.fill"
    case .failed: return "xmark.circle.fill"
    }
  }
}
