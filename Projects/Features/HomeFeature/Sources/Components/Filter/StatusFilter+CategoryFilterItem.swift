import SwiftUI
import PromisoShared

// MARK: - StatusFilter + CategoryFilterItem

extension StatusFilter: CategoryFilterItem {
  public var title: String {
    rawValue
  }

  public var icon: String {
    switch self {
    case .all: return "tray.fill"
    case .needResponse: return "envelope.badge"
    case .confirmed: return "checkmark.circle.fill"
    case .inProgress: return "clock.badge"
    }
  }

  public var selectedColor: Color {
    switch self {
    case .all: return .blue
    case .needResponse: return .orange
    case .confirmed: return .green
    case .inProgress: return .blue
    }
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 20) {
    CategoryFilterBar<StatusFilter>(
      selection: .constant(.all),
      counts: [.all: 10, .needResponse: 5, .confirmed: 3, .inProgress: 2]
    )

    CategoryFilterBar<StatusFilter>(
      selection: .constant(.needResponse),
      counts: [.all: 10, .needResponse: 5, .confirmed: 3, .inProgress: 2]
    )

    CategoryFilterBar<StatusFilter>(
      selection: .constant(.confirmed),
      counts: [.all: 10, .needResponse: 5, .confirmed: 3, .inProgress: 2]
    )
  }
  .padding()
  .auroraBackground()
}
