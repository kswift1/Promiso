import SwiftUI

// MARK: - Description Block Renderer

public struct DescriptionBlockRenderer: View {
  private let blocks: [DescriptionBlock]
  @Binding private var isExpanded: Bool
  private let onChecklistToggle: ((String, String) -> Void)?
  private let lineLimit: Int

  public init(
    blocks: [DescriptionBlock],
    isExpanded: Binding<Bool>,
    onChecklistToggle: ((String, String) -> Void)? = nil,
    lineLimit: Int = 5
  ) {
    self.blocks = blocks
    self._isExpanded = isExpanded
    self.onChecklistToggle = onChecklistToggle
    self.lineLimit = lineLimit
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      let visibleBlocks = isExpanded ? blocks : Array(blocks.prefix(2))

      ForEach(visibleBlocks) { block in
        blockView(block)
      }

      // 더보기/접기 (블록이 2개 초과일 때)
      if blocks.count > 2 {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
          }
        } label: {
          Text(isExpanded ? "접기" : "더보기")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.pmindigo.n500)
        }
      }
    }
  }

  // MARK: - Block Views

  @ViewBuilder
  private func blockView(_ block: DescriptionBlock) -> some View {
    switch block.content {
    case .text(let text):
      Text(text)
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .lineLimit(isExpanded ? nil : lineLimit)

    case .checklist(let items):
      VStack(alignment: .leading, spacing: 4) {
        ForEach(items) { item in
          checklistItemView(item, blockId: block.id)
        }
      }

    case .bulletList(let items):
      VStack(alignment: .leading, spacing: 4) {
        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
          HStack(alignment: .top, spacing: 6) {
            Text("•")
              .font(.system(size: 14, weight: .medium))
              .foregroundStyle(.secondary)

            Text(item)
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
          }
        }
      }
    }
  }

  private func checklistItemView(_ item: ChecklistItem, blockId: String) -> some View {
    Button {
      onChecklistToggle?(blockId, item.id)
    } label: {
      HStack(spacing: 6) {
        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 16))
          .foregroundStyle(item.isChecked ? Color.pmindigo.n500 : Color(.systemGray3))

        Text(item.text)
          .font(.system(size: 14))
          .foregroundStyle(item.isChecked ? .secondary : .primary)
          .strikethrough(item.isChecked)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(onChecklistToggle == nil)
  }
}

// MARK: - Previews

#Preview("접힌 상태") {
  @Previewable @State var isExpanded = false
  return DescriptionBlockRenderer(
    blocks: [
      DescriptionBlock(content: .text("강남역 2번 출구에서 만나요.")),
      DescriptionBlock(content: .checklist([
        ChecklistItem(text: "지갑", isChecked: true),
        ChecklistItem(text: "신분증")
      ])),
      DescriptionBlock(content: .bulletList(["장소: 강남역", "시간: 오후 6시"]))
    ],
    isExpanded: $isExpanded
  )
  .padding(16)
}

#Preview("펼친 상태") {
  @Previewable @State var isExpanded = true
  return DescriptionBlockRenderer(
    blocks: [
      DescriptionBlock(content: .text("강남역 2번 출구에서 만나요.")),
      DescriptionBlock(content: .checklist([
        ChecklistItem(text: "지갑", isChecked: true),
        ChecklistItem(text: "신분증")
      ])),
      DescriptionBlock(content: .bulletList(["장소: 강남역", "시간: 오후 6시"]))
    ],
    isExpanded: $isExpanded,
    onChecklistToggle: { _, _ in }
  )
  .padding(16)
}
