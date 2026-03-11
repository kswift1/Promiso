import Foundation
import PromisoShared

// MARK: - ScheduleModel → WidgetScheduleData 변환

extension WidgetScheduleData {
  /// ScheduleModel에서 WidgetScheduleData 생성
  public init(from model: ScheduleModel) {
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

extension Array where Element == ScheduleModel {
  /// ScheduleModel 배열을 WidgetScheduleData 배열로 변환
  public func toWidgetData() -> [WidgetScheduleData] {
    self.map { WidgetScheduleData(from: $0) }
  }
}
