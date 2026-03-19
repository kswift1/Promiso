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
        items: FeatureGuideView.scheduleGuideItems,
        onComplete: {
          store.send(.view(.dismissGuide))
        }
      )
    }

    @ViewBuilder
    private var calendarGuideView: some View {
      FeatureGuideView(
        items: FeatureGuideView.calendarGuideItems,
        onComplete: {
          store.send(.view(.dismissGuide))
        }
      )
    }
  }
}
