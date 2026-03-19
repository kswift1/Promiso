// MARK: - CalendarImportView.swift
// 온보딩 → 캘린더 가져오기

import ComposableArchitecture
import PromisoShared
import SwiftUI
import Clients

extension AppEntry.CalendarImport {
  public struct View: SwiftUI.View {
    let store: StoreOf<AppEntry.CalendarImport>

    public init(store: StoreOf<AppEntry.CalendarImport>) {
      self.store = store
    }

    @SwiftUI.State private var cardsScattered: Bool = true
    @SwiftUI.State private var cardsGathered: Bool = false
    @SwiftUI.State private var showContent: Bool = false
    @SwiftUI.State private var showButtons: Bool = false
    private var isImporting: Bool {
      switch store.phase {
      case .requesting, .scanning: return true
      default: return false
      }
    }

    private var isUploading: Bool {
      store.phase == .uploading
    }

    public var body: some SwiftUI.View {
      Group {
        switch store.phase {
        case .selecting, .uploading:
          selectingLayoutView
        default:
          defaultLayoutView
        }
      }
      .auroraBackground()
      .onAppear {
        if store.phase == .idle {
          Task {
            await runAnimationSequence()
          }
        }
      }
    }

    private var defaultLayoutView: some SwiftUI.View {
      VStack(spacing: 0) {
        Spacer()
        phaseContentView
        Spacer()
        buttonArea
          .padding(.horizontal, 24)
          .padding(.bottom, UIScreen.main.bounds.height < 700 ? 24 : 40)
      }
    }

    private var selectingLayoutView: some SwiftUI.View {
      ScrollView {
        selectingPhaseView
          .padding(.top, 60)
          .padding(.bottom, 100)
      }
      .safeAreaInset(edge: .bottom) {
        VStack(spacing: 0) {
          LinearGradient(
            colors: [
              Color(.systemBackground).opacity(0),
              Color(.systemBackground).opacity(0.6),
              Color(.systemBackground).opacity(0.95)
            ],
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(height: 40)
          .allowsHitTesting(false)

          VStack(spacing: 0) {
            GlassActionButton(
              title: isUploading ? "가져오는 중이에요" : "가져오기 (\(store.selectedEventCount)개)",
              isPrimary: true,
              isEnabled: store.selectedEventCount > 0 && !isUploading,
              action: { store.send(.view(.confirmImportTapped)) }
            )
            .overlay(alignment: .leading) {
              if isUploading {
                ProgressView()
                  .tint(.white)
                  .padding(.leading, 16)
              }
            }
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 16)
          .background(Color(.systemBackground).opacity(0.95))
        }
      }
    }

    // MARK: - Phase Content View

    @ViewBuilder
    private var phaseContentView: some SwiftUI.View {
      switch store.phase {
      case .idle, .requesting, .scanning:
        idlePhaseView
      case .selecting, .uploading:
        selectingPhaseView
      case .completed:
        EmptyView()
      }
    }

    // MARK: - Idle Phase

    private var idlePhaseView: some SwiftUI.View {
      VStack(spacing: 24) {
        sampleCardsView

        if showContent {
          VStack(spacing: 10) {
            Text("먼저 기존 일정을 확인할게요")
              .font(.largeTitle.bold())
              .foregroundStyle(Color.pmtext.primary)
              .multilineTextAlignment(.center)

            Text("애플 캘린더에 있는 일정을 가져오면\n홈에서 모든 약속을 한눈에 볼 수 있어요")
              .font(.title3)
              .foregroundStyle(Color.pmtext.secondary)
              .multilineTextAlignment(.center)
              .lineSpacing(4)
          }
          .transition(.opacity.combined(with: .offset(y: 12)))
        }
      }
      .padding(.horizontal, 40)
    }

    private var sampleCardsView: some SwiftUI.View {
      ZStack {
        // 좌상단에서 모여옴
        sampleEventCard(emoji: "☕️", title: "카페 모임", time: "오후 3:00", location: "스타벅스")
          .offset(
            x: cardsGathered ? 0 : -140,
            y: cardsGathered ? -70 : -180
          )
          .rotationEffect(.degrees(cardsGathered ? -2 : -12))
          .scaleEffect(cardsGathered ? 1 : 0.85)
          .opacity(cardsScattered ? 0 : (cardsGathered ? 1 : 0.6))

        // 우측에서 모여옴
        sampleEventCard(emoji: "💼", title: "프로젝트 회의", time: "오전 10:00", location: nil)
          .offset(
            x: cardsGathered ? 0 : 150,
            y: cardsGathered ? 0 : -40
          )
          .rotationEffect(.degrees(cardsGathered ? 1 : 8))
          .scaleEffect(cardsGathered ? 1 : 0.85)
          .opacity(cardsScattered ? 0 : (cardsGathered ? 1 : 0.6))

        // 하단에서 모여옴
        sampleEventCard(emoji: "🍽️", title: "점심 약속", time: "오후 12:30", location: "강남역")
          .offset(
            x: cardsGathered ? 0 : 60,
            y: cardsGathered ? 70 : 200
          )
          .rotationEffect(.degrees(cardsGathered ? 2 : 15))
          .scaleEffect(cardsGathered ? 1 : 0.85)
          .opacity(cardsScattered ? 0 : (cardsGathered ? 1 : 0.6))
      }
      .frame(height: 220)
    }

    private func sampleEventCard(
      emoji: String,
      title: String,
      time: String,
      location: String?
    ) -> some SwiftUI.View {
      HStack(alignment: .top, spacing: 12) {
        Text(emoji)
          .font(.system(size: 28))

        VStack(alignment: .leading, spacing: 3) {
          Text(title)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(Color.pmtext.primary)

          HStack(spacing: 10) {
            HStack(spacing: 3) {
              Image(systemName: "clock")
                .font(.system(size: 9))
              Text(time)
            }
            .font(.system(size: 11))
            .foregroundStyle(Color.pmtext.secondary)

            if let location {
              HStack(spacing: 3) {
                Image(systemName: "mappin")
                  .font(.system(size: 9))
                Text(location)
              }
              .font(.system(size: 11))
              .foregroundStyle(Color.pmtext.secondary)
            }
          }
        }

        Spacer()
      }
      .padding(12)
      .staticGlassBackground(cornerRadius: 14)
    }

    // MARK: - Selecting Phase

    private var selectingPhaseView: some SwiftUI.View {
      VStack(spacing: 20) {
        VStack(spacing: 8) {
          Text("가져올 일정을 선택해주세요")
            .font(.title2.bold())
            .foregroundStyle(Color.pmtext.primary)
          Text("Apple Calendar에 있는 일정이에요")
            .font(.subheadline)
            .foregroundStyle(Color.pmtext.secondary)
        }

        VStack(spacing: 8) {
          ForEach(store.calendarGroups) { group in
            CalendarGroupRow(
              group: group,
              selectedEventIds: store.selectedEventIds,
              isExpanded: store.expandedCalendarNames.contains(group.calendarName),
              onExpandToggle: { store.send(.view(.calendarExpandToggled(group.calendarName))) },
              onSectionToggle: { store.send(.view(.calendarToggled(group.calendarName))) },
              onEventToggle: { eventId in store.send(.view(.eventToggled(eventId))) }
            )
          }
        }
        .padding(.horizontal, 8)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.expandedCalendarNames)
      }
    }

    // MARK: - Button Area

    @ViewBuilder
    private var buttonArea: some SwiftUI.View {
      switch store.phase {
      case .idle, .requesting, .scanning:
        if showButtons {
          VStack(spacing: 14) {
            GlassActionButton(
              title: isImporting ? "가져오는 중이에요" : "가져오기",
              isPrimary: true,
              isEnabled: !isImporting,
              action: { store.send(.view(.importTapped)) }
            )
            .overlay(alignment: .leading) {
              if isImporting {
                ProgressView()
                  .tint(.white)
                  .padding(.leading, 16)
              }
            }
            .transition(.opacity.combined(with: .offset(y: 16)))

            if !isImporting {
              Button {
                store.send(.view(.laterTapped))
              } label: {
                Text("나중에")
                  .font(.footnote)
                  .foregroundStyle(Color.pmtext.secondary.opacity(0.6))
              }
              .buttonStyle(.plain)
              .transition(.opacity.combined(with: .offset(y: 16)))
            }
          }
        }
      default:
        EmptyView()
      }
    }

    // MARK: - Animation Sequence

    private func runAnimationSequence() async {
      // 1) 카드 흩어진 상태로 페이드인
      try? await Task.sleep(for: .seconds(0.3))
      withAnimation(.easeOut(duration: 0.5)) {
        cardsScattered = false
      }

      // 2) 흩어진 카드가 중앙으로 모여듦
      try? await Task.sleep(for: .seconds(0.6))
      withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
        cardsGathered = true
      }

      // 3) 텍스트 등장
      try? await Task.sleep(for: .seconds(0.5))
      withAnimation(.easeOut(duration: 0.65)) {
        showContent = true
      }

      // 4) 버튼 등장
      try? await Task.sleep(for: .seconds(0.5))
      withAnimation(.easeOut(duration: 0.55)) {
        showButtons = true
      }
    }
  }
}

// MARK: - CalendarGroupRow

private struct CalendarGroupRow: SwiftUI.View {
  let group: CalendarGroup
  let selectedEventIds: Set<String>
  let isExpanded: Bool
  let onExpandToggle: () -> Void
  let onSectionToggle: () -> Void
  let onEventToggle: (String) -> Void

  private var groupEventIds: Set<String> {
    Set(group.events.map(\.id))
  }

  private var allSelected: Bool {
    groupEventIds.isSubset(of: selectedEventIds)
  }

  private var someSelected: Bool {
    !groupEventIds.isDisjoint(with: selectedEventIds)
  }

  var body: some SwiftUI.View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
          .font(.caption)
          .foregroundStyle(Color.pmtext.secondary)
          .frame(width: 12)

        Circle()
          .fill(Color(hex: group.calendarColorHex))
          .frame(width: 12, height: 12)

        Text(group.calendarName)
          .font(.body.weight(.medium))
          .foregroundStyle(Color.pmtext.primary)

        Text("\(group.eventCount)개")
          .font(.caption)
          .foregroundStyle(Color.pmtext.secondary)

        Spacer()

        Toggle("", isOn: Binding(
          get: { allSelected },
          set: { _ in onSectionToggle() }
        ))
        .labelsHidden()
        .tint(Color.pmsuccess.n500)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .contentShape(Rectangle())
      .onTapGesture(perform: onExpandToggle)

      if isExpanded {
        VStack(spacing: 8) {
          ForEach(group.events, id: \.id) { event in
            CalendarEventCard(
              event: event,
              isSelected: selectedEventIds.contains(event.id),
              onToggle: { onEventToggle(event.id) }
            )
          }
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
    .background(Color.pmsurface.glass.opacity(0.3))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

// MARK: - CalendarEventCard

private struct CalendarEventCard: SwiftUI.View {
  let event: CalendarEvent
  let isSelected: Bool
  let onToggle: () -> Void

  var body: some SwiftUI.View {
    HStack(spacing: 12) {
      Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
        .font(.title3)
        .foregroundStyle(isSelected ? Color.pmsuccess.n500 : Color.pmgray.n300)

      Text(event.displayEmoji ?? "📅")
        .font(.system(size: 44))

      VStack(alignment: .leading, spacing: 4) {
        Text(event.displayTitle)
          .font(.system(size: 16, weight: .semibold))
          .foregroundStyle(Color.pmtext.primary)
          .lineLimit(1)

        HStack(spacing: 4) {
          Image(systemName: "clock")
            .font(.caption2)
          Text(event.timeText)
            .font(.caption)
        }
        .foregroundStyle(Color.pmtext.secondary)

        if let location = event.location, !location.isEmpty {
          HStack(spacing: 4) {
            Image(systemName: "location.fill")
              .font(.caption2)
            Text(location)
              .font(.caption)
              .lineLimit(1)
          }
          .foregroundStyle(Color.pmtext.secondary)
        }
      }

      Spacer()
    }
    .padding(16)
    .adaptiveGlassBackground(cornerRadius: 16)
    .contentShape(Rectangle())
    .onTapGesture(perform: onToggle)
  }
}

// MARK: - Previews

#Preview("Idle") {
  AppEntry.CalendarImport.View(
    store: Store(
      initialState: AppEntry.CalendarImport.State(nickname: "성원")
    ) {
      AppEntry.CalendarImport()
    }
  )
}

#Preview("Selecting") {
  let events: [CalendarEvent] = [
    CalendarEvent(id: "1", title: "🍽️ 점심 약속", startDate: Date(), endDate: Date().addingTimeInterval(3600), location: "강남역", isAllDay: false, calendarName: "업무", calendarColorHex: "#1E90FF"),
    CalendarEvent(id: "2", title: "📝 회의", startDate: Date().addingTimeInterval(7200), endDate: Date().addingTimeInterval(10800), location: nil, isAllDay: false, calendarName: "업무", calendarColorHex: "#1E90FF"),
    CalendarEvent(id: "3", title: "🎂 생일 파티", startDate: Date().addingTimeInterval(86400), endDate: Date().addingTimeInterval(90000), location: "이태원", isAllDay: false, calendarName: "개인", calendarColorHex: "#32CD32"),
    CalendarEvent(id: "4", title: "운동", startDate: Date().addingTimeInterval(172800), endDate: Date().addingTimeInterval(176400), location: nil, isAllDay: false, calendarName: "개인", calendarColorHex: "#32CD32"),
    CalendarEvent(id: "5", title: "가족 모임", startDate: Date().addingTimeInterval(259200), endDate: Date().addingTimeInterval(262800), location: "집", isAllDay: false, calendarName: "가족", calendarColorHex: "#FF4500"),
  ]
  let groups = CalendarGroup.groupBy(events)

  AppEntry.CalendarImport.View(
    store: Store(
      initialState: {
        var state = AppEntry.CalendarImport.State(nickname: "성원")
        state.phase = .selecting
        state.calendarGroups = groups
        state.selectedEventIds = Set(groups.flatMap(\.events).map(\.id))
        return state
      }()
    ) {
      AppEntry.CalendarImport()
    }
  )
}

#Preview("Uploading") {
  AppEntry.CalendarImport.View(
    store: Store(
      initialState: {
        var state = AppEntry.CalendarImport.State(nickname: "성원")
        state.phase = .uploading
        state.importProgress = 7
        state.importTotal = 15
        return state
      }()
    ) {
      AppEntry.CalendarImport()
    }
  )
}

