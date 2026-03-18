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
      VStack(spacing: 0) {
        Spacer()

        phaseContentView

        Spacer()

        buttonArea
          .padding(.horizontal, 24)
          .padding(.bottom, UIScreen.main.bounds.height < 700 ? 24 : 40)
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

        VStack(spacing: 12) {
          selectAllToggle

          ScrollView {
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
          }
          .frame(maxHeight: 350)
        }
        .padding(.horizontal, 8)
      }
    }

    private var selectAllToggle: some SwiftUI.View {
      HStack {
        Text("전체 선택")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(Color.pmtext.primary)
        Spacer()
        Toggle("", isOn: Binding(
          get: { store.isAllSelected },
          set: { _ in store.send(.view(.selectAllToggled)) }
        ))
        .labelsHidden()
        .tint(Color.pmsuccess.n500)
      }
      .padding(.horizontal, 20)
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
      case .selecting:
        GlassActionButton(
          title: "가져오기 (\(store.selectedEventCount)개)",
          isPrimary: true,
          isEnabled: store.selectedEventCount > 0,
          action: { store.send(.view(.confirmImportTapped)) }
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

        Button(action: onToggle) {
          Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title3)
            .foregroundStyle(isSelected ? Color.pmsuccess.n500 : Color.pmtext.secondary)
        }
        .buttonStyle(.plain)
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
    VStack(spacing: 4) {
      ForEach(Array(group.events.prefix(3)), id: \.id) { event in
        HStack(spacing: 8) {
          Text(event.displayEmoji ?? "📅")
            .font(.caption)

          Text(event.displayTitle)
            .font(.caption)
            .lineLimit(1)
            .foregroundStyle(Color.pmtext.primary)

          Spacer()

          Text(event.timeText)
            .font(.caption2)
            .foregroundStyle(Color.pmtext.secondary)
        }
        .padding(.leading, 40)
        .padding(.trailing, 16)
        .padding(.vertical, 4)
      }

      if group.eventCount > 3 {
        Text("외 \(group.eventCount - 3)개")
          .font(.caption2)
          .foregroundStyle(Color.pmtext.secondary)
          .padding(.leading, 40)
          .padding(.top, 2)
          .padding(.bottom, 8)
      }
    }
    .transition(.opacity.combined(with: .move(edge: .top)))
  }
}
