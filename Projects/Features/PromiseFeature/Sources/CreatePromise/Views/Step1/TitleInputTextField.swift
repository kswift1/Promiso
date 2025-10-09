import SwiftUI
import Clients
import ComposableArchitecture

struct TitleInputTextField: View {
  let title: String
  let emoji: String?
  let titlePrefix: Int
  let onTitleChange: (String) -> Void
  @FocusState.Binding var isFocused: Bool
  
  init(
    title: String,
    emoji: String?,
    titlePrefix: Int = 30,
    isFocused: FocusState<Bool>.Binding,
    onTitleChange: @escaping (String) -> Void
  ) {
    self.title = title
    self.emoji = emoji
    self.titlePrefix = titlePrefix
    self._isFocused = isFocused
    self.onTitleChange = onTitleChange
  }
  
  var body: some View {
    VStack(alignment: .trailing, spacing: 2) {
      TextField("예: 영화 관람, 카페 미팅", text: Binding(
        get: { title },
        set: { newValue in
          let trimmed = String(newValue.prefix(titlePrefix))
          onTitleChange(trimmed)
        }
      ))
      .focused($isFocused)
      .font(.system(size: 17))
      .padding(18)
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .frame(maxWidth: .infinity, minHeight: 80)
      
      Text("\(title.count)/\(titlePrefix)")
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }
  }
}

// MARK: - Previews

#Preview("빈 상태") {
  @Previewable @FocusState var isFocused: Bool
  @Previewable @State var title = ""
  TitleInputTextField(
    title: title,
    emoji: nil,
    isFocused: $isFocused,
    onTitleChange: { title = $0 }
  )
  .padding()
}

#Preview("텍스트 입력됨") {
  @Previewable @FocusState var isFocused: Bool
  @Previewable @State var title = "영화 관람"
  TitleInputTextField(
    title: title,
    emoji: "🍿",
    isFocused: $isFocused,
    onTitleChange: { title = $0 }
  )
  .padding()
}

#Preview("긴 텍스트") {
  @Previewable @FocusState var isFocused: Bool
  @Previewable @State var title = "강남역에서 저녁 먹고 영화 보기"
  TitleInputTextField(
    title: title,
    emoji: "🍿",
    isFocused: $isFocused,
    onTitleChange: { title = $0 }
  )
  .padding()
}

#Preview("최대 길이 (30자)") {
  @Previewable @FocusState var isFocused: Bool
  @Previewable @State var title = "123456789012345678901234567890"
  TitleInputTextField(
    title: title,
    emoji: "📅",
    isFocused: $isFocused,
    onTitleChange: { title = $0 }
  )
  .padding()
}

#Preview("다크모드") {
  @Previewable @FocusState var isFocused: Bool
  @Previewable @State var title = "다크모드 테스트"
  TitleInputTextField(
    title: title,
    emoji: "🌙",
    isFocused: $isFocused,
    onTitleChange: { title = $0 }
  )
  .padding()
  .preferredColorScheme(.dark)
}
