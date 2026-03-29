import SwiftUI

// MARK: - Detected Item

private struct DetectedItem: Identifiable {
  enum Kind { case url, phone, address }
  let id: String
  let kind: Kind
  let value: String
  let url: URL?

  var emoji: String {
    switch kind {
    case .url: "🔗"
    case .phone: "📞"
    case .address: "📍"
    }
  }

  var label: String {
    switch kind {
    case .url: url?.host ?? value
    case .phone: value
    case .address: value
    }
  }
}

// MARK: - Description Block Renderer

public struct DescriptionBlockRenderer: View {
  private let blocks: [DescriptionBlock]
  @Binding private var isExpanded: Bool
  private let onChecklistToggle: ((String, String) -> Void)?
  @Environment(\.openURL) private var openURL

  public init(
    blocks: [DescriptionBlock],
    isExpanded: Binding<Bool>,
    onChecklistToggle: ((String, String) -> Void)? = nil
  ) {
    self.blocks = blocks
    self._isExpanded = isExpanded
    self.onChecklistToggle = onChecklistToggle
  }

  // MARK: - Data Detection

  private static let dataDetector: NSDataDetector? = {
    let types: NSTextCheckingResult.CheckingType = [.link, .phoneNumber, .address]
    return try? NSDataDetector(types: types.rawValue)
  }()

  private var allText: String {
    blocks.flatMap { block -> [String] in
      switch block.content {
      case .text(let text): [text]
      case .checklist(let items): items.map(\.text)
      case .bulletList(let items): items
      }
    }
    .joined(separator: "\n")
  }

  private var detectedItems: [DetectedItem] {
    guard let detector = Self.dataDetector else { return [] }
    let text = allText
    let range = NSRange(text.startIndex..., in: text)
    let matches = detector.matches(in: text, options: [], range: range)
    var seen = Set<String>()
    return matches.compactMap { match -> DetectedItem? in
      switch match.resultType {
      case .link:
        guard let url = match.url else { return nil }
        let key = url.absoluteString
        guard seen.insert(key).inserted else { return nil }
        return DetectedItem(id: key, kind: .url, value: key, url: url)
      case .phoneNumber:
        guard let phone = match.phoneNumber else { return nil }
        guard seen.insert(phone).inserted else { return nil }
        let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        return DetectedItem(id: phone, kind: .phone, value: phone, url: URL(string: "tel:\(cleaned)"))
      case .address:
        guard let range = Range(match.range, in: text) else { return nil }
        let address = String(text[range])
        guard seen.insert(address).inserted else { return nil }
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        return DetectedItem(id: address, kind: .address, value: address, url: URL(string: "\(AppConstants.ExternalURLs.kakaoMapSearchBase)\(encoded)"))
      default:
        return nil
      }
    }
  }

  // 더보기 표시 여부: 블록이 많거나 체크리스트 항목이 5개 초과이거나 텍스트 블록이 많으면 표시
  private var needsExpansion: Bool {
    if blocks.count > 2 { return true }
    for block in blocks {
      if case .checklist(let items) = block.content, items.count > 5 { return true }
    }
    return false
  }

  // 접힌 상태에서 표시할 블록 목록
  private var visibleBlocks: [DescriptionBlock] {
    guard !isExpanded, needsExpansion else { return blocks }
    return Array(blocks.prefix(2))
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(visibleBlocks) { block in
        blockView(block)
      }

      let items = detectedItems
      if !items.isEmpty {
        let layout = items.count > 1
          ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
          : AnyLayout(HStackLayout(spacing: 6))
        layout {
          ForEach(items) { item in
            if let url = item.url {
              Button {
                openURL(url)
              } label: {
                HStack(spacing: 3) {
                  Text(item.emoji)
                    .font(.system(size: 11))
                  Text(item.label)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.secondary.opacity(0.2), lineWidth: 0.5))
                .contentShape(Capsule())
              }
              .buttonStyle(.plain)
            }
          }
        }
        .padding(.top, 4)
      }

      if needsExpansion {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
          }
        } label: {
          Text(isExpanded ? "접기" : "더보기")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.pmindigo.n500)
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: - Block Views

  @ViewBuilder
  private func blockView(_ block: DescriptionBlock) -> some View {
    switch block.content {
    case .text(let text):
      textView(text)

    case .checklist(let items):
      checklistView(items, blockId: block.id)

    case .bulletList(let items):
      bulletListView(items)
    }
  }

  // MARK: - Text View

  @ViewBuilder
  private func textView(_ text: String) -> some View {
    if !text.isEmpty {
      Text(text)
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.leading)
        .lineLimit(isExpanded ? nil : 5)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  // MARK: - Checklist View

  private func checklistView(
    _ items: [ChecklistItem],
    blockId: String
  ) -> some View {
    let visibleItems = isExpanded ? items : Array(items.prefix(5))
    return VStack(alignment: .leading, spacing: 5) {
      ForEach(visibleItems) { item in
        checklistItemView(item, blockId: blockId)
      }
      if !isExpanded && items.count > 5 {
        Text("외 \(items.count - 5)개")
          .font(.system(size: 12))
          .foregroundStyle(.tertiary)
          .padding(.leading, 26)
      }
    }
  }

  private func checklistItemView(
    _ item: ChecklistItem,
    blockId: String
  ) -> some View {
    Button {
      onChecklistToggle?(blockId, item.id)
    } label: {
      HStack(alignment: .center, spacing: 8) {
        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
          .font(.system(size: 16))
          .foregroundStyle(item.isChecked ? Color.pmindigo.n500 : Color(.systemGray3))
          .frame(width: 18)

        Text(item.text)
          .font(.system(size: 14))
          .foregroundStyle(item.isChecked ? Color.pmtext.secondary : .primary)
          .strikethrough(item.isChecked, color: Color.pmtext.secondary)
          .multilineTextAlignment(.leading)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(onChecklistToggle == nil)
  }

  // MARK: - Bullet List View

  private func bulletListView(_ items: [String]) -> some View {
    VStack(alignment: .leading, spacing: 5) {
      ForEach(Array(items.enumerated()), id: \.offset) { _, item in
        HStack(alignment: .top, spacing: 8) {
          Text("•")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.pmtext.secondary)
            .frame(width: 10)

          Text(item)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
      }
    }
  }
}

// MARK: - Previews

#Preview("접힌 상태") {
  @Previewable @State var isExpanded = false
  return DescriptionBlockRenderer(
    blocks: [
      DescriptionBlock(content: .text("강남역 2번 출구에서 만나요. 문의: 010-1234-5678")),
      DescriptionBlock(content: .checklist([
        ChecklistItem(text: "지갑", isChecked: true),
        ChecklistItem(text: "신분증"),
        ChecklistItem(text: "교통카드"),
        ChecklistItem(text: "우산"),
        ChecklistItem(text: "간식"),
        ChecklistItem(text: "물병")
      ])),
      DescriptionBlock(content: .bulletList(["장소: 강남역", "시간: 오후 6시", "참고: https://naver.com"]))
    ],
    isExpanded: $isExpanded
  )
  .padding(16)
}

#Preview("펼친 상태") {
  @Previewable @State var isExpanded = true
  return DescriptionBlockRenderer(
    blocks: [
      DescriptionBlock(content: .text("강남역 2번 출구에서 만나요. 늦으면 연락주세요. 문의: 010-1234-5678, https://naver.com")),
      DescriptionBlock(content: .checklist([
        ChecklistItem(text: "지갑", isChecked: true),
        ChecklistItem(text: "신분증"),
        ChecklistItem(text: "교통카드"),
        ChecklistItem(text: "우산"),
        ChecklistItem(text: "간식"),
        ChecklistItem(text: "물병")
      ])),
      DescriptionBlock(content: .bulletList(["장소: 강남역", "시간: 오후 6시"]))
    ],
    isExpanded: $isExpanded,
    onChecklistToggle: { _, _ in }
  )
  .padding(16)
}

#Preview("단순 텍스트") {
  @Previewable @State var isExpanded = false
  return DescriptionBlockRenderer(
    blocks: [
      DescriptionBlock(content: .text("간단한 메모입니다."))
    ],
    isExpanded: $isExpanded
  )
  .padding(16)
}
