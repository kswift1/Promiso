import Foundation
import PromisoShared

// MARK: - PersonalEventModel -> WidgetPromiseData 변환

extension WidgetPromiseData {
  /// PersonalEventModel에서 WidgetPromiseData(type: .personal) 생성
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
  /// PersonalEventModel 배열을 WidgetPromiseData 배열로 변환
  public func toWidgetData() -> [WidgetPromiseData] {
    self.map { WidgetPromiseData(from: $0) }
  }
}
