//
//  DescriptionBlockTests.swift
//  PromisoShared
//
//  DescriptionBlock 모델 단위 테스트
//
//  ## 테스트 대상
//  - `PromisoShared/Sources/Models/DescriptionBlock.swift`
//
//  ## 테스트 목적
//  - DescriptionBlock.isEmpty: 각 블록 타입별 빈 상태 판정
//  - Array<DescriptionBlock>.nilIfAllEmpty: 빈 블록 필터링 후 nil 반환
//  - Array<DescriptionBlock>.plainText: 빈 블록 제외하고 플레인 텍스트 생성
//

import Foundation
import Testing
@testable import PromisoShared

// MARK: - DescriptionBlock text isEmpty 테스트

@Suite("DescriptionBlock text isEmpty 테스트")
struct DescriptionBlockTextIsEmptyTests {

  @Test("빈 문자열이면 isEmpty = true")
  func emptyString_isEmptyTrue() {
    let block = DescriptionBlock(content: .text(""))
    #expect(block.isEmpty == true)
  }

  @Test("공백과 줄바꿈만 있으면 isEmpty = true")
  func whitespaceAndNewlines_isEmptyTrue() {
    let block = DescriptionBlock(content: .text("  \n  "))
    #expect(block.isEmpty == true)
  }

  @Test("내용이 있으면 isEmpty = false")
  func nonEmptyString_isEmptyFalse() {
    let block = DescriptionBlock(content: .text("내용"))
    #expect(block.isEmpty == false)
  }

  @Test("앞뒤 공백이 있어도 내용이 있으면 isEmpty = false")
  func paddedString_isEmptyFalse() {
    let block = DescriptionBlock(content: .text("  내용  "))
    #expect(block.isEmpty == false)
  }
}

// MARK: - DescriptionBlock checklist isEmpty 테스트

@Suite("DescriptionBlock checklist isEmpty 테스트")
struct DescriptionBlockChecklistIsEmptyTests {

  @Test("빈 배열이면 isEmpty = true")
  func emptyArray_isEmptyTrue() {
    let block = DescriptionBlock(content: .checklist([]))
    #expect(block.isEmpty == true)
  }

  @Test("빈 텍스트 아이템만 있으면 isEmpty = true")
  func singleEmptyTextItem_isEmptyTrue() {
    let block = DescriptionBlock(content: .checklist([
      ChecklistItem(text: ""),
    ]))
    #expect(block.isEmpty == true)
  }

  @Test("공백만 있는 텍스트 아이템이면 isEmpty = true")
  func whitespaceOnlyItem_isEmptyTrue() {
    let block = DescriptionBlock(content: .checklist([
      ChecklistItem(text: "  "),
    ]))
    #expect(block.isEmpty == true)
  }

  @Test("내용이 있는 아이템이 하나라도 있으면 isEmpty = false")
  func itemWithText_isEmptyFalse() {
    let block = DescriptionBlock(content: .checklist([
      ChecklistItem(text: "할 일"),
    ]))
    #expect(block.isEmpty == false)
  }

  @Test("체크된 아이템이어도 텍스트가 비어있으면 isEmpty = true")
  func checkedItemWithEmptyText_isEmptyTrue() {
    let block = DescriptionBlock(content: .checklist([
      ChecklistItem(text: "", isChecked: true),
    ]))
    #expect(block.isEmpty == true)
  }

  @Test("여러 아이템이 모두 빈 텍스트면 isEmpty = true")
  func multipleEmptyItems_isEmptyTrue() {
    let block = DescriptionBlock(content: .checklist([
      ChecklistItem(text: ""),
      ChecklistItem(text: "  "),
      ChecklistItem(text: "\n"),
    ]))
    #expect(block.isEmpty == true)
  }

  @Test("빈 아이템과 내용 아이템이 섞이면 isEmpty = false")
  func mixedItems_isEmptyFalse() {
    let block = DescriptionBlock(content: .checklist([
      ChecklistItem(text: ""),
      ChecklistItem(text: "할 일"),
    ]))
    #expect(block.isEmpty == false)
  }
}

// MARK: - DescriptionBlock bulletList isEmpty 테스트

@Suite("DescriptionBlock bulletList isEmpty 테스트")
struct DescriptionBlockBulletListIsEmptyTests {

  @Test("빈 배열이면 isEmpty = true")
  func emptyArray_isEmptyTrue() {
    let block = DescriptionBlock(content: .bulletList([]))
    #expect(block.isEmpty == true)
  }

  @Test("빈 문자열 항목만 있으면 isEmpty = true")
  func emptyStringItem_isEmptyTrue() {
    let block = DescriptionBlock(content: .bulletList([""]))
    #expect(block.isEmpty == true)
  }

  @Test("공백만 있는 항목이면 isEmpty = true")
  func whitespaceOnlyItem_isEmptyTrue() {
    let block = DescriptionBlock(content: .bulletList(["  "]))
    #expect(block.isEmpty == true)
  }

  @Test("내용이 있는 항목이 있으면 isEmpty = false")
  func itemWithText_isEmptyFalse() {
    let block = DescriptionBlock(content: .bulletList(["항목"]))
    #expect(block.isEmpty == false)
  }
}

// MARK: - Array<DescriptionBlock> nilIfAllEmpty 테스트

@Suite("Array<DescriptionBlock> nilIfAllEmpty 테스트")
struct DescriptionBlockArrayNilIfAllEmptyTests {

  @Test("빈 배열이면 nil 반환")
  func emptyArray_returnsNil() {
    let blocks: [DescriptionBlock] = []
    #expect(blocks.nilIfAllEmpty == nil)
  }

  @Test("모든 블록이 비어있으면 nil 반환")
  func allEmptyBlocks_returnsNil() {
    let blocks: [DescriptionBlock] = [
      DescriptionBlock(content: .text("")),
      DescriptionBlock(content: .checklist([])),
      DescriptionBlock(content: .bulletList([])),
    ]
    #expect(blocks.nilIfAllEmpty == nil)
  }

  @Test("내용 있는 블록이 하나라도 있으면 non-nil 반환")
  func oneNonEmptyBlock_returnsNonNil() {
    let blocks: [DescriptionBlock] = [
      DescriptionBlock(content: .text("")),
      DescriptionBlock(content: .text("내용")),
    ]
    #expect(blocks.nilIfAllEmpty != nil)
  }

  @Test("빈 블록은 필터링되고 내용 있는 블록만 반환")
  func filtersEmptyBlocks_returnsOnlyNonEmpty() {
    let nonEmpty = DescriptionBlock(content: .text("내용"))
    let blocks: [DescriptionBlock] = [
      DescriptionBlock(content: .text("")),
      nonEmpty,
      DescriptionBlock(content: .checklist([])),
    ]
    let result = blocks.nilIfAllEmpty
    #expect(result?.count == 1)
    #expect(result?.first?.id == nonEmpty.id)
  }

  @Test("모든 블록이 내용 있으면 전체 반환")
  func allNonEmptyBlocks_returnsAll() {
    let blocks: [DescriptionBlock] = [
      DescriptionBlock(content: .text("텍스트")),
      DescriptionBlock(content: .checklist([ChecklistItem(text: "할 일")])),
      DescriptionBlock(content: .bulletList(["항목"])),
    ]
    #expect(blocks.nilIfAllEmpty?.count == 3)
  }
}

// MARK: - Array<DescriptionBlock> plainText 빈 블록 필터링 테스트

@Suite("Array<DescriptionBlock> plainText 빈 블록 필터링 테스트")
struct DescriptionBlockArrayPlainTextTests {

  @Test("빈 배열이면 nil 반환")
  func emptyArray_returnsNil() {
    let blocks: [DescriptionBlock] = []
    #expect(blocks.plainText == nil)
  }

  @Test("모든 블록이 비어있으면 nil 반환")
  func allEmptyBlocks_returnsNil() {
    let blocks: [DescriptionBlock] = [
      DescriptionBlock(content: .text("")),
      DescriptionBlock(content: .checklist([])),
    ]
    #expect(blocks.plainText == nil)
  }

  @Test("빈 텍스트 블록은 제외하고 내용 있는 체크리스트만 포함")
  func emptyTextBlock_excludedFromPlainText() {
    let blocks: [DescriptionBlock] = [
      DescriptionBlock(content: .text("")),
      DescriptionBlock(content: .checklist([ChecklistItem(text: "할 일", isChecked: false)])),
    ]
    let result = blocks.plainText
    #expect(result != nil)
    #expect(result?.contains("할 일") == true)
    #expect(result?.contains("☐") == true)
  }

  @Test("내용 있는 블록들은 두 줄 간격으로 합쳐짐")
  func nonEmptyBlocks_joinedWithDoubleNewline() {
    let blocks: [DescriptionBlock] = [
      DescriptionBlock(content: .text("첫 번째")),
      DescriptionBlock(content: .text("두 번째")),
    ]
    let result = blocks.plainText
    #expect(result == "첫 번째\n\n두 번째")
  }

  @Test("빈 블록과 내용 블록 사이에 이중 줄바꿈 없음")
  func emptyBlockSkipped_noExtraNewlines() {
    let blocks: [DescriptionBlock] = [
      DescriptionBlock(content: .text("첫 번째")),
      DescriptionBlock(content: .text("")),
      DescriptionBlock(content: .text("두 번째")),
    ]
    let result = blocks.plainText
    #expect(result == "첫 번째\n\n두 번째")
  }

  @Test("체크리스트 완료 항목은 ☑ 기호로 표시")
  func checkedItem_showsCheckedSymbol() {
    let blocks: [DescriptionBlock] = [
      DescriptionBlock(content: .checklist([
        ChecklistItem(text: "완료 항목", isChecked: true),
        ChecklistItem(text: "미완료 항목", isChecked: false),
      ])),
    ]
    let result = blocks.plainText
    #expect(result?.contains("☑ 완료 항목") == true)
    #expect(result?.contains("☐ 미완료 항목") == true)
  }

  @Test("불릿 리스트 항목은 • 기호로 표시")
  func bulletList_showsBulletSymbol() {
    let blocks: [DescriptionBlock] = [
      DescriptionBlock(content: .bulletList(["항목 A", "항목 B"])),
    ]
    let result = blocks.plainText
    #expect(result?.contains("• 항목 A") == true)
    #expect(result?.contains("• 항목 B") == true)
  }
}
