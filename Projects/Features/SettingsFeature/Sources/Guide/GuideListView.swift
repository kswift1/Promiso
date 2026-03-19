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
      .navigationTitle("설명서")
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
            Text("준비 중")
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
      default:
        EmptyView()
      }
    }

    @ViewBuilder
    private var calendarGuideView: some View {
      FeatureGuideView(
        items: [
          .init(
            id: 0,
            title: "세 가지 시선으로 일정을 봐요",
            subtitle: "주간 타임라인 · 월간 리스트 · 월간 전체, 헤더 아이콘을 탭하거나 길게 눌러 전환해요",
            screenshot: ResourceKitAsset.guideCalendarModeSwitch.swiftUIImage,
            zoomScale: 1.5,
            zoomAnchor: .top
          ),
          .init(
            id: 1,
            title: "하루를 타임라인으로",
            subtitle: "24시간 일정을 한눈에 확인하고, 줌인·줌아웃으로 시간대를 확대하거나 축소할 수 있어요",
            screenshot: ResourceKitAsset.guideCalendarWeekTimeline.swiftUIImage
          ),
          .init(
            id: 2,
            title: "여기, 일정 하나 놓을게요",
            subtitle: "빈 시간대를 더블 탭하거나 꾹 눌러 일정을 배치하고, 드래그로 시간 범위를 조정할 수 있어요",
            screenshot: ResourceKitAsset.guideCalendarWeekCreate.swiftUIImage,
            zoomScale: 1.3,
            zoomAnchor: .center
          ),
          .init(
            id: 3,
            title: "한 달을 한눈에",
            subtitle: "상단 달력과 하단 일정 리스트를 함께 볼 수 있어요. 날짜를 탭하면 해당 일정으로 스크롤돼요",
            screenshot: ResourceKitAsset.guideCalendarMonthList.swiftUIImage
          ),
          .init(
            id: 4,
            title: "달력 안에서 모든 일정 확인",
            subtitle: "일정을 한눈에 파악해요. 일정 바를 탭하면 상세로, 날짜를 탭하면 주간 뷰로 전환돼요",
            screenshot: ResourceKitAsset.guideCalendarMonthExpanded.swiftUIImage
          ),
          .init(
            id: 5,
            title: "원하는 일정만, 그대로",
            subtitle: "그룹별 · 상태별로 필터링하고, 개인 일정과 iOS 캘린더 이벤트 표시를 조절할 수 있어요",
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
