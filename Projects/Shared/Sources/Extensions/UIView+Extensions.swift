import UIKit

extension UIView {
  /// 특정 타입의 모든 서브뷰를 재귀적으로 추출
  public func allSubviews<T: UIView>(ofType type: T.Type) -> [T] {
    subviews.compactMap { $0 as? T } +
    subviews.flatMap { $0.allSubviews(ofType: type) }
  }
}
