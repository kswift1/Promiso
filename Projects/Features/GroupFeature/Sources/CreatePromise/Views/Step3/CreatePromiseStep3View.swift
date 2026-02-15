import SwiftUI
import Clients
import ComposableArchitecture
import PhotosUI

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

          // 사진 첨부
          ImageAttachmentSection(
            localImages: store.localImageData,
            onPhotosSelected: { items in
              store.send(.view(.photosSelected(items)))
            },
            onRemoveExisting: { _ in },
            onRemoveLocal: { index in
              store.send(.view(.removeLocalImage(index)))
            }
          )
          .id("imageAttachment")

          // 최소 참가 인원
          MinimumParticipantsSection(store: store, scrollProxy: proxy)
            .id("minimumParticipants")
        }
        .padding(16)
      }
      .simultaneousGesture(
        DragGesture().onChanged { _ in
          isDescriptionFocused = false
          UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
      )
      .onTapGesture {
        isDescriptionFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
