import SwiftUI

struct StatusFilterView: View {
  @Binding var selectedFilter: StatusFilter

  var body: some View {
    Picker("Status Filter", selection: $selectedFilter) {
      ForEach(StatusFilter.allCases, id: \.self) { filter in
        HStack(spacing: 4) {
          Text(filter.rawValue)
        }
        .tag(filter)
      }
    }
    .pickerStyle(.segmented)
    .padding(.horizontal, 16)
    .padding(.vertical, 8)
  }
}

// MARK: - Preview

#Preview {
  struct PreviewWrapper: View {
    @State private var filter: StatusFilter = .needResponse

    var body: some View {
      VStack(spacing: 20) {
        StatusFilterView(selectedFilter: $filter)
        
        Text("Selected: \(filter.rawValue)")
          .font(.headline)
      }
      .padding()
    }
  }

  return PreviewWrapper()
}
