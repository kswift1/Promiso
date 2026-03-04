import Foundation

/// 개인 일정 생성 2단계
public enum CreatePersonalEventStep: Int, CaseIterable, Equatable, Sendable {
  case essential  // 제목 + 시작 시간 + 종료 시간
  case details    // 장소 + 알림 + 메모 + 사진
}

extension CreatePersonalEventStep {
  mutating func next() {
    guard let next = Self(rawValue: rawValue + 1) else { return }
    self = next
  }

  mutating func previous() {
    guard let prev = Self(rawValue: rawValue - 1) else { return }
    self = prev
  }
}
