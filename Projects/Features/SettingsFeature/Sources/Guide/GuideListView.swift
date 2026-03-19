import ComposableArchitecture
import SwiftUI
import PromisoShared
import ResourceKit

extension Guide {
  public struct RootView: View {
    @Bindable var store: StoreOf<Feature>

    public init(store: StoreOf<Feature>) {
      self.store = store
    }

    public var body: some View {
      ScrollView {
        VStack(spacing: 12) {
          ForEach(GuideTab.allCases) { tab in
            guideRow(tab)
          }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
      }
      .navigationTitle(LocalizedStrings.SettingsStrings.guide)
      .navigationBarTitleDisplayMode(.large)
      .auroraBackground()
      .fullScreenCover(
        item: Binding(
          get: { store.isShowingGuide },
          set: { _ in store.send(.view(.dismissGuide)) }
        )
      ) { tab in
        guideContent(for: tab)
      }
    }

    @ViewBuilder
    private func guideRow(_ tab: GuideTab) -> some View {
      Button {
        if tab.isAvailable {
          store.send(.view(.guideTapped(tab)))
        }
      } label: {
        HStack(spacing: 12) {
          Image(systemName: tab.icon)
            .font(.title3)
            .foregroundStyle(tab.isAvailable ? Color.pmindigo.n500 : Color.secondary)
            .frame(width: 28)

          Text(tab.title)
            .font(.body)
            .foregroundStyle(tab.isAvailable ? Color.primary : Color.secondary)

          Spacer()

          if tab.isAvailable {
            Image(systemName: "chevron.right")
              .font(.caption)
              .foregroundStyle(Color.secondary)
          } else {
            Text(LocalizedStrings.Common.comingSoon)
              .font(.caption)
              .foregroundStyle(Color.secondary)
          }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(!tab.isAvailable)
      .adaptiveGlassCard()
    }

    @ViewBuilder
    private func guideContent(for tab: GuideTab) -> some View {
      switch tab {
      case .calendar:
        calendarGuideView
      case .schedule:
        scheduleGuideView
      default:
        EmptyView()
      }
    }

    @ViewBuilder
    private var scheduleGuideView: some View {
      FeatureGuideView(
        items: [
          .init(
            id: 0,
            title: LocalizedStrings.Schedule.guideModeSwitchTitle,
            subtitle: LocalizedStrings.Schedule.guideModeSwitchSubtitle,
            screenshot: ResourceKitAsset.guideScheduleModeSwitch.swiftUIImage,
            zoomScale: 1.5,
            zoomAnchor: .top
          ),
          .init(
            id: 1,
            title: LocalizedStrings.Schedule.guideGroupListTitle,
            subtitle: LocalizedStrings.Schedule.guideGroupListSubtitle,
            screenshot: ResourceKitAsset.guideScheduleGroupList.swiftUIImage
          ),
          .init(
            id: 2,
            title: LocalizedStrings.Schedule.guideSwipeResponseTitle,
            subtitle: LocalizedStrings.Schedule.guideSwipeResponseSubtitle,
            screenshot: ResourceKitAsset.guideScheduleSwipeResponse.swiftUIImage,
            zoomScale: 1.3,
            zoomAnchor: .center
          ),
          .init(
            id: 3,
            title: LocalizedStrings.Schedule.guidePersonalTitle,
            subtitle: LocalizedStrings.Schedule.guidePersonalSubtitle,
            screenshot: ResourceKitAsset.guideSchedulePersonal.swiftUIImage
          ),
        ],
        onComplete: {
          store.send(.view(.dismissGuide))
        }
      )
    }

    @ViewBuilder
    private var calendarGuideView: some View {
      FeatureGuideView(
        items: [
          .init(
            id: 0,
            title: LocalizedStrings.Calendar.guideModeSwitchTitle,
            subtitle: LocalizedStrings.Calendar.guideModeSwitchSubtitle,
            screenshot: ResourceKitAsset.guideCalendarModeSwitch.swiftUIImage,
            zoomScale: 1.5,
            zoomAnchor: .top
          ),
          .init(
            id: 1,
            title: LocalizedStrings.Calendar.guideWeekTimelineTitle,
            subtitle: LocalizedStrings.Calendar.guideWeekTimelineSubtitle,
            screenshot: ResourceKitAsset.guideCalendarWeekTimeline.swiftUIImage
          ),
          .init(
            id: 2,
            title: LocalizedStrings.Calendar.guideWeekCreateTitle,
            subtitle: LocalizedStrings.Calendar.guideWeekCreateSubtitle,
            screenshot: ResourceKitAsset.guideCalendarWeekCreate.swiftUIImage,
            zoomScale: 1.3,
            zoomAnchor: .center
          ),
          .init(
            id: 3,
            title: LocalizedStrings.Calendar.guideMonthListTitle,
            subtitle: LocalizedStrings.Calendar.guideMonthListSubtitle,
            screenshot: ResourceKitAsset.guideCalendarMonthList.swiftUIImage
          ),
          .init(
            id: 4,
            title: LocalizedStrings.Calendar.guideMonthExpandedTitle,
            subtitle: LocalizedStrings.Calendar.guideMonthExpandedSubtitle,
            screenshot: ResourceKitAsset.guideCalendarMonthExpanded.swiftUIImage
          ),
          .init(
            id: 5,
            title: LocalizedStrings.Calendar.guideFilterTitle,
            subtitle: LocalizedStrings.Calendar.guideFilterSubtitle,
            screenshot: ResourceKitAsset.guideCalendarFilter.swiftUIImage,
            zoomScale: 1.2,
            zoomAnchor: .bottom
          ),
        ],
        onComplete: {
          store.send(.view(.dismissGuide))
        }
      )
    }
  }
}
