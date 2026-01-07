import Foundation

public extension Collection {
  var isNotEmpty: Bool {
    !isEmpty
  }
}

public extension Optional where Wrapped == String {
  var isNilOrEmpty: Bool {
    self?.isEmpty ?? true
  }

  var isNotNilOrEmpty: Bool {
    !isNilOrEmpty
  }
}
