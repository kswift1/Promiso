import SwiftUI
import ComposableArchitecture
import PromisoShared

extension PersonalEventDetail {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @State private var isDescriptionExpanded = false
    @State private var selectedImageIndex: Int?

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          headerSection
          scheduleSection

          // 날씨
          if let weatherInfo = store.weatherInfo,
             !store.event.isPast {
            ScheduleDetailWeatherSection(
              weatherInfo: weatherInfo,
              startAt: store.event.startAt,
              endAt: store.event.endAt
            )
          }

          // 이미지 갤러리
          if !store.event.imageUrls.isEmpty {
            imageGallerySection
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
      }
      .auroraBackground()
      .onAppear { store.send(.view(.onAppear)) }
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { toolbarContent }
      .alert(store: store.scope(state: \.$deleteAlert, action: \.alert))
      .sheet(
        item: $store.scope(state: \.editEvent, action: \.editEvent)
      ) { editStore in
        CreatePersonalEvent.RootView(store: editStore)
      }
    }

    // MARK: - Header Section

    private var headerSection: some View {
      HStack(alignment: .top, spacing: 12) {
        // 이모지
        Text(store.event.displayEmoji)
          .font(.system(size: 44))

        // 제목 + 설명
        VStack(alignment: .leading, spacing: 6) {
          Text(store.event.title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.primary)

          if !store.event.descriptionBlocks.isEmpty {
            DescriptionBlockRenderer(
              blocks: store.event.descriptionBlocks,
              isExpanded: $isDescriptionExpanded,
              onChecklistToggle: { blockId, itemId in
                store.send(.view(.toggleChecklist(blockId: blockId, itemId: itemId)))
              }
            )
          } else if let description = store.event.description, !description.isEmpty {
            ScheduleDetailExpandableText(
              text: description,
              isExpanded: $isDescriptionExpanded
            )
          }
        }

        Spacer()

        // 상태 배지 (우측 상단)
        statusBadge
      }
      .padding(16)
      .adaptiveGlassCard()
    }

    // MARK: - Status Badge

    private var statusBadge: some View {
      HStack(spacing: 4) {
        Image(systemName: statusIconName)
          .font(.system(size: 12, weight: .semibold))

        Text(statusText)
          .font(.system(size: 13, weight: .semibold))
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(statusColor.opacity(0.15))
      .foregroundStyle(statusColor)
      .clipShape(Capsule())
    }

    private var statusText: String {
      if store.event.isOngoing { return LocalizedStrings.Shared.statusOngoing }
      if store.event.isPast { return LocalizedStrings.Shared.statusEnded }
      let calendar = Calendar.current
      if calendar.isDateInToday(store.event.startAt) { return LocalizedStrings.Shared.statusToday }
      return LocalizedStrings.Shared.statusUpcoming
    }

    private var statusIconName: String {
      if store.event.isOngoing { return "bolt.fill" }
      if store.event.isPast { return "checkmark.circle.fill" }
      let calendar = Calendar.current
      if calendar.isDateInToday(store.event.startAt) { return "sun.max.fill" }
      return "clock.fill"
    }

    private var statusColor: Color {
      if store.event.isOngoing { return .green }
      if store.event.isPast { return Color.pmgray.n500 }
      let calendar = Calendar.current
      if calendar.isDateInToday(store.event.startAt) { return .orange }
      return Color.pmindigo.n500
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
      VStack(spacing: 0) {
        ScheduleDetailSectionHeader(title: LocalizedStrings.Common.schedule)

        VStack(spacing: 0) {
          // 날짜
          ScheduleDetailEmojiInfoRow(
            emoji: "📅",
            title: LocalizedStrings.Common.date,
            value: formatFullDate(store.event.startAt)
          )

          Divider().padding(.leading, 44)

          // 시간
          ScheduleDetailEmojiInfoRow(
            emoji: "⏰",
            title: LocalizedStrings.Common.time,
            value: store.event.timeRangeText
          )

          // 장소
          if let location = store.event.location {
            Divider().padding(.leading, 44)

            ScheduleDetailEmojiInfoRow(
              emoji: "📍",
              title: LocalizedStrings.Common.location,
              value: location.name
            )
          }

          // 알림
          if let minutes = store.event.reminderMinutesBefore {
            Divider().padding(.leading, 44)

            ScheduleDetailEmojiInfoRow(
              emoji: "🔔",
              title: LocalizedStrings.Common.reminder,
              value: reminderText(minutes)
            )
          }
        }
        .adaptiveGlassCard()
      }
    }

    // MARK: - Image Gallery Section

    private var imageGallerySection: some View {
      VStack(spacing: 0) {
        ScheduleDetailSectionHeader(title: LocalizedStrings.Common.photo)

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(Array(store.event.imageUrls.enumerated()), id: \.offset) { index, url in
              GalleryImageThumbnail(url: url)
                .onTapGesture { selectedImageIndex = index }
            }
          }
          .padding(.horizontal, 16)
          .padding(.vertical, 12)
        }
        .adaptiveGlassCard()
      }
      .fullScreenCover(isPresented: Binding(
        get: { selectedImageIndex != nil },
        set: { if !$0 { selectedImageIndex = nil } }
      )) {
        if let index = selectedImageIndex {
          PhotoGalleryViewer(
            imageUrls: store.event.imageUrls,
            initialIndex: index,
            onDismiss: { selectedImageIndex = nil }
          )
        }
      }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
      ToolbarItem(placement: .topBarTrailing) {
        Menu {
          Button {
            store.send(.view(.editTapped))
          } label: {
            Label(LocalizedStrings.Common.modify, systemImage: "pencil")
          }

          Button(role: .destructive) {
            store.send(.view(.deleteTapped))
          } label: {
            Label(LocalizedStrings.Common.delete, systemImage: "trash")
          }
        } label: {
          Image(systemName: "ellipsis.circle")
        }
      }
    }

    // MARK: - Helpers

    private func formatFullDate(_ date: Date) -> String {
      LocalizedDateFormatters.sectionHeader.string(from: date)
    }

    private func reminderText(_ minutes: Int) -> String {
      if minutes == 0 { return LocalizedStrings.Personal.reminderAtEvent }
      if minutes >= 10080 && minutes % (1440 * 7) == 0 {
        let weeks = minutes / (1440 * 7)
        return LocalizedStrings.Personal.reminderWeeks(weeks)
      }
      if minutes >= 1440 {
        let days = minutes / 1440
        return LocalizedStrings.Personal.reminderDays(days)
      }
      if minutes >= 60 {
        return LocalizedStrings.Personal.reminderHours(minutes / 60)
      }
      return LocalizedStrings.Personal.reminderMinutes(minutes)
    }
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    PersonalEventDetail.RootView(
      store: Store(
        initialState: PersonalEventDetail.Feature.State(
          event: PersonalEventModel.examples[0]
        )
      ) {
        PersonalEventDetail.Feature()
      }
    )
  }
}
