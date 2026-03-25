import SwiftUI

// MARK: - Description Block Editor

public struct DescriptionBlockEditor: View {
  @Binding public var blocks: [DescriptionBlock]
  public var characterLimit: Int
  @FocusState private var focusedItem: ItemFocus?

  private struct ItemFocus: Hashable {
    let blockIndex: Int
    let itemIndex: Int
  }

  public init(blocks: Binding<[DescriptionBlock]>, characterLimit: Int = 500) {
    self._blocks = blocks
    self.characterLimit = characterLimit
  }

  // 총 글자 수 계산 (사용자 입력 텍스트만)
  private var totalCharacterCount: Int {
    blocks.reduce(0) { total, block in
      switch block.content {
      case .text(let text):
        return total + text.count
      case .checklist(let items):
        return total + items.reduce(0) { $0 + $1.text.count }
      case .bulletList(let items):
        return total + items.reduce(0) { $0 + $1.count }
      }
    }
  }

  public var body: some View {
    ScrollViewReader { proxy in
      let _ = ensureDefaultBlock()
      VStack(alignment: .leading, spacing: 16) {
        ForEach(blocks.indices, id: \.self) { index in
          if blocks.count > 1 && index > 0 {
            Divider()
          }
          blockEditorRow(for: index, proxy: proxy)
        }

        // 컴팩트 블록 추가 버튼
        addBlockRow

        // 글자 수 카운터
        HStack {
          Spacer()
          Text("\(totalCharacterCount)/\(characterLimit)")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
        }
      }
      .onAppear {
        if blocks.isEmpty {
          blocks.append(DescriptionBlock(content: .text("")))
        }
      }
      .onChange(of: focusedItem) { _, newItem in
        guard let newItem else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
          proxy.scrollTo("block-\(newItem.blockIndex)-item-\(newItem.itemIndex)", anchor: .center)
        }
      }
    }
  }

  // body에서 호출하여 빈 경우 기본 블록 확보 (State 변경은 onAppear에서)
  @discardableResult
  private func ensureDefaultBlock() -> Bool {
    return !blocks.isEmpty
  }

  // MARK: - Block Editor Row

  @ViewBuilder
  private func blockEditorRow(for index: Int, proxy: ScrollViewProxy) -> some View {
    switch blocks[index].content {
    case .text:
      textBlockRow(for: index, proxy: proxy)
    case .checklist:
      checklistBlockRow(for: index)
    case .bulletList:
      bulletListBlockRow(for: index)
    }
  }

  // MARK: - Block Header (공통 — 전체 탭 가능, 오른쪽 ellipsis)

  private func blockHeader(for index: Int) -> some View {
    let title: String = switch blocks[index].content {
    case .text: "텍스트"
    case .checklist: "체크리스트"
    case .bulletList: "목록"
    }

    return Menu {
      Button {
        convertBlock(at: index, to: .text(""))
      } label: {
        Label("텍스트", systemImage: "text.alignleft")
      }

      Button {
        convertBlock(at: index, to: .checklist([ChecklistItem(text: "")]))
      } label: {
        Label("체크리스트", systemImage: "checklist")
      }

      Button {
        convertBlock(at: index, to: .bulletList([""]))
      } label: {
        Label("목록", systemImage: "list.bullet")
      }

      Divider()

      Button(role: .destructive) {
        withAnimation(.easeInOut(duration: 0.2)) {
          _ = blocks.remove(at: index)
        }
      } label: {
        Label("삭제", systemImage: "trash")
      }
    } label: {
      HStack(spacing: 4) {
        Image(systemName: blockTypeIconName(blocks[index].content))
          .font(.system(size: 13))
        Text(title)
          .font(.system(size: 13, weight: .medium))
        Spacer()
        Image(systemName: "ellipsis")
          .font(.system(size: 14))
      }
      .foregroundStyle(.secondary)
      .padding(.vertical, 2)
      .contentShape(Rectangle())
    }
    .menuStyle(.button)
    .buttonStyle(.plain)
  }

  // MARK: - Text Block

  private func textBlockRow(for index: Int, proxy: ScrollViewProxy) -> some View {
    let textContent: String = {
      if case .text(let text) = blocks[index].content { return text }
      return ""
    }()

    return VStack(alignment: .leading, spacing: 6) {
      blockHeader(for: index)

      TextField(
        "내용을 입력하세요",
        text: Binding(
          get: {
            if case .text(let text) = blocks[index].content { return text }
            return ""
          },
          set: { newValue in
            blocks[index].content = .text(newValue)
          }
        ),
        axis: .vertical
      )
      .lineLimit(2...10)
      .focused($focusedItem, equals: ItemFocus(blockIndex: index, itemIndex: 0))
      .font(.system(size: 15))
    }
    .id("block-\(index)-item-0")
    .onChange(of: textContent) { _, _ in
      guard focusedItem == ItemFocus(blockIndex: index, itemIndex: 0) else { return }
      DispatchQueue.main.async {
        withAnimation(.easeInOut(duration: 0.15)) {
          proxy.scrollTo("block-\(index)-item-0", anchor: .bottom)
        }
      }
    }
  }

  // MARK: - Checklist Block

  private func checklistBlockRow(for index: Int) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      blockHeader(for: index)

      if case .checklist(let items) = blocks[index].content {
        ForEach(items.indices, id: \.self) { itemIndex in
          checklistItemRow(blockIndex: index, itemIndex: itemIndex)
        }
      }
    }
  }

  private func checklistItemRow(blockIndex: Int, itemIndex: Int) -> some View {
    HStack(spacing: 8) {
      Button {
        if case .checklist(var items) = blocks[blockIndex].content {
          items[itemIndex].isChecked.toggle()
          blocks[blockIndex].content = .checklist(items)
        }
      } label: {
        Image(systemName: {
          if case .checklist(let items) = blocks[blockIndex].content,
             itemIndex < items.count {
            return items[itemIndex].isChecked
              ? "checkmark.circle.fill"
              : "circle"
          }
          return "circle"
        }())
        .font(.system(size: 18))
        .foregroundStyle(
          {
            if case .checklist(let items) = blocks[blockIndex].content,
               itemIndex < items.count, items[itemIndex].isChecked {
              return Color.pmindigo.n500
            }
            return Color(.systemGray3)
          }()
        )
      }
      .buttonStyle(.plain)

      TextField(
        "할 일",
        text: Binding(
          get: {
            if case .checklist(let items) = blocks[blockIndex].content,
               itemIndex < items.count {
              return items[itemIndex].text
            }
            return ""
          },
          set: { newValue in
            guard case .checklist(var items) = blocks[blockIndex].content,
                  itemIndex < items.count else { return }
            if let newlineIndex = newValue.firstIndex(of: "\n") {
              let before = String(newValue[newValue.startIndex..<newlineIndex])
              let after = String(newValue[newValue.index(after: newlineIndex)...])
              // 빈 문자열이면 줄바꿈만 제거하고 새 항목 추가 안 함
              guard !before.trimmingCharacters(in: .whitespaces).isEmpty else {
                items[itemIndex].text = before
                blocks[blockIndex].content = .checklist(items)
                return
              }
              // 이중 트리거 방지: 이미 분리된 상태면 스킵
              if items[itemIndex].text == before,
                 itemIndex + 1 < items.count,
                 items[itemIndex + 1].text == after {
                return
              }
              items[itemIndex].text = before
              let newItem = ChecklistItem(text: after)
              items.insert(newItem, at: itemIndex + 1)
              blocks[blockIndex].content = .checklist(items)
              DispatchQueue.main.async {
                focusedItem = ItemFocus(blockIndex: blockIndex, itemIndex: itemIndex + 1)
              }
            } else {
              items[itemIndex].text = newValue
              blocks[blockIndex].content = .checklist(items)
            }
          }
        ),
        axis: .vertical
      )
      .lineLimit(1)
      .focused($focusedItem, equals: ItemFocus(blockIndex: blockIndex, itemIndex: itemIndex))
      .font(.system(size: 15))
      .strikethrough({
        if case .checklist(let items) = blocks[blockIndex].content,
           itemIndex < items.count {
          return items[itemIndex].isChecked
        }
        return false
      }())

      // 삭제 버튼
      Button {
        if case .checklist(var items) = blocks[blockIndex].content {
          items.remove(at: itemIndex)
          if items.isEmpty {
            items.append(ChecklistItem(text: ""))
          }
          blocks[blockIndex].content = .checklist(items)
        }
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 11))
          .foregroundStyle(Color(.systemGray3))
      }
      .buttonStyle(.plain)
    }
    .id("block-\(blockIndex)-item-\(itemIndex)")
  }

  // MARK: - Bullet List Block

  private func bulletListBlockRow(for index: Int) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      blockHeader(for: index)

      if case .bulletList(let items) = blocks[index].content {
        ForEach(items.indices, id: \.self) { itemIndex in
          bulletItemRow(blockIndex: index, itemIndex: itemIndex)
        }
      }
    }
  }

  private func bulletItemRow(blockIndex: Int, itemIndex: Int) -> some View {
    HStack(spacing: 8) {
      Circle()
        .fill(Color.pmtext.secondary)
        .frame(width: 5, height: 5)
        .padding(.leading, 4)

      TextField(
        "항목",
        text: Binding(
          get: {
            if case .bulletList(let items) = blocks[blockIndex].content,
               itemIndex < items.count {
              return items[itemIndex]
            }
            return ""
          },
          set: { newValue in
            guard case .bulletList(var items) = blocks[blockIndex].content,
                  itemIndex < items.count else { return }
            if let newlineIndex = newValue.firstIndex(of: "\n") {
              let before = String(newValue[newValue.startIndex..<newlineIndex])
              let after = String(newValue[newValue.index(after: newlineIndex)...])
              // 빈 문자열이면 줄바꿈만 제거하고 새 항목 추가 안 함
              guard !before.trimmingCharacters(in: .whitespaces).isEmpty else {
                items[itemIndex] = before
                blocks[blockIndex].content = .bulletList(items)
                return
              }
              // 이중 트리거 방지
              if items[itemIndex] == before,
                 itemIndex + 1 < items.count,
                 items[itemIndex + 1] == after {
                return
              }
              items[itemIndex] = before
              items.insert(after, at: itemIndex + 1)
              blocks[blockIndex].content = .bulletList(items)
              DispatchQueue.main.async {
                focusedItem = ItemFocus(blockIndex: blockIndex, itemIndex: itemIndex + 1)
              }
            } else {
              items[itemIndex] = newValue
              blocks[blockIndex].content = .bulletList(items)
            }
          }
        ),
        axis: .vertical
      )
      .lineLimit(1)
      .focused($focusedItem, equals: ItemFocus(blockIndex: blockIndex, itemIndex: itemIndex))
      .font(.system(size: 15))

      // 삭제 버튼
      Button {
        if case .bulletList(var items) = blocks[blockIndex].content {
          items.remove(at: itemIndex)
          if items.isEmpty {
            items.append("")
          }
          blocks[blockIndex].content = .bulletList(items)
        }
      } label: {
        Image(systemName: "xmark")
          .font(.system(size: 11))
          .foregroundStyle(Color(.systemGray3))
      }
      .buttonStyle(.plain)
    }
    .id("block-\(blockIndex)-item-\(itemIndex)")
  }

  private func blockTypeIconName(_ content: DescriptionBlock.BlockContent) -> String {
    switch content {
    case .text: return "text.alignleft"
    case .checklist: return "checklist"
    case .bulletList: return "list.bullet"
    }
  }

  // MARK: - 타입 변환 로직

  private func convertBlock(at index: Int, to targetContent: DescriptionBlock.BlockContent) {
    let current = blocks[index].content

    // 이미 같은 타입이면 무시
    switch (current, targetContent) {
    case (.text, .text), (.checklist, .checklist), (.bulletList, .bulletList):
      return
    default:
      break
    }

    let newContent: DescriptionBlock.BlockContent
    switch targetContent {
    case .text:
      switch current {
      case .text(let t):
        newContent = .text(t)
      case .checklist(let items):
        newContent = .text(items.map { $0.text }.joined(separator: "\n"))
      case .bulletList(let items):
        newContent = .text(items.joined(separator: "\n"))
      }

    case .checklist:
      switch current {
      case .text(let t):
        let lines = t.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        let items = lines.isEmpty ? [ChecklistItem(text: "")] : lines.map { ChecklistItem(text: $0) }
        newContent = .checklist(items)
      case .checklist(let items):
        newContent = .checklist(items)
      case .bulletList(let items):
        let checkItems = items.isEmpty ? [ChecklistItem(text: "")] : items.map { ChecklistItem(text: $0) }
        newContent = .checklist(checkItems)
      }

    case .bulletList:
      switch current {
      case .text(let t):
        let lines = t.split(separator: "\n", omittingEmptySubsequences: false).map { String($0) }
        newContent = .bulletList(lines.isEmpty ? [""] : lines)
      case .checklist(let items):
        newContent = .bulletList(items.isEmpty ? [""] : items.map { $0.text })
      case .bulletList(let items):
        newContent = .bulletList(items)
      }
    }

    withAnimation(.easeInOut(duration: 0.15)) {
      blocks[index].content = newContent
    }
  }

  // MARK: - Add Block Row (컴팩트)

  private var addBlockRow: some View {
    HStack(spacing: 8) {
      addBlockButton(title: "+ 텍스트", content: .text(""))
      addBlockButton(title: "+ 체크리스트", content: .checklist([ChecklistItem(text: "")]))
      addBlockButton(title: "+ 목록", content: .bulletList([""]))
      Spacer()
    }
  }

  private func addBlockButton(
    title: String,
    content: DescriptionBlock.BlockContent
  ) -> some View {
    Button {
      withAnimation(.easeInOut(duration: 0.15)) {
        blocks.append(DescriptionBlock(content: content))
      }
    } label: {
      Text(title)
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(Color.pmindigo.n500)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.pmindigo.n50)
        .clipShape(Capsule())
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Previews

#Preview("빈 에디터") {
  @Previewable @State var blocks: [DescriptionBlock] = []
  return ScrollView {
    DescriptionBlockEditor(blocks: $blocks)
      .padding(16)
  }
}

#Preview("텍스트 블록") {
  @Previewable @State var blocks: [DescriptionBlock] = [
    DescriptionBlock(content: .text("일정 설명을 입력하세요."))
  ]
  return ScrollView {
    DescriptionBlockEditor(blocks: $blocks)
      .padding(16)
  }
}

#Preview("복합 블록") {
  @Previewable @State var blocks: [DescriptionBlock] = [
    DescriptionBlock(content: .text("준비물")),
    DescriptionBlock(content: .checklist([
      ChecklistItem(text: "지갑", isChecked: true),
      ChecklistItem(text: "신분증")
    ])),
    DescriptionBlock(content: .bulletList(["장소: 강남역", "시간: 오후 6시"]))
  ]
  return ScrollView {
    DescriptionBlockEditor(blocks: $blocks)
      .padding(16)
  }
}
