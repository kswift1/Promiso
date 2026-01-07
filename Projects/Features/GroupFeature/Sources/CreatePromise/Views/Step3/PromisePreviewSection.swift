import SwiftUI
import Clients
import ComposableArchitecture

struct PromisePreviewSection: View {
  let store: StoreOf<CreatePromise.Feature>
  @State private var showPreviewFullScreen = false

  var body: some View {
    SectionPlaceHolder(
      placeHolderTitle: "약속 미리보기",
      isRequired: false
    ) {
      Button(action: {
        showPreviewFullScreen = true
      }) {
        VStack(spacing: 0) {
          // 제목
          HStack(spacing: 12) {
            if let emoji = store.promise.emoji {
              Text(emoji)
                .font(.system(size: 32))
            }

            Text(store.promise.title)
              .font(.system(size: 20, weight: .bold))
              .foregroundColor(.primary)

            Spacer()

            Image(systemName: "arrow.up.right.circle.fill")
              .font(.system(size: 20))
              .foregroundColor(.blue)
          }
          .padding(16)
          .background(Color(.systemGray6).opacity(0.5))

          Divider()

          // 상세 정보
          VStack(spacing: 12) {
            if let group = store.promise.group {
              PreviewInfoRow(
                icon: "person.2.fill",
                text: group.name
              )
            }

            PreviewInfoRow(
              icon: "calendar",
              text: formattedDateTime
            )

            if let endAt = store.promise.endAt {
              PreviewInfoRow(
                icon: "clock",
                text: "종료: \(formattedTime(endAt))"
              )
            }

            PreviewInfoRow(
              icon: "person.3.fill",
              text: "최소 \(store.promise.minimumParticipants)명 참석 시 약속 확정"
            )

            if let location = store.promise.location {
              PreviewInfoRow(
                icon: "mappin.circle.fill",
                text: location.name
              )
            }
          }
          .padding(16)
          .background(Color(.systemGray6).opacity(0.5))

          // 탭하여 전체보기 힌트
          HStack {
            Spacer()
            Text("탭하여 전체 화면으로 보기")
              .font(.system(size: 12))
              .foregroundColor(.blue)
            Spacer()
          }
          .padding(.vertical, 8)
          .background(Color.blue.opacity(0.05))
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color.blue, lineWidth: 2)
        )
      }
      .buttonStyle(PlainButtonStyle())
    }
    .fullScreenCover(isPresented: $showPreviewFullScreen) {
      PromisePreviewFullScreen(store: store, isPresented: $showPreviewFullScreen)
    }
  }

  private var formattedDateTime: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일 (E) a h:mm"
    return formatter.string(from: store.promise.startAt)
  }

  private func formattedTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }
}

// MARK: - Preview Info Row
struct PreviewInfoRow: View {
  let icon: String
  let text: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 14))
        .foregroundColor(.secondary)
        .frame(width: 20)

      Text(text)
        .font(.system(size: 14))
        .foregroundColor(.primary)

      Spacer()
    }
  }
}

// MARK: - 풀스크린 미리보기
struct PromisePreviewFullScreen: View {
  let store: StoreOf<CreatePromise.Feature>
  @Binding var isPresented: Bool

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          // 헤더
          VStack(spacing: 12) {
            if let emoji = store.promise.emoji {
              Text(emoji)
                .font(.system(size: 72))
            }

            Text(store.promise.title)
              .font(.system(size: 28, weight: .bold))

            Text("멤버들이 받게 될 약속 초대입니다")
              .font(.system(size: 14))
              .foregroundColor(.secondary)
          }
          .padding(.top, 24)

          // 상세 정보 카드
          VStack(spacing: 0) {
            if let group = store.promise.group {
              DetailRow(
                icon: "person.2.fill",
                title: "그룹",
                content: group.name
              )

              Divider()
                .padding(.leading, 52)
            }

            DetailRow(
              icon: "calendar",
              title: "시작 시간",
              content: formattedDateTime
            )

            if let endAt = store.promise.endAt {
              Divider()
                .padding(.leading, 52)

              DetailRow(
                icon: "clock",
                title: "종료 시간",
                content: formattedEndDateTime(endAt)
              )
            }

            Divider()
              .padding(.leading, 52)

            DetailRow(
              icon: "person.3.fill",
              title: "참석 조건",
              content: "최소 \(store.promise.minimumParticipants)명 참석 시 약속 확정"
            )

            if let location = store.promise.location {
              Divider()
                .padding(.leading, 52)

              DetailRow(
                icon: "mappin.circle.fill",
                title: "장소",
                content: location.name
              )
            }

            if let description = store.promise.description, !description.isEmpty {
              Divider()
                .padding(.leading, 52)

              DetailRow(
                icon: "text.alignleft",
                title: "상세 설명",
                content: description
              )
            }
          }
          .background(Color(.systemBackground))
          .clipShape(RoundedRectangle(cornerRadius: 16))
          .shadow(color: Color.black.opacity(0.05), radius: 10, y: 4)

          // 안내 메시지
          HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
              .foregroundColor(.blue)
            Text("이 화면은 멤버들이 받게 될 약속 초대 화면입니다")
              .font(.system(size: 14))
              .foregroundColor(.secondary)
            Spacer(minLength: 0)
          }
          .padding(16)
          .background(Color.blue.opacity(0.1))
          .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
      }
      .navigationTitle("약속 초대 미리보기")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("닫기") {
            isPresented = false
          }
        }
      }
    }
  }

  private func formattedDateTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "yyyy년 M월 d일 (E) a h:mm"
    return formatter.string(from: date)
  }

  private var formattedDateTime: String {
    formattedDateTime(store.promise.startAt)
  }

  private func formattedEndDateTime(_ date: Date) -> String {
    formattedDateTime(date)
  }
}

// MARK: - Detail Row
struct DetailRow: View {
  let icon: String
  let title: String
  let content: String

  var body: some View {
    HStack(alignment: .top, spacing: 16) {
      Image(systemName: icon)
        .font(.system(size: 20))
        .foregroundColor(.blue)
        .frame(width: 28)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.system(size: 13))
          .foregroundColor(.secondary)
        Text(content)
          .font(.system(size: 16))
          .foregroundColor(.primary)
      }

      Spacer()
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 16)
  }
}
