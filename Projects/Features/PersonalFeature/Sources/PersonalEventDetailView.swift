import SwiftUI
import ComposableArchitecture
import PromisoShared
import SharedFeature

extension PersonalEventDetail {
  public struct RootView: View {
    @Bindable private var store: StoreOf<Feature>
    @Environment(\.dismiss) private var dismiss

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      NavigationStack {
        ScrollView {
          VStack(spacing: 24) {
            headerSection
            scheduleSection
            if store.event.reminderMinutesBefore != nil {
              reminderSection
            }
            if let description = store.event.description, !description.isEmpty {
              descriptionSection(description)
            }
          }
          .padding(.horizontal, 20)
          .padding(.vertical, 24)
        }
        .auroraBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .alert(store: store.scope(state: \.$deleteAlert, action: \.alert))
        .sheet(
          item: $store.scope(state: \.editEvent, action: \.editEvent)
        ) { editStore in
          CreatePersonalEvent.RootView(store: editStore)
        }
        .sheet(
          isPresented: Binding(
            get: { store.showShareSheet },
            set: { if !$0 { store.send(.view(.shareSheetDismissed)) } }
          )
        ) {
          ShareSheet(items: [store.event.shareText])
        }
      }
    }

    // MARK: - Header Section

    @ViewBuilder
    private var headerSection: some View {
      VStack(spacing: 16) {
        // 이모지
        Text(store.event.displayEmoji)
          .font(.system(size: 56))

        // 제목
        Text(store.event.title)
          .font(.system(size: 22, weight: .bold))
          .multilineTextAlignment(.center)
          .foregroundStyle(.primary)

        // 상태 배지
        if store.event.isPast {
          Text("지난 일정")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color(UIColor.systemGray5))
            .clipShape(Capsule())
        } else if store.event.isOngoing {
          Text("진행 중")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(Color.green)
            .clipShape(Capsule())
        }
      }
      .frame(maxWidth: .infinity)
      .padding(.vertical, 20)
      .adaptiveGlassCard()
    }

    // MARK: - Schedule Section

    @ViewBuilder
    private var scheduleSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("일정")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        VStack(spacing: 0) {
          // 날짜
          infoRow(
            icon: "calendar",
            title: "날짜",
            value: store.event.dateText
          )

          Divider()
            .padding(.horizontal, 16)

          // 시간
          infoRow(
            icon: "clock",
            title: "시간",
            value: store.event.timeRangeText
          )

          // 장소
          if let location = store.event.location {
            Divider()
              .padding(.horizontal, 16)

            infoRow(
              icon: "location.fill",
              title: "장소",
              value: location.name
            )
          }
        }
        .adaptiveGlassCard()
      }
    }

    // MARK: - Reminder Section

    @ViewBuilder
    private var reminderSection: some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("알림")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        HStack(spacing: 12) {
          Image(systemName: "bell.fill")
            .font(.body)
            .foregroundStyle(Color.pmindigo.n500)
            .frame(width: 24)

          Text(reminderText)
            .font(.body)
            .foregroundStyle(.primary)

          Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .adaptiveGlassCard()
      }
    }

    private var reminderText: String {
      guard let minutes = store.event.reminderMinutesBefore else { return "" }
      if minutes >= 60 {
        return "\(minutes / 60)시간 전 알림"
      }
      return "\(minutes)분 전 알림"
    }

    // MARK: - Description Section

    @ViewBuilder
    private func descriptionSection(_ text: String) -> some View {
      VStack(alignment: .leading, spacing: 10) {
        Text("메모")
          .font(.system(size: 16, weight: .semibold))
          .padding(.horizontal, 4)

        Text(text)
          .font(.body)
          .foregroundStyle(.primary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(16)
          .adaptiveGlassCard()
      }
    }

    // MARK: - Info Row

    @ViewBuilder
    private func infoRow(icon: String, title: String, value: String) -> some View {
      HStack(spacing: 12) {
        Image(systemName: icon)
          .font(.body)
          .foregroundStyle(Color.pmindigo.n500)
          .frame(width: 24)

        Text(title)
          .font(.body)
          .foregroundStyle(.secondary)

        Spacer()

        Text(value)
          .font(.body)
          .foregroundStyle(.primary)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 14)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
      ToolbarItem(placement: .cancellationAction) {
        Button("닫기") {
          dismiss()
        }
      }

      ToolbarItem(placement: .topBarTrailing) {
        HStack(spacing: 4) {
          Button {
            store.send(.view(.shareTapped))
          } label: {
            Image(systemName: "square.and.arrow.up")
          }

          Menu {
            Button {
              store.send(.view(.editTapped))
            } label: {
              Label("수정", systemImage: "pencil")
            }

            Button(role: .destructive) {
              store.send(.view(.deleteTapped))
            } label: {
              Label("삭제", systemImage: "trash")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
          }
        }
      }
    }
  }
}

// MARK: - Preview

#Preview {
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
