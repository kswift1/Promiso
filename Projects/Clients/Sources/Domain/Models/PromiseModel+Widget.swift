import Foundation
import PromisoShared

// MARK: - PromiseModel → WidgetPromiseData 변환

extension WidgetPromiseData {
  /// PromiseModel에서 WidgetPromiseData 생성
  public init(from model: PromiseModel) {
    self.init(
      id: model.id,
      title: model.title,
      emoji: model.displayEmoji,
      startAt: model.startAt,
      endAt: model.endAt,
      location: model.location?.name,
      groupId: model.groupId,
      groupName: model.group?.name,
      isConfirmed: model.isConfirmed,
      participantCount: model.votes.acceptedCount
    )
  }
}

extension Array where Element == PromiseModel {
  /// PromiseModel 배열을 WidgetPromiseData 배열로 변환
  public func toWidgetData() -> [WidgetPromiseData] {
    self.map { WidgetPromiseData(from: $0) }
  }
}
