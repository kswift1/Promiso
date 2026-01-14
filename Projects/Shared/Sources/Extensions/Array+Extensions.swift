// MARK: - Array+Extensions.swift
// 배열 유틸리티 확장

import Foundation

public extension Array {
  /// 배열을 지정된 크기의 청크로 분할
  /// - Parameter size: 각 청크의 최대 크기
  /// - Returns: 분할된 배열들의 배열
  ///
  /// 예시:
  /// ```
  /// [1, 2, 3, 4, 5].chunked(into: 2) // [[1, 2], [3, 4], [5]]
  /// ```
  func chunked(into size: Int) -> [[Element]] {
    guard size > 0 else { return [] }
    return stride(from: 0, to: count, by: size).map {
      Array(self[$0..<Swift.min($0 + size, count)])
    }
  }
}
