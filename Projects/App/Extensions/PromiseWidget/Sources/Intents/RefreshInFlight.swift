import Foundation

/// In-flight 중복 요청 합류
/// 같은 순간에 여러 perform()이 겹치면 하나로 합침
actor RefreshInFlight {
  static let shared = RefreshInFlight()

  private var task: Task<Void, Never>?

  /// 이미 실행 중이면 합류, 아니면 새로 실행
  func run(_ work: @escaping @Sendable () async -> Void) async {
    if let existingTask = task {
      // 이미 실행 중 → 완료 대기 후 리턴
      await existingTask.value
      return
    }

    let newTask = Task {
      await work()
    }
    task = newTask
    await newTask.value
    task = nil
  }
}
