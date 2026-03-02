import Foundation

// MARK: - Timeline Overlap Layout Engine

/// 타임라인 이벤트 겹침 레이아웃 엔진
/// 이벤트 간 시간 겹침을 픽셀 기준으로 판단하고 렌더 전략을 결정한다.
public enum TimelineOverlapLayout {

  // MARK: - Constants

  /// iOS HIG 최소 터치 타겟 = 44pt
  /// 타이틀(15pt) + 서브타이틀(11pt) + 패딩(18pt) = 최소 가독 높이
  public static let minReadableHeight: CGFloat = 44

  /// 카드 간 수직 gap (같은 column 내)
  public static let cardGap: CGFloat = 2

  /// Column Split 시 column 간 수평 gap
  public static let columnGap: CGFloat = 3

  /// 최대 column 수. 초과 시 마지막 column에 "+N" 처리
  public static let maxColumns: Int = 3

  // MARK: - OverlapSeverity

  /// 겹침 심각도
  public enum OverlapSeverity: Equatable, Sendable {
    /// 겹침 없음
    case none
    /// 시간은 겹치지만 카드 높이가 충분 → z-index 오버레이
    case layerable
    /// 카드가 44pt 미만으로 찌그러짐 → Column Split
    case colliding
  }

  // MARK: - Layout Result

  /// 레이아웃 계산 결과 (각 아이템별)
  public struct LayoutResult: Equatable, Sendable {
    /// 아이템 인덱스 (원본 배열에서의 위치)
    public let index: Int
    /// 할당된 column 인덱스 (0-based)
    public let columnIndex: Int
    /// 해당 그룹의 총 column 수
    public let columnCount: Int
    /// z-index (높을수록 앞에 렌더)
    public let zIndex: Int
    /// 겹침 심각도
    public let severity: OverlapSeverity
    /// colliding 그룹에서 숨겨진 이벤트 수 (maxColumns 초과분)
    public let overflowCount: Int

    public init(
      index: Int,
      columnIndex: Int,
      columnCount: Int,
      zIndex: Int,
      severity: OverlapSeverity,
      overflowCount: Int = 0
    ) {
      self.index = index
      self.columnIndex = columnIndex
      self.columnCount = columnCount
      self.zIndex = zIndex
      self.severity = severity
      self.overflowCount = overflowCount
    }
  }

  // MARK: - Severity Judgment

  /// 두 이벤트의 겹침 심각도 판단 (모든 판단은 픽셀 기준)
  public static func severity(
    aStartMinutes: CGFloat,
    aDurationMinutes: CGFloat,
    bStartMinutes: CGFloat,
    bDurationMinutes: CGFloat,
    pixelsPerMinute: CGFloat
  ) -> OverlapSeverity {
    // Step 1: 시간 겹침 확인
    let aEnd = aStartMinutes + aDurationMinutes
    let bEnd = bStartMinutes + bDurationMinutes
    let overlapStart = max(aStartMinutes, bStartMinutes)
    let overlapEnd = min(aEnd, bEnd)
    guard overlapStart < overlapEnd else { return .none }

    // Step 2: 시작 시간 픽셀 거리
    let startDiffPx = abs(aStartMinutes - bStartMinutes) * pixelsPerMinute

    // Step 3: 각 이벤트 렌더 높이
    let aHeight = aDurationMinutes * pixelsPerMinute
    let bHeight = bDurationMinutes * pixelsPerMinute

    // Step 4: colliding 조건
    let wouldCollide = startDiffPx < minReadableHeight
      || aHeight < minReadableHeight
      || bHeight < minReadableHeight

    return wouldCollide ? .colliding : .layerable
  }

  // MARK: - Layout Computation

  /// 이벤트 배열의 레이아웃 계산
  /// - Parameters:
  ///   - startMinutes: 각 이벤트의 시작 시각 (자정 기준 분)
  ///   - durationMinutes: 각 이벤트의 지속 시간 (분)
  ///   - pixelsPerMinute: 1분당 픽셀 수
  /// - Returns: 각 아이템의 레이아웃 결과 배열
  public static func computeLayout(
    startMinutes: [CGFloat],
    durationMinutes: [CGFloat],
    pixelsPerMinute: CGFloat
  ) -> [LayoutResult] {
    let count = startMinutes.count
    guard count > 0 else { return [] }

    if count == 1 {
      return [LayoutResult(
        index: 0, columnIndex: 0, columnCount: 1,
        zIndex: 0, severity: .none
      )]
    }

    // Step 1: Pairwise severity 계산 + adjacency list 구성
    var adjacency = Array(repeating: [Int](), count: count)
    var pairSeverity = [[OverlapSeverity]](
      repeating: [OverlapSeverity](repeating: .none, count: count),
      count: count
    )

    for i in 0..<count {
      for j in (i + 1)..<count {
        let sev = severity(
          aStartMinutes: startMinutes[i],
          aDurationMinutes: durationMinutes[i],
          bStartMinutes: startMinutes[j],
          bDurationMinutes: durationMinutes[j],
          pixelsPerMinute: pixelsPerMinute
        )
        pairSeverity[i][j] = sev
        pairSeverity[j][i] = sev
        if sev != .none {
          adjacency[i].append(j)
          adjacency[j].append(i)
        }
      }
    }

    // Step 2: 연결된 컴포넌트 추출 (BFS)
    var visited = Array(repeating: false, count: count)
    var components = [[Int]]()

    for i in 0..<count {
      guard !visited[i] else { continue }
      var queue = [i]
      var component = [Int]()
      visited[i] = true
      while !queue.isEmpty {
        let node = queue.removeFirst()
        component.append(node)
        for neighbor in adjacency[node] where !visited[neighbor] {
          visited[neighbor] = true
          queue.append(neighbor)
        }
      }
      components.append(component)
    }

    // Step 3: 각 컴포넌트별 레이아웃 결정
    var results = [LayoutResult?](repeating: nil, count: count)

    for component in components {
      if component.count == 1 {
        let idx = component[0]
        results[idx] = LayoutResult(
          index: idx, columnIndex: 0, columnCount: 1,
          zIndex: 0, severity: .none
        )
        continue
      }

      // 컴포넌트 내 최대 severity 결정
      var maxSeverity: OverlapSeverity = .layerable
      for i in 0..<component.count {
        for j in (i + 1)..<component.count {
          if pairSeverity[component[i]][component[j]] == .colliding {
            maxSeverity = .colliding
            break
          }
        }
        if maxSeverity == .colliding { break }
      }

      // startTime 오름차순, 동일이면 duration 내림차순
      let sorted = component.sorted { a, b in
        if startMinutes[a] != startMinutes[b] {
          return startMinutes[a] < startMinutes[b]
        }
        return durationMinutes[a] > durationMinutes[b]
      }

      if maxSeverity == .layerable {
        // Layerable: 전체 너비, z-index만 다르게
        // 짧은 이벤트(duration 작은)가 높은 z-index
        let byDuration = sorted.sorted { a, b in
          durationMinutes[a] > durationMinutes[b]
        }
        for (zIdx, itemIdx) in byDuration.enumerated() {
          results[itemIdx] = LayoutResult(
            index: itemIdx, columnIndex: 0, columnCount: 1,
            zIndex: zIdx, severity: .layerable
          )
        }
      } else {
        // Colliding: Column Split
        let visibleCount = min(sorted.count, maxColumns)
        let overflowCount = max(0, sorted.count - maxColumns)

        for (colIdx, itemIdx) in sorted.prefix(maxColumns).enumerated() {
          let overflow = (colIdx == visibleCount - 1) ? overflowCount : 0
          results[itemIdx] = LayoutResult(
            index: itemIdx, columnIndex: colIdx,
            columnCount: visibleCount, zIndex: 0,
            severity: .colliding, overflowCount: overflow
          )
        }

        // 숨겨진 이벤트 (maxColumns 초과)
        for itemIdx in sorted.dropFirst(maxColumns) {
          results[itemIdx] = LayoutResult(
            index: itemIdx, columnIndex: -1,
            columnCount: visibleCount, zIndex: -1,
            severity: .colliding, overflowCount: 0
          )
        }
      }
    }

    return (0..<count).map { results[$0]! }
  }
}
