import SwiftUI

// MARK: - Description Block Editor

public struct DescriptionBlockEditor: View {
  @Binding public var blocks: [DescriptionBlock]
  public var characterLimit: Int

  public init(blocks: Binding<[DescriptionBlock]>, characterLimit: Int = 500) {
    self._blocks = blocks
    self.characterLimit = characterLimit
  }

  // 총 글자 수 계산
  private var totalCharacterCount: Int {
    blocks.reduce(0) { total, block in
      total + block.plainText.count
    }
  }

  public var body: some View {
    let _ = ensureDefaultBlock()
    VStack(alignment: .leading, spacing: 16) {
      ForEach(blocks.indices, id: \.self) { index in
        blockEditorRow(for: index)
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
  }

  // body에서 호출하여 빈 경우 기본 블록 확보 (State 변경은 onAppear에서)
  @discardableResult
  private func ensureDefaultBlock() -> Bool {
    return !blocks.isEmpty
  }

  // MARK: - Block Editor Row

  @ViewBuilder
  private func blockEditorRow(for index: Int) -> some View {
    switch blocks[index].content {
    case .text:
      textBlockRow(for: index)
    case .checklist:
      checklistBlockRow(for: index)
    case .bulletList:
      bulletListBlockRow(for: index)
    }
  }

  // MARK: - Text Block (플랫, 카드 없음)

  private func textBlockRow(for index: Int) -> some View {
    HStack(alignment: .top, spacing: 8) {
      blockTypeMenu(for: index)

      TextField(
        "텍스트 입력",
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
      .font(.system(size: 15))
    }
  }

  // MARK: - Checklist Block

  private func checklistBlockRow(for index: Int) -> some View {
    HStack(alignment: .top, spacing: 8) {
      blockTypeMenu(for: index)

      VStack(alignment: .leading, spacing: 6) {
        if case .checklist(let items) = blocks[index].content {
          ForEach(items.indices, id: \.self) { itemIndex in
            checklistItemRow(blockIndex: index, itemIndex: itemIndex)
          }
        }
      }
      .padding(.leading, 4)
      .overlay(
        alignment: .leading,
        content: {
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.pmindigo.n500.opacity(0.3))
            .frame(width: 2)
            .padding(.leading, 0)
        }
      )
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
            if newValue.contains("\n") {
              let parts = newValue.split(
                separator: "\n",
                maxSplits: 1,
                omittingEmptySubsequences: false
              )
              items[itemIndex].text = String(parts[0])
              let newItemText = parts.count > 1 ? String(parts[1]) : ""
              let newItem = ChecklistItem(text: newItemText)
              items.insert(newItem, at: itemIndex + 1)
              blocks[blockIndex].content = .checklist(items)
            } else {
              items[itemIndex].text = newValue
              blocks[blockIndex].content = .checklist(items)
            }
          }
        )
      )
      .font(.system(size: 15))
      .strikethrough({
        if case .checklist(let items) = blocks[blockIndex].content,
           itemIndex < items.count {
          return items[itemIndex].isChecked
        }
        return false
      }())
    }
  }

  // MARK: - Bullet List Block

  private func bulletListBlockRow(for index: Int) -> some View {
    HStack(alignment: .top, spacing: 8) {
      blockTypeMenu(for: index)

      VStack(alignment: .leading, spacing: 6) {
        if case .bulletList(let items) = blocks[index].content {
          ForEach(items.indices, id: \.self) { itemIndex in
            bulletItemRow(blockIndex: index, itemIndex: itemIndex)
          }
        }
      }
      .padding(.leading, 4)
      .overlay(
        alignment: .leading,
        content: {
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.pmtext.secondary.opacity(0.4))
            .frame(width: 2)
        }
      )
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
            if newValue.contains("\n") {
              let parts = newValue.split(
                separator: "\n",
                maxSplits: 1,
                omittingEmptySubsequences: false
              )
              items[itemIndex] = String(parts[0])
              let newItemText = parts.count > 1 ? String(parts[1]) : ""
              items.insert(newItemText, at: itemIndex + 1)
              blocks[blockIndex].content = .bulletList(items)
            } else {
              items[itemIndex] = newValue
              blocks[blockIndex].content = .bulletList(items)
            }
          }
        )
      )
      .font(.system(size: 15))
    }
  }

  // MARK: - Block Type Menu (타입 전환 + 삭제)

  private func blockTypeMenu(for index: Int) -> some View {
    Menu {
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
      Image(systemName: blockTypeIconName(blocks[index].content))
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .frame(width: 20, height: 20)
        .contentShape(Rectangle())
    }
    .menuStyle(.button)
    .buttonStyle(.plain)
    .padding(.top, 2)
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
