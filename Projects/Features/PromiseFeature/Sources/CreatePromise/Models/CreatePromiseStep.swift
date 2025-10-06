import Foundation

public enum CreatePromiseStep: Int, CaseIterable {
  case first
  case second
  case third
  
  mutating func next() {
    self += 1
  }
  
  mutating func previous() {
    self -= 1
  }
  
  // 현재 step에 정수를 더해서 다음 step으로 이동
  static func + (lhs: CreatePromiseStep, rhs: Int) -> CreatePromiseStep {
    let all = CreatePromiseStep.allCases
    let newIndex = min(max(lhs.rawValue + rhs, 0), all.count - 1)
    return all[newIndex]
  }
  
  // 현재 step에서 정수를 빼서 이전 step으로 이동
  static func - (lhs: CreatePromiseStep, rhs: Int) -> CreatePromiseStep {
    return lhs + (-rhs)
  }
  
  static func += (lhs: inout CreatePromiseStep, rhs: Int) {
    lhs = lhs + rhs
  }
  
  static func -= (lhs: inout CreatePromiseStep, rhs: Int) {
    lhs = lhs - rhs
  }
}
