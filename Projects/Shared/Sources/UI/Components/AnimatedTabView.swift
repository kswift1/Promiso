import SwiftUI
import UIKit

/// 탭 선택을 위한 프로토콜
public protocol AnimatedTabSelectionProtocol: CaseIterable, Hashable {
  var title: String { get }
  var symbolImage: String { get }
}

/// 탭 선택 시 Symbol Effect 애니메이션을 지원하는 TabView
public struct AnimatedTabView<Selection: AnimatedTabSelectionProtocol, Content: TabContent<Selection>>: View {
  @Binding var selection: Selection
  @TabContentBuilder<Selection> var content: () -> Content
  var effects: (Selection) -> [any DiscreteSymbolEffect & SymbolEffect]

  /// View Properties
  @State private var imageViews: [Selection: UIImageView] = [:]

  public init(
    selection: Binding<Selection>,
    @TabContentBuilder<Selection> content: @escaping () -> Content,
    effects: @escaping (Selection) -> [any DiscreteSymbolEffect & SymbolEffect]
  ) {
    self._selection = selection
    self.content = content
    self.effects = effects
  }

  public var body: some View {
    TabView(selection: $selection) {
      content()
    }
    .tabViewStyle(.tabBarOnly)
    .background(ExtractImageViewsFromTabView {
      imageViews = $0
    })
    .compositingGroup()
    .onChange(of: selection) { oldValue, newValue in
      guard let imageView = imageViews[newValue] else { return }
      let symbolEffects = effects(newValue)

      for effect in symbolEffects {
        imageView.addSymbolEffect(effect, options: .nonRepeating)
      }
    }
  }
}

// MARK: - Private Helper

fileprivate struct ExtractImageViewsFromTabView<Value: AnimatedTabSelectionProtocol>: UIViewRepresentable {
  var result: ([Value: UIImageView]) -> Void

  func makeUIView(context: Context) -> UIView {
    let view = UIView()
    view.backgroundColor = .clear
    view.isUserInteractionEnabled = false

    DispatchQueue.main.async {
      if let compositingGroup = view.superview?.superview {
        guard let tabHostingController = compositingGroup.subviews.last else { return }
        guard let tabController = tabHostingController.subviews.first?.next as? UITabBarController else { return }

        extractImageViews(tabController.tabBar)
      }
    }

    return view
  }

  func updateUIView(_ uiView: UIView, context: Context) {}

  private func extractImageViews(_ tabBar: UITabBar) {
    let allImageViews = tabBar.allSubviews(ofType: UIImageView.self)
    let symbolImageViews = allImageViews.filter { $0.image?.isSymbolImage ?? false }
    let imageViews: [UIImageView]
    if isiOS26 {
      imageViews = symbolImageViews.filter { $0.tintColor == tabBar.tintColor }
    } else {
      imageViews = symbolImageViews
    }

    var dict: [Value: UIImageView] = [:]

    for tab in Value.allCases {
      if let imageView = imageViews.first(where: {
        $0.description.contains(tab.symbolImage)
      }) {
        dict[tab] = imageView
      }
    }

    result(dict)
  }

  private var isiOS26: Bool {
    if #available(iOS 26, *) {
      return true
    }
    return false
  }
}
