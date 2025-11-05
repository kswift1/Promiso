import CoreInfrastructure

// MARK: - Feature Namespace

public enum SideDrawer {}

// MARK: - Reducer

@Reducer
public struct SideDrawerFeature {
  @Dependency(\.hapticFeedback) var hapticFeedback

  @ObservableState
  public struct State: Equatable {
    /// 드래그 최대값
    public let maxDragOffset: CGFloat
    /// 사이드 드로어 표시 여부
    public var showDrawer: Bool = false
    /// 드래그 오프셋
    public var dragOffset: CGFloat = 0
    /// 오버레이 투명도 (드래그 위치에 따라 동적 변경)
    public var overlayOpacity: Double = 0.0

    public init(maxDragOffset: CGFloat) {
      self.maxDragOffset = maxDragOffset
    }
  }

  public enum Action: Equatable, Sendable {
    /// 드로어 토글
    case toggle
    /// 드로어 닫기
    case close
    /// 드래그 변경
    case dragChanged(CGFloat)
    /// 드래그 종료
    case dragEnded
  }

  public var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .toggle:
        state.showDrawer.toggle()
        state.overlayOpacity = state.showDrawer ? 0.1 : 0.0
        return .run { _ in
          await hapticFeedback.medium()
        }

      case .close:
        state.showDrawer = false
        state.dragOffset = 0
        state.overlayOpacity = 0.0
        return .run { _ in
          await hapticFeedback.medium()
        }

      case .dragChanged(let offset):
        state.dragOffset = offset
        // 드래그 위치에 따라 opacity 계산
        if state.showDrawer {
          // 드로어가 열려있을 때: 닫히는 방향으로 드래그하면 opacity 감소
          let progress = max(0, min(1, (state.maxDragOffset + offset) / state.maxDragOffset))
          state.overlayOpacity = 0.1 * progress
        } else {
          // 드로어가 닫혀있을 때: 열리는 방향으로 드래그하면 opacity 증가
          let progress = max(0, min(1, offset / state.maxDragOffset))
          state.overlayOpacity = 0.1 * progress
        }
        return .none

      case .dragEnded:
        let threshold: CGFloat = state.maxDragOffset * 0.4
        var shouldProvideHaptic = false

        if state.showDrawer {
          // 드로어가 열려있을 때: 음수 오프셋이 임계값보다 크면 닫기
          if state.dragOffset < -threshold {
            state.showDrawer = false
            state.overlayOpacity = 0.0
            shouldProvideHaptic = true
          } else {
            state.overlayOpacity = 0.1
          }
        } else {
          // 드로어가 닫혀있을 때: 양수 오프셋이 임계값보다 크면 열기
          if state.dragOffset > threshold {
            state.showDrawer = true
            state.overlayOpacity = 0.1
            shouldProvideHaptic = true
          } else {
            state.overlayOpacity = 0.0
          }
        }
        state.dragOffset = 0

        if shouldProvideHaptic {
          return .run { _ in
            await hapticFeedback.medium()
          }
        } else {
          return .none
        }
      }
    }
  }
}
