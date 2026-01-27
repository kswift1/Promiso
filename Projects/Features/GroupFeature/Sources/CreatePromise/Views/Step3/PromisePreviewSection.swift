import SwiftUI
import Clients
import ComposableArchitecture
import PromisoShared

struct PromisePreviewSection: View {
  let store: StoreOf<CreatePromise.Feature>
  @State private var showPreviewFullScreen = false

  var body: some View {
    SectionPlaceHolder(
      placeHolderTitle: "약속 미리보기",
    ) {
      Button(action: {
        showPreviewFullScreen = true
      }) {
        VStack(spacing: 16) {
          // 이모지 + 제목
          HStack(spacing: 12) {
            Text(store.promise.emoji ?? "🗓️")
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
              .foregroundColor(.blue.opacity(0.8))
          }

          // 일정 정보
          VStack(spacing: 8) {
            EmojiPreviewRow(emoji: "📅", text: formattedDate)
            EmojiPreviewRow(emoji: "⏰", text: formattedTime)
            if store.promise.location != nil {
              EmojiPreviewRow(emoji: "📍", text: store.promise.locationText)
            }
            EmojiPreviewRow(emoji: "👥", text: "최소 \(store.promise.minimumParticipants)명")
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
    }
    .fullScreenCover(isPresented: $showPreviewFullScreen) {
      PromisePreviewFullScreen(store: store, isPresented: $showPreviewFullScreen)
    }
  }

  private var formattedDate: String {
    KoreanDateFormatters.sectionHeader.string(from: store.promise.startAt)
  }

  private var formattedTime: String {
    store.promise.startAt.formattedTime
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
  @State private var isDescriptionExpanded = false

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
        }
      }
    }
  }

  // MARK: - Header Section (약속 상세화면과 동일한 스타일)

  private var headerSection: some View {
    HStack(alignment: .top, spacing: 12) {
      // 이모지
      Text(store.promise.emoji ?? "📌")
        .font(.system(size: 44))

      // 제목 + 그룹명
      VStack(alignment: .leading, spacing: 6) {
        Text(store.promise.title)
          .font(.system(size: 20, weight: .bold))
          .foregroundStyle(.primary)

        if let group = store.promise.group {
          HStack(spacing: 4) {
            Image(systemName: "person.2.fill")
              .font(.system(size: 11))
            Text(group.name)
              .font(.system(size: 13))
          }
          .foregroundStyle(.secondary)
        }
      }

      Spacer()

      // 미리보기 배지
      Text("미리보기")
        .font(.system(size: 13, weight: .semibold))
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(0.15))
        .foregroundStyle(.blue)
        .clipShape(Capsule())
    }
    .padding(16)
    .adaptiveGlassCard()
  }

  // MARK: - Schedule Section (약속 상세화면과 동일한 스타일)

  private var scheduleSection: some View {
    VStack(spacing: 0) {
      PreviewSectionHeader(title: "일정")

      VStack(spacing: 0) {
        // 날짜
        PreviewEmojiInfoRow(emoji: "📅", title: "날짜", value: formattedDate)

        Divider().padding(.leading, 44)

        // 시간
        PreviewEmojiInfoRow(emoji: "⏰", title: "시간", value: formattedTime)

        // 종료 시간
        if let endAt = store.promise.endAt {
          Divider().padding(.leading, 44)

          PreviewEmojiInfoRow(emoji: "🏁", title: "종료", value: formattedEndTime(endAt))
        }

        // 장소
        if let location = store.promise.location {
          Divider().padding(.leading, 44)

          PreviewLocationInfoRow(location: location)

          // 지도 미리보기 (좌표가 있는 경우)
          if let latitude = location.latitude,
             let longitude = location.longitude {
            Divider().padding(.leading, 44)

            KakaoMiniMapView(
              latitude: latitude,
              longitude: longitude,
              zoomLevel: 16
            )
            .frame(height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
          }
        }

        Divider().padding(.leading, 44)

        // 최소 확정 인원
        PreviewEmojiInfoRow(emoji: "👥", title: "최소 확정 인원", value: "\(store.promise.minimumParticipants)명")
      }
      .adaptiveGlassCard()
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
        .adaptiveGlassCard()
    }
  }

  // MARK: - Condition Section

  private var conditionSection: some View {
    VStack(spacing: 0) {
      PreviewSectionHeader(title: "확정 조건")

      HStack(spacing: 12) {
        Text("✅")
          .font(.system(size: 18))

        Text("최소 \(store.promise.minimumParticipants)명 참석 시 약속이 확정됩니다")
          .font(.system(size: 15))
          .foregroundStyle(.primary)

        Spacer()
      }
      .padding(16)
      .adaptiveGlassCard()
    }
  }

  // MARK: - Formatters

  private var formattedDate: String {
    KoreanDateFormatters.sectionHeader.string(from: store.promise.startAt)
  }

  private var formattedTime: String {
    store.promise.startAt.formattedTime
  }

  private func formattedEndTime(_ date: Date) -> String {
    date.formattedTime
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

private struct PreviewLocationInfoRow: View {
  let location: LocationInfoModel

  var body: some View {
    HStack(spacing: 10) {
      Text("📍")
        .font(.system(size: 18))
        .frame(width: 28)

      VStack(alignment: .leading, spacing: 2) {
        Text(location.name)
          .font(.system(size: 15, weight: .medium))

        if let address = location.address {
          Text(address)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }
}
