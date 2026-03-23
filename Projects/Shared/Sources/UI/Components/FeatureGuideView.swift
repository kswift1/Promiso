//
//  FeatureGuideView.swift
//  PromisoShared
//
//  기능 소개 온보딩/가이드 뷰 (iOS26StyleOnBoarding 기반)
//

import SwiftUI
import ResourceKit

// MARK: - FeatureGuideView

/// 기능 소개 가이드 뷰
/// 스크린샷과 텍스트로 구성된 온보딩/가이드 화면을 표시합니다.
///
/// Usage:
/// ```swift
/// FeatureGuideView(
///   items: [
///     .init(id: 0, title: "기능 제목", subtitle: "기능 설명", screenshot: ResourceKitAsset.guideImage.swiftUIImage),
///   ],
///   onComplete: { dismiss() }
/// )
/// ```
public struct FeatureGuideView: View {
  public var tint: Color = Color.pmindigo.n500
  public var hideBezels: Bool = false
  public var items: [Item]
  public var onComplete: () -> Void

  @State private var currentIndex: Int = 0
  @State private var screenshotSize: CGSize = .zero

  public init(
    tint: Color = Color.pmindigo.n500,
    hideBezels: Bool = false,
    items: [Item],
    onComplete: @escaping () -> Void
  ) {
    self.tint = tint
    self.hideBezels = hideBezels
    self.items = items
    self.onComplete = onComplete
  }

  public var body: some View {
    if items.isEmpty {
      Color.clear
    } else {
      mainContent
    }
  }

  @ViewBuilder
  private var mainContent: some View {
    ZStack(alignment: .bottom) {
      screenshotSection
        .compositingGroup()
        .scaleEffect(
          items[currentIndex].zoomScale,
          anchor: items[currentIndex].zoomAnchor
        )
        .padding(.top, 35)
        .padding(.horizontal, 30)
        .padding(.bottom, 220)

      VStack(spacing: 10) {
        textContentSection
        indicatorSection
        buttonRow
      }
      .padding(.top, 20)
      .padding(.horizontal, 15)
      .frame(height: 210)
      .background {
        variableGlassBlur(15)
      }

      // 닫기 버튼 (우측 상단)
      closeButton
    }
    .preferredColorScheme(.dark)
  }

  // MARK: - Screenshot

  @ViewBuilder
  private var screenshotSection: some View {
    GeometryReader { geo in
      let size = geo.size

      Rectangle()
        .fill(.black)

      ScrollView(.horizontal) {
        HStack(spacing: 12) {
          ForEach(items.indices, id: \.self) { index in
            let item = items[index]

            Group {
              if let screenshot = item.screenshot {
                screenshot
                  .resizable()
                  .aspectRatio(contentMode: .fit)
                  .onGeometryChange(for: CGSize.self) {
                    $0.size
                  } action: { newValue in
                    guard index == 0 && screenshotSize == .zero else { return }
                    screenshotSize = newValue
                  }
                  .clipShape(deviceShape)
              } else {
                Rectangle()
                  .fill(.black)
              }
            }
            .frame(width: size.width, height: size.height)
          }
        }
        .scrollTargetLayout()
      }
      .scrollDisabled(true)
      .scrollTargetBehavior(.viewAligned)
      .scrollIndicators(.hidden)
      .scrollPosition(id: .init(get: {
        return currentIndex
      }, set: { _ in }))
    }
    .clipShape(deviceShape)
    .overlay {
      if screenshotSize != .zero && !hideBezels {
        ZStack {
          deviceShape
            .stroke(.white, lineWidth: 6)

          deviceShape
            .stroke(.black, lineWidth: 4)

          deviceShape
            .stroke(.black, lineWidth: 6)
            .padding(4)
        }
        .padding(-7)
      }
    }
    .frame(
      maxWidth: screenshotSize.width == 0 ? nil : screenshotSize.width,
      maxHeight: screenshotSize.height == 0 ? nil : screenshotSize.height
    )
    .containerShape(RoundedRectangle(cornerRadius: deviceCornerRadius))
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  // MARK: - Text Content

  @ViewBuilder
  private var textContentSection: some View {
    GeometryReader { geo in
      let size = geo.size

      ScrollView(.horizontal) {
        HStack(spacing: 0) {
          ForEach(items.indices, id: \.self) { index in
            let item = items[index]
            let isActive = currentIndex == index

            VStack(spacing: 6) {
              Text(item.title)
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundStyle(.white)

              Text(item.subtitle)
                .font(.callout)
                .lineLimit(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
            }
            .frame(width: size.width)
            .compositingGroup()
            .blur(radius: isActive ? 0 : 30)
            .opacity(isActive ? 1 : 0)
          }
        }
        .scrollTargetLayout()
      }
      .scrollIndicators(.hidden)
      .scrollDisabled(true)
      .scrollTargetBehavior(.paging)
      .scrollClipDisabled()
      .scrollPosition(id: .init(get: {
        return currentIndex
      }, set: { _ in }))
    }
  }

  // MARK: - Indicator

  @ViewBuilder
  private var indicatorSection: some View {
    HStack(spacing: 6) {
      ForEach(items.indices, id: \.self) { index in
        let isActive: Bool = currentIndex == index

        Capsule()
          .fill(.white.opacity(isActive ? 1 : 0.4))
          .frame(width: isActive ? 25 : 6, height: 6)
      }
    }
    .padding(.bottom, 5)
  }

  // MARK: - Close Button

  @ViewBuilder
  private var closeButton: some View {
    if #available(iOS 26, *) {
      Button {
        onComplete()
      } label: {
        Image(systemName: "xmark")
          .font(.body.weight(.medium))
      }
      .buttonStyle(.glass)
      .buttonBorderShape(.circle)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
      .padding(.trailing, 15)
      .padding(.top, 5)
    } else {
      Button {
        onComplete()
      } label: {
        Image(systemName: "xmark")
          .font(.body.weight(.medium))
          .foregroundStyle(.white.opacity(0.7))
          .frame(width: 44, height: 44)
          .background(Color.white.opacity(0.15), in: Circle())
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
      .padding(.trailing, 15)
      .padding(.top, 5)
    }
  }

  // MARK: - Button Row (← 원형 + 다음)

  @ViewBuilder
  private var buttonRow: some View {
    let isLast = currentIndex == items.count - 1

    HStack(spacing: 12) {
      // Back button (원형)
      if currentIndex > 0 {
        if #available(iOS 26, *) {
          Button {
            withAnimation(animation) {
              currentIndex = max(currentIndex - 1, 0)
            }
          } label: {
            Image(systemName: "chevron.left")
              .font(.body.weight(.medium))
          }
          .buttonStyle(.glass)
          .buttonBorderShape(.circle)
        } else {
          Button {
            withAnimation(animation) {
              currentIndex = max(currentIndex - 1, 0)
            }
          } label: {
            Image(systemName: "chevron.left")
              .font(.body.weight(.medium))
              .foregroundStyle(.white.opacity(0.7))
              .frame(width: 44, height: 44)
              .background(Color.white.opacity(0.15), in: Circle())
          }
        }
      }

      // Continue button
      if #available(iOS 26, *) {
        Button {
          if isLast {
            onComplete()
          } else {
            withAnimation(animation) {
              currentIndex = min(currentIndex + 1, items.count - 1)
            }
          }
        } label: {
          Text(isLast ? LocalizedStrings.Common.done : LocalizedStrings.Common.next)
            .fontWeight(.medium)
            .contentTransition(.numericText())
            .padding(.vertical, 6)
        }
        .tint(tint)
        .buttonStyle(.glassProminent)
        .buttonSizing(.flexible)
      } else {
        Button {
          if isLast {
            onComplete()
          } else {
            withAnimation(animation) {
              currentIndex = min(currentIndex + 1, items.count - 1)
            }
          }
        } label: {
          Text(isLast ? LocalizedStrings.Common.done : LocalizedStrings.Common.next)
            .fontWeight(.medium)
            .contentTransition(.numericText())
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .tint(tint)
      }
    }
    .padding(.horizontal, 20)
  }

  // MARK: - Variable Glass Blur

  @ViewBuilder
  private func variableGlassBlur(_ radius: CGFloat) -> some View {
    let bgTint: Color = .black.opacity(0.5)

    if #available(iOS 26, *) {
      Rectangle()
        .fill(bgTint)
        .glassEffect(.clear, in: .rect)
        .blur(radius: radius)
        .padding([.horizontal, .bottom], -radius * 2)
        .padding(.top, -radius / 2 - 10)
        .opacity(items[currentIndex].zoomScale > 1 ? 1 : 0)
        .ignoresSafeArea()
    } else {
      LinearGradient(
        colors: [
          Color.black.opacity(0.95),
          Color.black.opacity(0.85),
          Color.black.opacity(0.6),
          Color.clear,
        ],
        startPoint: .bottom,
        endPoint: .top
      )
      .padding(.top, -30)
      .ignoresSafeArea()
    }
  }

  // MARK: - Device Shape & Corner Radius

  private var deviceShape: AnyShape {
    if #available(iOS 26, *) {
      AnyShape(ConcentricRectangle(corners: .concentric, isUniform: true))
    } else {
      AnyShape(RoundedRectangle(cornerRadius: deviceCornerRadius))
    }
  }

  private var deviceCornerRadius: CGFloat {
    guard let imageSize = items.first?.screenshotImageSize,
          imageSize.height > 0 else {
      return 55
    }
    let ratio = screenshotSize.height / imageSize.height
    let actualCornerRadius: CGFloat = 180
    return actualCornerRadius * ratio
  }

  private var animation: Animation {
    .interpolatingSpring(duration: 0.65, bounce: 0, initialVelocity: 0)
  }
}

// MARK: - Guide Items

extension FeatureGuideView {
  /// 일정 탭 온보딩 가이드 아이템 (GroupMainView, GuideListView 공유)
  public static var scheduleGuideItems: [Item] {
    [
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
    ]
  }

  /// 홈 탭 온보딩 가이드 아이템 (HomeRootView, GuideListView 공유)
  public static var homeGuideItems: [Item] {
    [
      .init(
        id: 0,
        title: LocalizedStrings.Home.guideOverviewTitle,
        subtitle: LocalizedStrings.Home.guideOverviewSubtitle,
        screenshot: ResourceKitAsset.guideHomeOverview.swiftUIImage
      ),
      .init(
        id: 1,
        title: LocalizedStrings.Home.guideCalendarOverlayTitle,
        subtitle: LocalizedStrings.Home.guideCalendarOverlaySubtitle,
        screenshot: ResourceKitAsset.guideHomeCalendarOverlay.swiftUIImage,
        zoomScale: 1.3,
        zoomAnchor: .top
      ),
      .init(
        id: 2,
        title: LocalizedStrings.Home.guideLiveActivityTitle,
        subtitle: LocalizedStrings.Home.guideLiveActivitySubtitle,
        screenshot: ResourceKitAsset.guideHomeLiveActivity.swiftUIImage
      ),
      .init(
        id: 3,
        title: LocalizedStrings.Home.guideProFeaturesTitle,
        subtitle: LocalizedStrings.Home.guideProFeaturesSubtitle,
        screenshot: ResourceKitAsset.guideHomeProFeatures.swiftUIImage,
        zoomScale: 1.2,
        zoomAnchor: .center
      ),
    ]
  }

  /// 캘린더 탭 온보딩 가이드 아이템 (CalendarRootView, GuideListView 공유)
  public static var calendarGuideItems: [Item] {
    [
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
    ]
  }
}

// MARK: - Item

extension FeatureGuideView {
  public struct Item: Identifiable, Hashable {
    public var id: Int
    public var title: String
    public var subtitle: String
    public var screenshot: Image?
    public var zoomScale: CGFloat
    public var zoomAnchor: UnitPoint
    /// 원본 이미지 크기 (deviceCornerRadius 계산용)
    public var screenshotImageSize: CGSize?

    public init(
      id: Int,
      title: String,
      subtitle: String,
      screenshot: Image? = nil,
      zoomScale: CGFloat = 1,
      zoomAnchor: UnitPoint = .center,
      screenshotImageSize: CGSize? = nil
    ) {
      self.id = id
      self.title = title
      self.subtitle = subtitle
      self.screenshot = screenshot
      self.zoomScale = zoomScale
      self.zoomAnchor = zoomAnchor
      self.screenshotImageSize = screenshotImageSize
    }

    // Hashable conformance for Image (non-equatable)
    public static func == (lhs: Item, rhs: Item) -> Bool {
      lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(id)
    }
  }
}

// MARK: - Preview

#Preview {
  FeatureGuideView(
    items: [
      .init(
        id: 0,
        title: "캘린더 모드 전환",
        subtitle: "주간, 월간 뷰를 자유롭게 전환하며 일정을 확인하세요.",
        screenshot: nil
      ),
      .init(
        id: 1,
        title: "주간 타임라인",
        subtitle: "시간대별로 일정을 한눈에 파악할 수 있어요.",
        screenshot: nil
      ),
    ],
    onComplete: {}
  )
}
