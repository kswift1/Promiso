import Foundation
import PromisoShared

// MARK: - PersonalEventModel -> WidgetScheduleData 변환

extension WidgetScheduleData {
  /// PersonalEventModel에서 WidgetScheduleData(type: .personal) 생성
  public init(from model: PersonalEventModel) {
    self.init(
      type: .personal,
      id: model.id,
      title: model.title,
      emoji: model.displayEmoji,
      startAt: model.startAt,
      endAt: model.endAt,
      location: model.location?.name
    )
  }
}

extension Array where Element == PersonalEventModel {
  /// PersonalEventModel 배열을 WidgetScheduleData 배열로 변환
  public func toWidgetData() -> [WidgetScheduleData] {
    self.map { WidgetScheduleData(from: $0) }
  }
}
