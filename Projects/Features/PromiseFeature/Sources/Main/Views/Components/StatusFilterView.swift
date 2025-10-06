import SwiftUI

struct StatusFilterView: View {
  @Binding var selectedFilter: StatusFilter

  var body: some View {
    HStack(spacing: 0) {
      ForEach(StatusFilter.allCases, id: \.self) { filter in
        FilterButton(
          filter: filter,
          isSelected: selectedFilter == filter,
          action: { selectedFilter = filter }
        )
      }

      Spacer()
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
    .background(Color(.systemGray6).opacity(0.5))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

private struct FilterButton: View {
  let filter: StatusFilter
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if filter != .all {
          Image(systemName: iconName)
            .font(.system(size: 13, weight: .semibold))
        }

        Text(filter.rawValue)
          .font(.system(size: 14, weight: isSelected ? .bold : .medium))
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .background(
        Group {
          if isSelected {
            RoundedRectangle(cornerRadius: 8)
              .fill(Color(.systemBackground))
              .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
          }
        }
      )
      .foregroundColor(foregroundColor)
    }
    .buttonStyle(PlainButtonStyle())
  }

  private var iconName: String {
    switch filter {
    case .needResponse:
      return "exclamationmark.circle.fill"
    case .confirmed:
      return "checkmark.circle.fill"
    default:
      return ""
    }
  }

  private var foregroundColor: Color {
    if !isSelected {
      return Color(.systemGray)
    }

    switch filter {
    case .all:
      return .primary
    case .needResponse:
      return .orange
    case .confirmed:
      return .green
    }
  }
}

// MARK: - Preview

#Preview {
  struct PreviewWrapper: View {
    @State private var filter: StatusFilter = .all

    var body: some View {
      VStack(spacing: 20) {
        StatusFilterView(selectedFilter: $filter)
        Text("Selected: \(filter.rawValue)")
      }
      .padding()
    }
  }

  return PreviewWrapper()
}
