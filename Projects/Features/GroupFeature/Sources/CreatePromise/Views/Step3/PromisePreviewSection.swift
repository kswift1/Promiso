import SwiftUI
import Clients
import ComposableArchitecture
import PromisoShared
import ResourceKit

struct PromisePreviewSection: View {
  let store: StoreOf<CreatePromise.Feature>
  @State private var showPreviewFullScreen = false
  @State private var isPressed = false

  var body: some View {
    SectionPlaceHolder(
      placeHolderTitle: "약속 미리보기",
      isRequired: false
    ) {
      Button(action: {
        showPreviewFullScreen = true
      }) {
        VStack(spacing: 16) {
          // 이모지 + 제목
          HStack(spacing: 12) {
            Text(store.promise.emoji ?? "📌")
              .font(.system(size: 36))

            VStack(alignment: .leading, spacing: 4) {
              Text(store.promise.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)

              if let group = store.promise.group {
                Text(group.name)
                  .font(.system(size: 13))
                  .foregroundColor(.secondary)
              }
            }

            Spacer()

            Image(systemName: "chevron.right.circle.fill")
              .font(.system(size: 24))
              .foregroundColor(Color.pmindigo.n500)
          }

          // 일정 정보
          VStack(spacing: 8) {
            EmojiPreviewRow(emoji: "📅", text: formattedDate)
            EmojiPreviewRow(emoji: "⏰", text: formattedTime)
            if store.promise.location != nil {
              EmojiPreviewRow(emoji: "📍", text: store.promise.locationText)
            }
            EmojiPreviewRow(emoji: "👥", text: "최소 \(store.promise.minimumParticipants)명")
            if let minutes = store.promise.trackingStartMinutesBefore {
              EmojiPreviewRow(emoji: "📡", text: "\(minutes)분 전부터 실시간 공유")
            }
          }
        }
        .padding(16)
        .background(Color(.systemBackground).opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
          RoundedRectangle(cornerRadius: 16)
            .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 8, y: 4)
      }
      .buttonStyle(PlainButtonStyle())
      .scaleEffect(isPressed ? 0.97 : 1.0)
      .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
      .sensoryFeedback(.impact(flexibility: .soft), trigger: showPreviewFullScreen)
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in isPressed = true }
          .onEnded { _ in isPressed = false }
      )
    }
    .fullScreenCover(isPresented: $showPreviewFullScreen) {
      PromisePreviewFullScreen(store: store, isPresented: $showPreviewFullScreen)
    }
  }

  private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일 (E)"
    return formatter.string(from: store.promise.startAt)
  }

  private var formattedTime: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: store.promise.startAt)
  }
}

// MARK: - Emoji Preview Row

private struct EmojiPreviewRow: View {
  let emoji: String
  let text: String

  var body: some View {
    HStack(spacing: 8) {
      Text(emoji)
        .font(.system(size: 14))
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
  @State private var isClosePressed = false

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 24) {
          headerSection
          scheduleSection

          if let description = store.promise.description, !description.isEmpty {
            descriptionSection(description)
          }

          conditionSection

          if store.promise.trackingStartMinutesBefore != nil {
            arrivalSharingSection
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
      }
      .auroraBackground()
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .principal) {
          Text("미리보기")
            .font(.headline)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("닫기") {
            isPresented = false
          }
          .scaleEffect(isClosePressed ? 0.9 : 1.0)
          .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isClosePressed)
          .sensoryFeedback(.impact(flexibility: .soft), trigger: isClosePressed)
          .simultaneousGesture(
            DragGesture(minimumDistance: 0)
              .onChanged { _ in isClosePressed = true }
              .onEnded { _ in isClosePressed = false }
          )
        }
      }
    }
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 16) {
      Text(store.promise.emoji ?? "📌")
        .font(.system(size: 64))

      Text(store.promise.title)
        .font(.system(size: 24, weight: .bold))
        .multilineTextAlignment(.center)

      if let group = store.promise.group {
        HStack(spacing: 6) {
          Image(systemName: "person.2.fill")
            .font(.system(size: 12))
          Text(group.name)
            .font(.system(size: 14, weight: .medium))
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 20)
  }

  // MARK: - Schedule Section

  private var scheduleSection: some View {
    VStack(spacing: 0) {
      PreviewSectionHeader(title: "일정")

      VStack(spacing: 0) {
        PreviewEmojiInfoRow(emoji: "📅", title: "날짜", value: formattedDate)

        Divider().padding(.leading, 44)

        PreviewEmojiInfoRow(emoji: "⏰", title: "시간", value: formattedTime)

        if let endAt = store.promise.endAt {
          Divider().padding(.leading, 44)

          PreviewEmojiInfoRow(emoji: "🏁", title: "종료", value: formattedEndTime(endAt))
        }

        if store.promise.location != nil {
          Divider().padding(.leading, 44)

          PreviewEmojiInfoRow(emoji: "📍", title: "장소", value: store.promise.locationText)
        }
      }
      .previewGlassCard()
    }
  }

  // MARK: - Description Section

  private func descriptionSection(_ description: String) -> some View {
    VStack(spacing: 0) {
      PreviewSectionHeader(title: "상세 설명")

      Text(description)
        .font(.system(size: 15))
        .foregroundStyle(.primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .previewGlassCard()
    }
  }

  // MARK: - Condition Section

  private var conditionSection: some View {
    VStack(spacing: 0) {
      PreviewSectionHeader(title: "확정 조건")

      HStack(spacing: 12) {
        Text("👥")
          .font(.system(size: 18))

        Text("최소 \(store.promise.minimumParticipants)명 참석 시 약속이 확정됩니다")
          .font(.system(size: 15))
          .foregroundStyle(.primary)

        Spacer()
      }
      .padding(16)
      .previewGlassCard()
    }
  }

  // MARK: - Arrival Sharing Section

  private var arrivalSharingSection: some View {
    VStack(spacing: 0) {
      PreviewSectionHeader(title: "실시간 공유")

      HStack(spacing: 12) {
        Text("📡")
          .font(.system(size: 18))

        if let minutes = store.promise.trackingStartMinutesBefore {
          Text("약속 \(minutes)분 전부터 실시간 공유가 시작됩니다")
            .font(.system(size: 15))
            .foregroundStyle(.primary)
        }

        Spacer()
      }
      .padding(16)
      .previewGlassCard()
    }
  }

  // MARK: - Formatters

  private var formattedDate: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "M월 d일 (E)"
    return formatter.string(from: store.promise.startAt)
  }

  private var formattedTime: String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: store.promise.startAt)
  }

  private func formattedEndTime(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "a h:mm"
    return formatter.string(from: date)
  }
}

// MARK: - Supporting Views

private struct PreviewSectionHeader: View {
  let title: String

  var body: some View {
    HStack {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.secondary)
        .textCase(.uppercase)
      Spacer()
    }
    .padding(.horizontal, 4)
    .padding(.bottom, 8)
  }
}

private struct PreviewEmojiInfoRow: View {
  let emoji: String
  let title: String
  let value: String

  var body: some View {
    HStack(spacing: 10) {
      Text(emoji)
        .font(.system(size: 18))
        .frame(width: 28)

      Text(title)
        .font(.system(size: 15))
        .foregroundStyle(.secondary)

      Spacer()

      Text(value)
        .font(.system(size: 15, weight: .medium))
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}

private extension View {
  func previewGlassCard() -> some View {
    self
      .background(Color(.systemBackground).opacity(0.8))
      .clipShape(RoundedRectangle(cornerRadius: 12))
      .overlay(
        RoundedRectangle(cornerRadius: 12)
          .stroke(Color(.systemGray5), lineWidth: 1)
      )
  }
}
