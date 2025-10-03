import SwiftUI
import Clients
import ComposableArchitecture

struct TitleInputTextField: View {
  private let store: StoreOf<CreatePromise.Feature>
  private let titlePrefix: Int
  @FocusState.Binding var isFocused: Bool

  init(store: StoreOf<CreatePromise.Feature>, titlePrefix: Int = 30, isFocused: FocusState<Bool>.Binding) {
    self.store = store
    self.titlePrefix = titlePrefix
    self._isFocused = isFocused
  }

  var body: some View {
    VStack(alignment: .trailing, spacing: 2) {
      TextField("예: 영화 관람, 카페 미팅", text: Binding(
        get: { store.promiseProposal.title },
        set: { store.send(.setTitle($0)) }
      ))
      .focused($isFocused)
      .onChange(of: store.promiseProposal.title, { _, newValue in
        if newValue.count > 30 {
          let trimmed = String(newValue.prefix(30))
          store.send(.setTitle(trimmed))
        }
      })
      .font(.system(size: 17))
      .padding(18)
      .background(Color(.systemGray6))
      .clipShape(RoundedRectangle(cornerRadius: 16))
      .frame(maxWidth: .infinity, minHeight: 80)
      
      Text("\(store.promiseProposal.title.count)/\(titlePrefix)")
        .font(.system(size: 13))
        .foregroundColor(.secondary)
    }
  }
}

// MARK: - Previews

#Preview("빈 상태") {
    @Previewable @FocusState var isFocused: Bool
    TitleInputTextField(
        store: Store(
            initialState: CreatePromise.Feature.State(
                promiseProposal: PromiseProposal.empty
            )
        ) {
            CreatePromise.Feature()
        },
        isFocused: $isFocused
    )
    .padding()
}

#Preview("텍스트 입력됨") {
    @Previewable @FocusState var isFocused: Bool
    TitleInputTextField(
        store: Store(
            initialState: CreatePromise.Feature.State(
                promiseProposal: PromiseProposal(
                    title: "영화 관람",
                    emoji: "🍿",
                    group: nil,
                    startedAt: Date(),
                    minimumParticipants: 2
                )
            )
        ) {
            CreatePromise.Feature()
        },
        isFocused: $isFocused
    )
    .padding()
}

#Preview("긴 텍스트") {
    @Previewable @FocusState var isFocused: Bool
    TitleInputTextField(
        store: Store(
            initialState: CreatePromise.Feature.State(
                promiseProposal: PromiseProposal(
                    title: "강남역에서 저녁 먹고 영화 보기",
                    emoji: "🍿",
                    group: nil,
                    startedAt: Date(),
                    minimumParticipants: 2
                )
            )
        ) {
            CreatePromise.Feature()
        },
        isFocused: $isFocused
    )
    .padding()
}

#Preview("최대 길이 (30자)") {
    @Previewable @FocusState var isFocused: Bool
    TitleInputTextField(
        store: Store(
            initialState: CreatePromise.Feature.State(
                promiseProposal: PromiseProposal(
                    title: "123456789012345678901234567890", // 정확히 30자
                    emoji: "📅",
                    group: nil,
                    startedAt: Date(),
                    minimumParticipants: 2
                )
            )
        ) {
            CreatePromise.Feature()
        },
        isFocused: $isFocused
    )
    .padding()
}

#Preview("다크모드") {
    @Previewable @FocusState var isFocused: Bool
    TitleInputTextField(
        store: Store(
            initialState: CreatePromise.Feature.State(
                promiseProposal: PromiseProposal(
                    title: "다크모드 테스트",
                    emoji: "🌙",
                    group: nil,
                    startedAt: Date(),
                    minimumParticipants: 2
                )
            )
        ) {
            CreatePromise.Feature()
        },
        isFocused: $isFocused
    )
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("여러 상태 비교") {
    @Previewable @FocusState var isFocused: Bool
    ScrollView {
        VStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("빈 상태")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TitleInputTextField(
                    store: Store(
                        initialState: CreatePromise.Feature.State(
                            promiseProposal: .empty
                        )
                    ) {
                        CreatePromise.Feature()
                    },
                    isFocused: $isFocused
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("짧은 텍스트 (5자)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TitleInputTextField(
                    store: Store(
                        initialState: CreatePromise.Feature.State(
                            promiseProposal: PromiseProposal(
                                title: "점심식사",
                                emoji: "🍽️",
                                group: nil,
                                startedAt: Date(),
                                minimumParticipants: 2
                            )
                        )
                    ) {
                        CreatePromise.Feature()
                    },
                    isFocused: $isFocused
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("중간 길이 텍스트 (15자)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TitleInputTextField(
                    store: Store(
                        initialState: CreatePromise.Feature.State(
                            promiseProposal: PromiseProposal(
                                title: "강남에서 저녁 먹고 영화 보기",
                                emoji: "🍿",
                                group: nil,
                                startedAt: Date(),
                                minimumParticipants: 2
                            )
                        )
                    ) {
                        CreatePromise.Feature()
                    },
                    isFocused: $isFocused
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("최대 길이 (30자)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TitleInputTextField(
                    store: Store(
                        initialState: CreatePromise.Feature.State(
                            promiseProposal: PromiseProposal(
                                title: "12345678901234567890123456789",
                                emoji: "📝",
                                group: nil,
                                startedAt: Date(),
                                minimumParticipants: 2
                            )
                        )
                    ) {
                        CreatePromise.Feature()
                    },
                    isFocused: $isFocused
                )
            }
        }
        .padding()
    }
}
