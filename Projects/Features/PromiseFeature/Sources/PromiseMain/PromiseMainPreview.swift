import SwiftUI

// MARK: - Preview

#Preview {
  PromiseMain.RootView(
    store: Store(
      initialState: PromiseMain.Feature.State.preview
    ) {
      PromiseMain.Feature()
    }
  )
}

extension PromiseMain.Feature.State {
  // MARK: - Preview Helper
  public static var preview: Self {
    var state = Self(currentUser: .init(id: "", email: "", nickname: ""))
//    state.currentGroup = CurrentGroup(
//      id: "1",
//      name: "지민과 나",
//      emoji: "👥",
//      activeCount: 2,
//      pendingCount: 1,
//      role: .admin,
//      notifications: true,
//      members: [
//        GroupMember(id: "1", name: "성원", emoji: "🧑‍💻", role: .admin, isMe: true),
//        GroupMember(id: "2", name: "지민", emoji: "👩‍🎨", role: .member, isMe: false),
//      ]
//    )
    state.currentGroup = .init(
      id: "1",
      emoji: "👥",
      title: "지민과 나",
      memberCount: 2
    )
    state.promisesState = .loaded([
      PromiseItem(
        id: "1",
        title: "카페 데이트",
        emoji: "☕",
        time: "오후 2:00",
        date: "오늘",
        location: "스타벅스 강남점",
        distance: "1.2km",
        with: "지민",
        status: .needResponse,
        responses: PromiseResponse(current: 0, total: 2),
        deadline: "3시간 후"
      ),
      PromiseItem(
        id: "2",
        title: "저녁 식사",
        emoji: "🍽️",
        time: "오후 7:00",
        date: "오늘",
        location: "이탈리안 레스토랑",
        distance: "2.5km",
        with: "지민",
        status: .confirmed,
        responses: PromiseResponse(current: 2, total: 2),
        deadline: nil
      ),
      PromiseItem(
        id: "3",
        title: "영화 보기",
        emoji: "🎬",
        time: "오후 3:00",
        date: "내일",
        location: "CGV 강남",
        distance: "3.1km",
        with: "지민",
        status: .sent,
        responses: PromiseResponse(current: 1, total: 2),
        deadline: nil
      ),
    ])
    return state
  }

  public static var loading: Self {
    var state = Self(
      currentUser: .init(
        id: "",
        email: "",
        nickname: ""
      )
    )
    state.currentGroup = .init(
      id: "1",
      emoji: "👥",
      title: "지민과 나",
      memberCount: 2
    )
    state.promisesState = .loading
    return state
  }
}
