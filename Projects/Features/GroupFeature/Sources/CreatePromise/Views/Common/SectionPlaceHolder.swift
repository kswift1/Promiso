import SwiftUI
import Clients

struct SectionPlaceHolder<PlaceHolderAccessory: View, Content: View>: View {
  private let placeHolderTitle: String
  private let placeHolderAccessory: () -> PlaceHolderAccessory
  private let content: () -> Content
  
  init(
    placeHolderTitle: String,
    placeHolderAccessory: @escaping () -> PlaceHolderAccessory = { EmptyView() },
    content: @escaping () -> Content
  ) {
    self.placeHolderTitle = placeHolderTitle
    self.placeHolderAccessory = placeHolderAccessory
    self.content = content
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 4) {
        Text(placeHolderTitle)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(.primary)

        Spacer()

        placeHolderAccessory()
      }

      content()
    }
  }
}

