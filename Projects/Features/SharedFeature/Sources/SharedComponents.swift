// MARK: - SharedComponents.swift
// SharedFeature에서 사용되는 공통 컴포넌트들

import SwiftUI
import PromisoShared
import ResourceKit

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

// MARK: - PromiseShareSheet

public struct PromiseShareSheet: View {
  let promise: PromiseModel
  let isKakaoSharing: Bool
  let onKakaoShareTapped: () -> Void
  let onSystemShareTapped: () -> Void

  public init(
    promise: PromiseModel,
    isKakaoSharing: Bool,
    onKakaoShareTapped: @escaping () -> Void,
    onSystemShareTapped: @escaping () -> Void
  ) {
    self.promise = promise
    self.isKakaoSharing = isKakaoSharing
    self.onKakaoShareTapped = onKakaoShareTapped
    self.onSystemShareTapped = onSystemShareTapped
  }

  public var body: some View {
    VStack(spacing: 20) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(LocalizedStrings.PromiseShare.title)
            .font(.system(size: 20, weight: .bold))

          Text(LocalizedStrings.PromiseShare.subtitle)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
        }
        .padding(.top, 12)

        Spacer()
      }

      HStack(spacing: 12) {
        Text(promise.displayEmoji)
          .font(.system(size: 32))

        VStack(alignment: .leading, spacing: 4) {
          Text(promise.title)
            .font(.system(size: 16, weight: .semibold))
            .lineLimit(1)

          Text("\(promise.dateText) \(promise.timeText)")
            .font(.system(size: 13))
            .foregroundStyle(.secondary)

          if let locationName = promise.location?.name {
            Text(locationName)
              .font(.system(size: 13))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }

        Spacer()
      }
      .padding(16)
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

      Button {
        onKakaoShareTapped()
      } label: {
        HStack(spacing: 8) {
          ResourceKitAsset.kakaoLogo.swiftUIImage
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: 20, height: 20)
          Text(LocalizedStrings.PromiseShare.kakaoButton)
        }
        .font(.system(size: 16, weight: .semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color(red: 254/255, green: 229/255, blue: 0/255))
        .foregroundStyle(.black)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.scale)
      .disabled(isKakaoSharing)
      .opacity(isKakaoSharing ? 0.6 : 1)

      Button {
        onSystemShareTapped()
      } label: {
        HStack(spacing: 8) {
          Image(systemName: "square.and.arrow.up")
          Text(LocalizedStrings.PromiseShare.systemButton)
        }
        .font(.system(size: 16, weight: .semibold))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.pmindigo.n500.opacity(0.12))
        .foregroundStyle(Color.pmindigo.n500)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
      }
      .buttonStyle(.scale)

      Spacer(minLength: 0)
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 20)
  }
}

// MARK: - ShareTextItem

public struct ShareTextItem: Identifiable {
  public let id = UUID()
  public let text: String

  public init(text: String) {
    self.text = text
  }
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
