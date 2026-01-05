import SwiftUI

struct PromiseTimelineView: View {
  let promisesState: LoadingState<[PromiseItem]>
  let selectedFilter: StatusFilter
  let responseStatuses: [String: PromiseAttendanceStatus]
  let onAccept: (String) -> Void
  let onReject: (String) -> Void
  let onDelete: ((String) -> Void)?
  let onChangeResponse: ((String, PromiseAttendanceStatus) -> Void)?
  
  private var promises: [PromiseItem] {
    promisesState.value ?? []
  }
  
  private var filteredPromises: [PromiseItem] {
    switch selectedFilter {
    case .all:
      return promises
    case .needResponse:
      return promises.filter {
        responseStatuses[$0.id] == nil
      }
    case .responded:
      return promises.filter {
        responseStatuses[$0.id] != nil
      }
    }
  }
  
  private var groupedPromises: [(date: String, promises: [PromiseItem])] {
    let grouped = Dictionary(grouping: filteredPromises, by: { $0.date })
    
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
  
  private var animationKey: [String] {
    groupedPromises.flatMap { section in
      [section.date] + section.promises.map(\.id)
    }
  }
  
  var body: some View {
    switch promisesState {
    case .idle, .loading:
      loadingView
      
    case .loaded:
      if groupedPromises.isEmpty {
        emptyStateScrollView
      } else {
        promisesListView
      }
      
    case .failed(let error):
      errorStateScrollView(error: error)
    }
  }
  
  private var emptyStateScrollView: some View {
    ScrollView {
      EmptyPromisesView(filter: selectedFilter)
        .padding(.top, 60)
    }
  }
  
  private func errorStateScrollView(error: Error) -> some View {
    ScrollView {
      ErrorView(message: error.localizedDescription)
        .padding(.top, 60)
    }
  }
  
  private var loadingView: some View {
    ScrollView {
      LazyVStack(spacing: 16) {
        ForEach(0..<3, id: \.self) { _ in
          PromiseCardSkeleton()
        }
      }
      .padding(.horizontal, 16)
      .padding(.top, 20)
      .padding(.bottom, 40)
    }
  }
  
  private var promisesListView: some View {
    List {
      ForEach(groupedPromises, id: \.date) { section in
        Section {
          ForEach(section.promises) { promise in
            PromiseRow(
              promise: promise,
              responseStatus: responseStatuses[promise.id],
              onAccept: onAccept,
              onReject: onReject,
              onDelete: onDelete,
              onChangeResponse: onChangeResponse
            )
          }
        } header: {
          sectionHeader(for: section.date)
        }
        .listSectionSeparator(.hidden)
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .animation(.spring(response: 0.45, dampingFraction: 0.85), value: animationKey)
  }
  
  @ViewBuilder
  private func sectionHeader(for date: String) -> some View {
    HStack {
      Text(date)
        .font(.system(size: 20, weight: .bold))
        .foregroundColor(.primary)
        .textCase(nil)
      
      Rectangle()
        .fill(Color(.systemGray4))
        .frame(height: 1)
    }
    .padding(.horizontal, 16)
    .padding(.top, date == groupedPromises.first?.date ? 12 : 24)
    .padding(.bottom, 12)
  }
}

private struct PromiseRow: View {
  let promise: PromiseItem
  let responseStatus: PromiseAttendanceStatus?
  let onAccept: (String) -> Void
  let onReject: (String) -> Void
  let onDelete: ((String) -> Void)?
  let onChangeResponse: ((String, PromiseAttendanceStatus) -> Void)?
  
  @State private var shakeOffset: CGFloat = 0
  @State private var hasShaken = false
  
  private var needsResponse: Bool {
    promise.status == .needResponse && responseStatus == nil
  }
  
  var body: some View {
    
    ZStack {
      // 배경 힌트 레이어 - 리스트 행 전체 영역
      swipeHintBackground
      
      // 실제 카드
      PromiseCard(
        promise: promise,
        responseStatus: responseStatus,
        onAccept: { onAccept(promise.id) },
        onReject: { onReject(promise.id) },
        onDelete: onDelete.map { delete in { delete(promise.id) } },
        onChangeResponse: onChangeResponse.map { change in { status in change(promise.id, status) } }
      )
      .offset(x: shakeOffset)
    }
    .listRowBackground(Color.clear)
    .listRowSeparator(.hidden)
    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
    .swipeActions(edge: .leading, allowsFullSwipe: true) {
      if let onChangeResponse = onChangeResponse {
        Button(action: { onChangeResponse(promise.id, .accepted) }) {
          Label("수락", systemImage: "checkmark.circle.fill")
        }
        .tint(.green)
      }
    }
    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
      if let responseStatus = responseStatus, let onChangeResponse = onChangeResponse {
        switch responseStatus {
        case .accepted:
          Button(action: { onChangeResponse(promise.id, .declined) }) {
            Label("거절로 변경", systemImage: "xmark.circle.fill")
          }
          .tint(.orange)
        case .declined:
          Button(action: { onChangeResponse(promise.id, .accepted) }) {
            Label("수락", systemImage: "checkmark.circle.fill")
          }
          .tint(.green)
        case .tentative:
          Button(action: { onChangeResponse(promise.id, .accepted) }) {
            Label("수락", systemImage: "checkmark.circle.fill")
          }
          .tint(.green)
          Button(action: { onChangeResponse(promise.id, .declined) }) {
            Label("거절", systemImage: "xmark.circle.fill")
          }
          .tint(.red)
        }
      }
      if promise.isHost, let onDelete = onDelete {
        Button(role: .destructive, action: { onDelete(promise.id) }) {
          Label("삭제", systemImage: "trash.fill")
        }
      }
    }
    .transition(
      .asymmetric(
        insertion: .move(edge: .top).combined(with: .opacity),
        removal: .opacity
      )
    )
    .onAppear {
      //      guard needsResponse && !hasShaken else { return }
      //      hasShaken = true
      
      // 0.5초 딜레이 후 흔들림 시작
//      DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
//        performShakeAnimation()
//      }
    }
  }
  
  private func performShakeAnimation() {
    let hintOffset: CGFloat = 70
    
    // 1단계: 오른쪽으로 (수락 힌트)
    withAnimation(.easeInOut(duration: 0.8)) {
      shakeOffset = hintOffset
    }
    
    // 2단계: 중앙으로
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
      withAnimation(.easeInOut(duration: 0.6)) {
        shakeOffset = 0
      }
    }
    
    // 3단계: 왼쪽으로 (거절/삭제 힌트)
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
      withAnimation(.easeInOut(duration: 0.8)) {
        shakeOffset = -hintOffset
      }
    }
    
    // 4단계: 중앙으로 복귀
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
      withAnimation(.easeInOut(duration: 0.6)) {
        shakeOffset = 0
      }
    }
  }
  
  @ViewBuilder
  private var swipeHintBackground: some View {
    ZStack {
      // Leading (수락)
      HStack {
        let progress = clamp((shakeOffset - 8) / 40) // 0~1
        swipeHintBubble(
          title: "수락",
          systemImage: "checkmark.circle.fill",
          fillColor: .green,
          progress: progress
        )
        .opacity(progress)
        .scaleEffect(0.3 + progress * 0.7)      // ✅ 0.3 → 1.0
        .offset(x: -4)                         // ✅ 더 바깥쪽(왼쪽)으로
        
        Spacer()
      }
      .padding(.leading, 0)
      
      // Trailing (거절/삭제)
      HStack {
        Spacer()
        
        let progress = clamp((abs(shakeOffset) - 8) / 40) // 0~1
        swipeHintBubble(
          title: promise.isHost ? "삭제" : "거절",
          systemImage: promise.isHost ? "trash.fill" : "xmark",
          fillColor: promise.isHost ? .red : .orange,
          progress: progress
        )
        .opacity(progress)
        .scaleEffect(0.3 + progress * 0.7)      // ✅ 0.3 → 1.0
        .offset(x: 4)                          // ✅ 더 바깥쪽(오른쪽)으로
      }
      .padding(.trailing, 0)
    }
    .frame(maxWidth: .infinity)
    .frame(height: 100) // PromiseCard 높이랑 맞추기 (필요하면 92~110 사이 조절)
  }
  
  private func swipeHintBubble(
    title: String,
    systemImage: String,
    fillColor: Color,
    progress: CGFloat
  ) -> some View {
    VStack(spacing: 8) {
      ZStack {
        Circle()
          .fill(fillColor)
          .frame(width: 48, height: 48)
        
        Image(systemName: systemImage)
          .font(.system(size: 15, weight: .bold))
          .tint(.white)
          .foregroundStyle(.white)
      }
      
      Text(title)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
    }
  }
  
  private func clamp(_ value: CGFloat) -> CGFloat {
    min(max(value, 0), 1)
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
    case .responded:
      return "checkmark.circle"
    }
  }

  private var message: String {
    switch filter {
    case .all:
      return "아직 약속이 없어요\n새로운 약속을 만들어보세요"
    case .needResponse:
      return "답변이 필요한 약속이 없어요"
    case .responded:
      return "응답한 약속이 없어요"
    }
  }
}
