import SwiftUI
import ComposableArchitecture

struct CreatePromiseStep3View: View {
  let store: StoreOf<CreatePromise.Feature>
  @FocusState private var isDescriptionFocused: Bool

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 32) {
          // 헤더
          CreatePromiseStep.third.headerView
            .id("header")

          // 도착 상황 공유 시작
          ArrivalSharingSection(store: store)
            .id("arrivalSharing")

          // 상세 설명
          DescriptionSection(store: store, isFocused: $isDescriptionFocused)
            .id("description")

          // 약속 미리보기
          PromisePreviewSection(store: store)
            .id("preview")
        }
        .padding(16)
      }
      .simultaneousGesture(
        DragGesture().onChanged { _ in
          isDescriptionFocused = false
        }
      )
      .onTapGesture {
        isDescriptionFocused = false
      }
      .onChange(of: isDescriptionFocused) { _, newValue in
        if newValue {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation {
              proxy.scrollTo("description", anchor: .top)
            }
          }
        }
      }
    }
  }
}
