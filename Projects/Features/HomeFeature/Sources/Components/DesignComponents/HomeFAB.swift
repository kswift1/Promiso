import SwiftUI

/// 홈 화면 Floating Action Button
struct HomeFAB: View {
  let action: () -> Void
  var isVisible: Bool = true

  var body: some View {
    Button(action: action) {
      Image(systemName: "plus")
        .font(.title2)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
        .frame(width: 56, height: 56)
        .background(Color.pmindigo.n500)
        .clipShape(Circle())
        .shadow(color: Color.pmindigo.n500.opacity(0.4), radius: 12, x: 0, y: 6)
    }
    .buttonStyle(.plain)
    .opacity(isVisible ? 1 : 0)
    .scaleEffect(isVisible ? 1 : 0.5)
    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
  }
}

/// FAB를 화면 우하단에 배치하는 ViewModifier
struct FABOverlayModifier: ViewModifier {
  let isVisible: Bool
  let action: () -> Void

  func body(content: Content) -> some View {
    content
      .overlay(alignment: .bottomTrailing) {
        HomeFAB(action: action, isVisible: isVisible)
          .padding(.trailing, 16)
          .padding(.bottom, 16)
      }
  }
}

extension View {
  /// FAB를 화면 우하단에 오버레이
  func fabOverlay(isVisible: Bool = true, action: @escaping () -> Void) -> some View {
    modifier(FABOverlayModifier(isVisible: isVisible, action: action))
  }
}

// MARK: - Preview

#Preview("FAB") {
  ZStack {
    Color.gray.opacity(0.1)
      .ignoresSafeArea()

    VStack {
      Text("홈 화면 콘텐츠")
        .font(.headline)
    }
  }
  .fabOverlay(isVisible: true) {
    print("FAB tapped")
  }
}

#Preview("FAB 숨김") {
  ZStack {
    Color.gray.opacity(0.1)
      .ignoresSafeArea()

    VStack {
      Text("스크롤 중...")
        .font(.headline)
    }
  }
  .fabOverlay(isVisible: false) {
    print("FAB tapped")
  }
}
