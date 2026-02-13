//
//  ArrayExtensionsTests.swift
//  PromisoShared
//
//  Array 확장 테스트
//
//  ## 테스트 대상
//  - `PromisoShared/Sources/Extensions/Array+Extensions.swift`
//
//  ## 테스트 목적
//  - chunked(into:): 배열을 지정된 크기의 청크로 분할
//  - 엣지 케이스: 빈 배열, 단일 요소, 청크 크기가 배열보다 큰 경우, 0 이하 크기
//

import Foundation
import Testing
@testable import PromisoShared

@Suite("Array.chunked(into:) 테스트")
struct ArrayChunkedTests {

  @Test("5개 요소를 2개씩 분할하면 [[1,2],[3,4],[5]]")
  func chunkedIntoTwo() {
    let array = [1, 2, 3, 4, 5]
    let result = array.chunked(into: 2)
    #expect(result == [[1, 2], [3, 4], [5]])
  }

  @Test("6개 요소를 3개씩 분할하면 [[1,2,3],[4,5,6]]")
  func evenlyDivisible() {
    let array = [1, 2, 3, 4, 5, 6]
    let result = array.chunked(into: 3)
    #expect(result == [[1, 2, 3], [4, 5, 6]])
  }

  @Test("빈 배열은 빈 결과 반환")
  func emptyArray_returnsEmpty() {
    let array: [Int] = []
    let result = array.chunked(into: 3)
    #expect(result.isEmpty)
  }

  @Test("단일 요소 배열은 하나의 청크 반환")
  func singleElement_returnsSingleChunk() {
    let array = [42]
    let result = array.chunked(into: 5)
    #expect(result == [[42]])
  }

  @Test("청크 크기가 배열보다 크면 전체가 하나의 청크")
  func chunkSizeLargerThanArray_returnsSingleChunk() {
    let array = [1, 2, 3]
    let result = array.chunked(into: 10)
    #expect(result == [[1, 2, 3]])
  }

  @Test("청크 크기 0이면 빈 배열 반환")
  func chunkSizeZero_returnsEmpty() {
    let array = [1, 2, 3]
    let result = array.chunked(into: 0)
    #expect(result.isEmpty)
  }

  @Test("청크 크기 음수면 빈 배열 반환")
  func chunkSizeNegative_returnsEmpty() {
    let array = [1, 2, 3]
    let result = array.chunked(into: -1)
    #expect(result.isEmpty)
  }

  @Test("청크 크기 1이면 각 요소가 별도의 청크")
  func chunkSizeOne_returnsIndividualChunks() {
    let array = [1, 2, 3]
    let result = array.chunked(into: 1)
    #expect(result == [[1], [2], [3]])
  }
}
