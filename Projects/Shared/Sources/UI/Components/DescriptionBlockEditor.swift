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
    VStack(alignment: .leading, spacing: 12) {
      // 블록 목록
      ForEach(blocks.indices, id: \.self) { index in
        blockEditorRow(for: index)
      }

      // 블록 추가 버튼
      addBlockMenu

      // 글자 수 카운터
      HStack {
        Spacer()
        Text("\(totalCharacterCount)/\(characterLimit)")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Block Editor Row

  @ViewBuilder
  private func blockEditorRow(for index: Int) -> some View {
    let block = blocks[index]
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 8) {
        // 블록 타입 아이콘
        blockTypeIcon(block.content)
          .padding(.top, 12)

        // 블록 콘텐츠 에디터
        blockContentEditor(for: index)

        // 삭제 버튼
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            _ = blocks.remove(at: index)
          }
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 18))
            .foregroundStyle(Color(.systemGray3))
        }
        .buttonStyle(.plain)
        .padding(.top, 10)
      }
    }
    .padding(12)
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  @ViewBuilder
  private func blockTypeIcon(_ content: DescriptionBlock.BlockContent) -> some View {
    Group {
      switch content {
      case .text:
        Image(systemName: "text.alignleft")
      case .checklist:
        Image(systemName: "checklist")
      case .bulletList:
        Image(systemName: "list.bullet")
      }
    }
    .font(.system(size: 14))
    .foregroundStyle(.secondary)
    .frame(width: 20)
  }

  // MARK: - Block Content Editors

  @ViewBuilder
  private func blockContentEditor(for index: Int) -> some View {
    switch blocks[index].content {
    case .text:
      textBlockEditor(for: index)
    case .checklist:
      checklistBlockEditor(for: index)
    case .bulletList:
      bulletListBlockEditor(for: index)
    }
  }

  // 텍스트 블록 에디터
  private func textBlockEditor(for index: Int) -> some View {
    TextField(
      "텍스트 입력",
      text: Binding(
        get: {
          if case .text(let text) = blocks[index].content {
            return text
          }
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

  // 체크리스트 블록 에디터
  private func checklistBlockEditor(for index: Int) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      if case .checklist(let items) = blocks[index].content {
        ForEach(items.indices, id: \.self) { itemIndex in
          checklistItemRow(blockIndex: index, itemIndex: itemIndex)
        }
      }

      // 항목 추가 버튼
      Button {
        if case .checklist(var items) = blocks[index].content {
          items.append(ChecklistItem(text: ""))
          blocks[index].content = .checklist(items)
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "plus.circle")
            .font(.system(size: 14))
          Text("항목 추가")
            .font(.system(size: 13))
        }
        .foregroundStyle(Color.pmindigo.n500)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
    }
  }

  private func checklistItemRow(blockIndex: Int, itemIndex: Int) -> some View {
    HStack(spacing: 8) {
      // 체크 토글
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

      // 텍스트 입력
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
            if case .checklist(var items) = blocks[blockIndex].content,
               itemIndex < items.count {
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

      // 삭제 버튼
      Button {
        if case .checklist(var items) = blocks[blockIndex].content {
          items.remove(at: itemIndex)
          blocks[blockIndex].content = .checklist(items)
        }
      } label: {
        Image(systemName: "minus.circle")
          .font(.system(size: 14))
          .foregroundStyle(Color(.systemGray3))
      }
      .buttonStyle(.plain)
    }
  }

  // 불릿 리스트 블록 에디터
  private func bulletListBlockEditor(for index: Int) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      if case .bulletList(let items) = blocks[index].content {
        ForEach(items.indices, id: \.self) { itemIndex in
          bulletItemRow(blockIndex: index, itemIndex: itemIndex)
        }
      }

      // 항목 추가 버튼
      Button {
        if case .bulletList(var items) = blocks[index].content {
          items.append("")
          blocks[index].content = .bulletList(items)
        }
      } label: {
        HStack(spacing: 6) {
          Image(systemName: "plus.circle")
            .font(.system(size: 14))
          Text("항목 추가")
            .font(.system(size: 13))
        }
        .foregroundStyle(Color.pmindigo.n500)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
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
            if case .bulletList(var items) = blocks[blockIndex].content,
               itemIndex < items.count {
              items[itemIndex] = newValue
              blocks[blockIndex].content = .bulletList(items)
            }
          }
        )
      )
      .font(.system(size: 15))

      Button {
        if case .bulletList(var items) = blocks[blockIndex].content {
          items.remove(at: itemIndex)
          blocks[blockIndex].content = .bulletList(items)
        }
      } label: {
        Image(systemName: "minus.circle")
          .font(.system(size: 14))
          .foregroundStyle(Color(.systemGray3))
      }
      .buttonStyle(.plain)
    }
  }

  // MARK: - Add Block Menu

  private var addBlockMenu: some View {
    Menu {
      Button {
        withAnimation {
          blocks.append(DescriptionBlock(content: .text("")))
        }
      } label: {
        Label("텍스트", systemImage: "text.alignleft")
      }

      Button {
        withAnimation {
          blocks.append(DescriptionBlock(content: .checklist([ChecklistItem(text: "")])))
        }
      } label: {
        Label("체크리스트", systemImage: "checklist")
      }

      Button {
        withAnimation {
          blocks.append(DescriptionBlock(content: .bulletList([""])))
        }
      } label: {
        Label("목록", systemImage: "list.bullet")
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: "plus.circle.fill")
          .font(.system(size: 16))
        Text("블록 추가")
          .font(.system(size: 14, weight: .medium))
      }
      .foregroundStyle(Color.pmindigo.n500)
      .frame(maxWidth: .infinity)
      .padding(.vertical, 10)
      .background(Color.pmindigo.n50)
      .clipShape(RoundedRectangle(cornerRadius: 10))
      .contentShape(Rectangle())
    }
  }
}

// MARK: - Previews

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
