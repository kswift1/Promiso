//#if canImport(UIKit)
//import UIKit
//#endif
import SwiftUI

// MARK: - Category Filter Item Protocol

/// 카테고리 필터 아이템 프로토콜
public protocol CategoryFilterItem: Hashable, CaseIterable {
  var title: String { get }
  var icon: String { get }
  var selectedColor: Color { get }
  /// 이 아이템 앞에 구분선을 표시할지 여부
  var hasSeparatorBefore: Bool { get }
}

public extension CategoryFilterItem {
  var hasSeparatorBefore: Bool { false }
}

// MARK: - Category Filter Bar

/// Apple Mail 스타일의 카테고리 필터 바
///
/// - 선택된 필터: 컬러 배경 + 아이콘 + 텍스트
/// - 미선택 필터: 회색 배경 + 아이콘만
/// - 수평 스크롤 가능
///
/// ```swift
/// enum Filter: CategoryFilterItem {
///   case needResponse, confirmed, all
///
///   var title: String { ... }
///   var icon: String { ... }
///   var selectedColor: Color { ... }
/// }
///
/// CategoryFilterBar(
///   selection: $selectedFilter
/// )
/// ```
public struct CategoryFilterBar<Item: CategoryFilterItem>: View {
  @Binding private var selection: Item

  public init(selection: Binding<Item>) {
    self._selection = selection
  }

  public var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(Array(Item.allCases), id: \.self) { item in
          if item.hasSeparatorBefore {
            separator
          }
          filterPill(for: item)
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 4)
    }
  }

  private var separator: some View {
    Text("|")
      .font(.system(size: 16, weight: .light))
      .foregroundStyle(.tertiary)
      .padding(.horizontal, 4)
  }

  @ViewBuilder
  private func filterPill(for item: Item) -> some View {
    let isSelected = selection == item

    Button {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        selection = item
      }
    } label: {
      HStack(spacing: 6) {
        Image(systemName: item.icon)
          .font(.system(size: 14, weight: .medium))

        if isSelected {
          Text(item.title)
            .font(.system(size: 14, weight: .semibold))
        }
      }
      .foregroundStyle(isSelected ? .white : .secondary)
      .padding(.horizontal, isSelected ? 14 : 12)
      .padding(.vertical, 10)
      .background(
        Capsule()
          .fill(isSelected ? item.selectedColor : Color(UIColor.systemGray5))
      )
    }
    .buttonStyle(.plain)
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isSelected)
  }
}

// MARK: - Previews

#Preview("기본") {
  enum SampleFilter: String, CategoryFilterItem, CaseIterable {
    case priority = "우선 순위"
    case transactions = "거래 관련"
    case updates = "업데이트"
    case promotions = "프로모션"
    case all = "모든 메일"

    var title: String { rawValue }

    var icon: String {
      switch self {
      case .priority: return "person.fill"
      case .transactions: return "cart.fill"
      case .updates: return "text.bubble.fill"
      case .promotions: return "megaphone.fill"
      case .all: return "tray.fill"
      }
    }

    var selectedColor: Color {
      switch self {
      case .priority: return .blue
      case .transactions: return .green
      case .updates: return .orange
      case .promotions: return .purple
      case .all: return Color(UIColor.systemGray)
      }
    }
  }

  struct PreviewWrapper: View {
    @State private var selection: SampleFilter = .priority

    var body: some View {
      VStack(spacing: 24) {
        CategoryFilterBar(selection: $selection)

        Text("선택: \(selection.title)")
          .foregroundStyle(.secondary)

        Spacer()
      }
      .padding(.top, 20)
    }
  }

  return PreviewWrapper()
}

#Preview("약속 필터") {
  enum PromiseFilter: String, CategoryFilterItem, CaseIterable {
    case needResponse = "응답 필요"
    case responded = "응답 완료"
    case confirmed = "확정"
    case all = "전체"

    var title: String { rawValue }

    var icon: String {
      switch self {
      case .needResponse: return "envelope.badge"
      case .responded: return "clock.badge.checkmark"
      case .confirmed: return "checkmark.circle.fill"
      case .all: return "list.bullet"
      }
    }

    var selectedColor: Color {
      switch self {
      case .needResponse: return .orange
      case .responded: return .blue
      case .confirmed: return .green
      case .all: return Color(UIColor.systemGray)
      }
    }
  }

  struct PreviewWrapper: View {
    @State private var selection: PromiseFilter = .all

    var body: some View {
      VStack(spacing: 24) {
        CategoryFilterBar(selection: $selection)

        Text("선택: \(selection.title)")
          .foregroundStyle(.secondary)

        Spacer()
      }
      .padding(.top, 20)
    }
  }

  return PreviewWrapper()
}

#Preview("다크 모드") {
  enum SampleFilter: String, CategoryFilterItem, CaseIterable {
    case priority = "우선 순위"
    case transactions = "거래 관련"
    case all = "모든 메일"

    var title: String { rawValue }

    var icon: String {
      switch self {
      case .priority: return "person.fill"
      case .transactions: return "cart.fill"
      case .all: return "tray.fill"
      }
    }

    var selectedColor: Color {
      switch self {
      case .priority: return .blue
      case .transactions: return .green
      case .all: return Color(UIColor.systemGray)
      }
    }
  }

  struct PreviewWrapper: View {
    @State private var selection: SampleFilter = .transactions

    var body: some View {
      VStack(spacing: 24) {
        CategoryFilterBar(selection: $selection)

        Text("선택: \(selection.title)")
          .foregroundStyle(.secondary)

        Spacer()
      }
      .padding(.top, 20)
      .background(Color(UIColor.systemBackground))
    }
  }

  return PreviewWrapper()
    .preferredColorScheme(.dark)
}
