import SwiftUI

public enum ToolbarType {
  case hamburger
  
}

public struct ToolbarButton: View {
  
  private let imageName: String
  private let action: () -> Void
  
  public init(imageName: String, action: @escaping () -> Void) {
    self.imageName = imageName
    self.action = action
  }
  
  public var body: some View {
    Button {
      action()
    } label: {
      Image(systemName: imageName)
        .tint(.primary)
    }
  }
}
