import SwiftUI

struct PromiseTimelineView: View {
  let promisesState: LoadingState<[PromiseItem]>
  let selectedFilter: StatusFilter
  let onAccept: (String) -> Void
  let acceptLoading: Bool
  let onReject: (String) -> Void
  let rejectLoading: Bool

  private var promises: [PromiseItem] {
    promisesState.value ?? []
  }

  private var filteredPromises: [PromiseItem] {
    switch selectedFilter {
    case .all:
      return promises
    case .needResponse:
      return promises.filter { $0.status == .needResponse }
    case .confirmed:
      return promises.filter { $0.status == .confirmed }
    }
  }

  private var groupedPromises: [(date: String, promises: [PromiseItem])] {
    let grouped = Dictionary(grouping: filteredPromises, by: { $0.date })

    // Sort by date priority: 오늘, 내일, then others
    return grouped.sorted { lhs, rhs in
      let priorityOrder = ["오늘": 0, "내일": 1]
      let lhsPriority = priorityOrder[lhs.key] ?? 2
      let rhsPriority = priorityOrder[rhs.key] ?? 2

      if lhsPriority != rhsPriority {
        return lhsPriority < rhsPriority
      }
      return lhs.key < rhs.key
    }.map { (date: $0.key, promises: $0.value) }
  }

  var body: some View {
    Group {
      switch promisesState {
      case .idle, .loading:
        loadingView

      case .loaded:
        if groupedPromises.isEmpty {
          EmptyPromisesView(filter: selectedFilter)
            .padding(.top, 60)
        } else {
          promisesListView
        }

      case .failed(let error):
        ErrorView(message: error.localizedDescription)
          .padding(.top, 60)
      }
    }
  }

  private var loadingView: some View {
    LazyVStack(spacing: 16) {
      ForEach(0..<3, id: \.self) { _ in
        PromiseCardSkeleton()
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 20)
    .padding(.bottom, 40)
  }

  private var promisesListView: some View {
    LazyVStack(alignment: .leading, spacing: 24) {
      ForEach(groupedPromises, id: \.date) { section in
        VStack(alignment: .leading, spacing: 12) {
          // Date Header
          HStack {
            Text(section.date)
              .font(.system(size: 20, weight: .bold))
              .foregroundColor(.primary)

            Rectangle()
              .fill(Color(.systemGray4))
              .frame(height: 1)
          }

          // Promise Cards
          ForEach(section.promises) { promise in
            PromiseCard(
              promise: promise,
              onAccept: { onAccept(promise.id) },
              acceptLoading: acceptLoading,
              onReject: { onReject(promise.id) },
              rejectLoading: rejectLoading
            )
          }
        }
      }
    }
    .padding(.horizontal, 16)
    .padding(.top, 20)
    .padding(.bottom, 40)
  }
}

private struct ErrorView: View {
  let message: String

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "exclamationmark.triangle")
        .font(.system(size: 60))
        .foregroundColor(.orange)

      Text("오류가 발생했습니다")
        .font(.system(size: 18, weight: .semibold))
        .foregroundColor(.primary)

      Text(message)
        .font(.system(size: 14))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 32)
  }
}

private struct EmptyPromisesView: View {
  let filter: StatusFilter

  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: iconName)
        .font(.system(size: 60))
        .foregroundColor(.secondary)

      Text(message)
        .font(.system(size: 16))
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }
    .frame(maxWidth: .infinity)
  }

  private var iconName: String {
    switch filter {
    case .all:
      return "calendar.badge.clock"
    case .needResponse:
      return "exclamationmark.bubble"
    case .confirmed:
      return "checkmark.circle"
    }
  }

  private var message: String {
    switch filter {
    case .all:
      return "아직 약속이 없어요\n새로운 약속을 만들어보세요"
    case .needResponse:
      return "답변이 필요한 약속이 없어요"
    case .confirmed:
      return "확정된 약속이 없어요"
    }
  }
}

// MARK: - Preview

//#Preview {
//  VStack(spacing: 0) {
//    PromiseTimelineView(
//      promisesState: .loaded(PromiseItem.exampleArr),
//      selectedFilter: .all,
//      onAccept: { _ in },
//      onReject: { _ in },
//      
//    )
//  }
//  .background(Color(.systemGray6))
//}
//
//#Preview("Loading State") {
//  PromiseTimelineView(
//    promisesState: .loading,
//    selectedFilter: .all,
//    onAccept: { _ in },
//    onReject: { _ in },
//    buttonDisabled: false
//  )
//  .background(Color(.systemGray6))
//}
//
//#Preview("Empty State") {
//  PromiseTimelineView(
//    promisesState: .loaded([]),
//    selectedFilter: .all,
//    onAccept: { _ in },
//    onReject: { _ in },
//    buttonDisabled: false
//  )
//  .background(Color(.systemGray6))
//}
//
//#Preview("Error State") {
//  PromiseTimelineView(
//    promisesState: .failed(NSError(domain: "PromiseError", code: -1, userInfo: [NSLocalizedDescriptionKey: "약속 목록을 불러오는데 실패했습니다."])),
//    selectedFilter: .all,
//    onAccept: { _ in },
//    onReject: { _ in },
//    buttonDisabled: false
//  )
//  .background(Color(.systemGray6))
//}
