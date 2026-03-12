import SwiftUI

public struct FlowLayout: Layout {
  public var spacing: CGFloat

  public init(spacing: CGFloat = 8) {
    self.spacing = spacing
  }

  public struct CacheData {
    let sizes: [CGSize]
    var rows: [[Int]] = []
    var rowHeights: [CGFloat] = []
  }

  public func makeCache(subviews: Subviews) -> CacheData {
    let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
    return CacheData(sizes: sizes)
  }

  public func sizeThatFits(
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout CacheData
  ) -> CGSize {
    let maxWidth = proposal.width ?? .infinity
    var rows: [[Int]] = [[]]
    var currentWidth: CGFloat = 0

    for index in cache.sizes.indices {
      let size = cache.sizes[index]
      if currentWidth + size.width > maxWidth, let lastRow = rows.last, !lastRow.isEmpty {
        rows.append([])
        currentWidth = 0
      }
      rows[rows.count - 1].append(index)
      currentWidth += size.width + spacing
    }
    cache.rows = rows
    cache.rowHeights = rows.map { rowIndices in
      rowIndices.map { cache.sizes[$0].height }.max() ?? 0
    }

    var height: CGFloat = 0
    for (index, rowHeight) in cache.rowHeights.enumerated() {
      height += rowHeight
      if index < cache.rowHeights.count - 1 {
        height += spacing
      }
    }
    return CGSize(width: proposal.width ?? 0, height: height)
  }

  public func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout CacheData
  ) {
    var y = bounds.minY
    for (rowIndex, rowIndices) in cache.rows.enumerated() {
      let rowHeight = cache.rowHeights[rowIndex]
      var x = bounds.minX
      for index in rowIndices {
        let subview = subviews[index]
        let size = cache.sizes[index]
        subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
        x += size.width + spacing
      }
      y += rowHeight + spacing
    }
  }
}
