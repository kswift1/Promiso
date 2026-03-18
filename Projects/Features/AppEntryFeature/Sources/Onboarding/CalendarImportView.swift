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

    @SwiftUI.State private var showEmoji: Bool = false
    @SwiftUI.State private var showContent: Bool = false
    @SwiftUI.State private var showButtons: Bool = false

    public var body: some SwiftUI.View {
      Group {
        if store.phase == .selecting {
          selectingLayoutView
        } else {
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
      VStack(spacing: 0) {
        ScrollView {
          selectingPhaseView
            .padding(.top, 60)
            .padding(.bottom, 100)
        }

        // 하단 고정 버튼 + 그라데이션
        VStack(spacing: 0) {
          GlassActionButton(
            title: "가져오기 (\(store.selectedEventCount)개)",
            isPrimary: true,
            isEnabled: store.selectedEventCount > 0,
            action: { store.send(.view(.confirmImportTapped)) }
          )
          .padding(.horizontal, 24)
          .padding(.vertical, 16)
        }
        .overlay(alignment: .top) {
          LinearGradient(
            colors: [Color.black.opacity(0), Color.black.opacity(0.15)],
            startPoint: .top,
            endPoint: .bottom
          )
          .frame(height: 24)
          .offset(y: -24)
          .allowsHitTesting(false)
        }
        .padding(.bottom, UIScreen.main.bounds.height < 700 ? 8 : 24)
      }
    }

    // MARK: - Phase Content View

    @ViewBuilder
    private var phaseContentView: some SwiftUI.View {
      switch store.phase {
      case .idle:
        idlePhaseView
      case .requesting, .scanning:
        loadingPhaseView
      case .selecting:
        selectingPhaseView
      case .uploading:
        uploadingPhaseView
      case .success(let result):
        successPhaseView(result: result)
      case .completed:
        EmptyView()
      }
    }

    // MARK: - Idle Phase

    private var idlePhaseView: some SwiftUI.View {
      VStack(spacing: 20) {
        if showEmoji {
          Text("📅")
            .font(.system(size: 72))
            .transition(.scale.combined(with: .opacity))
        }

        if showContent {
          VStack(spacing: 10) {
            Text("먼저 기존 일정을 확인할게요")
              .font(.largeTitle.bold())
              .foregroundStyle(Color.pmtext.primary)

            Text("Apple Calendar에 있는 일정을 가져오면\n홈에서 모든 약속을 한눈에 볼 수 있어요")
              .font(.title3)
              .foregroundStyle(Color.pmtext.secondary)
              .multilineTextAlignment(.center)
              .lineSpacing(4)
          }
          .transition(.opacity.combined(with: .offset(y: 12)))
        }
      }
      .padding(.horizontal, 20)
    }

    // MARK: - Loading Phase

    private var loadingPhaseView: some SwiftUI.View {
      VStack(spacing: 16) {
        ProgressView()
          .tint(Color.pmindigo.n500)
          .scaleEffect(1.2)

        Text("기존 약속을 확인하고 있어요...")
          .font(.body)
          .foregroundStyle(Color.pmtext.secondary)
      }
    }

    // MARK: - Selecting Phase

    private var selectingPhaseView: some SwiftUI.View {
      VStack(spacing: 20) {
        VStack(spacing: 8) {
          Text("가져올 캘린더를 선택해주세요")
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
              isSelected: store.selectedCalendarNames.contains(group.calendarName),
              isExpanded: store.expandedCalendarNames.contains(group.calendarName),
              onTap: { store.send(.view(.calendarExpandToggled(group.calendarName))) },
              onToggle: { store.send(.view(.calendarToggled(group.calendarName))) }
            )
          }
        }
        .padding(.horizontal, 8)
      }
    }

    // MARK: - Uploading Phase

    private var uploadingPhaseView: some SwiftUI.View {
      VStack(spacing: 16) {
        ProgressView(value: Double(store.importProgress), total: Double(store.importTotal))
          .progressViewStyle(.linear)
          .tint(Color.pmsuccess.n500)
          .frame(width: 200)

        Text("\(store.importProgress)/\(store.importTotal)개 가져오는 중...")
          .font(.body)
          .foregroundStyle(Color.pmtext.secondary)
      }
    }

    // MARK: - Success Phase

    private func successPhaseView(result: CalendarImportResult) -> some SwiftUI.View {
      VStack(spacing: 20) {
        Text(result.totalImported > 0 ? "🎉" : "📅")
          .font(.system(size: 72))

        VStack(spacing: 10) {
          Text(successTitle(result))
            .font(.largeTitle.bold())
            .foregroundStyle(Color.pmtext.primary)
            .multilineTextAlignment(.center)

          Text(successSubtitle(result))
            .font(.title3)
            .foregroundStyle(Color.pmtext.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
        }
      }
      .padding(.horizontal, 20)
      .transition(.opacity.combined(with: .offset(y: 12)))
    }

    private func successTitle(_ result: CalendarImportResult) -> String {
      if result.thisWeekCount > 0 {
        return "이번 주 약속 \(result.thisWeekCount)개\n가져왔어요!"
      } else if result.totalImported > 0 {
        return "일정 \(result.totalImported)개\n가져왔어요!"
      } else {
        return "준비 완료!"
      }
    }

    private func successSubtitle(_ result: CalendarImportResult) -> String {
      if result.totalImported > 0 {
        return "다가오는 약속을 미리 챙겨드릴게요"
      } else {
        return "첫 약속을 만들면 바로 챙겨드릴게요"
      }
    }

    // MARK: - Button Area

    @ViewBuilder
    private var buttonArea: some SwiftUI.View {
      switch store.phase {
      case .idle:
        if showButtons {
          VStack(spacing: 14) {
            GlassActionButton(
              title: "가져오기",
              isPrimary: true,
              action: { store.send(.view(.importTapped)) }
            )
            .transition(.opacity.combined(with: .offset(y: 16)))

            GlassActionButton(
              title: "나중에",
              isPrimary: false,
              action: { store.send(.view(.laterTapped)) }
            )
            .transition(.opacity.combined(with: .offset(y: 16)))
          }
        }
      case .success:
        GlassActionButton(
          title: "시작해보세요!",
          isPrimary: true,
          action: { store.send(.view(.startTapped)) }
        )
      default:
        EmptyView()
      }
    }

    // MARK: - Animation Sequence

    private func runAnimationSequence() async {
      try? await Task.sleep(for: .seconds(0.3))
      withAnimation(.spring(response: 0.7, dampingFraction: 0.6)) {
        showEmoji = true
      }

      try? await Task.sleep(for: .seconds(0.5))
      withAnimation(.easeOut(duration: 0.65)) {
        showContent = true
      }

      try? await Task.sleep(for: .seconds(0.6))
      withAnimation(.easeOut(duration: 0.55)) {
        showButtons = true
      }
    }
  }
}

// MARK: - CalendarGroupRow

private struct CalendarGroupRow: SwiftUI.View {
  let group: CalendarGroup
  let isSelected: Bool
  let isExpanded: Bool
  let onTap: () -> Void
  let onToggle: () -> Void

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
          get: { isSelected },
          set: { _ in onToggle() }
        ))
        .labelsHidden()
        .tint(Color.pmsuccess.n500)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .contentShape(Rectangle())
      .onTapGesture(perform: onTap)

      if isExpanded {
        expandedEventsView
      }
    }
    .background(Color.pmsurface.glass.opacity(0.3))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }

  @ViewBuilder
  private var expandedEventsView: some SwiftUI.View {
    VStack(spacing: 8) {
      ForEach(Array(group.events.prefix(5)), id: \.id) { event in
        CalendarEventCardRow(event: event)
      }
      if group.eventCount > 5 {
        Text("외 \(group.eventCount - 5)개")
          .font(.caption)
          .foregroundStyle(Color.pmtext.secondary)
          .frame(maxWidth: .infinity)
          .padding(.vertical, 4)
      }
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 12)
    .transition(.opacity.combined(with: .move(edge: .top)))
  }
}

// MARK: - CalendarEventCardRow

private struct CalendarEventCardRow: SwiftUI.View {
  let event: CalendarEvent

  var body: some SwiftUI.View {
    HStack(alignment: .top, spacing: 10) {
      Text(event.displayEmoji ?? "📅")
        .font(.system(size: 28))

      VStack(alignment: .leading, spacing: 4) {
        Text(event.displayTitle)
          .font(.subheadline.weight(.medium))
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
    .padding(10)
    .background(Color.pmsurface.glass.opacity(0.2))
    .clipShape(RoundedRectangle(cornerRadius: 10))
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
        state.selectedCalendarNames = Set(groups.map(\.calendarName))
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

#Preview("Success") {
  AppEntry.CalendarImport.View(
    store: Store(
      initialState: {
        var state = AppEntry.CalendarImport.State(nickname: "성원")
        state.phase = .success(CalendarImportResult(totalImported: 23, thisWeekCount: 5))
        return state
      }()
    ) {
      AppEntry.CalendarImport()
    }
  )
}
