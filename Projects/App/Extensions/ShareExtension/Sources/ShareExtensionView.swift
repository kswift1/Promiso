import PromisoShared
import ResourceKit
import SwiftUI

// MARK: - ShareExtensionView

struct ShareExtensionView: View {

  // MARK: - Properties

  let onSend: () -> Void
  let onCancel: () -> Void

  // MARK: - Body

  var body: some View {
    NavigationStack {
      contentView
        .toolbar {
          cancelToolbarItem
        }
    }
  }

  // MARK: - Content

  @ViewBuilder
  private var contentView: some View {
    VStack(spacing: 20) {
      Spacer()
      iconView
      labelView
      Spacer()
      sendButton
    }
    .padding(.horizontal, 24)
    .padding(.bottom, 32)
  }

  @ViewBuilder
  private var iconView: some View {
    Image(systemName: "sparkles")
      .resizable()
      .scaledToFit()
      .frame(width: 48, height: 48)
      .foregroundStyle(Color.pmindigo.n500)
  }

  @ViewBuilder
  private var labelView: some View {
    VStack(spacing: 8) {
      Text(LocalizedStrings.ShareExtension.title)
        .font(.system(size: 20, weight: .bold))
        .multilineTextAlignment(.center)

      Text(LocalizedStrings.ShareExtension.subtitle)
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
    }
  }

  @ViewBuilder
  private var sendButton: some View {
    Button {
      onSend()
    } label: {
      Text(LocalizedStrings.ShareExtension.sendButton)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.pmindigo.n500, in: RoundedRectangle(cornerRadius: 14))
        .contentShape(Rectangle())
    }
  }

  // MARK: - Toolbar

  private var cancelToolbarItem: some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
      Button(LocalizedStrings.Common.cancel) {
        onCancel()
      }
    }
  }
}

// MARK: - Preview

#Preview {
  ShareExtensionView(
    onSend: {},
    onCancel: {}
  )
}
