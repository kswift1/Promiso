import SwiftUI
import ComposableArchitecture
import PromisoShared
import SharedFeature

// MARK: - Root View

extension RecurringPersonalEventDetail {
  public struct RootView: View {
    @Bindable var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 24) {
          headerSection
          recurrenceSection
          scheduleSection

          if store.recurringEvent.location != nil {
            locationSection
          }

          if store.recurringEvent.description != nil {
            descriptionSection
          }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
      }
      .auroraBackground()
      .navigationTitle("반복 일정")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Menu {
            Button {
              store.send(.view(.editTapped))
            } label: {
              Label(LocalizedStrings.Common.modify, systemImage: "pencil")
            }

            if store.selectedInstance != nil {
              Button(role: .destructive) {
                store.send(.view(.excludeInstanceTapped))
              } label: {
                Label("이 날만 취소", systemImage: "calendar.badge.minus")
              }
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
      .sheet(item: $store.scope(state: \.editEvent, action: \.editEvent)) { editStore in
        CreateRecurringPersonalEvent.RootView(store: editStore)
          .presentationDragIndicator(.visible)
      }
      .alert(store: store.scope(state: \.$deleteAlert, action: \.alert))
      .onAppear {
        store.send(.view(.onAppear))
      }
    }

    // MARK: - Header Section

    private var headerSection: some View {
      HStack(alignment: .top, spacing: 12) {
        Text(store.recurringEvent.displayEmoji)
          .font(.system(size: 44))

        VStack(alignment: .leading, spacing: 6) {
          Text(store.recurringEvent.title)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.primary)

          if let instance = store.selectedInstance {
            Text(instance.dateKey)
              .font(.subheadline)
              .foregroundStyle(.secondary)
          } else {
            Text(store.recurringEvent.summaryText)
              .font(.system(size: 14))
              .foregroundStyle(.secondary)
          }
        }

        Spacer()
      }
      .padding(16)
      .adaptiveGlassCard()
    }

    // MARK: - Recurrence Section

    private var recurrenceSection: some View {
      VStack(spacing: 0) {
        ScheduleDetailSectionHeader(title: "반복 규칙")

        VStack(spacing: 0) {
          ScheduleDetailEmojiInfoRow(
            emoji: "🔄",
            title: "반복",
            value: store.recurringEvent.recurrence.displayText
          )

          Divider().padding(.leading, 44)

          ScheduleDetailEmojiInfoRow(
            emoji: "📅",
            title: "시작일",
            value: formattedDate(store.recurringEvent.seriesStartDate)
          )

          if let endDate = store.recurringEvent.recurrence.seriesEndDate {
            Divider().padding(.leading, 44)

            ScheduleDetailEmojiInfoRow(
              emoji: "🏁",
              title: "종료일",
              value: formattedDate(endDate)
            )
          }
        }
        .adaptiveGlassCard()
      }
    }

    // MARK: - Schedule Section

    private var scheduleSection: some View {
      VStack(spacing: 0) {
        ScheduleDetailSectionHeader(title: LocalizedStrings.Common.schedule)

        VStack(spacing: 0) {
          ScheduleDetailEmojiInfoRow(
            emoji: "⏰",
            title: LocalizedStrings.Common.time,
            value: store.recurringEvent.timeText
          )

          if let endText = store.recurringEvent.endTimeText {
            Divider().padding(.leading, 44)

            ScheduleDetailEmojiInfoRow(
              emoji: "⏱️",
              title: "종료 시간",
              value: endText
            )
          }

          if let reminder = store.recurringEvent.reminderMinutesBefore {
            Divider().padding(.leading, 44)

            ScheduleDetailEmojiInfoRow(
              emoji: "🔔",
              title: LocalizedStrings.Common.reminder,
              value: reminderText(reminder)
            )
          }
        }
        .adaptiveGlassCard()
      }
    }

    // MARK: - Location Section

    private var locationSection: some View {
      VStack(spacing: 0) {
        ScheduleDetailSectionHeader(title: LocalizedStrings.Common.location)

        if let location = store.recurringEvent.location {
          ScheduleDetailLocationInfoRow(location: location)
            .adaptiveGlassCard()
        }
      }
    }

    // MARK: - Description Section

    private var descriptionSection: some View {
      VStack(spacing: 0) {
        ScheduleDetailSectionHeader(title: "메모")

        Text(store.recurringEvent.description ?? "")
          .font(.system(size: 15))
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 16)
          .padding(.vertical, 14)
          .adaptiveGlassCard()
      }
    }

    // MARK: - Helpers

    private func formattedDate(_ date: Date) -> String {
      LocalizedDateFormatters.sectionHeader.string(from: date)
    }

    private func reminderText(_ minutes: Int) -> String {
      if minutes == 0 { return "이벤트 시점" }
      if minutes >= 10080 && minutes % (1440 * 7) == 0 {
        let weeks = minutes / (1440 * 7)
        return "\(weeks)주 전"
      }
      if minutes >= 1440 {
        let days = minutes / 1440
        return "\(days)일 전"
      }
      if minutes >= 60 {
        return LocalizedStrings.Shared.reminderHours(minutes / 60)
      }
      return LocalizedStrings.Shared.reminderMinutes(minutes)
    }
  }
}

// MARK: - Preview

#Preview {
  NavigationStack {
    RecurringPersonalEventDetail.RootView(
      store: Store(
        initialState: RecurringPersonalEventDetail.Feature.State(
          recurringEvent: RecurringPersonalEventModel.mock()
        )
      ) {
        RecurringPersonalEventDetail.Feature()
      }
    )
  }
}
