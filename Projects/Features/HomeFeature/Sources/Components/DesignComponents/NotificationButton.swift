import SwiftUI
import PromisoShared

struct NotificationButton: View {
  
  private var badgeCount: Int
  private var action: () -> Void
  
  init(badgeCount: Int, action: @escaping () -> Void) {
    self.badgeCount = badgeCount
    self.action = action
  }
  
  var body: some View {
    if #available(iOS 26.0, *) {
      ToolbarButton(
        imageName: "bell",
        action: { action() }
      )
      .badge(badgeCount)
    } else {
      Button {
        action()
      } label: {
        ZStack(alignment: .topTrailing) {
          Image(systemName: "bell")
            .font(.system(size: 18))
            .foregroundStyle(.primary)
          
          if badgeCount > 0 {
            BadgeView(count: badgeCount)
              .offset(x: 8, y: -8)
          }
        }
      }
      .buttonStyle(.plain)
    }
  }
}

// MARK: - BadgeView

private struct BadgeView: View {
  let count: Int
  
  private var displayText: String {
    if count > 999 {
      return "999+"
    } else {
      return "\(count)"
    }
  }
  
  var body: some View {
    Text(displayText)
      .font(.caption2)
      .fontWeight(.semibold)
      .foregroundStyle(.white)
      .padding(.horizontal, horizontalPadding(for: displayText))
      .frame(minHeight: 16)
      .background(Capsule().fill(.red))
      .minimumScaleFactor(0.8)
  }
  
  /// 숫자 자릿수에 따라 수평 패딩을 동적으로 조정
  private func horizontalPadding(for text: String) -> CGFloat {
    switch text.count {
    case 1: return 4
    case 2: return 5
    default: return 6 // "999+" or 3자리 이상
    }
  }
}
