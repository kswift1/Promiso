import UIKit

extension UIView {
  /// 특정 타입의 모든 서브뷰를 반복적으로 추출 (큐 기반, 스택 오버플로우 방지)
  public func allSubviews<T: UIView>(ofType type: T.Type) -> [T] {
    var result: [T] = []
    var queue = self.subviews

    while !queue.isEmpty {
      let view = queue.removeFirst()
      if let typedView = view as? T {
        result.append(typedView)
      }
      queue.append(contentsOf: view.subviews)
    }

    return result
  }
}
