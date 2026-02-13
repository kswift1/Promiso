//
//  StringExtensionsTests.swift
//  PromisoShared
//
//  String 및 Collection 확장 테스트
//
//  ## 테스트 대상
//  - `PromisoShared/Sources/Extensions/String+Extensions.swift`
//
//  ## 테스트 목적
//  - Collection.isNotEmpty: 비어있지 않은 컬렉션 판별
//  - Optional<String>.isNilOrEmpty: nil 또는 빈 문자열 판별
//  - Optional<String>.isNotNilOrEmpty: nil도 아니고 빈 문자열도 아닌지 판별
//

import Foundation
import Testing
@testable import PromisoShared

// MARK: - Collection.isNotEmpty 테스트

@Suite("Collection.isNotEmpty 테스트")
struct CollectionIsNotEmptyTests {

  @Test("비어있지 않은 문자열은 isNotEmpty = true")
  func nonEmptyString_isNotEmpty() {
    let str = "hello"
    #expect(str.isNotEmpty == true)
  }

  @Test("빈 문자열은 isNotEmpty = false")
  func emptyString_isNotNotEmpty() {
    let str = ""
    #expect(str.isNotEmpty == false)
  }

  @Test("비어있지 않은 배열은 isNotEmpty = true")
  func nonEmptyArray_isNotEmpty() {
    let arr = [1, 2, 3]
    #expect(arr.isNotEmpty == true)
  }

  @Test("빈 배열은 isNotEmpty = false")
  func emptyArray_isNotNotEmpty() {
    let arr: [Int] = []
    #expect(arr.isNotEmpty == false)
  }
}

// MARK: - Optional<String>.isNilOrEmpty 테스트

@Suite("Optional<String>.isNilOrEmpty 테스트")
struct OptionalStringIsNilOrEmptyTests {

  @Test("nil은 isNilOrEmpty = true")
  func nilValue_isNilOrEmpty() {
    let str: String? = nil
    #expect(str.isNilOrEmpty == true)
  }

  @Test("빈 문자열은 isNilOrEmpty = true")
  func emptyString_isNilOrEmpty() {
    let str: String? = ""
    #expect(str.isNilOrEmpty == true)
  }

  @Test("값이 있는 문자열은 isNilOrEmpty = false")
  func nonEmptyString_isNotNilOrEmpty() {
    let str: String? = "hello"
    #expect(str.isNilOrEmpty == false)
  }

  @Test("공백 문자열은 isNilOrEmpty = false (공백은 비어있지 않음)")
  func whitespaceString_isNotNilOrEmpty() {
    let str: String? = "  "
    #expect(str.isNilOrEmpty == false)
  }
}

// MARK: - Optional<String>.isNotNilOrEmpty 테스트

@Suite("Optional<String>.isNotNilOrEmpty 테스트")
struct OptionalStringIsNotNilOrEmptyTests {

  @Test("nil은 isNotNilOrEmpty = false")
  func nilValue_isNotNotNilOrEmpty() {
    let str: String? = nil
    #expect(str.isNotNilOrEmpty == false)
  }

  @Test("빈 문자열은 isNotNilOrEmpty = false")
  func emptyString_isNotNotNilOrEmpty() {
    let str: String? = ""
    #expect(str.isNotNilOrEmpty == false)
  }

  @Test("값이 있는 문자열은 isNotNilOrEmpty = true")
  func nonEmptyString_isNotNilOrEmpty() {
    let str: String? = "hello"
    #expect(str.isNotNilOrEmpty == true)
  }
}
